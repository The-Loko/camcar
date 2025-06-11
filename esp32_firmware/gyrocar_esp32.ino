/*
  GyroCar ESP32 Firmware
  
  This firmware allows an ESP32 to receive gyroscope data from a mobile app
  via either WiFi or Bluetooth, and control DC motors accordingly.
  
  Features:
  - Dual connectivity mode (WiFi or Bluetooth)
  - JSON parsing for gyroscope data
  - DC motor control with L298N driver
  - Obstacle avoidance with HC-SR04 ultrasonic sensor
  - Status LED indicators
  
  Hardware:
  - ESP32 board
  - L298N motor driver
  - HC-SR04 ultrasonic sensor
  - DC motors (2)
  - Optional status LEDs
  - 9V or 12V battery for motors
*/

#include <BluetoothSerial.h> // For Bluetooth connectivity

// Check if Bluetooth is properly supported
#if !defined(CONFIG_BT_ENABLED) || !defined(CONFIG_BLUEDROID_ENABLED)
  #error Bluetooth is not enabled! Please run `make menuconfig` to enable it
#endif

// Add forward declarations for functions used before they’re defined
void stopMotors();
void blinkLED(int pin, int times, int delayMs);
void handleBluetoothData();
void checkForObstacles();
void checkTimeout();
void handleObstacleAvoidance();
void processGyroData(String jsonData);
void controlMotors(float x, float y);
void setMotors(int leftSpeed, int rightSpeed, bool leftForward, bool rightForward);

// Motor control pins for L298N
#define MOTOR_A_IN1 15  // Input 1 for motor A direction
#define MOTOR_A_IN2 26  // Input 2 for motor A direction
#define MOTOR_B_IN3 5   // Input 3 for motor B direction
#define MOTOR_B_IN4 18  // Input 4 for motor B direction
#define MOTOR_A_ENA 4   // Enable pin for motor A (PWM)
#define MOTOR_B_ENB 19  // Enable pin for motor B (PWM)

// HC-SR04 Ultrasonic Sensor pins
#define TRIG_PIN 13     // Trigger pin
#define ECHO_PIN 12     // Echo pin

// Status LEDs
#define LED_STATUS 2    // Built-in LED for status
#define LED_WIFI   27   // LED for WiFi connection status
#define LED_BT     14   // LED for Bluetooth connection status

// PWM properties
#define PWM_FREQ 5000   // PWM frequency
#define PWM_RESOLUTION 8 // 8-bit resolution (0-255)
#define PWM_A_CHANNEL 0  // PWM channel for motor A
#define PWM_B_CHANNEL 1  // PWM channel for motor B

// Obstacle avoidance parameters
#define MIN_DISTANCE 20 // Minimum distance in cm before stopping/avoiding
#define AVOID_DURATION 1000 // Duration of avoidance maneuver in ms

// Connection status
bool btConnected = false;

// Current motor values
int leftMotorSpeed = 0;
int rightMotorSpeed = 0;
bool leftMotorForward = true;
bool rightMotorForward = true;

// Obstacle avoidance state
bool obstacleDetected = false;
unsigned long obstacleDetectedTime = 0;
bool avoidanceManeuverActive = false;

// Create Bluetooth Serial object
BluetoothSerial SerialBT;

// Last activity timestamp
unsigned long lastActivityTime = 0;
const unsigned long TIMEOUT_MS = 3000; // 3 seconds timeout

// Ultrasonic sensor measurements
long duration;
float distance;
unsigned long lastUltrasonicReadTime = 0;
const unsigned long ULTRASONIC_INTERVAL = 100; // Read every 100ms

