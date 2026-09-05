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

    test('does not lock while the finger is clearly heading left', () {
      expect(
        VoiceGesture.phaseFor(-60, -75),
        isNot(VoiceGesturePhase.willLock),
      );
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
