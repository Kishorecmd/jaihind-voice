import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Draws a row of bars for a voice note.
///
/// Used twice: live while recording, where the bars are loudness arriving in
/// real time, and in the bubble afterwards, where the same stored bars are
/// filled up to the playback position.
///
/// When a note carries no waveform -- one from the teacher app, or from a
/// build older than this feature -- [bars] is empty and a neutral pattern is
/// drawn instead. That pattern is deliberately regular rather than
/// speech-shaped: it should not be mistakable for a real reading of audio
/// nobody measured.
class WaveformPainter extends CustomPainter {
  const WaveformPainter({
    required this.bars,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
    this.barWidth = 3,
    this.gap = 2,
  });

  final List<double> bars;

  /// 0..1. Bars to the left of this are drawn as played.
  final double progress;

  final Color playedColor;
  final Color unplayedColor;
  final double barWidth;
  final double gap;

  /// The stand-in for a note whose shape was never measured.
  static List<double> neutral(int count) => List<double>.generate(
    count,
    // A gentle repeating rise and fall. Regular on purpose: it reads as a
    // placeholder rather than as someone's voice.
    (i) => 0.35 + 0.25 * math.sin(i * 0.9),
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final slot = barWidth + gap;
    final count = math.max(1, (size.width / slot).floor());

    final source = bars.isNotEmpty ? bars : neutral(count);
    final mid = size.height / 2;
    final played = (count * progress.clamp(0.0, 1.0)).round();

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    for (var i = 0; i < count; i++) {
      // The stored bars and the drawable slots rarely match, so the waveform
      // is stretched across whatever width it is given rather than truncated.
      final value =
          source[((i / count) * source.length).floor().clamp(
            0,
            source.length - 1,
          )];

      // Never zero: a bar of no height reads as a gap in the recording.
      final half = math.max(
        1.5,
        (value.clamp(0.0, 1.0) * (size.height / 2 - 1)),
      );

      paint.color = i < played ? playedColor : unplayedColor;
      final x = i * slot + barWidth / 2;
      canvas.drawLine(Offset(x, mid - half), Offset(x, mid + half), paint);
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter old) =>
      old.progress != progress ||
      old.bars.length != bars.length ||
      old.playedColor != playedColor ||
      old.unplayedColor != unplayedColor;
}

/// A waveform sized to its box.
class Waveform extends StatelessWidget {
  const Waveform({
    super.key,
    required this.bars,
    required this.playedColor,
    required this.unplayedColor,
    this.progress = 0,
    this.height = 26,
  });

  final List<double> bars;
  final double progress;
  final Color playedColor;
  final Color unplayedColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: WaveformPainter(
          bars: bars,
          progress: progress,
          playedColor: playedColor,
          unplayedColor: unplayedColor,
        ),
      ),
    );
  }
}
