import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'voice_gesture.dart';
import 'voice_theme.dart';

/// The microphone a parent holds to record.
///
/// It owns the finger and nothing else: it reports when to start, where the
/// finger has travelled, and what the release meant. The screen above it owns
/// the recorder, the timer and the file, so this can be driven in a test
/// without a microphone.
///
/// Hold rather than tap, because the brief asks for the interaction parents
/// already know from every other messaging app they use. The locked mode
/// exists so that holding is never the ONLY way: a parent who cannot keep a
/// finger down for a minute slides up once and uses buttons instead.
class VoiceRecordButton extends StatefulWidget {
  const VoiceRecordButton({
    super.key,
    required this.onStart,
    required this.onUpdate,
    required this.onSend,
    required this.onCancel,
    required this.onLock,
    this.enabled = true,
    this.theme,
  });

  /// Called the moment the press is recognised. Returning false -- microphone
  /// refused, say -- abandons the gesture without a recording bar appearing.
  final Future<bool> Function() onStart;

  /// Where the finger is, so the bar can animate.
  final void Function(double cancelProgress, double lockProgress) onUpdate;

  final VoidCallback onSend;
  final VoidCallback onCancel;
  final VoidCallback onLock;
  final bool enabled;

  /// Overrides the ambient theme. Rarely needed.
  final VoiceTheme? theme;

  @override
  State<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends State<VoiceRecordButton> {
  VoiceGesturePhase _phase = VoiceGesturePhase.idle;
  Offset _origin = Offset.zero;
  double _dx = 0;
  double _dy = 0;

  /// True once the gesture has ended in a way that already did something, so a
  /// trailing onLongPressEnd cannot send the same recording twice.
  bool _resolved = false;

  /// The press was interrupted rather than released -- a call arriving, the
  /// app going to the background.
  ///
  /// Flutter routes a pointer cancel through onLongPressEnd once the press has
  /// been recognised, which is indistinguishable from letting go. Without this
  /// an incoming call SENT the half-finished recording, and a parent has no
  /// way to withdraw it.
  bool _interrupted = false;

  bool get _live =>
      _phase != VoiceGesturePhase.idle && _phase != VoiceGesturePhase.locked;

  Future<void> _begin(LongPressStartDetails d) async {
    if (!widget.enabled || _live) return;

    _origin = d.globalPosition;
    _dx = 0;
    _dy = 0;
    _resolved = false;
    _interrupted = false;

    final started = await widget.onStart();
    if (!mounted) return;

    if (!started) {
      // Permission refused, or the microphone was unavailable. Nothing is
      // shown and nothing is recorded; the screen has already explained why.
      setState(() => _phase = VoiceGesturePhase.idle);
      return;
    }

    // A short tick, so a parent knows recording began without watching the
    // screen -- the phone is often at their ear or in one hand.
    HapticFeedback.mediumImpact();
    setState(() => _phase = VoiceGesturePhase.holding);
  }

  void _move(LongPressMoveUpdateDetails d) {
    if (!_live) return;

    _dx = d.globalPosition.dx - _origin.dx;
    _dy = d.globalPosition.dy - _origin.dy;

    final next = VoiceGesture.phaseFor(_dx, _dy);
    final crossed =
        next != _phase &&
        (next == VoiceGesturePhase.willCancel ||
            next == VoiceGesturePhase.willLock);

    if (crossed) {
      // Fired on crossing, not continuously: the parent is told once that
      // letting go now does something different.
      HapticFeedback.selectionClick();
    }

    if (next == VoiceGesturePhase.willLock) {
      _lock();
      return;
    }

    setState(() => _phase = next);
    widget.onUpdate(
      VoiceGesture.cancelProgress(_dx),
      VoiceGesture.lockProgress(_dy),
    );
  }

  void _lock() {
    if (_resolved) return;
    _resolved = true;

    HapticFeedback.mediumImpact();
    setState(() => _phase = VoiceGesturePhase.locked);
    widget.onLock();
  }

  void _end(_) {
    if (!_live || _resolved) return;
    _resolved = true;

    final phase = _phase;
    setState(() => _phase = VoiceGesturePhase.idle);

    if (_interrupted) {
      // Interrupted, not released. Kept out of the thread rather than sent
      // half-said.
      widget.onCancel();
      return;
    }

    if (VoiceGesture.releaseDiscards(phase)) {
      widget.onCancel();
      return;
    }
    if (VoiceGesture.releaseSends(phase)) {
      HapticFeedback.lightImpact();
      widget.onSend();
      return;
    }

    // Any other ending -- a cancelled gesture, an interrupted press -- keeps
    // nothing. Silence here would leave the microphone running.
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final travelling = _phase == VoiceGesturePhase.willCancel;
    final t = widget.theme ?? VoiceTheme.of(context);

    return Semantics(
      button: true,
      label: 'Hold to record voice message',
      hint: 'Slide left to cancel, slide up to lock',
      child: Listener(
        // Seen before the recogniser turns it into an "end".
        onPointerCancel: (_) => _interrupted = true,
        child: GestureDetector(
          onLongPressStart: _begin,
          onLongPressMoveUpdate: _move,
          onLongPressEnd: _end,
          onLongPressCancel: () => _end(null),
          // A plain tap is not a recording, but saying nothing looks broken to a
          // parent who has not met hold-to-talk before.
          onTap: widget.enabled ? () => widget.onUpdate(-1, -1) : null,
          child: Transform.translate(
            offset: Offset(VoiceGesture.buttonOffset(_dx), 0),
            child: Container(
              // 48 square before padding: a thumb target, not an icon.
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: travelling
                    ? t.danger.withValues(alpha: 0.12)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: AnimatedScale(
                scale: _live ? 1.35 : 1.0,
                duration: const Duration(milliseconds: 140),
                child: Icon(
                  Icons.mic_none,
                  size: 24,
                  color: travelling ? t.danger : (_live ? t.accent : t.ink),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
