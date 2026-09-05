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
  Widget host({bool onDark = false}) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: VoiceNotePlayer(
          url: 'https://erp.jaihind.school/uploads/messages/msg_x.m4a',
          onDark: onDark,
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

  testWidgets('readable on the parent\'s own blue bubble as well as white', (
    tester,
  ) async {
    for (final onDark in [true, false]) {
      await tester.pumpWidget(host(onDark: onDark));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    }
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
