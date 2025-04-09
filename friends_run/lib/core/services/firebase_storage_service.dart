import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseStorageService {
  static Future<String?> uploadProfileImage(String uid, File imageFile) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(uid)
          .child('profile.jpg');

      final uploadTask = await ref.putFile(imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print("Erro ao fazer upload da imagem: $e");
      return null;
    }
  }

  static Future<String?> getProfileImageUrl(String uid) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(uid)
          .child('profile.jpg');

      return await ref.getDownloadURL();
    } catch (e) {
      print("Erro ao pegar a URL da imagem: $e");
      return null;
    }
  }

  static Future<void> deleteProfileImage(String uid) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(uid)
          .child('profile.jpg');

      await ref.delete();
    } catch (e) {
      print("Erro ao deletar a imagem: $e");
    }
  }
}

