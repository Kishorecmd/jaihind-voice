import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jaihind_voice/jaihind_voice.dart';

/// A voice note as a parent sees it.
///
/// The chat screen knew 'pdf' and treated everything else as a picture, so the
/// first voice note the school sent was drawn as "Image unavailable". The
/// parent could see something had arrived and had no way to hear it — which is
/// worse than the message not arriving, because it looks like their fault.
void main() {
  Widget host({Color? background, Duration? duration}) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: VoiceNotePlayer(
          url: 'https://erp.jaihind.school/uploads/messages/msg_x.m4a',
          background: background,
          duration: duration,
        ),
      ),
    ),
  );

  testWidgets('offers a play button before anything is downloaded', (
    tester,
  ) async {
    // Nothing loads until the parent asks for it: a thread of notes must cost
    // nothing to scroll past on mobile data.
    await tester.pumpWidget(host());

    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsNothing);
  });

  testWidgets('says what it is before the length is known', (tester) async {
    // Until the file's duration arrives there is no time to show, and an empty
    // row reads as a rendering fault.
    await tester.pumpWidget(host());

    expect(find.text('Voice note'), findsOneWidget);
  });

  testWidgets('the play control is named for a screen reader', (tester) async {
    // The whole control is an icon. Without a label it is unusable by a parent
    // relying on TalkBack.
    await tester.pumpWidget(host());

    expect(find.bySemanticsLabel('Play voice note'), findsOneWidget);
  });

  testWidgets('readable on a dark bubble and on a pale one', (tester) async {
    // Contrast is worked out from the colour actually behind the player, not
    // from a flag. The flag lasted one build: the parent app's own bubble is
    // dark blue and the teacher app's is pale green, both were passed "this is
    // the sender's own bubble", and the teacher's voice notes rendered white
    // on near-white -- a play button nobody could see.
    for (final background in [
      const Color(0xFF2563EB), // parent app, sender's own bubble
      const Color(0xFFDCF8C6), // teacher app, school's own bubble
      Colors.white,
    ]) {
      await tester.pumpWidget(host(background: background));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    }
  });

  testWidgets('a known length is shown before anything is downloaded', (
    tester,
  ) async {
    // The duration travels with the message so a thread can say "0:18"
    // without every phone fetching every recording to find out.
    await tester.pumpWidget(host(duration: const Duration(seconds: 18)));
    await tester.pump();

    expect(find.text('0:18'), findsOneWidget);
    expect(find.text('Voice note'), findsNothing);
  });

  testWidgets('survives large system text', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: const Scaffold(
            body: Center(
              child: VoiceNotePlayer(url: 'https://test.local/a.m4a'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
