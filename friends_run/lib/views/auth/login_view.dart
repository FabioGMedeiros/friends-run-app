import 'package:flutter/material.dart';
import 'package:friends_run/core/utils/colors.dart';
import 'package:friends_run/core/utils/validationsUtils.dart';
import 'auth_widgets.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  _LoginViewState createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _login() {
    if (_formKey.currentState!.validate()) {
      // Chamar a API de autenticação de usuário
      print("Login realizado com sucesso!");
    }
  }

  @override
  Widget build(BuildContext context) {
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

              // Campo Email
              AuthTextField(
                controller: _emailController,
                label: "Email",
                validator: ValidationUtils.validateEmail,
              ),
              const SizedBox(height: 15),

              // Campo Senha
              AuthTextField(
                controller: _passwordController,
                label: "Senha",
                isPassword: true,
                validator: ValidationUtils.validatePassword,
              ),
              const SizedBox(height: 30),

              // Botão Login
              PrimaryButton(
                text: "Entrar",
                onPressed: _login,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
