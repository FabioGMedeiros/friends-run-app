import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseStorageService {
  // Caminho para a imagem placeholder no Firebase Storage
  static const String placeholderPath = 'https://firebasestorage.googleapis.com/v0/b/friends-run-f4061.firebasestorage.app/o/profile_placeholder.png?alt=media&token=5943558c-0747-4250-a601-999080a820cb';
  
  /// Faz upload da imagem de perfil (opcional) e retorna a URL
  /// Se imageFile for null, retorna a URL do placeholder
  static Future<String> uploadProfileImage(String uid, {File? imageFile}) async {
    try {
      if (imageFile == null) {
        // Retorna a URL do placeholder se nenhuma imagem for fornecida
        return getPlaceholderImageUrl();
      }
      
      final ref = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(uid)
          .child('profile.jpg');

      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      print("Erro ao fazer upload da imagem: $e");
      // Em caso de erro, retorna o placeholder
      return getPlaceholderImageUrl();
    }
  }

  /// Obtém a URL da imagem de perfil ou o placeholder se não existir
  static Future<String> getProfileImageUrl(String uid) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(uid)
          .child('profile.jpg');

      return await ref.getDownloadURL();
    } catch (e) {
      print("Imagem não encontrada, usando placeholder: $e");
      return getPlaceholderImageUrl();
    }
  }

  /// Remove a imagem de perfil e retorna a URL do placeholder
  static Future<String> deleteProfileImage(String uid) async {
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
    
    // Sempre retorna o placeholder após deletar
    return getPlaceholderImageUrl();
  }

  /// Obtém a URL da imagem placeholder
  static Future<String> getPlaceholderImageUrl() async {
    try {
      final ref = FirebaseStorage.instance.ref().child(placeholderPath);
      return await ref.getDownloadURL();
    } catch (e) {
      print("Erro ao obter placeholder: $e");
      // Fallback para um placeholder genérico se o padrão não existir
      return 'https://via.placeholder.com/150';
    }
  }
}