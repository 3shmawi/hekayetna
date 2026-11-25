import 'package:family_stories/features/family/data/models.dart';

/// One step on a path through the family, always read from the person we
/// are standing on: to their parent, to their child, to their spouse, or
/// to their sibling.
enum KinStep { up, down, spouse, sibling }

/// The family as a pure data structure: parents, children, spouses and
/// siblings per person, built from persons + relationships. Only
/// **confirmed** relationships make the graph; pending ones are kept apart
/// so the tree can draw them dashed and kinship never uses them.
///
/// Relationship rows follow the existing convention: for a row
/// (personId, relatedPersonId, type), `parent` means the related person is
/// the parent of personId, `child` means the related person is the child of
/// personId.
class FamilyGraph {
  FamilyGraph._({
    required this.persons,
    required this.meId,
    required this.parents,
    required this.children,
    required this.spouses,
    required this.siblings,
    required this.pending,
    required this.storyCounts,
    required this.storyMinutes,
  });

  /// [storiesByNarrator] maps a person id to the durations (seconds) of the
  /// accessible stories they narrate; its length is the story count.
  factory FamilyGraph.build({
    required List<Person> persons,
    required List<Relationship> relationships,
    String? meId,
    Map<String, List<int>> storiesByNarrator = const {},
  }) {
    final byId = {for (final p in persons) p.id: p};
    final parents = <String, Set<String>>{};
    final children = <String, Set<String>>{};
    final spouses = <String, Set<String>>{};
    final siblings = <String, Set<String>>{};
    final pending = <PendingEdge>[];

    void parentOf(String child, String parent) {
      parents.putIfAbsent(child, () => {}).add(parent);
      children.putIfAbsent(parent, () => {}).add(child);
    }

    void pair(Map<String, Set<String>> m, String a, String b) {
      m.putIfAbsent(a, () => {}).add(b);
      m.putIfAbsent(b, () => {}).add(a);
    }

    for (final r in relationships) {
      if (!byId.containsKey(r.personId) ||
          !byId.containsKey(r.relatedPersonId) ||
          r.personId == r.relatedPersonId) {
        continue;
      }
      if (r.status == RelationshipStatus.pending) {
        pending.add(switch (r.type) {
          RelationshipType.parent => PendingEdge(
            r.relatedPersonId,
            r.personId,
            PendingKind.parentChild,
          ),
          RelationshipType.child => PendingEdge(
            r.personId,
            r.relatedPersonId,
            PendingKind.parentChild,
          ),
          RelationshipType.spouse => PendingEdge(
            r.personId,
            r.relatedPersonId,
            PendingKind.spouse,
          ),
          RelationshipType.sibling => PendingEdge(
            r.personId,
            r.relatedPersonId,
            PendingKind.sibling,
          ),
        });
        continue;
      }
      switch (r.type) {
        case RelationshipType.parent:
          parentOf(r.personId, r.relatedPersonId);
        case RelationshipType.child:
          parentOf(r.relatedPersonId, r.personId);
        case RelationshipType.spouse:
          pair(spouses, r.personId, r.relatedPersonId);
        case RelationshipType.sibling:
          pair(siblings, r.personId, r.relatedPersonId);
      }
    }
    // Two people with a shared confirmed parent are siblings.
    for (final kids in children.values) {
      final list = kids.toList();
      for (var i = 0; i < list.length; i++) {
        for (var j = i + 1; j < list.length; j++) {
          pair(siblings, list[i], list[j]);
        }
      }
    }

    List<String> sorted(Set<String>? s) => (s?.toList() ?? <String>[])..sort();
    return FamilyGraph._(
      persons: byId,
      meId: meId != null && byId.containsKey(meId) ? meId : null,
      parents: {for (final e in parents.entries) e.key: sorted(e.value)},
      children: {for (final e in children.entries) e.key: sorted(e.value)},
      spouses: {for (final e in spouses.entries) e.key: sorted(e.value)},
      siblings: {for (final e in siblings.entries) e.key: sorted(e.value)},
      pending: pending,
      storyCounts: {
        for (final p in persons) p.id: storiesByNarrator[p.id]?.length ?? 0,
      },
      storyMinutes: {
        for (final p in persons)
          p.id:
              ((storiesByNarrator[p.id] ?? const <int>[]).fold<int>(
                        0,
                        (a, b) => a + b,
                      ) /
                      60)
                  .round(),
      },
    );
  }

  final Map<String, Person> persons;

  /// The person the signed-in user is (family_memberships.person_id).
  final String? meId;
  final List<PendingEdge> pending;
  final Map<String, int> storyCounts;
  final Map<String, int> storyMinutes;

  /// Confirmed adjacency, ids sorted. Prefer the `...Of` accessors.
  final Map<String, List<String>> parents;
  final Map<String, List<String>> children;
  final Map<String, List<String>> spouses;
  final Map<String, List<String>> siblings;

  List<String> parentsOf(String id) => parents[id] ?? const [];
  List<String> childrenOf(String id) => children[id] ?? const [];
  List<String> spousesOf(String id) => spouses[id] ?? const [];
  List<String> siblingsOf(String id) => siblings[id] ?? const [];

  int get totalStories => storyCounts.values.fold(0, (a, b) => a + b);

  bool isConnected(String id) =>
      parentsOf(id).isNotEmpty ||
      childrenOf(id).isNotEmpty ||
      spousesOf(id).isNotEmpty ||
      siblingsOf(id).isNotEmpty;

  /// Confirmed neighbours with the step that reaches them, in a fixed order
  /// (up, sibling, spouse, down; ids sorted) so searches are deterministic.
  Iterable<(KinStep, String)> neighbours(String id) sync* {
    for (final p in parentsOf(id)) {
      yield (KinStep.up, p);
    }
    for (final p in siblingsOf(id)) {
      yield (KinStep.sibling, p);
    }
    for (final p in spousesOf(id)) {
      yield (KinStep.spouse, p);
    }
    for (final p in childrenOf(id)) {
      yield (KinStep.down, p);
    }
  }

  /// Shortest confirmed path from [from] to [to] as people and steps, or
  /// null when no confirmed path exists.
  KinPath? pathBetween(String from, String to) {
    if (!persons.containsKey(from) || !persons.containsKey(to)) return null;
    if (from == to) return KinPath([from], const []);
    final prev = <String, (String, KinStep)>{};
    final seen = {from};
    var frontier = [from];
    while (frontier.isNotEmpty) {
      final next = <String>[];
      for (final id in frontier) {
        for (final (step, n) in neighbours(id)) {
          if (!seen.add(n)) continue;
          prev[n] = (id, step);
          if (n == to) return _unwind(prev, from, to);
          next.add(n);
        }
      }
      frontier = next;
    }
    return null;
  }

  KinPath _unwind(Map<String, (String, KinStep)> prev, String from, String to) {
    final ids = <String>[to];
    final steps = <KinStep>[];
    var cur = to;
    while (cur != from) {
      final (p, s) = prev[cur]!;
      steps.add(s);
      ids.add(p);
      cur = p;
    }
    return KinPath(ids.reversed.toList(), steps.reversed.toList());
  }
}

enum PendingKind { parentChild, spouse, sibling }

/// A relationship not confirmed yet. For parentChild, [a] is the parent.
class PendingEdge {
  const PendingEdge(this.a, this.b, this.kind);
  final String a;
  final String b;
  final PendingKind kind;
}

class KinPath {
  const KinPath(this.people, this.steps);
  final List<String> people;
  final List<KinStep> steps;
}
