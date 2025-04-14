import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Importe os serviços
import 'package:friends_run/core/services/firebase_storage_service.dart';
import 'package:friends_run/models/user/app_user.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart'; // Para debugPrint

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, AppUser> _userCache = {}; 

  Future<AppUser?> registerUser({
    required String name,
    required String email,
    required String password,
    File? profileImage, // Opcional
  }) async {
    // Lógica e logging de Updated upstream, com adição ao cache
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

      debugPrint("--- AuthService.registerUser: Chamando uploadProfileImage do serviço ---");
      imageUrl = await FirebaseStorageService.uploadProfileImage(
        uid,
        imageFile: profileImage,
      );
      final placeholderUrl = FirebaseStorageService.getPlaceholderImageUrl();
      if (imageUrl == placeholderUrl && profileImage != null) {
         debugPrint("--- AuthService.registerUser: Upload falhou (serviço retornou placeholder), mas continuando com placeholder URL. ---");
         // Considerar lançar erro se o upload for crítico
         // throw Exception("Falha no upload da imagem durante o registro.");
      } else {
         debugPrint("--- AuthService.registerUser: URL da imagem obtida/definida: $imageUrl ---");
      }

      final appUser = AppUser(
        uid: uid,
        name: name,
        email: email,
        profileImageUrl: imageUrl,
      );
      debugPrint("--- AuthService.registerUser: Salvando usuário no Firestore... ---");
      await _firestore.collection('users').doc(uid).set(appUser.toMap());

      // Adiciona ao cache (de Stashed changes)
      _userCache[uid] = appUser;
      debugPrint("--- AuthService.registerUser: Usuário salvo no Firestore e adicionado ao cache. END ---");

      return appUser;

    } on FirebaseAuthException catch (e) {
      debugPrint("--- AuthService.registerUser: ERRO FirebaseAuth: ${e.code} - ${e.message} ---");
      // Joga exceção mais específica (de Updated upstream)
      throw Exception("Erro no registro: ${e.message ?? e.code}");
    } catch (e) {
      debugPrint("--- AuthService.registerUser: ERRO GERAL: $e ---");
      // Relança a exceção (de Updated upstream)
      rethrow;
    }
  }

  Future<AppUser?> loginUser({
    required String email,
    required String password,
  }) async {
    // Usa getUserById (de Stashed changes) mas com error handling de Updated upstream
    debugPrint("--- AuthService.loginUser START ---");
    try {
      UserCredential userCred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCred.user;
      if (user == null) {
        // Segurança adicional, embora signInWithEmailAndPassword deva jogar erro antes
        throw Exception("Falha ao obter usuário após login.");
      }
      final uid = user.uid;
      debugPrint("--- AuthService.loginUser: Logado no Auth, buscando AppUser (UID: $uid)... ---");

      // Usa getUserById para buscar (inclui cache)
      final appUser = await getUserById(uid);

      if (appUser == null) {
        // Usuário autenticado mas sem registro no Firestore - estado inconsistente
        debugPrint("--- AuthService.loginUser: Usuário autenticado ($uid) mas não encontrado no Firestore. Deslogando. ---");
        await logout(); // Desloga para evitar estado inconsistente
        throw Exception('Dados do usuário não encontrados. Por favor, tente novamente.');
      }

      debugPrint("--- AuthService.loginUser: AppUser encontrado. END ---");
      return appUser;

    } on FirebaseAuthException catch (e) {
      debugPrint("--- AuthService.loginUser: ERRO FirebaseAuth: ${e.code} - ${e.message} ---");
      // Trata erros específicos de login (de Updated upstream)
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential' || e.code == 'invalid-email') {
         throw Exception('Email ou senha inválidos.');
      }
      throw Exception('Erro no login (${e.code}).'); // Outros erros auth
    } catch (e) {
      debugPrint("--- AuthService.loginUser: ERRO GERAL: $e ---");
      // Relança outros erros (de Updated upstream)
      rethrow;
    }
  }

  Future<AppUser?> signInWithGoogle() async {
    // Combina getUserById (Stashed changes) com error handling e uso de placeholder (Updated upstream)
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
      debugPrint("--- AuthService.signInWithGoogle: Logado no Auth, verificando AppUser (UID: $uid)... ---");

      // Usa getUserById (de Stashed changes)
      AppUser? appUser = await getUserById(uid);

      if (appUser == null) {
        // Novo usuário via Google ou Firestore incompleto
        debugPrint("--- AuthService.signInWithGoogle: Novo usuário Google ou Firestore incompleto. Criando/Atualizando Doc... ---");
        // Usa placeholder como fallback seguro (Updated upstream), mas tenta foto do Google primeiro (Stashed changes)
        final String profilePic = user.photoURL ?? FirebaseStorageService.getPlaceholderImageUrl();

        appUser = AppUser(
          uid: uid,
          name: user.displayName ?? 'Usuário Google',
          email: user.email ?? '', // Email deve vir do Google
          profileImageUrl: profilePic,
        );
        // Usa set com merge para segurança (de Updated upstream) caso algo exista parcialmente
        await _firestore.collection('users').doc(uid).set(appUser.toMap(), SetOptions(merge: true));
        _userCache[uid] = appUser; // Adiciona ao cache (de Stashed changes)
        debugPrint("--- AuthService.signInWithGoogle: Documento Firestore criado/atualizado. END ---");
      } else {
        debugPrint("--- AuthService.signInWithGoogle: Usuário existente no Firestore. END ---");
        // Opcional: Atualizar dados se necessário (lógica comentada de Stashed changes pode ser adaptada aqui se preciso)
      }

      return appUser;

    } on FirebaseAuthException catch (e) {
      debugPrint("--- AuthService.signInWithGoogle: ERRO FirebaseAuth: ${e.code} - ${e.message} ---");
      // Lança exceção (de Updated upstream)
      throw Exception("Erro ao fazer login com Google (${e.code}).");
    } catch (e) {
      debugPrint('--- AuthService.signInWithGoogle: ERRO GERAL: $e ---');
      try { await GoogleSignIn().signOut(); } catch (_) {} // Tenta limpar estado do Google
      // Relança exceção (de Updated upstream)
      rethrow;
    }
  }

  Future<void> logout() async {
    // Combina limpeza de cache (Stashed changes) com logging e rethrow (Updated upstream)
    debugPrint("--- AuthService.logout START ---");
    try {
      _userCache.clear(); // Limpa o cache
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
      rethrow; // Relança para AuthNotifier (Updated upstream)
    }
  }

  Future<AppUser?> getCurrentUser() async {
    // Usa a lógica com cache e getUserById (Stashed changes)
    try {
      final user = _auth.currentUser;
      if (user == null) {
        // Não precisa logar aqui, é um estado normal
        return null;
      }

      // Tenta obter do cache primeiro
      if (_userCache.containsKey(user.uid)) {
        // debugPrint("Usuário atual encontrado no cache: ${user.uid}"); // Log opcional
        return _userCache[user.uid];
      }

      // Se não está no cache, busca usando getUserById
      // debugPrint("Buscando usuário atual (via getUserById): ${user.uid}"); // Log opcional
      final appUser = await getUserById(user.uid);
      return appUser;

    } catch (e) {
      // Erro silencioso (Updated upstream), mas loga para debug
      debugPrint('Erro silencioso ao obter usuário atual: $e');
      return null;
    }
  }

  // --- getUserById (Veio de Stashed changes, mantido) ---
  Future<AppUser?> getUserById(String userId) async {
    if (_userCache.containsKey(userId)) {
      // debugPrint("Usuário encontrado no cache: $userId"); // Log opcional
      return _userCache[userId];
    }
    // debugPrint("Buscando usuário no Firestore: $userId"); // Log opcional
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        final appUser = AppUser.fromMap(doc.data()!);
        _userCache[userId] = appUser;
        return appUser;
      } else {
        // debugPrint("Usuário com ID $userId não encontrado no Firestore."); // Log opcional
        return null;
      }
    } catch (e) {
      debugPrint('Erro ao buscar usuário por ID ($userId): $e'); // Log mais informativo
      return null;
    }
  }

  // --- Funções Auxiliares e updateUserProfile (Veio de Updated upstream, mantido) ---
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<bool> isGoogleSignedIn() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData.any((info) => info.providerId == GoogleAuthProvider.PROVIDER_ID);
  }

  Future<bool> updateUserProfile({
    required String uid,
    required String name,
    required String email,
    File? newProfileImage,
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
      debugPrint("--- AuthService.updateUserProfile: Preparando atualização de nome para '$name' ---");
      updates['name'] = name;
      needsFirestoreUpdate = true;

      // 2. Atualizar Email
      final String currentAuthEmail = user.email ?? "";
      if (email.trim().toLowerCase() != currentAuthEmail.toLowerCase()) {
         debugPrint("--- AuthService.updateUserProfile: Tentando atualizar email Auth de '$currentAuthEmail' para '$email' ---");
        try {
          // ATENÇÃO: O Firebase Auth pode exigir reautenticação recente para updateEmail
          await user.verifyBeforeUpdateEmail(email.trim());
          // await user.updateEmail(email.trim()); // Método antigo, pode não enviar verificação
           debugPrint("--- AuthService.updateUserProfile: Verificação de email enviada (ou email Auth atualizado se não houver verificação). ---");
          // Nota: O email no Firestore só deve ser atualizado após a verificação pelo usuário.
          // Por simplicidade aqui, atualizamos imediatamente, mas o ideal seria
          // ter um campo 'pendingEmail' ou atualizar apenas após confirmação.
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
         // Verifica se o upload realmente funcionou (não retornou placeholder)
        if (newImageUrl != placeholderUrl) {
           debugPrint("--- AuthService.updateUserProfile: Upload OK. Atualizando URL no Firestore. ---");
          updates['profileImageUrl'] = newImageUrl;
          needsFirestoreUpdate = true;
          // Atualiza cache se o usuário atual estiver nele
          if (_userCache.containsKey(uid)) {
             _userCache[uid] = _userCache[uid]!.copyWith(profileImageUrl: newImageUrl);
          }
        } else {
           // Upload falhou, mas uma imagem foi fornecida. Lançar erro.
           debugPrint("--- AuthService.updateUserProfile: ERRO - Upload da imagem falhou (serviço retornou placeholder). ---");
          throw Exception('Falha ao salvar a nova foto de perfil.');
        }
      } else {
         debugPrint("--- AuthService.updateUserProfile: Nenhuma nova imagem fornecida. ---");
      }

      // 4. Atualizar dados no Firestore (se houver alterações)
      if (needsFirestoreUpdate && updates.isNotEmpty) {
         debugPrint("--- AuthService.updateUserProfile: Atualizando Firestore com: $updates ---");
        await _firestore.collection('users').doc(uid).update(updates);
        // Atualiza o cache se o usuário atual estiver nele (nome/email)
         if (_userCache.containsKey(uid)) {
             _userCache[uid] = _userCache[uid]!.copyWith(
                 name: updates['name'] ?? _userCache[uid]!.name,
                 email: updates['email'] ?? _userCache[uid]!.email,
                 // A imagem já foi atualizada acima se necessário
             );
         }
         debugPrint("--- AuthService.updateUserProfile: Firestore atualizado. ---");
      } else {
         debugPrint("--- AuthService.updateUserProfile: Nenhuma atualização necessária no Firestore. ---");
      }

      debugPrint("--- AuthService.updateUserProfile: END (Sucesso) ---");
      return true; // Sucesso geral

    } on FirebaseException catch (e) {
       // Captura erros específicos do Firebase (ex: permissão negada)
       debugPrint("--- AuthService.updateUserProfile: ERRO FirebaseException: ${e.code} - ${e.message} ---");
       // Relança exceções que já são informativas
       if (e.message != null && (e.code == 'requires-recent-login' || e.code == 'email-already-in-use')) {
         throw Exception(e.message);
       }
       // Erro genérico do Firebase
       throw Exception('Erro ao salvar (${e.code}). Verifique sua conexão.');
    } catch (e) {
       // Captura outras exceções (upload de imagem, etc.)
       debugPrint("--- AuthService.updateUserProfile: ERRO GERAL: $e ---");
       // Tenta extrair a mensagem da exceção, se houver
       if (e is Exception && e.toString().contains("Exception: ")) {
          throw Exception(e.toString().replaceFirst("Exception: ", ""));
       }
       // Fallback para erro genérico
       throw Exception('Ocorreu um erro inesperado ao salvar seu perfil.');
    }
  } // Fim de updateUserProfile

} // Fim da classe AuthService