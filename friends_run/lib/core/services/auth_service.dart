import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:friends_run/core/services/firebase_storage_service.dart';
import 'package:friends_run/models/user/app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<AppUser?> registerUser({
    required String name,
    required String email,
    required String password,
    required File profileImage,
  }) async {
    try {
      // 1. Cria o usuário com email/senha
      UserCredential userCred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCred.user!.uid;

      // 2. Faz o upload da imagem de perfil
      final imageUrl = await FirebaseStorageService.uploadProfileImage(uid, profileImage);

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

}
