import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';

class PhotoPickerField extends StatelessWidget {
  final List<String> paths;
  final ValueChanged<List<String>> onChanged;
  final int maxPhotos;

  const PhotoPickerField({
    super.key,
    required this.paths,
    required this.onChanged,
    this.maxPhotos = 5,
  });

  Future<void> _pick(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final image = await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (image != null) onChanged([...paths, image.path]);
  }

  void _remove(int index) =>
      onChanged(List<String>.from(paths)..removeAt(index));

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (paths.isNotEmpty) ...[
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: paths.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(paths[i]),
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: context.colors.border),
                        ),
                        child: Icon(Icons.broken_image_outlined,
                            color: context.colors.textMuted, size: 28),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _remove(i),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            size: 13, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (paths.length < maxPhotos)
          GestureDetector(
            onTap: () => _pick(context),
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.colors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 18, color: context.colors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      paths.isEmpty ? 'Add photos' : 'Add another photo',
                      style: TextStyle(
                          color: context.colors.textSecondary, fontSize: 13),
                    ),
                  ),
                  Text(
                    '${paths.length}/$maxPhotos',
                    style: TextStyle(
                        color: context.colors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
