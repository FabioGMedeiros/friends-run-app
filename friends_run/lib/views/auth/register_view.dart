import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:friends_run/core/services/auth_service.dart';
import 'package:friends_run/views/home/home_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:friends_run/core/utils/colors.dart';
import 'package:friends_run/core/utils/validationsUtils.dart';
import 'package:friends_run/core/providers/auth_provider.dart';
import 'auth_widgets.dart';

class RegisterView extends ConsumerStatefulWidget {
  const RegisterView({super.key});

  @override
  ConsumerState<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends ConsumerState<RegisterView> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    XFile? pickedFile;

    await showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text("Tirar uma foto"),
            onTap: () async {
              pickedFile = await picker.pickImage(source: ImageSource.camera);
              Navigator.pop(context);
              if (pickedFile != null) {
                ref.read(authProvider.notifier).updateProfileImage(pickedFile!.path);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.image),
            title: const Text("Escolher da galeria"),
            onTap: () async {
              pickedFile = await picker.pickImage(source: ImageSource.gallery);
              Navigator.pop(context);
              if (pickedFile != null) {
                ref.read(authProvider.notifier).updateProfileImage(pickedFile!.path);
              }
            },
          ),
        ],
      ),
    );
  }

  void _register() async {
    if (_formKey.currentState!.validate()) {
      final notifier = ref.read(authProvider.notifier);
      final authState = ref.read(authProvider);

      if (authState.profileImage == null || authState.profileImage!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Por favor, selecione uma imagem de perfil"),
          ),
        );
        return;
      }

      notifier.setLoading(true); // Ativa loading

      final File profileImageFile = File(authState.profileImage!);
      final user = await AuthService().registerUser(
        name: authState.name,
        email: authState.email,
        password: authState.password,
        profileImage: profileImageFile,
      );

      notifier.setLoading(false); // Desativa loading

      if (user != null) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeView()),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erro ao cadastrar usuário")),
        );
      }
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text("Cadastro", style: TextStyle(color: AppColors.white)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ProfileImagePicker(
                imagePath: authState.profileImage,
                onTap: _pickImage,
              ),
              const SizedBox(height: 20),
              AuthTextField(
                label: "Nome Completo",
                validator: ValidationUtils.validateName,
                onChanged: (value) =>
                    ref.read(authProvider.notifier).updateName(value),
              ),
              const SizedBox(height: 15),
              AuthTextField(
                label: "Email",
                validator: ValidationUtils.validateEmail,
                onChanged: (value) =>
                    ref.read(authProvider.notifier).updateEmail(value),
              ),
              const SizedBox(height: 15),
              AuthTextField(
                label: "Senha",
                isPassword: true,
                controller: _passwordController,
                validator: ValidationUtils.validatePassword,
                onChanged: (value) =>
                    ref.read(authProvider.notifier).updatePassword(value),
              ),
              const SizedBox(height: 15),
              AuthTextField(
                label: "Confirmar Senha",
                isPassword: true,
                validator: (value) =>
                    ValidationUtils.validateConfirmPassword(
                      value,
                      _passwordController.text,
                    ),
              ),
              const SizedBox(height: 30),

              // Loading ou botão
              authState.isLoading
                  ? const CircularProgressIndicator(color: AppColors.white)
                  : PrimaryButton(
                      text: "Criar Conta",
                      onPressed: _register,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

