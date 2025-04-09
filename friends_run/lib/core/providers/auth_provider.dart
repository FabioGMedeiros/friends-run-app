import 'package:flutter_riverpod/flutter_riverpod.dart';

// Estado da autenticação
class AuthState {
  final String name;
  final String email;
  final String password;
  final String? profileImage;
  final bool isLoading;

  AuthState({
    this.name = '',
    this.email = '',
    this.password = '',
    this.profileImage,
    this.isLoading = false,
  });

  // Método auxiliar para facilitar as cópias
  AuthState copyWith({
    String? name,
    String? email,
    String? password,
    String? profileImage,
    bool? isLoading,
  }) {
    return AuthState(
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      profileImage: profileImage ?? this.profileImage,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// Notifier para gerenciar o estado da autenticação
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState());

  void updateName(String name) => state = state.copyWith(name: name);
  void updateEmail(String email) => state = state.copyWith(email: email);
  void updatePassword(String password) => state = state.copyWith(password: password);
  void updateProfileImage(String imagePath) => state = state.copyWith(profileImage: imagePath);
  void setLoading(bool isLoading) => state = state.copyWith(isLoading: isLoading);
}

// Provider para acesso global ao AuthNotifier
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());
