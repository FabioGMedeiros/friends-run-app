import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; // Para debugPrint

class FirebaseStorageService {

  // URL Completa da imagem placeholder no Firebase Storage
  static const String placeholderUrl = 'https://firebasestorage.googleapis.com/v0/b/friends-run-f4061.firebasestorage.app/o/profile_placeholder.png?alt=media&token=5943558c-0747-4250-a601-999080a820cb';

  // Retorna diretamente a URL da imagem placeholder.
  static String getPlaceholderImageUrl() {
    return placeholderUrl;
  }

  /// Faz upload da imagem de perfil e retorna a URL.
  /// Retorna a URL do placeholder se imageFile for null ou ocorrer erro no upload.
  static Future<String> uploadProfileImage(String uid, {File? imageFile}) async {
    debugPrint("--- FSS.uploadProfileImage: INÍCIO (UID: $uid, imageFile: ${imageFile?.path ?? 'null'}) ---");
    try {
      if (imageFile == null) {
        debugPrint("--- FSS.uploadProfileImage: imageFile é NULL, retornando placeholder. ---");
        return getPlaceholderImageUrl();
      }

      final ref = FirebaseStorage.instance
          .ref()
          .child('users') // Pasta 'users'
          .child(uid)     // Subpasta com o UID do usuário
          .child('profile.jpg'); // Nome do arquivo padrão

      final metadata = SettableMetadata(contentType: 'image/jpeg');

      debugPrint("--- FSS.uploadProfileImage: TENTANDO ref.putFile para ${ref.fullPath} ---");
      await ref.putFile(imageFile, metadata); // Upload acontece aqui

      debugPrint("--- FSS.uploadProfileImage: putFile BEM SUCEDIDO. Obtendo URL... ---");
      final downloadUrl = await ref.getDownloadURL(); // Obtenção da URL acontece aqui

      debugPrint("--- FSS.uploadProfileImage: URL obtida: $downloadUrl ---");
      return downloadUrl;

    } catch (e) {
      // Captura qualquer erro durante o putFile ou getDownloadURL
      debugPrint("--- FSS.uploadProfileImage: ERRO CAPTURADO: $e ---");
      final placeholder = getPlaceholderImageUrl();
      debugPrint("--- FSS.uploadProfileImage: Retornando placeholder ($placeholder) devido ao erro. ---");
      return placeholder;
    }
  }

  /// Obtém a URL da imagem de perfil do usuário ou o placeholder se não existir/erro.
  static Future<String> getProfileImageUrl(String uid) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(uid)
          .child('profile.jpg');
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      return getPlaceholderImageUrl();
    }
  }

  /// Remove a imagem de perfil do usuário no Storage.
  /// Retorna a URL do placeholder após a tentativa de exclusão.
  static Future<String> deleteProfileImage(String uid) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(uid)
          .child('profile.jpg');
      debugPrint("Tentando deletar ${ref.fullPath}");
      await ref.delete();
      debugPrint("Imagem deletada com sucesso para $uid.");
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') {
        debugPrint("Erro ao deletar a imagem ($uid): ${e.code} - ${e.message}");
      } else {
        debugPrint("Imagem para $uid não encontrada para deletar (já não existia?).");
      }
    } catch (e) {
      debugPrint("Erro inesperado ao deletar a imagem ($uid): $e");
    }
    return getPlaceholderImageUrl();
  }
}