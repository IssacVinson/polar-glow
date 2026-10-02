import 'package:image_picker/image_picker.dart';

/// Picks a single image through the platform system picker.
///
/// Android uses the Photo Picker (see [enableAndroidSystemPhotoPicker]).
/// iOS uses PHPicker. Neither path requests broad photo-library access.
class JobPhotoPicker {
  JobPhotoPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Gallery / library selection for receipts or before/after job photos.
  Future<XFile?> pickFromGallery({int imageQuality = 85}) {
    return _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: imageQuality,
    );
  }
}
