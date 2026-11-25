import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/features/family/domain/invite_code.dart';
import 'package:family_stories/features/family/presentation/invite_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _InviteData {
  const _InviteData({
    required this.id,
    required this.name,
    required this.code,
    required this.isOwner,
  });
  final String id;
  final String name;
  final ShortInviteCode code;
  final bool isOwner;
}

/// Loads the family and who the viewer is, then shows [InvitePage].
class InviteScreen extends ConsumerWidget {
  const InviteScreen({this.from = 'unknown', super.key});

  final String from;

  Future<_InviteData?> _load(WidgetRef ref) async {
    final repo = ref.read(familyRepositoryProvider);
    final space = await repo.getMySpace().unwrap();
    if (space == null) return null;
    final members = await repo.listMembers(space.id).unwrap();
    final myId = ref.read(currentUserIdProvider);
    final code = InviteCode.parse(space.inviteShortCode);
    if (code is! ShortInviteCode) return null;
    return _InviteData(
      id: space.id,
      name: space.name,
      code: code,
      isOwner: members.any((m) => m.userId == myId && m.isOwner),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<_InviteData?>(
      future: _load(ref),
      builder: (context, snap) {
        final data = snap.data;
        if (data == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: snap.connectionState == ConnectionState.done
                  ? const SizedBox.shrink()
                  : const CircularProgressIndicator(),
            ),
          );
        }
        return InvitePage(
          familyName: data.name,
          shortCode: data.code,
          isOwner: data.isOwner,
          from: from,
          onRotate: () async {
            final raw = await ref
                .read(familyRepositoryProvider)
                .rotateInviteCode(data.id)
                .unwrap();
            final next = InviteCode.parse(raw);
            return next is ShortInviteCode ? next : null;
          },
        );
      },
    );
  }
}
