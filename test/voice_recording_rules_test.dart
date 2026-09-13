import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jaihind_voice/jaihind_voice.dart';

/// The rules of a voice recording.
///
/// Pulled away from the microphone on purpose: the limits, the waveform maths
/// and the clock are where the mistakes actually are, and a device cannot tell
/// you whether a five-minute recording is kept or a flat waveform is drawn as
/// a broken line.
void main() {
  group('the ceiling', () {
    test('is five minutes, as briefed', () {
      expect(VoiceRules.maxLength, const Duration(minutes: 5));
    });

    test('warns before it stops, not as it stops', () {
      // Being cut off mid-sentence with no notice loses the message.
      expect(
        VoiceRules.shouldWarn(const Duration(minutes: 4, seconds: 29)),
        isFalse,
      );
      expect(
        VoiceRules.shouldWarn(const Duration(minutes: 4, seconds: 30)),
        isTrue,
      );
      expect(VoiceRules.warnAfter, lessThan(VoiceRules.maxLength));
    });

    test('remaining never goes negative', () {
      // A timer that reads "-0:03 left" is worse than one that reads 0:00.
      expect(VoiceRules.remaining(const Duration(minutes: 6)), Duration.zero);
      expect(
        VoiceRules.remaining(const Duration(minutes: 4)),
        const Duration(minutes: 1),
      );
    });

    test('reaching it is a stop, not a discard', () {
      // Stated as its own case because the brief is explicit: at the limit the
      // recording is KEPT. Five minutes of a parent speaking must not vanish.
      expect(VoiceRules.reachedLimit(VoiceRules.maxLength), isTrue);
      expect(
        VoiceRules.reachedLimit(const Duration(minutes: 4, seconds: 59)),
        isFalse,
      );
    });
  });

  group('too short to send', () {
    test('a tap is not a message', () {
      expect(VoiceRules.isTooShort(const Duration(milliseconds: 200)), isTrue);
      expect(VoiceRules.isTooShort(const Duration(seconds: 2)), isFalse);
    });

    test('the threshold is under a second, not a fussy two', () {
      // "Yes mam" is a legitimate voice note and lasts about a second.
      expect(VoiceRules.minLength, lessThan(const Duration(seconds: 1)));
    });
  });

  group('the clock', () {
    test('pads the seconds', () {
      expect(VoiceRules.clock(Duration.zero), '0:00');
      expect(VoiceRules.clock(const Duration(seconds: 7)), '0:07');
      expect(VoiceRules.clock(const Duration(minutes: 1, seconds: 5)), '1:05');
      expect(VoiceRules.clock(const Duration(minutes: 4, seconds: 59)), '4:59');
    });
  });

  group('loudness to a bar height', () {
    test('silence is a low bar, not a flat line', () {
      // A row of zero-height bars reads as a broken recording rather than a
      // quiet one, so the floor is deliberately above zero.
      expect(VoiceRules.normaliseAmplitude(-60), greaterThan(0.0));
      expect(VoiceRules.normaliseAmplitude(-60), lessThan(0.2));
    });

    test('the loudest the device can hear is a full bar', () {
      expect(VoiceRules.normaliseAmplitude(0), 1.0);
    });

    test('speech lands somewhere in between', () {
      final quiet = VoiceRules.normaliseAmplitude(-35);
      final loud = VoiceRules.normaliseAmplitude(-10);

      expect(quiet, lessThan(loud));
      expect(loud, lessThan(1.0));
    });

    test('a device reporting nonsense does not crash the waveform', () {
      // Some Android builds return -infinity before the first sample.
      expect(
        VoiceRules.normaliseAmplitude(double.negativeInfinity),
        greaterThan(0.0),
      );
      expect(VoiceRules.normaliseAmplitude(double.nan), greaterThan(0.0));
    });
  });

  group('reducing samples to bars', () {
    test('always produces the same number of bars', () {
      for (final count in [0, 1, 5, 39, 40, 41, 2500]) {
        final samples = List<double>.filled(count, 0.5);
        expect(
          VoiceRules.downsample(samples).length,
          VoiceRules.waveformBars,
          reason: '$count samples',
        );
      }
    });

    test('averages rather than picks, so a short loud word survives', () {
      // 100 samples, 40 bars: each bar covers 2.5 samples, and bar 20 spans
      // indices 50-52. The shout goes at 51 ON PURPOSE -- index 50 is that
      // bar's FIRST sample, so a version that picked the first value instead
      // of averaging would still have found it and this test would have
      // proved nothing. It did exactly that until a mutation caught it.
      final samples = List<double>.filled(100, 0.1);
      samples[51] = 1.0;

      final bars = VoiceRules.downsample(samples);

      expect(
        bars.any((b) => b > 0.1),
        isTrue,
        reason: 'a loud syllable between two picks was lost',
      );
    });

    test('a silent recording is bars, not an empty list', () {
      expect(VoiceRules.downsample(const []).length, VoiceRules.waveformBars);
    });
  });

  group('storing the waveform', () {
    test('survives the round trip', () {
      final bars = [0.06, 0.25, 0.5, 0.75, 1.0];
      final decoded = VoiceRules.decodeWaveform(
        VoiceRules.encodeWaveform(bars),
      );

      expect(decoded.length, bars.length);
      for (var i = 0; i < bars.length; i++) {
        expect(decoded[i], closeTo(bars[i], 0.02));
      }
    });

    test('is small enough to travel with every message', () {
      // Forty floats as JSON runs past 200 bytes; this is 80 and rides along
      // on every message in a thread.
      final bars = List<double>.filled(VoiceRules.waveformBars, 0.5);

      expect(
        VoiceRules.encodeWaveform(bars).length,
        VoiceRules.waveformBars * 2,
      );
    });

    test(
      'a missing or malformed waveform gives an empty list, not a crash',
      () {
        // A note from the teacher app carries none. The bubble then draws a
        // neutral pattern, which is honest: we do not know its shape.
        for (final raw in [null, '', '   ', 'abc', '123', 'zz11']) {
          expect(VoiceRules.decodeWaveform(raw), isEmpty, reason: '$raw');
        }
      },
    );

    test('every stored value stays inside the drawable range', () {
      final decoded = VoiceRules.decodeWaveform(
        VoiceRules.encodeWaveform([0.0, 2.0, -1.0]),
      );

      for (final v in decoded) {
        expect(v, inInclusiveRange(0.0, 1.0));
      }
    });
  });

  group('a recording must not outlive the screen it belongs to', () {
    test('the app going away throws the recording away', () {
      // A live microphone with nothing on screen is one stray tap away from
      // sending whatever it picked up. It happened: an unattended locked
      // recording ran while an app was in the background and fourteen seconds
      // of an empty room reached a family.
      expect(VoiceRules.abandonsRecording(AppLifecycleState.paused), isTrue);
      expect(VoiceRules.abandonsRecording(AppLifecycleState.hidden), isTrue);
      expect(VoiceRules.abandonsRecording(AppLifecycleState.detached), isTrue);
    });

    test('a glance at a notification does not', () {
      // On iOS `inactive` fires for the notification shade and for a banner
      // passing over the app. Discarding a half-spoken message because
      // somebody looked at a notification would be its own bug.
      expect(VoiceRules.abandonsRecording(AppLifecycleState.inactive), isFalse);
    });

    test('the app being in front certainly does not', () {
      expect(VoiceRules.abandonsRecording(AppLifecycleState.resumed), isFalse);
    });

    test('every state has an answer', () {
      // A new lifecycle state must not silently default to "keep recording".
      for (final state in AppLifecycleState.values) {
        expect(() => VoiceRules.abandonsRecording(state), returnsNormally,
            reason: '$state');
      }
    });
  });
}
