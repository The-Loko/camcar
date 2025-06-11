import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:mjpeg/mjpeg.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_joystick/flutter_joystick.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Bluetooth connection and streaming
  BluetoothConnection? _connection;
  bool isBtConnected = false;
  String cameraUrl = 'http://192.168.4.1:80/stream';
  double distance = 0, temperature = 0, humidity = 0;

  @override
  void initState() {
    super.initState();
    _connectBluetooth();
  }

  Future<void> _connectBluetooth() async {
    List<BluetoothDevice> devices = await FlutterBluetoothSerial.instance.getBondedDevices();
    BluetoothDevice? target =
        devices.firstWhere((d) => d.name == 'GyroCar', orElse: () => null);
    if (target != null) {
      BluetoothConnection.connect(target.address).then((conn) {
        _connection = conn;
        setState(() => isBtConnected = true);
        conn.input?.listen(_onDataReceived).onDone(() {
          setState(() => isBtConnected = false);
        });
      }).catchError((_) {});
    }
  }

  void _onDataReceived(Uint8List data) {
    String str = utf8.decode(data).trim();
    if (str.startsWith('DIST:')) {
      var parts = str.split(',');
      for (var p in parts) {
        if (p.startsWith('DIST:')) distance = double.tryParse(p.split(':')[1]) ?? 0;
        else if (p.startsWith('TEMP:')) temperature = double.tryParse(p.split(':')[1]) ?? 0;
        else if (p.startsWith('HUM:')) humidity = double.tryParse(p.split(':')[1]) ?? 0;
      }
      setState(() {});
    }
  }

  void _sendJoystick(Offset pos) {
    if (isBtConnected && _connection != null) {
      var msg = jsonEncode({'x': pos.dx, 'y': pos.dy});
      _connection!.output.add(utf8.encode(msg + '\n'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Video stream section
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Mjpeg(
                  stream: cameraUrl,
                  isLive: true,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Parameters section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildParameter('Distance', distance.toStringAsFixed(1)),
                _buildParameter('Temp', temperature.toStringAsFixed(1)),
                _buildParameter('Hum', humidity.toStringAsFixed(1)),
              ],
            ),
            const SizedBox(height: 20),
            // Controls section
            Row(
              children: [
                // Joystick
                Expanded(
                  child: Joystick(
                    mode: JoystickMode.all,
                    listener: (details) {
                      _sendJoystick(Offset(details.x, details.y));
                    },
                  ),
                ),
                const SizedBox(width: 30),
                // Buttons
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        shape: const StadiumBorder(),
                        primary: Colors.red,
                      ),
                      child: const Text('Power'),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        shape: const StadiumBorder(),
                        primary: Colors.blue,
                      ),
                      child: const Text('Mode'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParameter(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      ],
    );
  }
}
