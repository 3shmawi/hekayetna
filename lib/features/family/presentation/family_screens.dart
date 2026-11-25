import 'dart:io';

import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/ids.dart';
import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/core/theme/app_colors.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/features/family/data/models.dart';
import 'package:family_stories/features/family/presentation/family_tree_page.dart';
import 'package:family_stories/features/family/presentation/family_tree_providers.dart';
import 'package:family_stories/features/family/presentation/family_tree_view.dart';
import 'package:family_stories/features/onboarding/data/onboarding.dart';
import 'package:family_stories/features/photos/data/models.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

/// Family tab: the space, its members, and the people directory. The map is
/// a list on purpose; nobody is forced to build a tree.
class FamilyHomeScreen extends ConsumerStatefulWidget {
  const FamilyHomeScreen({super.key});

  @override
  ConsumerState<FamilyHomeScreen> createState() => _FamilyHomeScreenState();
}

class _FamilyHomeScreenState extends ConsumerState<FamilyHomeScreen> {
  int _reload = 0; // bump to refetch after a mutation
  bool _treeView = false; // the list stays the default directory

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(s.family)),
      body: FutureBuilder(
        key: ValueKey(_reload),
        future: ref.read(familyRepositoryProvider).getMySpace().unwrap(),
        builder: (context, snap) {
          final space = snap.data;
          if (space == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return FutureBuilder<List<Person>>(
            future: ref
                .read(familyRepositoryProvider)
                .listPersons(space.id)
                .unwrap(),
            builder: (context, personsSnap) {
              final persons = personsSnap.data ?? const <Person>[];
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: ListTile(
                      title: Text(
                        space.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('${s.inviteCode}: ${space.inviteCode}'),
                      trailing: IconButton(
                        tooltip: s.inviteCode,
                        icon: const Icon(Icons.copy_outlined),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: space.inviteCode),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(s.inviteCopied)),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // The welcome screens can leave a draft of first names
                  // (you, optionally your parents). Offer to add exactly
                  // those people once; nothing is created before this
                  // confirmation, and dismissing drops the draft.
                  if (Onboarding.draft.value case final draft?)
                    _SeedTreeCard(
                      draft: draft,
                      onAdd: () => _seedTree(
                        context,
                        draft,
                        space.id,
                        () => setState(() => _reload++),
                      ),
                      onDismiss: () async {
                        await Onboarding.clearDraft();
                        setState(() => _reload++);
                      },
                    ),
                  // Members (accounts with access) are distinct from persons
                  // (people represented in the directory). Only the owner can
                  // remove a member; removal revokes their grants immediately.
                  FutureBuilder<List<FamilyMember>>(
                    future: ref
                        .read(familyRepositoryProvider)
                        .listMembers(space.id)
                        .unwrap(),
                    builder: (context, memberSnap) {
                      final members = memberSnap.data ?? const <FamilyMember>[];
                      final myId = ref.read(currentUserIdProvider);
                      final iAmOwner = members.any(
                        (m) => m.userId == myId && m.isOwner,
                      );
                      if (members.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            s.members,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          for (final m in members)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.account_circle_outlined,
                              ),
                              title: Text(m.displayName),
                              subtitle: m.isOwner ? Text(s.ownerRole) : null,
                              trailing: iAmOwner && !m.isOwner
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.person_remove_outlined,
                                      ),
                                      tooltip: s.removeMember,
                                      onPressed: () => _removeMember(
                                        context,
                                        m,
                                        () => setState(() => _reload++),
                                      ),
                                    )
                                  : null,
                            ),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.family,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _editPerson(
                          context,
                          ref,
                          () => setState(() => _reload++),
                          spaceId: space.id,
                        ),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: Text(s.addPerson),
                      ),
                    ],
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: false,
                          icon: const Icon(Icons.list),
                          label: Text(s.familyListView),
                        ),
                        ButtonSegment(
                          value: true,
                          icon: const Icon(Icons.account_tree_outlined),
                          label: Text(s.familyTreeView),
                        ),
                      ],
                      selected: {_treeView},
                      onSelectionChanged: (v) =>
                          setState(() => _treeView = v.first),
                    ),
                  ),
                  if (_treeView &&
                      persons.isNotEmpty &&
                      (ref.watch(familyTreeGraphEnabledProvider).value ??
                          false))
                    SizedBox(
                      height: 560,
                      child: FamilyTreePage(
                        spaceId: space.id,
                        spaceName: s.family,
                        onOpenPerson: (id) =>
                            context.push('/family/people/$id'),
                      ),
                    )
                  else if (_treeView && persons.isNotEmpty)
                    FutureBuilder<List<Relationship>>(
                      future: ref
                          .read(familyRepositoryProvider)
                          .listRelationships(space.id)
                          .unwrap(),
                      builder: (context, relSnap) => SizedBox(
                        height: 420,
                        child: FamilyTreeView(
                          persons: persons,
                          relationships: relSnap.data ?? const <Relationship>[],
                          onTapPerson: (p) =>
                              context.push('/family/people/${p.id}'),
                        ),
                      ),
                    ),
                  if (!_treeView)
                    for (final p in persons)
                      Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(p.fullName.characters.first),
                          ),
                          title: Text(p.fullName),
                          subtitle: Text(
                            [
                              p.approxBirthDate,
                              p.approxDeathDate,
                            ].whereType<String>().join(' — '),
                          ),
                          onTap: () => context.push('/family/people/${p.id}'),
                        ),
                      ),
                  if (persons.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(s.addPerson, textAlign: TextAlign.center),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class PersonDetailScreen extends ConsumerStatefulWidget {
  const PersonDetailScreen({required this.personId, super.key});
  final String personId;

  @override
  ConsumerState<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends ConsumerState<PersonDetailScreen> {
  int _reload = 0;

  Future<_PersonBundle> _load() async {
    final repo = ref.read(familyRepositoryProvider);
    final space = await repo.getMySpace().unwrap();
    if (space == null) return const _PersonBundle(null, [], [], [], []);
    final persons = await repo.listPersons(space.id).unwrap();
    final rels = await repo.listRelationships(space.id).unwrap();
    final members = await repo.listMembers(space.id).unwrap();
    final photos = await ref
        .read(photoRepositoryProvider)
        .listPhotos(space.id, personId: widget.personId)
        .unwrap();
    return _PersonBundle(space, persons, rels, members, photos);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder<_PersonBundle>(
        key: ValueKey(_reload),
        future: _load(),
        builder: (context, snap) {
          final bundle = snap.data;
          if (bundle == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final person = bundle.persons
              .where((p) => p.id == widget.personId)
              .firstOrNull;
          if (person == null) return Center(child: Text(s.errorUnknown));
          final rels = bundle.relationships
              .where(
                (r) =>
                    r.personId == person.id || r.relatedPersonId == person.id,
              )
              .toList();
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              CircleAvatar(
                radius: 40,
                child: Text(
                  person.fullName.characters.first,
                  style: const TextStyle(fontSize: 32),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                person.fullName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (person.approxBirthDate != null ||
                  person.approxDeathDate != null)
                Text(
                  [
                    person.approxBirthDate,
                    person.approxDeathDate,
                  ].whereType<String>().join(' — '),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.inkSoft),
                ),
              if (person.bio != null) ...[
                const SizedBox(height: 16),
                Text(person.bio!),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _editPerson(
                  context,
                  ref,
                  () => setState(() => _reload++),
                  spaceId: person.spaceId,
                  person: person,
                ),
                icon: const Icon(Icons.edit_outlined),
                label: Text(s.editPerson),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.relationships,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: bundle.persons.length < 2
                        ? null
                        : () =>
                              _addRelationship(context, person, bundle.persons),
                    icon: const Icon(Icons.link),
                    label: Text(s.addRelationship),
                  ),
                ],
              ),
              for (final r in rels)
                Builder(
                  builder: (context) {
                    final otherId = r.personId == person.id
                        ? r.relatedPersonId
                        : r.personId;
                    final other = bundle.persons
                        .where((p) => p.id == otherId)
                        .firstOrNull;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(switch (r.type) {
                        RelationshipType.parent => Icons.arrow_upward,
                        RelationshipType.child => Icons.arrow_downward,
                        RelationshipType.spouse => Icons.favorite_outline,
                        RelationshipType.sibling => Icons.people_outline,
                      }),
                      title: Text(
                        '${_relLabel(s, r.type)} · ${other?.fullName ?? ''}',
                      ),
                      subtitle: r.status == RelationshipStatus.pending
                          ? Text(s.pending)
                          : null,
                      trailing: r.status == RelationshipStatus.pending
                          ? TextButton(
                              onPressed: () async {
                                try {
                                  await ref
                                      .read(familyRepositoryProvider)
                                      .confirmRelationship(r.id)
                                      .unwrap();
                                  setState(() => _reload++);
                                } on Exception catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(s.errorUnknown)),
                                    );
                                  }
                                }
                              },
                              child: Text(s.confirmed),
                            )
                          : null,
                    );
                  },
                ),
              if (rels.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    s.addRelationship,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.inkSoft),
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.photos,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _addPhoto(context, person),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(s.addPhoto),
                  ),
                ],
              ),
              if (bundle.photos.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    s.addPhoto,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.inkSoft),
                  ),
                )
              else
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    for (final p in bundle.photos) _PhotoThumb(photo: p),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  String _relLabel(AppLocalizations s, RelationshipType t) => switch (t) {
    RelationshipType.parent => s.relParent,
    RelationshipType.child => s.relChild,
    RelationshipType.spouse => s.relSpouse,
    RelationshipType.sibling => s.relSibling,
  };

  Future<void> _addRelationship(
    BuildContext context,
    Person person,
    List<Person> persons,
  ) async {
    final s = context.l10n;
    final others = persons.where((p) => p.id != person.id).toList();
    var selected = others.firstOrNull;
    var type = RelationshipType.parent;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(s.addRelationship),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Person>(
                initialValue: selected,
                decoration: InputDecoration(labelText: s.relatedPerson),
                items: [
                  for (final p in others)
                    DropdownMenuItem(value: p, child: Text(p.fullName)),
                ],
                onChanged: (v) => setDialogState(() => selected = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<RelationshipType>(
                initialValue: type,
                decoration: InputDecoration(labelText: s.relationships),
                items: [
                  for (final t in RelationshipType.values)
                    DropdownMenuItem(value: t, child: Text(_relLabel(s, t))),
                ],
                onChanged: (v) => setDialogState(() => type = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(s.save),
            ),
          ],
        ),
      ),
    );
    if (ok != true || selected == null) return;
    try {
      await ref
          .read(familyRepositoryProvider)
          .addRelationship(
            personId: person.id,
            relatedPersonId: selected!.id,
            type: type,
          )
          .unwrap();
      setState(() => _reload++);
    } on Exception catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.errorUnknown)));
      }
    }
  }

  /// Pick, describe, and upload a photo of this person. Visibility is the
  /// photo's own setting; tagging or later linking to a story never widens it.
  Future<void> _addPhoto(BuildContext context, Person person) async {
    final s = context.l10n;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
    );
    if (picked == null || !context.mounted) return;

    final caption = TextEditingController();
    var visibility = PhotoVisibility.private; // always starts private
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(s.addPhoto),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: caption,
                  decoration: InputDecoration(labelText: s.photoCaption),
                ),
                const SizedBox(height: 16),
                Text(
                  s.whoCanSee,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                RadioGroup<PhotoVisibility>(
                  groupValue: visibility,
                  onChanged: (x) => setDialogState(() => visibility = x!),
                  child: Column(
                    children: [
                      for (final v in PhotoVisibility.values)
                        RadioListTile<PhotoVisibility>(
                          value: v,
                          title: Text(
                            v == PhotoVisibility.private
                                ? s.visPrivate
                                : s.visFamily,
                          ),
                          subtitle: Text(
                            v == PhotoVisibility.private
                                ? s.visPhotoPrivateDesc
                                : s.visPhotoFamilyDesc,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(s.save),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    try {
      final uid = ref.read(currentUserIdProvider);
      if (uid == null) throw StateError('no session');
      final photoId = newUuid();
      final ext = picked.name.contains('.')
          ? picked.name.split('.').last
          : 'jpg';
      // Uploader-namespaced path: the storage insert policy rejects any write
      // outside your own prefix.
      final storagePath = '${person.spaceId}/$uid/$photoId/photo.$ext';
      final repo = ref.read(photoRepositoryProvider);
      await repo.uploadImage(picked.path, storagePath).unwrap();
      try {
        await repo
            .createPhoto(
              Photo(
                id: photoId,
                spaceId: person.spaceId,
                imagePath: storagePath,
                caption: caption.text.trim().isEmpty
                    ? null
                    : caption.text.trim(),
                visibility: visibility,
                uploadedBy: uid,
                personIds: [person.id],
              ),
            )
            .unwrap();
      } on Exception catch (_) {
        // Photo-row insert failed after the upload: remove the orphan object.
        await repo.deleteImage(storagePath).unwrap();
        rethrow;
      }
      setState(() => _reload++);
    } on Exception catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.errorUnknown)));
      }
    }
  }
}

