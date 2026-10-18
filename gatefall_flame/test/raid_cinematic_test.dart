import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gatefall/combat/battle.dart';
import 'package:gatefall/data/element.dart';
import 'package:gatefall/ui/gate_screen.dart';
import 'package:gatefall/ui/raid_cinematic.dart';
import 'package:gatefall/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('post-raid dialogue requires a won raid and an unlocked beat', () {
    expect(
      shouldOfferPostRaidScene(
        status: BattleStatus.won,
        beatReady: true,
      ),
      isTrue,
    );
    for (final state in [
      BattleStatus.lost,
      BattleStatus.fighting,
    ]) {
      expect(
        shouldOfferPostRaidScene(status: state, beatReady: true),
        isFalse,
      );
    }
    expect(
      shouldOfferPostRaidScene(
        status: BattleStatus.won,
        beatReady: false,
      ),
      isFalse,
    );
  });

  testWidgets('encounter banner follows simulation wave and guardian status',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: gatefallTheme(),
      home: const Scaffold(
        body: Column(
          children: [
            RaidEncounterBanner(
              element: GateElement.gloam,
              waveIndex: 1,
              waveCount: 3,
              onBoss: false,
            ),
            RaidEncounterBanner(
              element: GateElement.gloam,
              waveIndex: 2,
              waveCount: 3,
              onBoss: true,
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('WAVE 2 / 3'), findsOneWidget);
    expect(find.text('THE GATE GUARDIAN'), findsOneWidget);
    expect(find.byKey(const Key('raid-encounter-banner')), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('outcome hero preserves victory and withdrawal labels',
      (tester) async {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.devicePixelRatio = 1;
    view.physicalSize = const Size(320, 960);
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
      theme: gatefallTheme(),
      home: const Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              RaidOutcomeHero(
                won: true,
                element: GateElement.gloam,
                gateName: 'Gloam Fracture',
                elapsedSeconds: 42,
                partyIds: ['player', 'faelen'],
              ),
              RaidOutcomeHero(
                won: false,
                element: GateElement.gloam,
                gateName: 'Gloam Fracture',
                elapsedSeconds: 31,
                partyIds: ['player'],
              ),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Gate cleared'), findsOneWidget);
    expect(find.text('Party withdrawn'), findsOneWidget);
    expect(find.textContaining('42s in the gate'), findsOneWidget);
    expect(find.byKey(const Key('raid-outcome-hero')), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('story bridges describe only the supplied eligible chapters',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: gatefallTheme(),
      home: const Scaffold(
        body: Column(
          children: [
            RaidStoryBridge(
              characterId: 'faelen',
              title: 'After the Wall',
              postRaid: true,
            ),
            RaidStoryBridge(
              characterId: 'faelen',
              title: 'The First Truth',
              postRaid: false,
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('raid-post-story-bridge')), findsOneWidget);
    expect(find.byKey(const Key('raid-ready-story-bridge')), findsOneWidget);
    expect(find.text('After the Wall'), findsOneWidget);
    expect(find.text('The First Truth'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
