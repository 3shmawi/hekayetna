import 'dart:io';

import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/core/theme/app_colors.dart';
import 'package:family_stories/features/photos/data/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StoryPhotosGrid extends ConsumerWidget {
  const StoryPhotosGrid({required this.photoIds, super.key});
  final List<String> photoIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(isDemoModeProvider);
    return FutureBuilder<List<Photo>>(
      future: ref
          .read(familyRepositoryProvider)
          .getMySpace()
          .unwrap()
          .then(
            (space) => space == null
                ? <Photo>[]
                : ref
                      .read(photoRepositoryProvider)
                      .listPhotos(space.id)
                      .unwrap(),
          ),
      builder: (context, snap) {
        final visible = (snap.data ?? const <Photo>[])
            .where((p) => photoIds.contains(p.id))
            .toList();
        return GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            // One frame per LINKED photo, even when the photo itself is not
            // accessible: the link is story metadata, the image is not.
            for (final id in photoIds)
              if (visible.any((p) => p.id == id))
                _StoryPhotoThumb(
                  photo: visible.firstWhere((p) => p.id == id),
                  demo: demo,
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.sand,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.inkSoft),
                  ),
                  child: const Center(
                    child: Icon(Icons.lock_outline, color: AppColors.inkSoft),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _StoryPhotoThumb extends ConsumerWidget {
  const _StoryPhotoThumb({required this.photo, required this.demo});
  final Photo photo;
  final bool demo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