/// Shared create/edit person flow. [person] null means create. On failure the
/// snackbar says so; no fake success.
Future<void> _editPerson(
  BuildContext context,
  WidgetRef ref,
  VoidCallback onSaved, {
  required String spaceId,
  Person? person,
}) async {
  final s = context.l10n;
  final name = TextEditingController(text: person?.fullName ?? '');
  final birth = TextEditingController(text: person?.approxBirthDate ?? '');
  final death = TextEditingController(text: person?.approxDeathDate ?? '');
  final bio = TextEditingController(text: person?.bio ?? '');
  var gender = person?.gender;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(person == null ? s.addPerson : s.editPerson),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: InputDecoration(labelText: s.personName),
            ),
            TextField(
              controller: birth,
              decoration: InputDecoration(labelText: s.birthDate),
            ),
            TextField(
              controller: death,
              decoration: InputDecoration(labelText: s.deathDate),
            ),
            TextField(
              controller: bio,
              decoration: InputDecoration(labelText: s.bio),
            ),
            SizedBox(height: AppDimens.md),
            StatefulBuilder(
              builder: (context, setGender) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSectionLabel(s.personGender),
                  Wrap(
                    spacing: AppDimens.sm,
                    children: [
                      for (final g in PersonGender.values)
                        AppChip(
                          label: g == PersonGender.female
                              ? s.genderFemale
                              : s.genderMale,
                          selected: gender == g,
                          onTap: () =>
                              setGender(() => gender = gender == g ? null : g),
                        ),
                    ],
                  ),
                  Text(
                    s.personGenderHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(s.save),
        ),
      ],
    ),
  );
  if (ok != true || name.text.trim().isEmpty) return;
  try {
    final repo = ref.read(familyRepositoryProvider);
    if (person == null) {
      await repo
          .createPerson(
            Person(
              id: '',
              spaceId: spaceId,
              fullName: name.text.trim(),
              approxBirthDate: birth.text.trim().isEmpty
                  ? null
                  : birth.text.trim(),
              approxDeathDate: death.text.trim().isEmpty
                  ? null
                  : death.text.trim(),
              bio: bio.text.trim().isEmpty ? null : bio.text.trim(),
              gender: gender,
              createdBy: '',
            ),
          )
          .unwrap();
    } else {
      await repo
          .updatePerson(
            Person(
              id: person.id,
              spaceId: person.spaceId,
              fullName: name.text.trim(),
              photoPath: person.photoPath,
              approxBirthDate: birth.text.trim().isEmpty
                  ? null
                  : birth.text.trim(),
              approxDeathDate: death.text.trim().isEmpty
                  ? null
                  : death.text.trim(),
              bio: bio.text.trim().isEmpty ? null : bio.text.trim(),
              linkedUserId: person.linkedUserId,
              gender: gender,
              createdBy: person.createdBy,
            ),
          )
          .unwrap();
    }
    onSaved();
  } on Exception catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.errorUnknown)));
    }
  }
}

