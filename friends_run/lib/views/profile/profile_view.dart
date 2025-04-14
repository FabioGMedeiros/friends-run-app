import 'dart:io'; // Import necessário para usar a classe File (para upload de imagem)

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:friends_run/core/services/auth_service.dart'; // Ajuste o caminho do import se necessário
import 'package:friends_run/models/user/app_user.dart'; // Ajuste o caminho do import se necessário
import 'package:friends_run/core/utils/colors.dart';
import 'package:image_picker/image_picker.dart'; // Ajuste o caminho do import se necessário (se AppColors existir)

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final ImagePicker picker = ImagePicker();
  XFile? pickedFile;
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>(); // Chave para validar o formulário

  bool _isLoading = true; // Começa carregando
  bool _isEditing = false; // Controla se está em modo de edição ou visualização
  AppUser? _currentUser; // Armazena os dados do usuário carregado

  // Controladores para os campos do formulário
  late TextEditingController _nameController;
  late TextEditingController
  _emailController; // Nota: Alterar email geralmente requer verificação

  // Placeholder para o arquivo da nova imagem de perfil escolhida pelo usuário
  File? _newProfileImageFile;

  @override
  void initState() {
    super.initState();
    // Inicializa os controladores
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    // Carrega os dados do usuário ao iniciar a tela
    _loadUserData();
  }

  @override
  void dispose() {
    // Libera os recursos dos controladores quando a tela for destruída
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // Função assíncrona para carregar os dados do usuário
  Future<void> _loadUserData() async {
    setState(() => _isLoading = true); // Ativa o indicador de carregamento
    try {
      final user = await _authService.getCurrentUser(); // Busca o usuário atual
      if (user != null) {
        // Se encontrou o usuário, atualiza o estado
        setState(() {
          _currentUser = user;
          // Preenche os controladores com os dados atuais
          _nameController.text = user.name;
          _emailController.text = user.email;
          _isLoading = false; // Desativa o indicador de carregamento
        });
      } else {
        // Caso não consiga carregar o usuário (ex: não logado)
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não foi possível carregar os dados do usuário.'),
            ),
          );
          // Opcionalmente, pode navegar de volta ou mostrar uma tela de erro permanente
          // Navigator.pop(context);
        }
      }
    } catch (e) {
      // Trata erros durante o carregamento
      setState(() => _isLoading = false);
      debugPrint("Erro ao carregar usuário no perfil: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar perfil: ${e.toString()}')),
        );
        // Opcionalmente, navegar de volta
        // Navigator.pop(context);
      }
    }
  }

  // Alterna entre modo de visualização e edição
  void _toggleEditMode() {
    if (!_isEditing) {
      // Entrando no modo de edição: Garante que os controllers tenham os dados atuais
      _nameController.text = _currentUser?.name ?? '';
      _emailController.text = _currentUser?.email ?? '';
      _newProfileImageFile =
          null; // Reseta a seleção de imagem ao entrar no modo de edição
    }
    setState(() {
      _isEditing = !_isEditing; // Inverte o estado de edição
    });
  }

  // Cancela a edição, descartando alterações
  void _cancelEdit() {
    // Restaura os valores originais nos controladores
    _nameController.text = _currentUser?.name ?? '';
    _emailController.text = _currentUser?.email ?? '';
    _newProfileImageFile = null; // Limpa qualquer imagem selecionada
    setState(() {
      _isEditing = false; // Volta para o modo de visualização
    });
  }

  // Salva as alterações feitas no perfil
  Future<void> _saveChanges() async {
    // Verifica se o formulário é válido
    if (_formKey.currentState?.validate() ?? false) {
      if (_currentUser == null) return; // Segurança, não deve acontecer

      setState(
        () => _isLoading = true,
      ); // Ativa o carregamento durante o salvamento

      // Obtém os novos valores dos controladores
      final newName = _nameController.text.trim();
      final newEmail = _emailController.text.trim();
      final newImageFile =
          _newProfileImageFile; // Pega a nova imagem (se houver)

      try {
        // --- Placeholder para a Lógica de Atualização Real ---
        // Você precisaria implementar um método como `updateUserProfile` no AuthService.
        // Este método cuidaria de:
        // 1. Atualizar o email no Firebase Auth (pode exigir re-autenticação).
        // 2. Fazer upload da nova imagem de perfil (se `newImageFile` existir) para o Storage.
        // 3. Atualizar o documento do usuário no Firestore com nome, email e URL da imagem.

        /* Exemplo de chamada (requer implementação no AuthService):
        bool success = await _authService.updateUserProfile(
           uid: _currentUser!.uid,
           name: newName,
           email: newEmail, // Cuidado com alterações de email
           newProfileImage: newImageFile, // Passa o arquivo da imagem
        );

        if (success) {
          // Recarrega os dados do usuário para refletir as mudanças
          await _loadUserData();
           setState(() {
             _isEditing = false; // Sai do modo de edição ao salvar com sucesso
             _isLoading = false;
           });
           if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Perfil atualizado com sucesso!'), backgroundColor: Colors.green),
            );
           }
        } else {
           throw Exception("Falha ao atualizar perfil.");
        }
        */

        // --- Simulação Temporária ---
        // Simula um atraso de rede e atualiza o estado local para demonstração
        await Future.delayed(const Duration(seconds: 1));
        setState(() {
          // Atualiza o objeto local _currentUser com os novos dados
          _currentUser = AppUser(
            uid: _currentUser!.uid,
            name: newName,
            email: newEmail, // Atualiza o email local
            // profileImageUrl: urlDaNovaImagem, // Deveria vir do serviço de update
            profileImageUrl:
                _currentUser!
                    .profileImageUrl, // Mantém a imagem antiga por enquanto
          );
          _isEditing = false; // Sai do modo de edição
          _isLoading = false; // Para o indicador de carregamento
          _newProfileImageFile = null; // Limpa a imagem selecionada após salvar
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Perfil salvo (simulado)!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        // --- Fim da Simulação Temporária ---
      } catch (e) {
        // Trata erros durante o salvamento
        setState(() => _isLoading = false);
        debugPrint("Erro ao salvar perfil: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao salvar: ${e.toString()}')),
          );
        }
      }
    }
  }

  // --- Placeholder para a Lógica de Seleção de Imagem ---
  /*
  Future<void> _pickImage() async {
    // Usar o pacote image_picker ou similar
    final ImagePicker picker = ImagePicker();
    // Permitir escolher da galeria ou câmera
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        // Armazena o arquivo selecionado no estado
        _newProfileImageFile = File(image.path);
      });
    }
  }
  */
  // --- Fim do Placeholder ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, // Cor de fundo
      appBar: AppBar(
        title: const Text(
          'Meu Perfil',
          style: TextStyle(color: AppColors.white),
        ),
        backgroundColor: AppColors.background,
        iconTheme: const IconThemeData(
          color: AppColors.white,
        ), // Cor do ícone de voltar
        actions: [
          // Mostra o botão de editar apenas se não estiver editando, não estiver carregando e o usuário existir
          if (!_isEditing && !_isLoading && _currentUser != null)
            IconButton(
              icon: const Icon(Icons.edit, color: AppColors.white),
              tooltip: 'Editar Perfil',
              onPressed:
                  _toggleEditMode, // Chama a função para entrar no modo de edição
            ),
        ],
      ),
      // Corpo da tela: mostra loading, erro ou o conteúdo do perfil
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: AppColors.primaryRed),
              ) // Indicador de carregamento
              : _currentUser == null
              ? _buildErrorState() // Widget de estado de erro se o usuário for nulo após carregar
              : _buildProfileContent(), // Constrói o conteúdo principal do perfil
    );
  }

  // Widget para mostrar em caso de erro ao carregar o perfil
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            const Text(
              'Não foi possível carregar o perfil.',
              style: TextStyle(color: AppColors.white, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: AppColors.white,
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar Novamente'),
              onPressed: _loadUserData, // Tenta carregar os dados novamente
            ),
          ],
        ),
      ),
    );
  }

  // Constrói o conteúdo principal do perfil (foto, infos, botões)
  Widget _buildProfileContent() {
    // Usa SingleChildScrollView para permitir rolagem se o conteúdo (especialmente com teclado) for maior que a tela
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0), // Espaçamento interno
      child: Form(
        // Envolve o conteúdo em um Form para validação
        key: _formKey, // Associa a chave do formulário
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center, // Centraliza a foto
          children: [
            _buildProfilePictureSection(), // Seção da foto de perfil
            const SizedBox(height: 32), // Espaçamento
            // Mostra o formulário de edição ou as informações de visualização
            if (_isEditing) _buildEditFormFields() else _buildDisplayInfo(),
            const SizedBox(height: 40), // Espaçamento
            // Mostra os botões de Salvar/Cancelar apenas no modo de edição
            if (_isEditing) _buildActionButtonsEditMode(),
            // O botão "Editar" foi movido para a AppBar
          ],
        ),
      ),
    );
  }

  // Constrói a seção da foto de perfil
  Widget _buildProfilePictureSection() {
    final imageUrl = _currentUser?.profileImageUrl;

    // Determina qual imagem exibir: a nova selecionada (se houver) ou a atual do usuário
    ImageProvider? displayImageProvider;
    if (_newProfileImageFile != null) {
      // Se uma nova imagem foi selecionada, usa FileImage
      displayImageProvider = FileImage(_newProfileImageFile!);
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      // Se não há nova imagem, mas existe uma URL, usa CachedNetworkImage
      displayImageProvider = CachedNetworkImageProvider(imageUrl);
    }
    // Se nenhum dos casos acima, displayImageProvider será null (mostrará o ícone placeholder)

    return Stack(
      // Stack permite sobrepor o ícone de edição sobre a foto
      alignment:
          Alignment.bottomRight, // Alinha o ícone no canto inferior direito
      children: [
        CircleAvatar(
          radius: 60, // Tamanho do avatar
          backgroundColor: AppColors.white.withOpacity(
            0.2,
          ), // Fundo levemente visível
          backgroundImage:
              displayImageProvider, // Define a imagem de fundo (pode ser nula)
          // Mostra um ícone padrão apenas se não houver imagem (displayImageProvider é nulo)
          child:
              displayImageProvider == null
                  ? const Icon(
                    Icons.person,
                    size: 60,
                    color: AppColors.primaryRed, // Cor do ícone padrão
                  )
                  : null, // Não mostra o ícone se houver imagem
        ),
        // Mostra o botão de editar foto (ícone de câmera) apenas no modo de edição
        if (_isEditing)
          Positioned(
            right: 0,
            bottom: 0,
            child: Material(
              // Material para dar efeito visual ao InkWell
              color: AppColors.primaryRed, // Cor de fundo do botão
              shape: const CircleBorder(), // Formato circular
              elevation: 2.0, // Sombra leve
              child: InkWell(
                // InkWell para efeito de toque
                onTap: () async {
                  // --- Chamada para a função de escolher imagem (NÃO IMPLEMENTADA) ---
                  pickedFile = await picker.pickImage(
                    source: ImageSource.camera,
                  );
                  if (pickedFile != null) {
                    setState(() {
                      _newProfileImageFile = File(pickedFile!.path);
                    });
                  }
                },
                borderRadius: BorderRadius.circular(20), // Raio do InkWell
                child: const Padding(
                  padding: EdgeInsets.all(8.0), // Espaçamento interno do ícone
                  child: Icon(
                    Icons.camera_alt,
                    color: AppColors.white, // Cor do ícone da câmera
                    size: 20, // Tamanho do ícone
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Constrói a seção de visualização das informações
  Widget _buildDisplayInfo() {
    return Column(
      children: [
        _buildInfoTile(
          Icons.person_outline,
          "Nome",
          _currentUser?.name ?? 'N/A',
        ),
        const SizedBox(height: 16),
        _buildInfoTile(
          Icons.email_outlined,
          "Email",
          _currentUser?.email ?? 'N/A',
        ),
      ],
    );
  }

  // Widget auxiliar para criar um tile de informação (ícone, label, valor)
  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white.withOpacity(0.1), // Cor de fundo do tile
        borderRadius: BorderRadius.circular(8), // Bordas arredondadas
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryRed, size: 24), // Ícone
          const SizedBox(width: 16), // Espaçamento
          Expanded(
            // Para o texto ocupar o espaço restante
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start, // Alinha textos à esquerda
              children: [
                Text(
                  // Label (Nome, Email)
                  label,
                  style: TextStyle(
                    color: AppColors.white.withOpacity(
                      0.6,
                    ), // Cor mais suave para o label
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  // Valor (o nome/email do usuário)
                  value,
                  style: const TextStyle(color: AppColors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Constrói os campos do formulário de edição
  Widget _buildEditFormFields() {
    return Column(
      children: [
        // Campo de texto para o Nome
        TextFormField(
          controller: _nameController, // Vincula ao controlador de nome
          style: const TextStyle(
            color: AppColors.white,
          ), // Cor do texto digitado
          decoration: _buildInputDecoration(
            // Estilo do campo
            labelText: 'Nome',
            prefixIcon: Icons.person_outline,
          ),
          validator: (value) {
            // Regra de validação
            if (value == null || value.trim().isEmpty) {
              return 'Por favor, insira seu nome'; // Mensagem de erro
            }
            return null; // Retorna nulo se for válido
          },
        ),
        const SizedBox(height: 16), // Espaçamento
        // Campo de texto para o Email
        TextFormField(
          controller: _emailController, // Vincula ao controlador de email
          style: const TextStyle(color: AppColors.white),
          keyboardType: TextInputType.emailAddress, // Define o tipo de teclado
          decoration: _buildInputDecoration(
            labelText: 'Email',
            prefixIcon: Icons.email_outlined,
          ),
          validator: (value) {
            // Validação do email
            if (value == null || value.trim().isEmpty) {
              return 'Por favor, insira seu email';
            }
            // Regex simples para validação de formato de email
            if (!RegExp(
              r'^.+@[a-zA-Z]+\.{1}[a-zA-Z]+(\.{0,1}[a-zA-Z]+)$',
            ).hasMatch(value)) {
              return 'Por favor, insira um email válido';
            }
            return null;
          },
          // Considerar adicionar uma nota sobre a necessidade de verificação ao mudar email
        ),
      ],
    );
  }

  // Função auxiliar para criar a decoração (estilo) dos TextFormField
  InputDecoration _buildInputDecoration({
    required String labelText,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      labelText: labelText, // Texto do label flutuante
      labelStyle: TextStyle(
        color: AppColors.white.withOpacity(0.7),
      ), // Estilo do label
      prefixIcon: Icon(
        prefixIcon,
        color: AppColors.primaryRed,
      ), // Ícone no início do campo
      filled: true, // Habilita cor de fundo
      fillColor: AppColors.white.withOpacity(
        0.1,
      ), // Cor de fundo levemente transparente
      border: OutlineInputBorder(
        // Borda padrão (sem linha visível)
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        // Borda quando o campo não está focado
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        // Borda quando o campo está focado
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: AppColors.primaryRed,
          width: 1.5,
        ), // Destaca com a cor primária
      ),
      errorBorder: OutlineInputBorder(
        // Borda quando há erro de validação
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.5,
        ), // Cor vermelha para erro
      ),
      focusedErrorBorder: OutlineInputBorder(
        // Borda quando há erro e está focado
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  // Constrói os botões "Cancelar" e "Salvar" para o modo de edição
  Widget _buildActionButtonsEditMode() {
    return Row(
      // Organiza os botões lado a lado
      children: [
        // Botão Cancelar
        Expanded(
          // Faz o botão ocupar metade do espaço disponível
          child: OutlinedButton(
            // Botão com borda, sem preenchimento
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryRed, // Cor do texto e da borda
              side: const BorderSide(
                color: AppColors.primaryRed,
              ), // Define a borda
              padding: const EdgeInsets.symmetric(
                vertical: 14,
              ), // Espaçamento interno vertical
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ), // Bordas arredondadas
            ),
            onPressed:
                _isLoading
                    ? null
                    : _cancelEdit, // Desabilita se estiver carregando, senão chama _cancelEdit
            child: const Text('Cancelar'),
          ),
        ),
        const SizedBox(width: 16), // Espaçamento entre os botões
        // Botão Salvar
        Expanded(
          // Ocupa a outra metade do espaço
          child: ElevatedButton(
            // Botão preenchido
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed, // Cor de fundo
              foregroundColor: AppColors.white, // Cor do texto
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            // Desabilita o botão se estiver carregando (`_isLoading`), senão chama _saveChanges
            onPressed: _isLoading ? null : _saveChanges,
            // Mostra um indicador de progresso dentro do botão se estiver carregando
            child:
                _isLoading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                    : const Text('Salvar'), // Texto normal do botão
          ),
        ),
      ],
    );
  }
}
