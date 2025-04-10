import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:friends_run/core/services/firebase_storage_service.dart';
import 'package:friends_run/models/user/app_user.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<AppUser?> registerUser({
  required String name,
  required String email,
  required String password,
  File? profileImage, // Tornamos opcional
}) async {
  try {
    // 1. Cria o usuário com email/senha
    UserCredential userCred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = userCred.user!.uid;
    String imageUrl;

    // 2. Se não tiver imagem, usa a placeholder
    if (profileImage == null) {
      imageUrl = 'https://firebasestorage.googleapis.com/v0/b/friends-run-f4061.firebasestorage.app/o/profile_placeholder.png?alt=media&token=5943558c-0747-4250-a601-999080a820cb'; // Caminho da sua imagem placeholder
    } else {
      // Faz upload apenas se tiver imagem
      imageUrl = await FirebaseStorageService.uploadProfileImage(
        uid,
        imageFile: profileImage,
      );
    }

    // 3. Cria o objeto AppUser
    final user = AppUser(
      uid: uid,
      name: name,
      email: email,
      profileImageUrl: imageUrl,
    );

    // 4. Salva no Firestore
    await _firestore.collection('users').doc(uid).set(user.toMap());

    return user;
  } catch (e) {
    print("Erro no registro: $e");
    return null;
  }
}

  Future<AppUser?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      // 1. Login com email e senha
      UserCredential userCred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCred.user!.uid;

      // 2. Busca os dados do usuário no Firestore
      final doc = await _firestore.collection('users').doc(uid).get();

      if (!doc.exists) {
        throw Exception('Usuário não encontrado no Firestore');
      }

      // 3. Constrói e retorna o AppUser
      return AppUser.fromMap(doc.data()!);
    } catch (e) {
      print("Erro no login: $e");
      return null;
    }
  }

  Future<AppUser?> signInWithGoogle() async {
    try {
      // 1. Faz login com o Google
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 2. Cria credencial pro Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 3. Faz login no Firebase com a credencial
      final UserCredential userCred = await _auth.signInWithCredential(
        credential,
      );
      final User user = userCred.user!;
      final uid = user.uid;

      // 4. Verifica se já existe no Firestore
      final doc = await _firestore.collection('users').doc(uid).get();

      if (!doc.exists) {
        // Novo usuário, cria o AppUser e salva no Firestore
        final appUser = AppUser(
          uid: uid,
          name: user.displayName ?? '',
          email: user.email ?? '',
          profileImageUrl: user.photoURL ?? '',
        );

        await _firestore.collection('users').doc(uid).set(appUser.toMap());

        return appUser;
      }

      // Usuário já existe, retorna os dados
      return AppUser.fromMap(doc.data()!);
    } catch (e) {
      print('Erro no login com Google: $e');
      return null;
    }
  }

  Future<void> logout() async {
    try {
      // 1. Use a mesma instância do GoogleSignIn (não crie nova)
      final GoogleSignIn googleSignIn = GoogleSignIn();

      // 2. Verifique se está logado com Google antes de tentar deslogar
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }

      // 3. Sempre faça signOut do Firebase Auth
      await _auth.signOut();

      // 4. Adicione um delay para garantir que tudo foi processado
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      print('Erro ao fazer logout: $e');
      rethrow; // Melhor para debug
    }
  }

  Future<AppUser?> getCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();

      if (data == null) return null;

      return AppUser.fromMap(data);
    } catch (e) {
      print('Erro ao obter usuário atual: $e');
      return null;
    }
  }

  Future<bool> isGoogleSignedIn() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final providerData = user.providerData;
    return providerData.any((info) => info.providerId == 'google.com');
  }
}
