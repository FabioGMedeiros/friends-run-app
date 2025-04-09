import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:friends_run/core/services/auth_service.dart';
import 'package:friends_run/core/utils/colors.dart';
import 'package:friends_run/core/utils/validationsUtils.dart';
import 'package:friends_run/views/home/home_view.dart';
import 'package:friends_run/core/providers/auth_provider.dart';
import 'auth_widgets.dart';

class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  _LoginViewState createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _login() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      ref.read(authProvider.notifier).setLoading(true);

      final user = await AuthService().loginUser(
        email: email,
        password: password,
      );

      ref.read(authProvider.notifier).setLoading(false);

      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeView()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email ou senha inválidos')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text("Login", style: TextStyle(color: AppColors.white)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              AuthTextField(
                controller: _emailController,
                label: "Email",
                validator: ValidationUtils.validateEmail,
              ),
              const SizedBox(height: 15),

              AuthTextField(
                controller: _passwordController,
                label: "Senha",
                isPassword: true,
                validator: ValidationUtils.validatePassword,
              ),
              const SizedBox(height: 30),

              authState.isLoading
                  ? const CircularProgressIndicator(color: AppColors.white)
                  : PrimaryButton(text: "Entrar", onPressed: _login),
              const SizedBox(height: 20),

              // Divisor
              const DividerWithText(text: "OU"),
              const SizedBox(height: 20),

              // Botão Login com Google
              SocialLoginButton(
                text: "Entrar com Google",
                iconPath: "assets/icons/google.png",
                onPressed: () async {
                  final user = await AuthService().signInWithGoogle();

                  if (user != null) {
                    if (context.mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeView()),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Erro ao fazer login com Google'),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