void setup() {
  // Initialize Serial port for debugging
  Serial.begin(115200);
  Serial.println("GyroCar ESP32 Firmware Starting...");
  
  // Initialize status LEDs
  pinMode(LED_STATUS, OUTPUT);
  pinMode(LED_WIFI, OUTPUT);
  pinMode(LED_BT, OUTPUT);
  
  // Initialize motor control pins
  pinMode(MOTOR_A_IN1, OUTPUT);
  pinMode(MOTOR_A_IN2, OUTPUT);
  pinMode(MOTOR_B_IN3, OUTPUT);
  pinMode(MOTOR_B_IN4, OUTPUT);
  
  // Configure PWM for motor speed control
  ledcSetup(PWM_A_CHANNEL, PWM_FREQ, PWM_RESOLUTION);
  ledcSetup(PWM_B_CHANNEL, PWM_FREQ, PWM_RESOLUTION);
  ledcAttachPin(MOTOR_A_ENA, PWM_A_CHANNEL);
  ledcAttachPin(MOTOR_B_ENB, PWM_B_CHANNEL);
  
  // Initialize HC-SR04 ultrasonic sensor pins
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  
  // Stop motors initially
  stopMotors();
  
  // Start Bluetooth with the name "GyroCar"
  SerialBT.begin("GyroCar");
  
  // All systems initialized
  blinkLED(LED_STATUS, 3, 200); // Blink status LED 3 times
}

void loop() {
  // Handle Bluetooth data
  if (SerialBT.available()) {
    handleBluetoothData();
  }
  
  // Check for obstacles regularly
  if (millis() - lastUltrasonicReadTime > ULTRASONIC_INTERVAL) {
    checkForObstacles();
    lastUltrasonicReadTime = millis();
  }
  
  // Check for connection timeout
  checkTimeout();
  
  // Handle obstacle avoidance if needed
  handleObstacleAvoidance();
}

// Handle gyroscope data received via Bluetooth
void handleBluetoothData() {
  String jsonData = "";
  
  // Read until we get a complete line
  while (SerialBT.available()) {
    char c = SerialBT.read();
    jsonData += c;
    
    if (c == '\n') {
      break;
    }
  }
  
  if (jsonData.length() > 0) {
    btConnected = true;
    digitalWrite(LED_BT, HIGH); // Turn on BT LED
    
    processGyroData(jsonData);
    lastActivityTime = millis();
    
    // Send acknowledgement with obstacle data
    String response = "OK";
    if (obstacleDetected) {
      response += " OBSTACLE:" + String(distance);
    }
    SerialBT.println(response);
  }
}

// Process gyroscope data and control motors
void processGyroData(String jsonData) {
  // Print raw data for debugging
  Serial.print("Received data: ");
  Serial.println(jsonData);

  // Manual parsing: expect {"x":<num>,"y":<num>,"z":<num>}
  char buf[64];
  jsonData.toCharArray(buf, sizeof(buf));
  float x=0, y=0, z=0;
  if (sscanf(buf, "{\"x\":%f,\"y\":%f,\"z\":%f}", &x, &y, &z) != 3) {
    Serial.println("JSON parse error");
    return;
  }

  // Debug output
  Serial.print("X: "); Serial.print(x);
  Serial.print(", Y: "); Serial.print(y);
  Serial.print(", Z: "); Serial.println(z);

  // Don't control motors if obstacle avoidance is active
  if (!avoidanceManeuverActive) {
    // Map gyro values to motor speeds
    controlMotors(x, y);
  }
  
  // Blink status LED
  digitalWrite(LED_STATUS, !digitalRead(LED_STATUS));
}

// Control motors based on gyroscope data
void controlMotors(float x, float y) {
  // Y controls forward/backward
  // X controls left/right turning
  
  // Determine direction and speed
  int speedValue = abs(y) * 255;  // Convert to 0-255 range
  speedValue = constrain(speedValue, 0, 255);
  
  int turnValue = abs(x) * 100;  // Turning effect (0-100)
  turnValue = constrain(turnValue, 0, 100);
  
  // Forward/Backward direction
  bool goingForward = (y < 0);
  
  // If obstacle detected, prevent forward motion
  if (obstacleDetected && goingForward) {
    speedValue = 0;
  }
  
  // Calculate motor speeds with turning effect
  if (x < 0) { // Turning left
    leftMotorSpeed = speedValue * (1 - turnValue/100.0);
    rightMotorSpeed = speedValue;
  } else if (x > 0) { // Turning right
    leftMotorSpeed = speedValue;
    rightMotorSpeed = speedValue * (1 - turnValue/100.0);
  } else { // Going straight
    leftMotorSpeed = speedValue;
    rightMotorSpeed = speedValue;
  }
  
  // Set the direction for both motors
  leftMotorForward = goingForward;
  rightMotorForward = goingForward;
  
  // Apply motor settings
  setMotors(leftMotorSpeed, rightMotorSpeed, leftMotorForward, rightMotorForward);
  
  // Debug output
  Serial.print("Motors: L=");
  Serial.print(leftMotorSpeed);
  Serial.print(leftMotorForward ? " FWD" : " REV");
  Serial.print(" R=");
  Serial.print(rightMotorSpeed);
  Serial.println(rightMotorForward ? " FWD" : " REV");
}

