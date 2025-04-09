import 'package:flutter_riverpod/flutter_riverpod.dart';

// Estado da autenticação
class AuthState {
  final String name;
  final String email;
  final String password;
  final String? profileImage;

  AuthState({this.name = '', this.email = '', this.password = '', this.profileImage});
}

// Notifier para gerenciar o estado da autenticação
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState());

  void updateName(String name) => state = AuthState(name: name, email: state.email, password: state.password, profileImage: state.profileImage);
  void updateEmail(String email) => state = AuthState(name: state.name, email: email, password: state.password, profileImage: state.profileImage);
  void updatePassword(String password) => state = AuthState(name: state.name, email: state.email, password: password, profileImage: state.profileImage);
  void updateProfileImage(String imagePath) => state = AuthState(name: state.name, email: state.email, password: state.password, profileImage: imagePath);
}

// Provider para acesso global ao AuthNotifier
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());