extension on _FamilyHomeScreenState {
  /// Adds the welcome-screen draft as real people: you first, then each
  /// parent with a parent relationship to you. Runs once; the draft is
  /// cleared either way.
  Future<void> _seedTree(
    BuildContext context,
    OnboardingDraft draft,
    String spaceId,
    VoidCallback onDone,
  ) async {
    final s = context.l10n;
    try {
      final repo = ref.read(familyRepositoryProvider);
      Person? you;
      if (draft.name.trim().isNotEmpty) {
        you = await repo
            .createPerson(
              Person(
                id: '',
                spaceId: spaceId,
                fullName: draft.name.trim(),
                createdBy: '',
              ),
            )
            .unwrap();
      }
      for (final parentName in [draft.father, draft.mother]) {
        if (parentName.trim().isEmpty) continue;
        final parent = await repo
            .createPerson(
              Person(
                id: '',
                spaceId: spaceId,
                fullName: parentName.trim(),
                createdBy: '',
              ),
            )
            .unwrap();
        if (you != null) {
          await repo
              .addRelationship(
                personId: you.id,
                relatedPersonId: parent.id,
                type: RelationshipType.parent,
              )
              .unwrap();
        }
      }
      await Onboarding.clearDraft();
      onDone();
    } on Exception catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.errorUnknown)));
      }
    }
  }

  Future<void> _removeMember(
    BuildContext context,
    FamilyMember member,
    VoidCallback refresh,
  ) async {
    final s = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.removeMember),
        content: Text(s.removeMemberBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.removeMember),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(familyRepositoryProvider).removeMember(member.id).unwrap();
      refresh();
    } on Exception catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.errorUnknown)));
      }
    }
  }
}

