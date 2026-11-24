import 'package:flutter/services.dart';

/// Free space on the app's storage volume, read through a small native
/// channel (Android `StatFs`, iOS `volumeAvailableCapacityForImportantUsage`)
/// so no extra package is needed. Feeds the low-storage guard (spec 02).
abstract final class StorageSpace {
  static const channel = MethodChannel('com.mohager.hekayetna/storage');

  /// Free bytes, or null when the platform can't say (tests, web). Null
  /// means "unknown", which never blocks recording.
  static Future<int?> freeBytes() async {
    try {
      return await channel.invokeMethod<int>('freeBytes');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
