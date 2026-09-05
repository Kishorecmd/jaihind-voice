import 'package:flutter/material.dart';

import 'voice_recording.dart';
import 'voice_theme.dart';
import 'waveform.dart';

/// The bar shown in place of the composer while a parent is holding to record.
///
/// Everything here answers one question at a glance: what happens if I let go
/// now. The label and the colour change as the finger travels, so releasing is
/// never a guess.
class HoldingRecordBar extends StatelessWidget {
  const HoldingRecordBar({
    super.key,
    required this.elapsed,
    required this.samples,
    required this.cancelProgress,
    required this.willCancel,
    this.theme,
  });

  final Duration elapsed;
  final List<double> samples;
  final double cancelProgress;
  final bool willCancel;
  final VoiceTheme? theme;

  @override
  Widget build(BuildContext context) {
    final nearLimit = VoiceRules.shouldWarn(elapsed);
    final left = VoiceRules.remaining(elapsed);
    final t = theme ?? VoiceTheme.of(context);

    return Semantics(
      liveRegion: true,
      label: willCancel
          ? 'Release to discard the recording'
          : 'Recording ${VoiceRules.clock(elapsed)}. Slide left to cancel, slide up to lock.',
      child: Row(
        children: [
          // The dot says "live" without anything having to be read.
          Icon(Icons.fiber_manual_record, size: 13, color: t.danger),
          const SizedBox(width: 8),
          Text(
            VoiceRules.clock(elapsed),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              // Tabular figures stop the row twitching as the seconds tick.
              // There was a fixed 46px box here too, which overflowed the moment
              // a parent turned system text up to 2x -- and a parent who needs
              // larger text is exactly who should not meet a broken layout.
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: _middle(t, nearLimit, left)),
        ],
      ),
    );
  }

  Widget _middle(VoiceTheme t, bool nearLimit, Duration left) {
    if (willCancel) {
      return Text(
        'Release to cancel',
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: t.danger,
        ),
      );
    }

    if (nearLimit) {
      // Said in words, not by turning the timer red: a colour change alone
      // says nothing to a colour-blind parent.
      return Text(
        '${VoiceRules.clock(left)} left',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: t.warning,
        ),
      );
    }

    return Opacity(
      // Fades as the finger travels, so the instruction gets out of the way
      // once it has been followed.
      opacity: (1 - cancelProgress).clamp(0.25, 1.0),
      child: Row(
        children: [
          // Expanded, not Flexible. The waveform asks for infinite width, and a
          // loose Flexible grants that -- it took the whole row and pushed
          // "Slide to cancel" 185px off the right edge at 2x system text.
          // Expanded lays out the fixed children first and gives the waveform
          // what is left.
          Expanded(
            child: Waveform(
              bars: samples,
              playedColor: t.accent,
              unplayedColor: t.accent.withAlpha(70),
              progress: 1,
              height: 22,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_left, size: 16, color: Colors.black45),
          const Flexible(
            child: Text(
              'Slide to cancel',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

/// The padlock that rises above the microphone while holding.
class LockHint extends StatelessWidget {
  const LockHint({super.key, required this.progress, this.theme});

  /// 0..1 toward locking.
  final double progress;

  /// Overrides the ambient theme. Rarely needed.
  final VoiceTheme? theme;

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    final armed = p >= 1;
    final t = theme ?? VoiceTheme.of(context);

    return Semantics(
      label: 'Lock recording',
      child: Opacity(
        // Dim until the finger starts upward, so it does not clutter the
        // composer for a parent who only taps and holds.
        opacity: p == 0 ? 0.45 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: armed ? t.accent : t.accentSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                armed ? Icons.lock : Icons.lock_open,
                size: 17,
                color: armed ? Colors.white : t.accent,
              ),
              const SizedBox(height: 2),
              Icon(
                Icons.keyboard_arrow_up,
                size: 15,
                color: armed ? Colors.white70 : t.accent.withAlpha(150),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The bar shown once recording is locked and the finger has gone.
///
/// Nothing is being held any more, so every action needs a real button. Delete
/// sits at the opposite end from send: they are the irreversible pair, and a
/// mis-tap between them is the expensive one.
class LockedRecordBar extends StatelessWidget {
  const LockedRecordBar({
    super.key,
    required this.elapsed,
    required this.samples,
    required this.paused,
    required this.onPauseResume,
    required this.onDelete,
    required this.onSend,
    this.theme,
  });

  final Duration elapsed;
  final List<double> samples;
  final bool paused;
  final VoidCallback onPauseResume;
  final VoidCallback onDelete;
  final VoidCallback onSend;
  final VoiceTheme? theme;

  @override
  Widget build(BuildContext context) {
    final nearLimit = VoiceRules.shouldWarn(elapsed);
    final t = theme ?? VoiceTheme.of(context);

    return Row(
      children: [
        Semantics(
          button: true,
          label: 'Delete voice recording',
          child: IconButton(
            icon: Icon(Icons.delete_outline, color: t.danger),
            tooltip: 'Delete recording',
            onPressed: onDelete,
          ),
        ),
        Semantics(
          button: true,
          label: paused ? 'Resume recording' : 'Pause recording',
          child: IconButton(
            icon: Icon(
              paused ? Icons.fiber_manual_record : Icons.pause,
              color: paused ? t.danger : t.ink,
            ),
            tooltip: paused ? 'Resume' : 'Pause',
            onPressed: onPauseResume,
          ),
        ),
        Text(
          VoiceRules.clock(elapsed),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _middle(t, nearLimit)),
        const SizedBox(width: 4),
        Semantics(
          button: true,
          label: 'Send voice message',
          child: CircleAvatar(
            radius: 22,
            backgroundColor: t.accent,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 19),
              tooltip: 'Send',
              onPressed: onSend,
            ),
          ),
        ),
      ],
    );
  }

  Widget _middle(VoiceTheme t, bool nearLimit) {
    if (paused) {
      // Named, not implied by the icon alone. A paused recording that looks
      // live is how a parent talks to a phone that is not listening.
      return const Text(
        'Paused',
        style: TextStyle(fontSize: 13, color: Colors.black54),
      );
    }

    if (nearLimit) {
      return Text(
        '${VoiceRules.clock(VoiceRules.remaining(elapsed))} left',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: t.warning,
        ),
      );
    }

    return Waveform(
      bars: samples,
      playedColor: t.accent,
      unplayedColor: t.accent.withAlpha(70),
      progress: 1,
      height: 22,
    );
  }
}
