import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'voice_theme.dart';

/// Playing a voice note the school has sent.
///
/// Without this the app fell through to its image branch and drew "Image
/// unavailable" over a perfectly good recording — the parent could see that
/// their child's teacher had sent something and had no way to hear it.
///
/// Deliberately small: a play button, a bar and a length. No scrubbing, no
/// speed control, no waveform. Nothing downloads until the button is pressed,
/// so a thread of notes costs nothing to scroll past on mobile data.
class VoiceNotePlayer extends StatefulWidget {
  const VoiceNotePlayer({
    super.key,
    required this.url,
    this.onDark = false,
    this.theme,
  });

  final String url;

  /// True on the sender's own tinted bubble, false on a plain one.
  final bool onDark;

  /// Overrides the ambient theme. Rarely needed.
  final VoiceTheme? theme;

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  final AudioPlayer _player = AudioPlayer();

  Duration _position = Duration.zero;
  Duration? _length;
  bool _playing = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();

    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _length = d);
    });
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
    _player.onPlayerComplete.listen((_) {
      // Back to the start, so pressing play again replays rather than doing
      // nothing — which reads as the note being broken.
      if (mounted) {
        setState(() {
          _playing = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      if (_playing) {
        await _player.pause();
        return;
      }
      await _player.play(UrlSource(widget.url));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  static String _clock(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');

    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    // Was a hard-coded blue from the parent app. It now comes from whichever
    // app is drawing it, so the teacher app's own accent is used unchanged.
    final t = widget.theme ?? VoiceTheme.of(context);
    final ink = widget.onDark ? Colors.white : t.accent;
    final muted = widget.onDark ? Colors.white70 : t.muted;

    if (_failed) {
      // A note that will not play has to say so. Silence is indistinguishable
      // from a note nobody recorded anything into.
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 15, color: muted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Voice note could not be played',
              style: TextStyle(fontSize: 12.5, color: muted),
            ),
          ),
        ],
      );
    }

    final total = _length;
    final progress = (total == null || total.inMilliseconds == 0)
        ? 0.0
        : (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: 210,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              label: _playing ? 'Pause voice note' : 'Play voice note',
              child: InkWell(
                onTap: _toggle,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: widget.onDark ? Colors.white.withAlpha(48) : ink,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _playing ? Icons.pause : Icons.play_arrow,
                    color: widget.onDark ? Colors.white : Colors.white,
                    size: 21,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: widget.onDark
                          ? Colors.white.withAlpha(60)
                          : Colors.black.withAlpha(26),
                      valueColor: AlwaysStoppedAnimation(
                        widget.onDark ? Colors.white : ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    // Elapsed once it is running, the whole length before that,
                    // so a parent can tell whether it is worth starting.
                    total == null
                        ? 'Voice note'
                        : (_position > Duration.zero
                              ? '${_clock(_position)} / ${_clock(total)}'
                              : _clock(total)),
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
