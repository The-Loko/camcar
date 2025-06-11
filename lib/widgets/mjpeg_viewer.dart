import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

/// Widget to display MJPEG stream
class MjpegViewer extends StatelessWidget {
  final String stream;
  final bool isLive;

  const MjpegViewer({super.key, required this.stream, this.isLive = true});

  @override
  Widget build(BuildContext context) {
    return Mjpeg(
      stream: stream,
      isLive: isLive,
      error: (context, error, stack) => const Center(
        child: Text(
          'Error loading stream',
        ),
      ),
      loading: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
