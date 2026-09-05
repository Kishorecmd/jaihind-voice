# jaihind_voice

Voice notes for the Jaihind school apps: recording, the hold-to-talk gesture,
the waveform and the player.

Shared by the **parent app** and the **teacher app** so the two ends of a
conversation cannot drift apart. The five-minute ceiling, the too-short
threshold, the slide-to-cancel distance and the waveform's storage format are
decisions that have to be identical at both ends, and two copies of them would
not stay identical for long.

## What is in here

| file | what it decides |
|---|---|
| `voice_recording.dart` | the limits, loudness to bar height, the waveform's stored form |
| `voice_gesture.dart` | where a drag from the microphone leads |
| `voice_recorder_service.dart` | the microphone, the temp file, the permission |
| `waveform.dart` | drawing bars, live or played |
| `recording_bars.dart` | the held bar, the lock hint, the locked bar |
| `voice_record_button.dart` | the gesture host |
| `voice_note_player.dart` | playing one back |
| `voice_theme.dart` | the colour boundary |

Nothing here knows about a school, a thread, or an API. Recording produces a
file and a waveform; sending it is the app's business.

## Colours

Taken from the surrounding app's own `ColorScheme` via `VoiceTheme.of(context)`.
The parent app's violet and the teacher app's indigo both come out right with
no configuration, and a dark theme follows for free. Pass a `VoiceTheme` only
to override a role.

## Depending on it

Both apps use a path dependency, because they are separate repositories that
sit side by side on disk:

```yaml
dependencies:
  jaihind_voice:
    path: ../jaihind-voice
```

That works on the dev laptop and in CI only if the checkout preserves the
layout. **The durable form is a git dependency**, which needs this package
pushed to a remote first — worth doing before anyone else clones the apps.

## Tests

`flutter test` — 58 of them, and none need a microphone. The limits, the
gesture thresholds and the waveform maths are all pure, which is deliberate:
they are where the mistakes are, and a device cannot tell you whether a
five-minute recording is kept or a flat waveform reads as a broken line.
