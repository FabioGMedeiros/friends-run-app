import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Importe os serviços e modelos necessários
import 'package:friends_run/core/services/firebase_storage_service.dart'; // Certifique-se que este serviço existe e tem os métodos usados
import 'package:friends_run/models/user/app_user.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart'; // Para debugPrint

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Cache simples para evitar buscas repetidas no Firestore pelo mesmo ID rapidamente.
  // Pode ser mais sofisticado se necessário (ex: usando um package de cache).
  final Map<String, AppUser> _userCache = {};

  /// Registra um novo usuário com email, senha, nome e imagem de perfil opcional.
  Future<AppUser?> registerUser({
    required String name,
    required String email,
    required String password,
    File? profileImage,
  }) async {
    debugPrint("--- AuthService.registerUser START ---");
    try {
      // 1. Cria o usuário no Firebase Auth
      UserCredential userCred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Garantia que user não é nulo após criação bem-sucedida
      final User user = userCred.user!;
      final String uid = user.uid;
      debugPrint("--- AuthService.registerUser: Usuário criado no Auth (UID: $uid) ---");

      // 2. Lida com a imagem de perfil
      String imageUrl;
      if (profileImage == null) {
        debugPrint("--- AuthService.registerUser: Nenhuma imagem fornecida, usando placeholder. ---");
        // Usa URL explícita do placeholder
        imageUrl = FirebaseStorageService.getPlaceholderImageUrl();
         // OU: 'https://firebasestorage.googleapis.com/v0/b/friends-run-f4061.firebasestorage.app/o/profile_placeholder.png?alt=media&token=5943558c-0747-4250-a601-999080a820cb';

      } else {
        debugPrint("--- AuthService.registerUser: Imagem fornecida, chamando uploadProfileImage... ---");
        // Faz upload da imagem fornecida
        imageUrl = await FirebaseStorageService.uploadProfileImage(
          uid,
          imageFile: profileImage,
        );
        debugPrint("--- AuthService.registerUser: Upload retornou URL: $imageUrl ---");
         // Verificação se upload falhou silenciosamente (opcional)
         if (imageUrl == FirebaseStorageService.getPlaceholderImageUrl()) {
            debugPrint("--- AuthService.registerUser: ALERTA - Upload retornou URL do placeholder, usando-a mesmo assim. ---");
            // Poderia lançar um erro aqui se o upload for crítico
            // throw Exception("Falha no upload da imagem.");
         }
      }

      // 3. Cria o objeto AppUser
      final appUser = AppUser(
        uid: uid,
        name: name,
        email: email, // Email validado pelo Firebase Auth
        profileImageUrl: imageUrl,
      );
      debugPrint("--- AuthService.registerUser: Objeto AppUser criado. ---");


      // 4. Salva no Firestore
      debugPrint("--- AuthService.registerUser: Salvando usuário no Firestore... ---");
      await _firestore.collection('users').doc(uid).set(appUser.toMap());

      // 5. Adiciona ao cache
      _userCache[uid] = appUser;
      debugPrint("--- AuthService.registerUser: Usuário salvo e cacheado. END (Sucesso) ---");

      return appUser;

    } on FirebaseAuthException catch (e) {
      // Trata erros específicos do FirebaseAuth de forma mais granular
      debugPrint("--- AuthService.registerUser: ERRO FirebaseAuth: ${e.code} - ${e.message} ---");
      // Retorna null para ser tratado pelo Notifier/UI
      return null;
    } catch (e) {
      debugPrint("--- AuthService.registerUser: ERRO GERAL: $e ---");
       // Retorna null para outros erros
      return null;
    }
  }

  /// Realiza login com email e senha.
  Future<AppUser?> loginUser({
    required String email,
    required String password,
  }) async {
    debugPrint("--- AuthService.loginUser START ---");
    try {
      // 1. Autentica no Firebase Auth
      UserCredential userCred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User user = userCred.user!;
      final String uid = user.uid;
      debugPrint("--- AuthService.loginUser: Logado no Auth (UID: $uid). Buscando dados... ---");

      // 2. Busca os dados do AppUser (usa cache)
      final appUser = await getUserById(uid);

      if (appUser == null) {
        // Usuário autenticado mas sem registro no Firestore - estado inconsistente
        debugPrint("--- AuthService.loginUser: ERRO - Usuário autenticado ($uid) mas não encontrado no Firestore. Deslogando. ---");
        await logout(); // Desloga para evitar estado inconsistente
        return null; // Retorna null para indicar falha
      }

      debugPrint("--- AuthService.loginUser: AppUser encontrado. END (Sucesso) ---");
      return appUser;

    } on FirebaseAuthException catch (e) {
      debugPrint("--- AuthService.loginUser: ERRO FirebaseAuth: ${e.code} - ${e.message} ---");
      // Exemplos de códigos: 'user-not-found', 'wrong-password', 'invalid-credential', 'invalid-email'
      return null; // Retorna null para ser tratado pelo Notifier/UI
    } catch (e) {
      debugPrint("--- AuthService.loginUser: ERRO GERAL: $e ---");
      return null; // Retorna null para outros erros
    }
  }

  /// Realiza login ou registro usando conta Google.
  Future<AppUser?> signInWithGoogle() async {
    debugPrint("--- AuthService.signInWithGoogle START ---");
    try {
      // 1. Faz login com o Google
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        debugPrint("--- AuthService.signInWithGoogle: Login com Google cancelado pelo usuário. ---");
        return null; // Usuário cancelou
      }
      debugPrint("--- AuthService.signInWithGoogle: Usuário Google obtido: ${googleUser.displayName} ---");


      // 2. Obtém credenciais do Google para o Firebase
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
       debugPrint("--- AuthService.signInWithGoogle: Credencial Google obtida. ---");

      // 3. Faz login no Firebase com a credencial Google
      final UserCredential userCred = await _auth.signInWithCredential(credential);
      final User user = userCred.user!; // Garantido não ser nulo aqui
      final String uid = user.uid;
      debugPrint("--- AuthService.signInWithGoogle: Logado no Firebase Auth (UID: $uid). Verificando Firestore... ---");

      // 4. Verifica se já existe no Firestore (ou usa getUserById com cache)
      AppUser? appUser = await getUserById(uid);

      if (appUser == null) {
        // Novo usuário via Google, cria o AppUser e salva no Firestore
        debugPrint("--- AuthService.signInWithGoogle: Novo usuário via Google. Criando doc Firestore... ---");
        // Define uma URL de placeholder se o Google não fornecer uma foto
        final profilePic = user.photoURL ?? FirebaseStorageService.getPlaceholderImageUrl();

        appUser = AppUser(
          uid: uid,
          name: user.displayName ?? 'Usuário Google', // Nome padrão se não houver
          email: user.email ?? '', // Email DEVE existir vindo do Google
          profileImageUrl: profilePic,
        );

        await _firestore.collection('users').doc(uid).set(appUser.toMap());
        _userCache[uid] = appUser; // Adiciona ao cache
         debugPrint("--- AuthService.signInWithGoogle: Novo usuário salvo e cacheado. ---");
      } else {
         debugPrint("--- AuthService.signInWithGoogle: Usuário existente via Google: ${appUser.name} ---");
         // Opcional: Atualizar dados do Firestore com os do Google (nome, foto) se desejar
         bool needsUpdate = false;
         Map<String, dynamic> updates = {};
         if (appUser.name != user.displayName && user.displayName != null) {
            updates['name'] = user.displayName;
            needsUpdate = true;
         }
         // Usa placeholder como fallback seguro ao comparar URL da foto
         final googlePhotoUrl = user.photoURL ?? FirebaseStorageService.getPlaceholderImageUrl();
         if (appUser.profileImageUrl != googlePhotoUrl) {
             updates['profileImageUrl'] = googlePhotoUrl;
             needsUpdate = true;
         }
         if (needsUpdate) {
             debugPrint("--- AuthService.signInWithGoogle: Atualizando dados do usuário existente com dados do Google: $updates ---");
             await _firestore.collection('users').doc(uid).update(updates);
             // Atualiza o cache com os novos dados
             _userCache[uid] = appUser.copyWith(
                 name: updates['name'] ?? appUser.name,
                 profileImageUrl: updates['profileImageUrl'] ?? appUser.profileImageUrl,
             );
             // Busca novamente para garantir que temos o objeto mais recente (após copyWith)
             appUser = _userCache[uid];
         }
      }

      debugPrint("--- AuthService.signInWithGoogle: END (Sucesso) ---");
      return appUser;

    } on FirebaseAuthException catch (e) {
       debugPrint("--- AuthService.signInWithGoogle: ERRO FirebaseAuth: ${e.code} - ${e.message} ---");
       // Exemplo: 'account-exists-with-different-credential'
       return null; // Retorna null para ser tratado pelo Notifier/UI
    } catch (e) {
      debugPrint('--- AuthService.signInWithGoogle: ERRO GERAL: $e ---');
      // Tenta deslogar do Google em caso de erro desconhecido
      try { await GoogleSignIn().signOut(); } catch (_) {}
      return null; // Retorna null para ser tratado pelo Notifier/UI
    }
  }

  /// Realiza logout do Firebase Auth e Google Sign In.
  Future<void> logout() async {
    debugPrint("--- AuthService.logout START ---");
    try {
      // Limpa o cache local ao deslogar
      _userCache.clear();
      debugPrint("--- AuthService.logout: Cache limpo. ---");

      // Desloga do Google se estiver logado com ele
      final GoogleSignIn googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
        debugPrint("--- AuthService.logout: Google Signed Out ---");
      } else {
         debugPrint("--- AuthService.logout: Não estava logado com Google. ---");
      }
      // Desloga do Firebase Auth (sempre)
      await _auth.signOut();
      debugPrint("--- AuthService.logout: Firebase Auth Signed Out ---");
      debugPrint("--- AuthService.logout END ---");
    } catch (e) {
      // Loga o erro mas não relança, pois o objetivo principal (deslogar do Auth)
      // pode ter sido alcançado mesmo com erro no Google SignOut.
      debugPrint('--- AuthService.logout: ERRO (não relançado): $e ---');
    }
  }

  /// Obtém o AppUser atualmente logado, buscando no cache ou Firestore.
  Future<AppUser?> getCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        // debugPrint("Nenhum usuário Firebase autenticado."); // Log opcional
        return null;
      }

      // Tenta obter do cache primeiro
      if (_userCache.containsKey(user.uid)) {
         debugPrint("Usuário atual encontrado no cache: ${user.uid}");
         return _userCache[user.uid];
      }

      // Se não está no cache, busca usando getUserById (que também usa cache)
      debugPrint("Buscando usuário atual (via getUserById): ${user.uid}");
      final appUser = await getUserById(user.uid); // Reutiliza a busca e o cache
      return appUser;

    } catch (e) {
      debugPrint('Erro silencioso ao obter usuário atual: $e');
      return null;
    }
  }

  /// Busca um usuário específico no Firestore pelo seu UID, usando cache.
  Future<AppUser?> getUserById(String userId) async {
    // Verifica o cache primeiro
    if (_userCache.containsKey(userId)) {
       debugPrint("Usuário encontrado no cache: $userId");
       return _userCache[userId];
    }

    debugPrint("Buscando usuário no Firestore: $userId");
    try {
      final doc = await _firestore.collection('users').doc(userId).get();

      if (doc.exists && doc.data() != null) {
        final appUser = AppUser.fromMap(doc.data()!);
        // Adiciona ao cache após buscar com sucesso
        _userCache[userId] = appUser;
         debugPrint("Usuário $userId encontrado no Firestore e adicionado ao cache.");
        return appUser;
      } else {
        debugPrint("Usuário com ID $userId não encontrado no Firestore.");
        return null; // Usuário não existe no Firestore
      }
    } catch (e) {
      debugPrint('Erro ao buscar usuário por ID ($userId): $e');
      return null; // Erro durante a busca
    }
  }

  /// Atualiza os dados do perfil do usuário no Firebase Auth e Firestore.
  /// Retorna `true` em sucesso, `false` ou lança exceção em erro.
  Future<bool> updateUserProfile({
    required String uid,
    required String name,
    required String email,
    File? newProfileImage,
  }) async {
     debugPrint("--- AuthService.updateUserProfile START (UID: $uid) ---");
    final user = _auth.currentUser;
    // Validação crucial
    if (user == null || user.uid != uid) {
       debugPrint("--- AuthService.updateUserProfile: ERRO - Usuário inválido ou UID não corresponde. ---");
      throw Exception("Usuário não autenticado ou UID não corresponde para atualização.");
    }

    try {
      final Map<String, dynamic> updates = {}; // Mapa para atualizações do Firestore
      bool needsFirestoreUpdate = false;
      AppUser? currentUserFromCache = _userCache[uid]; // Pega versão atual do cache (pode ser null)

      // 1. Atualizar Nome (se diferente do cache ou se cache vazio)
      if (currentUserFromCache == null || name != currentUserFromCache.name) {
         debugPrint("--- AuthService.updateUserProfile: Preparando atualização de nome para '$name' ---");
         updates['name'] = name;
         needsFirestoreUpdate = true;
      }

      // 2. Atualizar Email (se diferente do Auth atual)
      final String currentAuthEmail = user.email ?? "";
      final String trimmedEmail = email.trim();
      if (trimmedEmail.isNotEmpty && trimmedEmail.toLowerCase() != currentAuthEmail.toLowerCase()) {
         debugPrint("--- AuthService.updateUserProfile: Tentando atualizar email Auth de '$currentAuthEmail' para '$trimmedEmail' ---");
        try {
          // Tenta atualizar com verificação (requer login recente)
          await user.verifyBeforeUpdateEmail(trimmedEmail);
           debugPrint("--- AuthService.updateUserProfile: Verificação de email enviada/atualização Auth iniciada. ---");
          // Atualiza no Firestore (idealmente após confirmação, mas feito aqui por simplicidade)
          updates['email'] = trimmedEmail;
          needsFirestoreUpdate = true;
        } on FirebaseAuthException catch (e) {
           debugPrint("--- AuthService.updateUserProfile: ERRO FirebaseAuth ao atualizar email: ${e.code} ---");
           // Transforma erros comuns em mensagens mais claras
           if (e.code == 'requires-recent-login') {
            throw Exception('Para alterar seu email, por favor, faça logout e login novamente.');
          } else if (e.code == 'email-already-in-use') {
            throw Exception('Este email já está sendo utilizado por outra conta.');
          } else {
            throw Exception('Ocorreu um erro ao atualizar seu email (${e.code}).');
          }
        }
      } else {
         debugPrint("--- AuthService.updateUserProfile: Email não modificado ('$trimmedEmail'). ---");
      }

      // 3. Atualizar Foto de Perfil (se nova imagem fornecida)
      String? finalImageUrlForUpdate = null; // URL a ser salva no Firestore
      if (newProfileImage != null) {
         debugPrint("--- AuthService.updateUserProfile: Nova imagem fornecida. Fazendo upload... ---");
        try {
            finalImageUrlForUpdate = await FirebaseStorageService.uploadProfileImage(
              uid,
              imageFile: newProfileImage,
            );
            // Verifica se o upload não falhou retornando o placeholder
            if (finalImageUrlForUpdate == FirebaseStorageService.getPlaceholderImageUrl()) {
               debugPrint("--- AuthService.updateUserProfile: ERRO - Upload da imagem falhou (serviço retornou placeholder). ---");
               throw Exception('Falha ao salvar a nova foto de perfil.');
            }
             debugPrint("--- AuthService.updateUserProfile: Upload OK. URL: $finalImageUrlForUpdate ---");
            updates['profileImageUrl'] = finalImageUrlForUpdate;
            needsFirestoreUpdate = true;
        } catch(e) {
            debugPrint("--- AuthService.updateUserProfile: ERRO durante upload: $e ---");
             throw Exception('Erro ao fazer upload da imagem: ${e.toString()}');
        }
      } else {
         debugPrint("--- AuthService.updateUserProfile: Nenhuma nova imagem fornecida. ---");
      }

      // 4. Atualizar dados no Firestore (se houver alterações)
      if (needsFirestoreUpdate && updates.isNotEmpty) {
         debugPrint("--- AuthService.updateUserProfile: Atualizando Firestore com: $updates ---");
        await _firestore.collection('users').doc(uid).update(updates);
        debugPrint("--- AuthService.updateUserProfile: Firestore atualizado. ---");

        // Atualiza o cache APÓS sucesso no Firestore
         if (_userCache.containsKey(uid)) {
             _userCache[uid] = _userCache[uid]!.copyWith(
                 name: updates['name'] ?? _userCache[uid]!.name,
                 email: updates['email'] ?? _userCache[uid]!.email,
                 profileImageUrl: updates['profileImageUrl'] ?? _userCache[uid]!.profileImageUrl,
             );
              debugPrint("--- AuthService.updateUserProfile: Cache atualizado. ---");
         }

      } else {
         debugPrint("--- AuthService.updateUserProfile: Nenhuma atualização necessária no Firestore. ---");
      }

      debugPrint("--- AuthService.updateUserProfile: END (Sucesso) ---");
      return true; // Sucesso geral

    } on FirebaseException catch (e) {
       debugPrint("--- AuthService.updateUserProfile: ERRO FirebaseException: ${e.code} - ${e.message} ---");
       // Se já lançamos exceção específica (email), não precisa lançar de novo
       // Apenas relança outros erros Firebase
       if (e.message == null || !(e.message!.contains('logout e login') || e.message!.contains('email já está sendo utilizado'))) {
           throw Exception('Erro ao salvar (${e.code}). Verifique sua conexão.');
       } else {
          rethrow; // Relança as exceções de email já tratadas
       }
    } catch (e) {
       debugPrint("--- AuthService.updateUserProfile: ERRO GERAL: $e ---");
       // Tenta ser mais específico se possível
       if (e is Exception) {
         throw e; // Relança a exceção original
       }
       throw Exception('Ocorreu um erro inesperado ao salvar seu perfil.');
    }
  }

  // --- FUNÇÕES AUXILIARES ---
  /// Retorna o stream do usuário autenticado no Firebase.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Verifica se o usuário atual fez login usando Google.
  Future<bool> isGoogleSignedIn() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final providerData = user.providerData;
    // Usa a constante do provider do Firebase Auth para segurança
    return providerData.any((info) => info.providerId == GoogleAuthProvider.PROVIDER_ID);
  }

} // Fim da classe AuthService