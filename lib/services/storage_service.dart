import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  // ════════════════════════════════════════════════════════════════════
  // IMAGE PICKING
  // ════════════════════════════════════════════════════════════════════

  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked == null) return null;
      return File(picked.path);
    } catch (e) {
      return null;
    }
  }

  Future<File?> pickImageFromCamera() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked == null) return null;
      return File(picked.path);
    } catch (e) {
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // UPLOAD OPERATIONS
  // ════════════════════════════════════════════════════════════════════

  // Upload driver shuttle ID image
  Future<Map<String, dynamic>> uploadShuttleIdImage({
    required File imageFile,
    required String uid,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final ref = _storage.ref().child('shuttle_ids/$uid/shuttle_id.jpg');

      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Track upload progress
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((snapshot) {
          final progress =
              snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }

      await uploadTask;
      final downloadUrl = await ref.getDownloadURL();

      return {'success': true, 'url': downloadUrl};
    } catch (e) {
      return {'success': false, 'error': 'Failed to upload image. Please try again.'};
    }
  }

  // Upload profile picture
  Future<Map<String, dynamic>> uploadProfilePicture({
    required File imageFile,
    required String uid,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final ref = _storage.ref().child('profile_pictures/$uid/profile.jpg');

      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((snapshot) {
          final progress =
              snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }

      await uploadTask;
      final downloadUrl = await ref.getDownloadURL();

      return {'success': true, 'url': downloadUrl};
    } catch (e) {
      return {'success': false, 'error': 'Failed to upload profile picture.'};
    }
  }

  // Upload puzzle image (admin only)
  Future<Map<String, dynamic>> uploadPuzzleImage({
    required File imageFile,
    required String storagePath,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final ref = _storage.ref().child(storagePath);

      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }

      await uploadTask;
      final downloadUrl = await ref.getDownloadURL();

      return {'success': true, 'url': downloadUrl};
    } catch (e) {
      return {'success': false, 'error': 'Failed to upload puzzle image.'};
    }
  }

  // Upload lost & found item image
  Future<Map<String, dynamic>> uploadLostFoundImage({
    required File imageFile,
    required String itemId,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final ref = _storage.ref().child('lost_found/$itemId/item_image.jpg');
      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }
      await uploadTask;
      final downloadUrl = await ref.getDownloadURL();
      return {'success': true, 'url': downloadUrl};
    } catch (e) {
      return {'success': false, 'error': 'Failed to upload image. Please try again.'};
    }
  }

  // Upload ad image (admin only)
  Future<Map<String, dynamic>> uploadAdImage({
    required File imageFile,
    required String adId,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final ref = _storage.ref().child('ads/$adId/ad_image.jpg');

      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((snapshot) {
          final progress =
              snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }

      await uploadTask;
      final downloadUrl = await ref.getDownloadURL();

      return {'success': true, 'url': downloadUrl};
    } catch (e) {
      return {'success': false, 'error': 'Failed to upload ad image.'};
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // DELETE OPERATIONS
  // ════════════════════════════════════════════════════════════════════

  Future<bool> deleteFile(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
      return true;
    } catch (e) {
      return false;
    }
  }
}