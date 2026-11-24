import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_text_styles.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// A person's avatar: the photo when there is one, else their first letter
/// on a tint. Members are olive-tint; narrators of the open story are
/// terracotta-tint (Design System PersonChip card).
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    required this.name,
    this.photoUrl,
    this.size,
    this.tone = PersonAvatarTone.olive,
    super.key,
  });

  final String name;
  final String? photoUrl;

  /// Defaults to the Design System `avatar` size (44).
  final double? size;
  final PersonAvatarTone tone;

  @override
  Widget build(BuildContext context) {
    final hk = context.hk;
    final diameter = size ?? AppDimens.avatar;
    final (background, foreground) = switch (tone) {
      PersonAvatarTone.olive => (
        Theme.of(context).colorScheme.primaryContainer,
        Theme.of(context).colorScheme.onSurface,
      ),
      PersonAvatarTone.terracotta => (hk.recordTint, hk.record),
    };
    return Semantics(
      label: name,
      image: photoUrl != null,
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: background,
          image: photoUrl == null
              ? null
              : DecorationImage(
                  image: NetworkImage(photoUrl!),
                  fit: BoxFit.cover,
                ),
        ),
        alignment: Alignment.center,
        child: photoUrl == null
            ? ExcludeSemantics(
                child: Text(
                  name.isEmpty ? '?' : name.characters.first,
                  style: AppTextStyles.title.copyWith(color: foreground),
                ),
              )
            : null,
      ),
    );
  }
}

enum PersonAvatarTone { olive, terracotta }