/// The one-time card offering to add the welcome-screen names to the tree.
class _SeedTreeCard extends StatelessWidget {
  const _SeedTreeCard({
    required this.draft,
    required this.onAdd,
    required this.onDismiss,
  });

  final OnboardingDraft draft;
  final VoidCallback onAdd;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final separator = s.localeName == 'ar' ? '، ' : ', ';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.onboardingSeedTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(s.onboardingSeedBody(draft.names.join(separator))),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    key: const Key('seed_tree_add'),
                    onPressed: onAdd,
                    child: Text(s.onboardingSeedAdd),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    key: const Key('seed_tree_dismiss'),
                    onPressed: onDismiss,
                    child: Text(s.onboardingSeedDismiss),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonBundle {
  const _PersonBundle(
    this.space,
    this.persons,
    this.relationships,
    this.members,
    this.photos,
  );
  final FamilySpace? space;
  final List<Person> persons;
  final List<Relationship> relationships;
  final List<FamilyMember> members;
  final List<Photo> photos;
}

/// Photo thumbnail. Demo mode keeps the picked local file path; live mode
/// mints a short-lived signed URL. Never a placeholder that fakes content.
class _PhotoThumb extends ConsumerWidget {
  const _PhotoThumb({required this.photo});
  final Photo photo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(isDemoModeProvider);
    if (demo) {
      // dart:io File is unsupported on web preview builds: show the plain
      // sample frame there instead of throwing before errorBuilder can run.
      if (kIsWeb) {
        // A real URL (the bundled synthetic fixture) renders for real, so
        // review builds verify image display; anything else gets the frame.
        if (photo.imagePath.startsWith('http')) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              photo.imagePath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) =>
                  const ColoredBox(color: AppColors.sand),
            ),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: const ColoredBox(
            color: AppColors.sand,
            child: Center(
              child: Icon(Icons.photo_outlined, color: AppColors.inkSoft),
            ),
          ),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(photo.imagePath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) =>
              const ColoredBox(color: AppColors.sand),
        ),
      );
    }
    return FutureBuilder<String>(
      future: ref
          .read(photoRepositoryProvider)
          .createImageUrl(photo.imagePath)
          .unwrap(),
      builder: (context, snap) {
        final url = snap.data;
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: url == null
              ? const ColoredBox(color: AppColors.sand)
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) =>
                      const ColoredBox(color: AppColors.sand),
                ),
        );
      },
    );
  }
}
