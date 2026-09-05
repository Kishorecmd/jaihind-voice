import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jaihind_voice/jaihind_voice.dart';

/// Holding the microphone, and letting go.
///
/// Driven through the real gesture recogniser rather than by calling the
/// callbacks, because the mistakes worth catching are in the wiring: a release
/// that both sends and cancels, a lock that also sends, a refused microphone
/// that still shows a recording bar.
void main() {
  late List<String> events;

  Widget host({bool started = true, bool enabled = true}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: VoiceRecordButton(
            enabled: enabled,
            onStart: () async {
              events.add('start');
              return started;
            },
            onUpdate: (_, __) {},
            onSend: () => events.add('send'),
            onCancel: () => events.add('cancel'),
            onLock: () => events.add('lock'),
          ),
        ),
      ),
    );
  }

  setUp(() => events = <String>[]);

  Future<TestGesture> hold(WidgetTester tester) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(VoiceRecordButton)),
    );
    // Past the long-press threshold, or nothing starts.
    await tester.pump(const Duration(milliseconds: 600));

    return gesture;
  }

  testWidgets('holding starts a recording', (tester) async {
    await tester.pumpWidget(host());
    final g = await hold(tester);
    await tester.pumpAndSettle();

    expect(events, ['start']);
    await g.up();
    await tester.pumpAndSettle();
  });

  testWidgets('releasing sends it', (tester) async {
    await tester.pumpWidget(host());
    final g = await hold(tester);
    await tester.pumpAndSettle();
    await g.up();
    await tester.pumpAndSettle();

    expect(events, ['start', 'send']);
  });

  testWidgets('sliding left and releasing cancels instead of sending', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    final g = await hold(tester);
    await tester.pumpAndSettle();

    await g.moveBy(const Offset(-120, 0));
    await tester.pumpAndSettle();
    await g.up();
    await tester.pumpAndSettle();

    expect(events, ['start', 'cancel']);
    expect(events, isNot(contains('send')));
  });

  testWidgets('a small wobble still sends', (tester) async {
    // Speaking while holding a phone moves the thumb. If that cancelled, the
    // feature would be unusable.
    await tester.pumpWidget(host());
    final g = await hold(tester);
    await tester.pumpAndSettle();

    await g.moveBy(const Offset(-30, 6));
    await tester.pumpAndSettle();
    await g.up();
    await tester.pumpAndSettle();

    expect(events, ['start', 'send']);
  });

  testWidgets('sliding up locks, and does not also send', (tester) async {
    await tester.pumpWidget(host());
    final g = await hold(tester);
    await tester.pumpAndSettle();

    await g.moveBy(const Offset(0, -90));
    await tester.pumpAndSettle();

    expect(events, ['start', 'lock']);

    // The finger leaving after a lock must do nothing at all: the recording
    // carries on, and the parent sends it with the button.
    await g.up();
    await tester.pumpAndSettle();

    expect(events, ['start', 'lock']);
  });

  testWidgets('a locked recording is never also cancelled by the release', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    final g = await hold(tester);
    await tester.pumpAndSettle();

    await g.moveBy(const Offset(0, -90));
    await tester.pumpAndSettle();
    // Drifting left AFTER locking must not discard it -- the gesture is over.
    await g.moveBy(const Offset(-200, 0));
    await tester.pumpAndSettle();
    await g.up();
    await tester.pumpAndSettle();

    expect(events, ['start', 'lock']);
    expect(events, isNot(contains('cancel')));
  });

  testWidgets('a refused microphone records nothing and sends nothing', (
    tester,
  ) async {
    await tester.pumpWidget(host(started: false));
    final g = await hold(tester);
    await tester.pumpAndSettle();
    await g.up();
    await tester.pumpAndSettle();

    // onStart said no. Releasing must not send an imaginary recording.
    expect(events, ['start']);
  });

  testWidgets('an interrupted press does not leave the microphone running', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    final g = await hold(tester);
    await tester.pumpAndSettle();

    await g.cancel();
    await tester.pumpAndSettle();

    expect(events.last, 'cancel');
  });

  testWidgets('the touch target is big enough for a thumb', (tester) async {
    await tester.pumpWidget(host());

    final size = tester.getSize(find.byType(VoiceRecordButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('it announces itself to a screen reader', (tester) async {
    await tester.pumpWidget(host());

    expect(
      find.bySemanticsLabel('Hold to record voice message'),
      findsOneWidget,
    );
  });

  group('the bars', () {
    testWidgets('the holding bar says how to cancel', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HoldingRecordBar(
              elapsed: Duration(seconds: 8),
              samples: [],
              cancelProgress: 0,
              willCancel: false,
            ),
          ),
        ),
      );

      expect(find.text('0:08'), findsOneWidget);
      expect(find.text('Slide to cancel'), findsOneWidget);
    });

    testWidgets('and changes what it says once releasing would discard', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HoldingRecordBar(
              elapsed: Duration(seconds: 8),
              samples: [],
              cancelProgress: 1,
              willCancel: true,
            ),
          ),
        ),
      );

      expect(find.text('Release to cancel'), findsOneWidget);
      expect(find.text('Slide to cancel'), findsNothing);
    });

    testWidgets('warns in words near the five-minute limit', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HoldingRecordBar(
              elapsed: Duration(minutes: 4, seconds: 45),
              samples: [],
              cancelProgress: 0,
              willCancel: false,
            ),
          ),
        ),
      );

      expect(find.text('0:15 left'), findsOneWidget);
    });

    testWidgets('the locked bar offers every control the finger used to', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LockedRecordBar(
              elapsed: const Duration(seconds: 32),
              samples: const [],
              paused: false,
              onPauseResume: () {},
              onDelete: () {},
              onSend: () {},
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Delete voice recording'), findsOneWidget);
      expect(find.bySemanticsLabel('Pause recording'), findsOneWidget);
      expect(find.bySemanticsLabel('Send voice message'), findsOneWidget);
      expect(find.text('0:32'), findsOneWidget);
    });

    testWidgets('a paused recording says so in words, not just an icon', (
      tester,
    ) async {
      // A paused recording that looks live is how a parent ends up talking to
      // a phone that is not listening.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LockedRecordBar(
              elapsed: const Duration(seconds: 32),
              samples: const [],
              paused: true,
              onPauseResume: () {},
              onDelete: () {},
              onSend: () {},
            ),
          ),
        ),
      );

      expect(find.text('Paused'), findsOneWidget);
      expect(find.bySemanticsLabel('Resume recording'), findsOneWidget);
    });

    testWidgets('both bars survive large system text', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(
              body: Column(
                children: [
                  const HoldingRecordBar(
                    elapsed: Duration(seconds: 8),
                    samples: [],
                    cancelProgress: 0,
                    willCancel: false,
                  ),
                  LockedRecordBar(
                    elapsed: const Duration(seconds: 32),
                    samples: const [],
                    paused: false,
                    onPauseResume: () {},
                    onDelete: () {},
                    onSend: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('the lock hint', () {
    testWidgets('is closed until the gesture completes it', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LockHint(progress: 0.4))),
      );

      expect(find.byIcon(Icons.lock_open), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsNothing);
    });

    testWidgets('and shuts once it would take', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LockHint(progress: 1))),
      );

      expect(find.byIcon(Icons.lock), findsOneWidget);
    });
  });

  test('the gesture thresholds are the ones the bars describe', () {
    // The bar tells a parent to slide left and up. If those distances ever
    // diverge from the gesture, the instruction becomes a lie.
    expect(VoiceGesture.cancelDistance, greaterThan(VoiceGesture.axisSlop));
    expect(VoiceGesture.lockDistance, greaterThan(VoiceGesture.axisSlop));
  });
}
