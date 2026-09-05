import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'voice_recording.dart';

/// Whether the microphone may be used, and if not, what to tell the parent.
enum MicPermission {
  granted,

  /// Refused this time. Asking again is reasonable.
  denied,

  /// Refused for good, or blocked by device policy. The system will not show
  /// a prompt again, so asking repeatedly does nothing and the parent has to
  /// be sent to Settings instead.
  permanentlyDenied,
}

/// Recording a voice note.
///
/// Owns the microphone, the temporary file and the loudness samples. It knows
/// nothing about the chat screen or the network: it hands back a finished
/// [VoiceRecording], or it deletes the file and hands back nothing.
///
/// Every exit path deletes the temporary file except the one that returns it,
/// because a recording left behind on a parent's phone is both clutter and a
/// small privacy problem.
class VoiceRecorderService {
  VoiceRecorderService({AudioRecorder? recorder})
    : _rec = recorder ?? AudioRecorder();

  final AudioRecorder _rec;

  String? _path;
  Timer? _sampler;
  final List<double> _samples = <double>[];
  DateTime? _startedAt;

  bool get isRecording => _path != null;

  /// Loudness so far, for the live waveform.
  List<double> get samples => List.unmodifiable(_samples);

  Duration get elapsed => _startedAt == null
      ? Duration.zero
      : DateTime.now().difference(_startedAt!);

  /// Asks for the microphone, distinguishing "not now" from "not ever".
  ///
  /// The distinction matters: the platform silently ignores a second request
  /// once a parent has refused permanently, so an app that keeps calling
  /// request() looks broken — the button does nothing and nothing explains
  /// why.
  Future<MicPermission> checkPermission() async {
    var status = await Permission.microphone.status;

    if (status.isGranted) return MicPermission.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return MicPermission.permanentlyDenied;
    }

    status = await Permission.microphone.request();

    if (status.isGranted) return MicPermission.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return MicPermission.permanentlyDenied;
    }

    return MicPermission.denied;
  }

  /// Opens the system settings page for this app.
  Future<void> openSettings() => openAppSettings();

  /// Begins recording. Returns false when the microphone was refused; the
  /// caller decides what to say, because only it knows which dialog fits.
  Future<bool> start() async {
    if (isRecording) return true;

    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _rec.start(
        // AAC in an m4a container: recorded natively by Android, played by
        // iOS without transcoding, accepted by the server's voice_note
        // category, and a fraction of the size of the uncompressed WAV the
        // brief rules out.
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          // Speech, not music. Five minutes lands near 2.4 MB, well inside the
          // server's ceiling, and sends over a phone's mobile data.
          bitRate: 64000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );

      _path = path;
      _startedAt = DateTime.now();
      _samples.clear();
      _startSampling();

      return true;
    } catch (_) {
      await _discard();

      return false;
    }
  }

  void _startSampling() {
    _sampler?.cancel();
    _sampler = Timer.periodic(VoiceRules.amplitudeInterval, (_) async {
      try {
        final amp = await _rec.getAmplitude();
        _samples.add(VoiceRules.normaliseAmplitude(amp.current));
      } catch (_) {
        // A device that will not report loudness still records perfectly well.
        // The waveform simply stays flat rather than the recording failing.
        _samples.add(0.06);
      }
    });
  }

  /// Stops and returns the recording, or null when there is nothing to send.
  ///
  /// [keepShort] is for the ceiling: a five-minute recording is kept whatever
  /// its length, because the parent has already spoken it.
  Future<VoiceRecording?> stop({bool keepShort = false}) async {
    if (_path == null) return null;

    final path = _path!;
    final took = elapsed;
    _sampler?.cancel();
    _path = null;
    _startedAt = null;

    try {
      await _rec.stop();
    } catch (_) {
      // Already stopped, or the platform lost it. The file may still be there.
    }

    final file = File(path);
    if (!await file.exists() || await file.length() == 0) {
      await _deleteQuietly(file);

      return null;
    }

    if (!keepShort && VoiceRules.isTooShort(took)) {
      // A mis-tap. Deleted rather than sent, and the caller says so out loud —
      // silently dropping it looks like a broken button.
      await _deleteQuietly(file);

      return null;
    }

    return VoiceRecording(
      path: path,
      duration: took,
      waveform: VoiceRules.downsample(_samples),
    );
  }

  /// Abandons the recording and removes the file. Used by slide-to-cancel and
  /// by the bin in locked mode.
  Future<void> cancel() => _discard();

  Future<void> _discard() async {
    final path = _path;
    _sampler?.cancel();
    _path = null;
    _startedAt = null;
    _samples.clear();

    if (path == null) return;

    try {
      await _rec.stop();
    } catch (_) {}
    await _deleteQuietly(File(path));
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _discard();
    try {
      await _rec.dispose();
    } catch (_) {}
  }
}
