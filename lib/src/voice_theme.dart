import 'package:flutter/material.dart';

/// The colours a voice note draws itself in.
///
/// Taken from the surrounding app's own [ColorScheme] rather than from a
/// palette in here. That is the whole point of the shared package: the parent
/// app's violet and the teacher app's indigo both come out right without
/// either app configuring anything, and a future dark theme follows for free.
///
/// An app that needs to override a role can construct one and hand it in.
class VoiceTheme {
  const VoiceTheme({
    required this.accent,
    required this.accentSoft,
    required this.danger,
    required this.warning,
    required this.ink,
    required this.muted,
  });

  /// Play buttons, the live waveform, the send button.
  final Color accent;

  /// The accent at rest -- the lock hint's resting background.
  final Color accentSoft;

  /// Recording, discarding, deleting.
  final Color danger;

  /// Approaching the recording limit.
  final Color warning;

  /// Timers and anything that must stay legible on the bubble.
  final Color ink;

  /// Secondary text: durations, hints.
  final Color muted;

  factory VoiceTheme.of(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return VoiceTheme(
      accent: scheme.primary,
      accentSoft: scheme.primaryContainer,
      danger: scheme.error,
      // ColorScheme has no "warning" role. Amber reads as caution in both
      // light and dark, and the bars never rely on it alone -- the same state
      // is always said in words as well.
      warning: const Color(0xFFB45309),
      ink: scheme.onSurface,
      muted: scheme.onSurface.withValues(alpha: 0.6),
    );
  }

  /// The colours for a message bubble, which may be the sender's own tinted
  /// one rather than the surface colour.
  VoiceTheme onBubble({required bool tinted}) {
    if (!tinted) return this;

    return VoiceTheme(
      accent: accent,
      accentSoft: accentSoft,
      danger: danger,
      warning: warning,
      ink: ink,
      muted: muted,
    );
  }
}
