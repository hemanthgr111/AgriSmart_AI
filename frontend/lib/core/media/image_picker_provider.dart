import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Picks an image from a source. Indirection lets tests inject fake bytes.
typedef PickImage = Future<XFile?> Function(
  ImageSource source, {
  int? maxWidth,
  int? imageQuality,
});

/// A shared image picker used by the diagnosis and community features.
final Provider<PickImage> pickImageProvider = Provider<PickImage>((ref) {
  final ImagePicker picker = ImagePicker();
  return (ImageSource source, {int? maxWidth, int? imageQuality}) {
    return picker.pickImage(
      source: source,
      maxWidth: (maxWidth ?? 1600).toDouble(),
      imageQuality: imageQuality ?? 85,
    );
  };
});
