import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:friends_run/core/services/auth_service.dart';
import 'package:friends_run/models/user/app_user.dart';
import 'package:meta/meta.dart';

// Estado da autenticação
@immutable // Boa prática para estados Riverpod
class AuthActionState {
  final bool isLoading;
  final String? error;

  const AuthActionState._({this.isLoading = false, this.error});

  factory AuthActionState.initial() => const AuthActionState._();

  AuthActionState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AuthActionState._(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthActionState &&
          runtimeType == other.runtimeType &&
          isLoading == other.isLoading &&
          error == other.error;

  @override
  int get hashCode => isLoading.hashCode ^ error.hashCode;
}

// Notifier para gerenciar o estado da autenticação
class AuthNotifier extends StateNotifier<AuthActionState> {
  final AuthService _authService;

  // Recebe o AuthService via injeção de dependência
  AuthNotifier(this._authService) : super(AuthActionState.initial());

  // --- Métodos de Ação ---

  Future<AppUser?> registerUser({
    required String name,
    required String email,
    required String password,
    File? profileImage,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _authService.registerUser(
        name: name,
        email: email,
        password: password,
        profileImage: profileImage,
      );
      state = state.copyWith(isLoading: false);
      // Retorna o usuário se o registro for bem-sucedido
      // A UI não precisa mais ouvir o AppUser daqui,
      // o currentUserProvider (que definiremos abaixo) será atualizado automaticamente.
      return user;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: "Erro no registro: ${e.toString()}");
      return null; // Indica falha
    }
  }

  Future<AppUser?> loginUser({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _authService.loginUser(
        email: email,
        password: password,
      );
      state = state.copyWith(isLoading: false);
      // Retorna o usuário se o login for bem-sucedido
      return user;
    } catch (e) {
      // Tenta extrair uma mensagem mais amigável do FirebaseException se possível
      String errorMessage = "Email ou senha inválidos.";
      if (e is FirebaseException) {
         // Você pode adicionar mais verificações de e.code aqui
         // if (e.code == 'user-not-found') errorMessage = 'Usuário não encontrado.';
         // if (e.code == 'wrong-password') errorMessage = 'Senha incorreta.';
         // etc...
         print("Firebase Auth Error Code: ${e.code}"); // Log para debug
      } else {
         errorMessage = "Erro no login: ${e.toString()}";
      }
      state = state.copyWith(isLoading: false, error: errorMessage);
      return null; // Indica falha
    }
  }

  Future<AppUser?> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _authService.signInWithGoogle();
      state = state.copyWith(isLoading: false);
      return user;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: "Erro no login com Google: ${e.toString()}");
      return null;
    }
  }

  Future<bool> logout() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _authService.logout();
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: "Erro ao sair: ${e.toString()}");
      return false;
    }
  }

  // Método para limpar o erro manualmente, se necessário
  void clearError() {
    if (state.error != null) {
      state = state.copyWith(clearError: true);
    }
  }
}

// --- Service Provider ---
// Provider para AuthService (pode já existir)
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// --- Action Notifier Provider ---
// Provider para o AuthNotifier refatorado (gerencia AuthActionState)
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthActionState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});

// --- Data Providers (Estado da Autenticação) ---

// Provider que expõe o Stream de mudanças de estado de autenticação do Firebase
// Ele emite o objeto `User?` do Firebase Auth.
final authStateChangesProvider = StreamProvider<User?>((ref) {
  // Ouve diretamente o stream do FirebaseAuth
  return FirebaseAuth.instance.authStateChanges();
});

// Provider que expõe o AppUser logado atualmente (ou null)
// Ele depende do authStateChangesProvider e busca os dados no Firestore
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  // Ouve o stream de mudanças do Firebase Auth
  final authState = ref.watch(authStateChangesProvider);

  // Quando o estado do Firebase Auth muda...
  return authState.when(
    data: (firebaseUser) {
      // Se há um usuário Firebase logado...
      if (firebaseUser != null) {
        // Busca os dados correspondentes do AppUser no Firestore.
        // Retorna um Stream que emite o AppUser ou null se não encontrado.
        // (Você pode precisar de um método no AuthService para isso ou fazer aqui)
        try {
          // Escuta por mudanças no documento do usuário no Firestore
          return FirebaseFirestore.instance
              .collection('users')
              .doc(firebaseUser.uid)
              .snapshots() // Usa snapshots para ouvir mudanças no perfil
              .map((docSnapshot) {
                if (docSnapshot.exists && docSnapshot.data() != null) {
                  // Converte os dados do Firestore para AppUser
                  return AppUser.fromMap(docSnapshot.data()!);
                } else {
                  // Documento não existe no Firestore (caso raro, pode indicar erro no registro)
                  print("AVISO: Usuário ${firebaseUser.uid} logado no Firebase Auth, mas não encontrado no Firestore.");
                  return null;
                }
              })
              .handleError((error) {
                 print("Erro ao buscar/ouvir AppUser do Firestore: $error");
                 return null; // Emite null em caso de erro no stream do Firestore
              });
        } catch (e) {
           print("Erro ao configurar stream do Firestore para AppUser: $e");
           return Stream.value(null); // Retorna stream com null em caso de erro inicial
        }

      } else {
        // Se não há usuário Firebase logado, emite null.
        return Stream.value(null);
      }
    },
    // Se o stream do Firebase Auth estiver carregando, emite null temporariamente.
    loading: () => Stream.value(null),
    // Se houver erro no stream do Firebase Auth, emite null.
    error: (err, stack) {
       print("Erro no authStateChangesProvider: $err");
       return Stream.value(null);
    },
  );
});