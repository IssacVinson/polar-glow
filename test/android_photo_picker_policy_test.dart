import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:polar_glow/core/media/android_photo_picker.dart';
import 'package:polar_glow/core/media/job_photo_picker.dart';

void main() {
  test('Play upload version is 1.0.3+6', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      RegExp(r'^version:\s*1\.0\.3\+6\s*$', multiLine: true).hasMatch(pubspec),
      isTrue,
    );
  });

  test('Android manifest strips broad photo/video/storage permissions', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(manifest.contains('xmlns:tools="http://schemas.android.com/tools"'),
        isTrue);

    for (final permission in [
      'android.permission.READ_MEDIA_IMAGES',
      'android.permission.READ_MEDIA_VIDEO',
      'android.permission.READ_MEDIA_AUDIO',
      'android.permission.READ_MEDIA_VISUAL_USER_SELECTED',
      'android.permission.READ_EXTERNAL_STORAGE',
      'android.permission.WRITE_EXTERNAL_STORAGE',
    ]) {
      expect(manifest.contains(permission), isTrue,
          reason: '$permission must be listed so the merger can remove it');
    }

    final permissionBlocks = RegExp(
      r'<uses-permission\b[^>]*>',
      multiLine: true,
    ).allMatches(manifest).map((m) => m.group(0)!);

    for (final block in permissionBlocks) {
      final isBroadMedia = block.contains('READ_MEDIA_') ||
          block.contains('READ_EXTERNAL_STORAGE') ||
          block.contains('WRITE_EXTERNAL_STORAGE');
      if (!isBroadMedia) continue;
      expect(
        block.contains('tools:node="remove"') ||
            block.contains("tools:node='remove'"),
        isTrue,
        reason: 'Broad media/storage permission must be removed: $block',
      );
    }
  });

  test('startup enables the Android Photo Picker before image_picker runs', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    expect(mainSource.contains('enableAndroidSystemPhotoPicker()'), isTrue);
    expect(
      mainSource.indexOf('enableAndroidSystemPhotoPicker()') <
          mainSource.indexOf('runApp('),
      isTrue,
    );
  });

  test('receipt and job photos go through JobPhotoPicker gallery', () {
    final reimbursement =
        File('lib/screens/employee_reimbursement_screen.dart').readAsStringSync();
    expect(reimbursement.contains('JobPhotoPicker'), isTrue);
    expect(reimbursement.contains('pickFromGallery'), isTrue);
    expect(reimbursement.contains('ImageSource.gallery'), isFalse);
    expect(reimbursement.contains('Permission.photos'), isFalse);
    expect(reimbursement.contains('READ_MEDIA'), isFalse);
  });

  test('enableAndroidSystemPhotoPicker is safe on the test host', () {
    expect(enableAndroidSystemPhotoPicker, returnsNormally);
  });

  test('JobPhotoPicker can be constructed without a live picker session', () {
    expect(JobPhotoPicker.new, returnsNormally);
  });
}
