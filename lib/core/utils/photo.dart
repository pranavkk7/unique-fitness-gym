import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/sub_page.dart';
import 'contact.dart';

/// Asks camera or gallery, then returns a small JPEG (about 600 px wide) so photos stay light in
/// storage and backups. Returns null if cancelled. [allowRemove] adds a "Remove photo" option,
/// which returns an empty list.
Future<Uint8List?> pickMemberPhoto(BuildContext context, {bool allowRemove = false}) async {
  final choice = await showAppSheet<String>(
    context,
    scrollable: false,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHeader('Member photo'),
            ListTile(leading: const Icon(Icons.photo_camera_rounded), title: const Text('Take a photo'), onTap: () => Navigator.pop(sheetContext, 'camera')),
            ListTile(leading: const Icon(Icons.photo_library_rounded), title: const Text('Choose from gallery'), onTap: () => Navigator.pop(sheetContext, 'gallery')),
            if (allowRemove) ListTile(leading: const Icon(Icons.delete_outline_rounded), title: const Text('Remove photo'), onTap: () => Navigator.pop(sheetContext, 'remove')),
          ],
        ),
      ),
    ),
  );
  if (choice == null) return null;
  if (choice == 'remove') return Uint8List(0);
  try {
    final file = await ImagePicker().pickImage(
      source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 78,
      preferredCameraDevice: CameraDevice.front,
    );
    return file == null ? null : await file.readAsBytes();
  } catch (_) {
    if (context.mounted) showMessage(context, 'Could not open the ${choice == 'camera' ? 'camera' : 'gallery'}.');
    return null;
  }
}
