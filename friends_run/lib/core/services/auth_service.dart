import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Importe o serviço
import 'package:friends_run/core/services/firebase_storage_service.dart';
import 'package:friends_run/models/user/app_user.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart'; // Para debugPrint

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<AppUser?> registerUser({
    required String name,
    required String email,
    required String password,
    File? profileImage, // Opcional
  }) async {
    debugPrint("--- AuthService.registerUser START ---");
    try {
      UserCredential userCred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCred.user;
      if (user == null) {
        throw Exception("Falha ao criar usuário no Firebase Auth.");
      }
      final uid = user.uid;
      String imageUrl;

      // Lógica de upload/placeholder usando o SERVIÇO
      debugPrint("--- AuthService.registerUser: Chamando uploadProfileImage do serviço ---");
      // Passa o profileImage (pode ser null) para o serviço tratar
      imageUrl = await FirebaseStorageService.uploadProfileImage(
        uid,
        imageFile: profileImage,
      );
      // Verifica se o upload falhou (retornou placeholder mesmo com imagem)
       final placeholderUrl = FirebaseStorageService.getPlaceholderImageUrl();
       if (imageUrl == placeholderUrl && profileImage != null) {
          debugPrint("--- AuthService.registerUser: Upload falhou (serviço retornou placeholder), mas continuando com placeholder URL. ---");
          // Decide se quer lançar erro ou apenas usar placeholder
          // throw Exception("Falha no upload da imagem durante o registro.");
       } else {
          debugPrint("--- AuthService.registerUser: URL da imagem obtida/definida: $imageUrl ---");
       }


      final appUser = AppUser(
        uid: uid,
        name: name,
        email: email,
        profileImageUrl: imageUrl, // Usa a URL retornada pelo serviço
      );
      debugPrint("--- AuthService.registerUser: Salvando usuário no Firestore... ---");
      await _firestore.collection('users').doc(uid).set(appUser.toMap());
      debugPrint("--- AuthService.registerUser: Usuário salvo no Firestore. END ---");
      return appUser;

    } on FirebaseAuthException catch (e) {
       debugPrint("--- AuthService.registerUser: ERRO FirebaseAuth: ${e.code} - ${e.message} ---");
      throw Exception("Erro no registro: ${e.message ?? e.code}");
    } catch (e) {
       debugPrint("--- AuthService.registerUser: ERRO GERAL: $e ---");
      // Relança a exceção para o chamador (AuthNotifier) tratar
      rethrow;
      // throw Exception("Erro desconhecido durante o registro."); // Alternativa
    }
  }

  Future<AppUser?> loginUser({
    required String email,
    required String password,
  }) async {
    debugPrint("--- AuthService.loginUser START ---");
    try {
      UserCredential userCred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCred.user;
      if (user == null) {
        throw Exception("Falha ao obter usuário após login.");
      }
      final uid = user.uid;
      debugPrint("--- AuthService.loginUser: Logado no Auth, buscando Firestore (UID: $uid)... ---");
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists || doc.data() == null) {
         debugPrint("--- AuthService.loginUser: Documento não encontrado no Firestore. Deslogando. ---");
        await _auth.signOut();
        throw Exception('Dados do usuário não encontrados.');
      }
      debugPrint("--- AuthService.loginUser: Documento encontrado. END ---");
      return AppUser.fromMap(doc.data()!);
    } on FirebaseAuthException catch (e) {
      debugPrint("--- AuthService.loginUser: ERRO FirebaseAuth: ${e.code} - ${e.message} ---");
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
         throw Exception('Email ou senha inválidos.');
      }
       throw Exception('Erro no login (${e.code}).');
    } catch (e) {
      debugPrint("--- AuthService.loginUser: ERRO GERAL: $e ---");
      rethrow; // Relança para AuthNotifier
      // throw Exception('Erro desconhecido durante o login.');
    }
  }

  Future<AppUser?> signInWithGoogle() async {
     debugPrint("--- AuthService.signInWithGoogle START ---");
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
         debugPrint("--- AuthService.signInWithGoogle: Usuário cancelou fluxo Google. ---");
        return null; // Usuário cancelou
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

       debugPrint("--- AuthService.signInWithGoogle: Obtendo credencial Firebase... ---");
      final UserCredential userCred = await _auth.signInWithCredential(credential);
      final user = userCred.user;
      if (user == null) {
         throw Exception("Falha ao obter usuário do Firebase após login com Google.");
      }
      final uid = user.uid;
       debugPrint("--- AuthService.signInWithGoogle: Logado no Auth, verificando Firestore (UID: $uid)... ---");

      final docRef = _firestore.collection('users').doc(uid);
      final docSnap = await docRef.get();

      if (!docSnap.exists || docSnap.data() == null) {
         debugPrint("--- AuthService.signInWithGoogle: Novo usuário Google ou Firestore incompleto. Criando/Atualizando Doc... ---");
        String imageUrl = FirebaseStorageService.getPlaceholderImageUrl(); // Usa placeholder

        final appUser = AppUser(
          uid: uid,
          name: user.displayName ?? 'Usuário Google',
          email: user.email ?? '',
          profileImageUrl: imageUrl, // Usa placeholder definido
        );
        await docRef.set(appUser.toMap(), SetOptions(merge: true));
         debugPrint("--- AuthService.signInWithGoogle: Documento Firestore criado/atualizado. END ---");
        return appUser;
      } else {
         debugPrint("--- AuthService.signInWithGoogle: Usuário existente no Firestore. END ---");
        return AppUser.fromMap(docSnap.data()!);
      }
    } on FirebaseAuthException catch(e){
       debugPrint("--- AuthService.signInWithGoogle: ERRO FirebaseAuth: ${e.code} - ${e.message} ---");
       // Tratar 'account-exists-with-different-credential' se necessário
       throw Exception("Erro ao fazer login com Google (${e.code}).");
    } catch (e) {
      debugPrint('--- AuthService.signInWithGoogle: ERRO GERAL: $e ---');
       try { await GoogleSignIn().signOut(); } catch (_) {} // Tenta limpar estado do Google
      rethrow;
      // throw Exception("Erro desconhecido durante o login com Google.");
    }
  }

  Future<void> logout() async {
     debugPrint("--- AuthService.logout START ---");
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
         debugPrint("--- AuthService.logout: Google Signed Out ---");
      }
      await _auth.signOut();
       debugPrint("--- AuthService.logout: Firebase Auth Signed Out ---");
       debugPrint("--- AuthService.logout END ---");
    } catch (e) {
      debugPrint('--- AuthService.logout: ERRO: $e ---');
      rethrow; // Relança para AuthNotifier
    }
  }

  Future<AppUser?> getCurrentUser() async {
     // Este método não precisa de logs extensos, usado internamente ou raramente
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return AppUser.fromMap(data);
    } catch (e) {
      debugPrint('Erro silencioso ao obter usuário atual: $e');
      return null; // Retorna null silenciosamente
    }
  }

  Future<bool> isGoogleSignedIn() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData.any((info) => info.providerId == GoogleAuthProvider.PROVIDER_ID);
  }


  // --- Método de Atualização de Perfil ---
  Future<bool> updateUserProfile({
    required String uid,
    required String name,
    required String email,
    File? newProfileImage, // Opcional
  }) async {
     debugPrint("--- AuthService.updateUserProfile START (UID: $uid) ---");
    final user = _auth.currentUser;
    if (user == null || user.uid != uid) {
       debugPrint("--- AuthService.updateUserProfile: ERRO - Usuário inválido ou UID não corresponde. ---");
      throw Exception("Usuário não autenticado ou UID não corresponde.");
    }

    try {
      final Map<String, dynamic> updates = {};
      bool needsFirestoreUpdate = false;

      // 1. Atualizar Nome
      // Opcional: Comparar com valor atual antes de marcar para update
      // AppUser? currentUserData = await getCurrentUser(); // Poderia buscar aqui
      // if (currentUserData == null || currentUserData.name != name) { ... }
      debugPrint("--- AuthService.updateUserProfile: Preparando atualização de nome para '$name' ---");
      updates['name'] = name;
      needsFirestoreUpdate = true;

      // 2. Atualizar Email
      final String currentAuthEmail = user.email ?? "";
      if (email.trim().toLowerCase() != currentAuthEmail.toLowerCase()) {
         debugPrint("--- AuthService.updateUserProfile: Tentando atualizar email Auth de '$currentAuthEmail' para '$email' ---");
        try {
          await user.updateEmail(email.trim());
           debugPrint("--- AuthService.updateUserProfile: Email Auth atualizado. ---");
          updates['email'] = email.trim();
          needsFirestoreUpdate = true;
        } on FirebaseAuthException catch (e) {
           debugPrint("--- AuthService.updateUserProfile: ERRO FirebaseAuth ao atualizar email: ${e.code} ---");
           if (e.code == 'requires-recent-login') {
            throw Exception('Para alterar seu email, por favor, faça logout e login novamente.');
          } else if (e.code == 'email-already-in-use') {
            throw Exception('Este email já está sendo utilizado por outra conta.');
          } else {
            throw Exception('Ocorreu um erro ao atualizar seu email (${e.code}).');
          }
        }
      } else {
         debugPrint("--- AuthService.updateUserProfile: Email não modificado ('$email'). ---");
      }

      // 3. Atualizar Foto de Perfil
      if (newProfileImage != null) {
         debugPrint("--- AuthService.updateUserProfile: Nova imagem fornecida. Chamando uploadProfileImage do serviço... ---");
        String newImageUrl = await FirebaseStorageService.uploadProfileImage(
          uid,
          imageFile: newProfileImage,
        );

        final placeholderUrl = FirebaseStorageService.getPlaceholderImageUrl();
         debugPrint("--- AuthService.updateUserProfile: URL retornada pelo serviço: $newImageUrl ---");
         debugPrint("--- AuthService.updateUserProfile: URL placeholder para comparação: $placeholderUrl ---");

        // Verifica se o upload falhou (retornou placeholder)
        if (newImageUrl == placeholderUrl) {
           debugPrint("--- AuthService.updateUserProfile: ERRO - Upload da imagem falhou (serviço retornou placeholder). ---");
          throw Exception('Falha ao salvar a nova foto de perfil.');
        } else {
           // Somente atualiza se o upload foi bem-sucedido
           debugPrint("--- AuthService.updateUserProfile: Upload OK. Atualizando URL no Firestore. ---");
          updates['profileImageUrl'] = newImageUrl;
          needsFirestoreUpdate = true;
        }
      } else {
         debugPrint("--- AuthService.updateUserProfile: Nenhuma nova imagem fornecida. ---");
      }

      // 4. Atualizar dados no Firestore (se houver alterações)
      if (needsFirestoreUpdate && updates.isNotEmpty) {
         debugPrint("--- AuthService.updateUserProfile: Atualizando Firestore com: $updates ---");
        await _firestore.collection('users').doc(uid).update(updates);
         debugPrint("--- AuthService.updateUserProfile: Firestore atualizado. ---");
      } else {
         debugPrint("--- AuthService.updateUserProfile: Nenhuma atualização necessária no Firestore. ---");
      }

      debugPrint("--- AuthService.updateUserProfile: END (Sucesso) ---");
      return true; // Sucesso geral

    } on FirebaseException catch (e) {
       debugPrint("--- AuthService.updateUserProfile: ERRO FirebaseException: ${e.code} - ${e.message} ---");
        if (e.message != null && (e.code == 'requires-recent-login' || e.code == 'email-already-in-use')) {
         throw Exception(e.message);
       }
      throw Exception('Erro ao salvar (${e.code}). Verifique sua conexão.');
    } catch (e) {
       debugPrint("--- AuthService.updateUserProfile: ERRO GERAL: $e ---");
       if (e is Exception && e.toString().contains("Exception: ")) {
          throw Exception(e.toString().replaceFirst("Exception: ", ""));
       }
      throw Exception('Ocorreu um erro inesperado ao salvar seu perfil.');
    }
  } // Fim de updateUserProfile
} // Fim da classe AuthService