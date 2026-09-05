import 'dart:io';
import 'dart:math' as math;

/// The rules of a voice recording, with no plugins attached.
///
/// Separated from the recorder itself so they can be tested without a
/// microphone: the limits, the waveform maths and the clock are where the
/// mistakes actually live, and none of them need a device to check.

/// Why a recording ended.
enum VoiceRecordingEnd {
  /// The parent finished normally.
  released,

  /// They slid away to cancel. The file is deleted, nothing is sent.
  cancelled,

  /// Too short to be a message — a mis-tap, not speech.
  tooShort,

  /// The ceiling was reached. The recording is KEPT: the parent has spoken
  /// for five minutes and must not lose it.
  limitReached,
}

/// A finished recording, ready to send.
class VoiceRecording {
  const VoiceRecording({
    required this.path,
    required this.duration,
    required this.waveform,
  });

  final String path;
  final Duration duration;

  /// Loudness over time, 0..1, sampled while recording.
  ///
  /// Real amplitude from the microphone rather than decoration. A note that
  /// arrives without one — from another app, or an older build — is drawn with
  /// a neutral pattern instead, and that is honest: we do not know its shape.
  final List<double> waveform;

  /// Removes the temporary file.
  ///
  /// Called when a recording is discarded, and after it has been uploaded.
  /// Recordings left behind accumulate in the app's temp directory, and a
  /// recording of someone's voice is not a thing to leave lying on a phone.
  ///
  /// Never throws: failing to delete a temp file is not worth interrupting
  /// anyone over, and the platform clears the directory eventually.
  Future<void> delete() async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}

class VoiceRules {
  /// Five minutes, per the brief. Configurable in one place.
  static const Duration maxLength = Duration(minutes: 5);

  /// The last stretch, where the parent is told how long is left rather than
  /// simply being cut off mid-sentence.
  static const Duration warnAfter = Duration(minutes: 4, seconds: 30);

  /// Below this it is a mis-tap. An empty note cannot be unsent, and it costs
  /// the reader a tap to find out it was nothing.
  static const Duration minLength = Duration(milliseconds: 900);

  /// How many bars a stored waveform is reduced to.
  ///
  /// Enough to look like speech, small enough to sit in a database column and
  /// travel with every message in a thread.
  static const int waveformBars = 40;

  /// How often loudness is sampled while recording.
  static const Duration amplitudeInterval = Duration(milliseconds: 120);

  static bool isTooShort(Duration d) => d < minLength;

  static bool shouldWarn(Duration elapsed) => elapsed >= warnAfter;

  static bool reachedLimit(Duration elapsed) => elapsed >= maxLength;

  /// What is left before the recording stops itself, never negative.
  static Duration remaining(Duration elapsed) {
    final left = maxLength - elapsed;

    return left.isNegative ? Duration.zero : left;
  }

  /// "0:07", and "1:05" rather than "1:5".
  static String clock(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');

    return '$m:$s';
  }

  /// Microphone loudness in dBFS, as 0..1.
  ///
  /// The plugin reports decibels below full scale: 0 is the loudest the device
  /// can hear and about -60 is silence. Anything quieter is floored rather
  /// than allowed to go negative, and a bar is never drawn at exactly zero
  /// height — a flat line reads as a broken recording rather than a quiet one.
  static double normaliseAmplitude(double dbfs, {double floor = -45}) {
    if (dbfs.isNaN || dbfs.isInfinite) return 0.06;

    final clamped = dbfs.clamp(floor, 0.0).toDouble();
    final value = (clamped - floor) / (0 - floor);

    return value.clamp(0.06, 1.0).toDouble();
  }

  /// Reduces however many samples were taken to a fixed number of bars.
  ///
  /// Averaged rather than sampled, so a short loud syllable is not lost
  /// between two picks and the shape still resembles what was said.
  static List<double> downsample(
    List<double> samples, {
    int bars = waveformBars,
  }) {
    if (bars <= 0) return const [];
    if (samples.isEmpty) return List<double>.filled(bars, 0.06);
    if (samples.length <= bars) {
      return [...samples, ...List<double>.filled(bars - samples.length, 0.06)];
    }

    final out = <double>[];
    final size = samples.length / bars;
    for (var i = 0; i < bars; i++) {
      final start = (i * size).floor();
      final end = math.min(((i + 1) * size).ceil(), samples.length);
      var sum = 0.0;
      for (var j = start; j < end; j++) {
        sum += samples[j];
      }
      out.add(end > start ? sum / (end - start) : 0.06);
    }

    return out;
  }

  /// The compact form stored against the message: two digits per bar.
  ///
  /// Deliberately not JSON. This travels on every message in a thread, and a
  /// list of forty floats spelled out costs more than the audio's own header.
  static String encodeWaveform(List<double> bars) => bars
      .map((b) => (b.clamp(0.0, 1.0) * 99).round().toString().padLeft(2, '0'))
      .join();

  /// Reads back what [encodeWaveform] wrote. Anything malformed gives an empty
  /// list, and the bubble then draws its neutral pattern rather than throwing.
  static List<double> decodeWaveform(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty || text.length.isOdd) return const [];

    final out = <double>[];
    for (var i = 0; i < text.length; i += 2) {
      final n = int.tryParse(text.substring(i, i + 2));
      if (n == null) return const [];
      out.add((n / 99).clamp(0.0, 1.0));
    }

    return out;
  }
}
