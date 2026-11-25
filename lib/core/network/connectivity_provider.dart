import 'package:family_stories/core/network/connectivity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// true while the device has a network connection. Tests override it with
/// a plain stream: `onlineProvider.overrideWith((ref) => Stream.value(false))`.
final onlineProvider = StreamProvider<bool>(
  (ref) => ConnectivityStatus.onlineChanges,
);
