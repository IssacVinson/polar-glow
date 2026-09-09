import 'package:flutter/foundation.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

/// Enables the Android system Photo Picker for `image_picker`.
///
/// Play's Photo & Video Permissions policy requires apps that only need
/// occasional photo selection (receipts, before/after job photos) to use a
/// system picker instead of `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO`.
///
/// On Android 13+ the plugin already uses the Photo Picker. Setting this flag
/// also uses the Play-services backport on Android 12 and below, so the app
/// does not need `READ_EXTERNAL_STORAGE`.
void enableAndroidSystemPhotoPicker() {
  if (kIsWeb) return;
  final implementation = ImagePickerPlatform.instance;
  if (implementation is ImagePickerAndroid) {
    implementation.useAndroidPhotoPicker = true;
  }
}