// Set motors with specified speed and direction
void setMotors(int leftSpeed, int rightSpeed, bool leftForward, bool rightForward) {
  // Set left motor direction
  digitalWrite(MOTOR_A_IN1, leftForward ? HIGH : LOW);
  digitalWrite(MOTOR_A_IN2, leftForward ? LOW : HIGH);
  
  // Set right motor direction
  digitalWrite(MOTOR_B_IN3, rightForward ? HIGH : LOW);
  digitalWrite(MOTOR_B_IN4, rightForward ? LOW : HIGH);
  
  // Set motor speeds
  ledcWrite(PWM_A_CHANNEL, leftSpeed);
  ledcWrite(PWM_B_CHANNEL, rightSpeed);
}

// Stop both motors
void stopMotors() {
  digitalWrite(MOTOR_A_IN1, LOW);
  digitalWrite(MOTOR_A_IN2, LOW);
  digitalWrite(MOTOR_B_IN3, LOW);
  digitalWrite(MOTOR_B_IN4, LOW);
  
  ledcWrite(PWM_A_CHANNEL, 0);
  ledcWrite(PWM_B_CHANNEL, 0);
  
  leftMotorSpeed = 0;
  rightMotorSpeed = 0;
  
  Serial.println("Motors stopped");
}

// Measure distance using HC-SR04 ultrasonic sensor
void checkForObstacles() {
  // Clear the TRIG_PIN
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  
  // Set the TRIG_PIN HIGH for 10 microseconds
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  
  // Read the ECHO_PIN, return the sound wave travel time in microseconds
  duration = pulseIn(ECHO_PIN, HIGH, 30000); // Timeout after 30ms (about 5m)
  
  // Calculate the distance
  // Speed of sound = 343 m/s = 0.0343 cm/µs
  // Distance = (Time × Speed of sound) / 2
  distance = (duration * 0.0343) / 2;
  
  // Check if we have an obstacle
  if (distance > 0 && distance < MIN_DISTANCE) {
    if (!obstacleDetected) {
      Serial.print("Obstacle detected at ");
      Serial.print(distance);
      Serial.println(" cm");
      
      obstacleDetected = true;
      obstacleDetectedTime = millis();
      
      // Stop if moving forward
      if (leftMotorForward || rightMotorForward) {
        stopMotors();
        avoidanceManeuverActive = true;
      }
    }
  } else {
    if (obstacleDetected) {
      Serial.println("Obstacle cleared");
      obstacleDetected = false;
    }
  }
}

// Handle obstacle avoidance maneuver
void handleObstacleAvoidance() {
  if (avoidanceManeuverActive) {
    // Simple avoidance: back up slightly, then turn right
    unsigned long currentTime = millis();
    unsigned long elapsedTime = currentTime - obstacleDetectedTime;
    
    if (elapsedTime < 500) {
      // Back up for 500ms
      setMotors(150, 150, false, false);
    } else if (elapsedTime < 1000) {
      // Turn right for 500ms
      setMotors(150, 150, true, false);
    } else {
      // Maneuver complete
      avoidanceManeuverActive = false;
      stopMotors();
    }
  }
}

// Check if there's been no activity and stop motors
void checkTimeout() {
  if (millis() - lastActivityTime > TIMEOUT_MS && btConnected) {
    // No activity for the timeout period
    if (leftMotorSpeed > 0 || rightMotorSpeed > 0) {
      Serial.println("Connection timeout, stopping motors");
      stopMotors();
    }
  }
}

// Blink an LED n times with a specified delay
void blinkLED(int pin, int times, int delayMs) {
  for (int i = 0; i < times; i++) {
    digitalWrite(pin, HIGH);
    delay(delayMs);
    digitalWrite(pin, LOW);
    delay(delayMs);
  }
}
