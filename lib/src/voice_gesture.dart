import 'dart:math' as math;

/// What holding the microphone is currently doing.
enum VoiceGesturePhase {
  /// Not recording.
  idle,

  /// Held, recording, finger still down. Releasing sends.
  holding,

  /// Dragged far enough left that releasing will discard instead.
  willCancel,

  /// Dragged far enough up that releasing will lock rather than send.
  willLock,

  /// Recording hands-free. The finger is gone; send and bin are buttons.
  locked,

  /// Locked and paused. The recording is kept and can be resumed.
  lockedPaused,
}

/// Where a drag from the microphone button leads.
///
/// Pure geometry, deliberately: the thresholds and the transitions are the
/// part that goes wrong, and testing them by hand on a phone means recording
/// something every time. The widget owns the finger; this owns the meaning.
class VoiceGesture {
  /// How far left before releasing discards instead of sending.
  ///
  /// Comfortably further than a thumb wobbles while speaking, because the cost
  /// of an accidental cancel is a recording the parent has to make again, and
  /// the cost of an accidental send is a message they cannot withdraw. Neither
  /// is free, so this sits where a deliberate slide is unmistakable.
  static const double cancelDistance = 90;

  /// How far up before the recording locks and the finger can leave.
  static const double lockDistance = 70;

  /// Sideways slop allowed before an upward drag stops counting as one.
  ///
  /// A slide to the lock is rarely straight up; a slide to cancel is rarely
  /// straight across. Whichever axis is travelling further decides.
  static const double axisSlop = 12;

  /// How far along the cancel gesture the finger is, 0..1, for animating.
  static double cancelProgress(double dx) {
    if (dx >= 0) return 0;

    return (dx.abs() / cancelDistance).clamp(0.0, 1.0);
  }

  /// How far along the lock gesture the finger is, 0..1.
  static double lockProgress(double dy) {
    if (dy >= 0) return 0;

    return (dy.abs() / lockDistance).clamp(0.0, 1.0);
  }

  /// What a drag to ([dx], [dy]) from the button means right now.
  ///
  /// Negative dx is left, negative dy is up, matching Flutter's coordinates.
  /// Only one of the two can win: a parent dragging diagonally is doing
  /// whichever they have committed to further, so a hesitant diagonal never
  /// silently discards a recording.
  static VoiceGesturePhase phaseFor(double dx, double dy) {
    final left = dx < 0 ? dx.abs() : 0.0;
    final up = dy < 0 ? dy.abs() : 0.0;

    final cancelling = left >= cancelDistance;
    final locking = up >= lockDistance;

    if (cancelling && locking) {
      // Both thresholds crossed at once. Whichever axis has travelled further
      // wins, and a tie locks rather than cancels: keeping a recording the
      // parent did not want costs a tap, losing one they did costs the whole
      // message.
      return left > up
          ? VoiceGesturePhase.willCancel
          : VoiceGesturePhase.willLock;
    }
    // Past the cancel threshold. Only a flat enough slide discards: a finger
    // also travelling upward is reaching for the lock, so it locks instead.
    // The fallback must never be `holding`, because releasing from `holding`
    // sends — the one outcome a parent cannot undo.
    if (cancelling) {
      return up < axisSlop
          ? VoiceGesturePhase.willCancel
          : VoiceGesturePhase.willLock;
    }

    // Past the lock threshold, with or without sideways drift. Sideways travel
    // short of cancelDistance is not a cancel, and holding would send.
    if (locking) return VoiceGesturePhase.willLock;

    return VoiceGesturePhase.holding;
  }

  /// Whether releasing now sends the recording.
  static bool releaseSends(VoiceGesturePhase phase) =>
      phase == VoiceGesturePhase.holding;

  /// Whether releasing now throws the recording away.
  static bool releaseDiscards(VoiceGesturePhase phase) =>
      phase == VoiceGesturePhase.willCancel;

  /// How far the button itself should follow the finger.
  ///
  /// It trails rather than tracks: the button drifting the full distance makes
  /// the gesture feel loose and lands it under the parent's own hand.
  static double buttonOffset(
    double travel, {
    double factor = 0.45,
    double max = 60,
  }) {
    final followed = travel * factor;

    return math.max(-max, math.min(0, followed));
  }
}
