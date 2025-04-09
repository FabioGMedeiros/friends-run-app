import 'package:flutter/material.dart';
import 'package:friends_run/core/services/auth_service.dart';
import 'package:friends_run/core/utils/colors.dart';
import 'package:friends_run/models/user/app_user.dart';
import 'package:friends_run/views/auth/auth_main_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final Future<AppUser?> _userFuture;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _userFuture = _loadUser();
  }

  Future<AppUser?> _loadUser() async {
    try {
      return await _authService.getCurrentUser();
    } catch (e) {
      // Consider adding error handling/logging here
      return null;
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      final authService = AuthService();
      await authService.logout();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthMainView()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao fazer logout: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Home", style: TextStyle(color: AppColors.white)),
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.white),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: FutureBuilder<AppUser?>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Erro ao carregar usuário",
                    style: TextStyle(color: AppColors.white, fontSize: 20),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed:
                        () => setState(() {
                          _userFuture = _loadUser();
                        }),
                    child: const Text("Tentar novamente"),
                  ),
                ],
              ),
            );
          }

          final user = snapshot.data!;
          return Center(
            child: Text(
              "Bem-vindo, ${user.name}!",
              style: const TextStyle(color: AppColors.white, fontSize: 20),
            ),
          );
        },
      ),
    );
  }
}
