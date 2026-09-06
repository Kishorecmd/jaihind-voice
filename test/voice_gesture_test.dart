import 'package:flutter_test/flutter_test.dart';

import 'package:jaihind_voice/jaihind_voice.dart';

/// Where a drag from the microphone leads.
///
/// The asymmetry throughout is deliberate and worth stating once: an
/// accidental CANCEL costs a parent a recording they must make again, and an
/// accidental SEND costs them a message they cannot withdraw. Neither is free,
/// so the thresholds sit where a deliberate slide is unmistakable and a
/// hesitant one does nothing.
void main() {
  group('sliding left to cancel', () {
    test('a thumb wobble is not a cancel', () {
      // Speaking while holding a phone moves the thumb a few pixels. If that
      // discarded the recording the feature would be unusable.
      expect(VoiceGesture.phaseFor(-8, 0), VoiceGesturePhase.holding);
      expect(VoiceGesture.phaseFor(-40, 0), VoiceGesturePhase.holding);
    });

    test('a deliberate slide is', () {
      expect(VoiceGesture.phaseFor(-90, 0), VoiceGesturePhase.willCancel);
      expect(VoiceGesture.phaseFor(-200, 0), VoiceGesturePhase.willCancel);
    });

    test('progress climbs to one and stops there', () {
      // Drives the animation. Past the threshold it must not keep growing, or
      // the label slides off the bar.
      expect(VoiceGesture.cancelProgress(0), 0);
      expect(VoiceGesture.cancelProgress(-45), closeTo(0.5, 0.01));
      expect(VoiceGesture.cancelProgress(-90), 1.0);
      expect(VoiceGesture.cancelProgress(-400), 1.0);
    });

    test('dragging right is not dragging left', () {
      expect(VoiceGesture.cancelProgress(60), 0);
      expect(VoiceGesture.phaseFor(120, 0), VoiceGesturePhase.holding);
    });
  });

  group('sliding up to lock', () {
    test('needs a real upward move', () {
      expect(VoiceGesture.phaseFor(0, -20), VoiceGesturePhase.holding);
      expect(VoiceGesture.phaseFor(0, -70), VoiceGesturePhase.willLock);
    });

    test('progress climbs to one and stops there', () {
      expect(VoiceGesture.lockProgress(-35), closeTo(0.5, 0.01));
      expect(VoiceGesture.lockProgress(-70), 1.0);
      expect(VoiceGesture.lockProgress(-999), 1.0);
    });

    test('dragging down does nothing', () {
      expect(VoiceGesture.lockProgress(90), 0);
      expect(VoiceGesture.phaseFor(0, 90), VoiceGesturePhase.holding);
    });
  });

  group('a diagonal drag', () {
    test('does not cancel while the finger is also heading for the lock', () {
      // Reaching for the lock is rarely straight up. Without the slop check a
      // parent aiming at the lock would silently lose the recording.
      expect(
        VoiceGesture.phaseFor(-95, -40),
        isNot(VoiceGesturePhase.willCancel),
      );
    });

    test('a left-leaning drag past the lock still locks, never sends', () {
      // -60 has not reached cancelDistance, so this is not a cancel. The old
      // fallback here was `holding`, which sent the note on release — the one
      // outcome a parent cannot undo.
      final phase = VoiceGesture.phaseFor(-60, -75);
      expect(phase, VoiceGesturePhase.willLock);
      expect(VoiceGesture.releaseSends(phase), isFalse);
    });

    test('a thumb that arcs while sliding to the bin never sends', () {
      // A slide to cancel pivots at the base of the thumb, so it arcs upward.
      // Each of these used to fall through to `holding` and send the note.
      for (final dy in <double>[-13, -20, -35, -60]) {
        expect(
          VoiceGesture.releaseSends(VoiceGesture.phaseFor(-120, dy)),
          isFalse,
          reason: 'dy=$dy released as a send',
        );
      }
    });

    test('sideways drift while reaching the lock still locks', () {
      for (final dx in <double>[-60, -25, -13, 13, 25]) {
        expect(
          VoiceGesture.phaseFor(dx, -90),
          VoiceGesturePhase.willLock,
          reason: 'dx=$dx did not lock',
        );
      }
    });

    test('when both are crossed, the further one wins', () {
      expect(VoiceGesture.phaseFor(-300, -75), VoiceGesturePhase.willCancel);
      expect(VoiceGesture.phaseFor(-95, -300), VoiceGesturePhase.willLock);
    });

    test('a dead heat locks rather than discards', () {
      // Keeping a recording the parent did not want costs one tap. Losing one
      // they did want costs the whole message.
      expect(VoiceGesture.phaseFor(-100, -100), VoiceGesturePhase.willLock);
    });
  });

  group('what releasing does', () {
    test('only a plain hold sends', () {
      expect(VoiceGesture.releaseSends(VoiceGesturePhase.holding), isTrue);
      for (final phase in [
        VoiceGesturePhase.willCancel,
        VoiceGesturePhase.willLock,
        VoiceGesturePhase.locked,
        VoiceGesturePhase.idle,
      ]) {
        expect(VoiceGesture.releaseSends(phase), isFalse, reason: '$phase');
      }
    });

    test('only a committed cancel discards', () {
      expect(
        VoiceGesture.releaseDiscards(VoiceGesturePhase.willCancel),
        isTrue,
      );
      expect(VoiceGesture.releaseDiscards(VoiceGesturePhase.holding), isFalse);
      // Releasing at the lock must NOT throw the recording away -- that is the
      // whole point of locking.
      expect(VoiceGesture.releaseDiscards(VoiceGesturePhase.willLock), isFalse);
    });
  });

  group('the button following the finger', () {
    test('trails rather than tracks', () {
      // Following one-to-one puts the button under the parent's own hand and
      // makes the gesture feel loose.
      expect(VoiceGesture.buttonOffset(-100).abs(), lessThan(100));
    });

    test('never runs away with the layout', () {
      expect(VoiceGesture.buttonOffset(-5000), greaterThanOrEqualTo(-60));
    });

    test('does not drift right when the finger does', () {
      expect(VoiceGesture.buttonOffset(200), 0);
    });
  });
}
