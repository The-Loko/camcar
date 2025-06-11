import 'package:flutter/material.dart';
import 'package:mjpeg/mjpeg.dart';

/// Widget to display MJPEG stream
class MjpegViewer extends StatelessWidget {
  final String stream;
  final bool isLive;

  const MjpegViewer({Key? key, required this.stream, this.isLive = true}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Mjpeg(
      stream: stream,
      isLive: isLive,
      error: (context, error, stack) => Center(
        child: Text(
          'Error loading stream',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
      loading: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
