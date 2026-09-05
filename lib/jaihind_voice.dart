/// Voice notes for the Jaihind school apps.
///
/// One implementation, shared by the parent and teacher apps, so the two
/// cannot drift apart on what a recording is allowed to be -- the five-minute
/// ceiling, the too-short threshold, the slide-to-cancel distance and the
/// waveform's storage format are decisions that must be identical at both ends
/// of a conversation.
///
/// Nothing here knows about a school, a thread or an API. Recording produces a
/// file and a waveform; sending it is the app's business.
library;

// Everything a listener needs comes from the playback package, re-exported
// so an app that records does not have to import two things.
export 'package:jaihind_voice_player/jaihind_voice_player.dart';

export 'src/recording_bars.dart';
export 'src/voice_gesture.dart';
export 'src/voice_record_button.dart';
export 'src/voice_recorder_service.dart';
export 'src/voice_recording.dart';
