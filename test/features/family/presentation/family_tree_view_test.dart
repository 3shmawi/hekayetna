import 'package:family_stories/features/family/data/models.dart';
import 'package:family_stories/features/family/presentation/family_tree_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Person person(String id, String name, {String? linked}) => Person(
  id: id,
  spaceId: 's',
  fullName: name,
  createdBy: 'u',
  linkedUserId: linked,
);

Relationship rel(
  String a,
  String b,
  RelationshipType t, [
  RelationshipStatus st = RelationshipStatus.confirmed,
]) => Relationship(
  id: '$a-$b-${t.name}',
  personId: a,
  relatedPersonId: b,
  type: t,
  status: st,
);

void main() {
  testWidgets('tree renders every person and keeps the account holder filled', (
    tester,
  ) async {
    final persons = [
      person('me', 'Me', linked: 'u1'),
      person('mama', 'Mama'),
      person('baba', 'Baba'),
    ];
    final rels = [
      rel('me', 'mama', RelationshipType.parent),
      rel('me', 'baba', RelationshipType.parent),
      rel('mama', 'baba', RelationshipType.spouse),
      rel('me', 'x', RelationshipType.parent, RelationshipStatus.pending),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FamilyTreeView(persons: persons, relationships: rels),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('M'), findsNWidgets(2)); // Me + Mama initials
    expect(find.text('B'), findsOneWidget);
    // Full names read under the nodes, no legend needed.
    expect(find.text('Mama'), findsOneWidget);
    expect(find.text('Baba'), findsOneWidget);
  });

  testWidgets('the layout mirrors horizontally in RTL, names stay readable', (
    tester,
  ) async {
    final persons = [person('a', 'Amal'), person('b', 'Badr')];
    final rels = [rel('a', 'b', RelationshipType.spouse)];

    Future<Offset> centerOf(TextDirection dir) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: dir,
            child: Scaffold(
              body: FamilyTreeView(persons: persons, relationships: rels),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.getCenter(find.text('A'));
    }

    final ltr = await centerOf(TextDirection.ltr);
    final rtl = await centerOf(TextDirection.rtl);
    // Mirrored: A's x flips around the content center, y unchanged.
    expect(rtl.dx, isNot(closeTo(ltr.dx, 1)));
    expect(rtl.dy, closeTo(ltr.dy, 1));
    // And the Arabic-shaped name is still drawn unmirrored.
    expect(find.text('Amal'), findsOneWidget);
  });

  testWidgets('tapping a node reports the person', (tester) async {
    Person? tapped;
    final persons = [person('me', 'Me', linked: 'u1')];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FamilyTreeView(
            persons: persons,
            relationships: const [],
            onTapPerson: (p) => tapped = p,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('M'));
    expect(tapped?.id, 'me');
  });

  testWidgets('empty tree renders nothing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FamilyTreeView(persons: [], relationships: []),
        ),
      ),
    );
    expect(find.byType(InteractiveViewer), findsNothing);
  });
}
