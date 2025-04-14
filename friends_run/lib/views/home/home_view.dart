import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:friends_run/core/providers/race_provider.dart';
import 'package:friends_run/core/providers/auth_provider.dart';
import 'package:friends_run/core/providers/location_provider.dart'; // Deve conter os FutureProviders agora
import 'package:friends_run/models/race/race_model.dart';
import 'package:friends_run/core/utils/colors.dart'; // Import AppUser
import 'package:friends_run/views/auth/auth_main_view.dart';
import 'package:friends_run/views/profile/profile_view.dart';
import 'package:friends_run/views/race/create_race_view.dart';

class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  // Método de logout (sem alterações)
  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authServiceProvider).logout();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthMainView()),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao fazer logout: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Ouve o provider de corridas próximas
    final nearbyRacesAsync = ref.watch(nearbyRacesProvider);

    // 2. Listener para erros de AÇÃO da corrida (join/leave, etc.)
    ref.listen<RaceActionState>(raceNotifierProvider, (_, next) {
      if (next.error != null && next.error!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.redAccent,
          ),
        );
        ref.read(raceNotifierProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      // 3. 'const' removido do _HomeDrawer
      drawer: const _HomeDrawer(), // <-- 'const' REMOVIDO
      appBar: AppBar(
        leading: Builder(
          builder:
              (context) => IconButton(
                icon: const Icon(Icons.menu, color: AppColors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
        ),
        title: const Text(
          'Corridas Próximas',
          style: TextStyle(color: AppColors.white),
        ),
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.white),
            tooltip: "Atualizar localização e corridas",
            onPressed: () {
              // 4. Invalida o provider de localização para refazer a busca
              ref.invalidate(currentLocationProvider);
              // Invalidar o de localização geralmente invalida o de corridas automaticamente
              // ref.invalidate(nearbyRacesProvider);
            },
          ),
        ],
      ),
      body: nearbyRacesAsync.when(
        data: (races) {
          // Se a lista de corridas está vazia, verifica o estado da localização
          if (races.isEmpty) {
            final locationState = ref.watch(currentLocationProvider);
            return Center(
              child: locationState.when(
                // Usa .when no estado da localização
                data:
                    (position) => Text(
                      position == null
                          ? 'Não foi possível obter sua localização.\nVerifique as permissões.'
                          : 'Nenhuma corrida próxima encontrada.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.white.withOpacity(0.8),
                        fontSize: 18,
                      ),
                    ),
                loading:
                    () => const CircularProgressIndicator(
                      color: AppColors.primaryRed,
                    ), // Loading da localização
                error:
                    (err, stack) => Text(
                      // Erro ao buscar localização
                      'Erro ao buscar localização:\n${err.toString().replaceFirst("Exception: ", "")}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.redAccent, fontSize: 16),
                    ),
              ),
            );
          }
          // Se temos corridas, construímos a lista
          return ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: races.length, // <-- Vírgula adicionada aqui
            itemBuilder:
                (context, index) => _buildRaceCard(context, ref, races[index]),
            separatorBuilder: (_, __) => const SizedBox(height: 4),
          );
        },
        loading:
            () => const Center(
              child: CircularProgressIndicator(color: AppColors.primaryRed),
            ), // Loading das corridas
        error:
            (error, stackTrace) => Center(
              // Erro ao buscar corridas
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 50,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Erro ao carregar corridas:\n${error.toString().replaceFirst("Exception: ", "")}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      ref.invalidate(currentLocationProvider);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: AppColors.white,
                    ),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
      ),
      floatingActionButton: _buildFAB(context),
    );
  }

  // FAB (sem alterações significativas)
  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: AppColors.primaryRed,
      onPressed: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: AppColors.background,
          isScrollControlled: true, // Permite altura flexível
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (context) {
            return Padding(
              // Padding para evitar proximidade com notch/bottom bar
              padding: EdgeInsets.only(
                bottom:
                    MediaQuery.of(
                      context,
                    ).viewInsets.bottom, // Ajusta com teclado
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Wrap(
                // Usa Wrap para conteúdo de altura variável
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.add_location,
                      color: AppColors.primaryRed,
                    ),
                    title: const Text(
                      'Criar Corrida',
                      style: TextStyle(color: AppColors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateRaceView(),
                        ), // Constrói a tela diretamente
                      );
                    },
                  ),
                  const SizedBox(height: 16), // Espaço extra no final
                ],
              ),
            );
          },
        );
      },
      child: const Icon(Icons.add, color: AppColors.white),
    );
  }

  // Card da Corrida (lógica de estado e interação principal)
  Widget _buildRaceCard(BuildContext context, WidgetRef ref, Race race) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final currentUserId = currentUserAsync.asData?.value?.uid;
    // Ouve o estado de ação AQUI dentro para o botão específico
    final actionState = ref.watch(raceNotifierProvider);

    // !! IMPORTANTE: Esta lógica assume que race.participants/pendingParticipants
    // !! contém objetos AppUser completos. Se contiver apenas IDs, ajuste aqui.
    final bool isParticipant =
        currentUserId != null &&
        race.participants.any((p) => p.uid == currentUserId);
    final bool isPending =
        currentUserId != null &&
        race.pendingParticipants.any((p) => p.uid == currentUserId);

    bool canInteract = currentUserId != null && !isParticipant && !isPending;
    String buttonText = race.isPrivate ? "Solicitar" : "Participar";
    VoidCallback? onPressedAction =
        currentUserId != null
            ? () =>
                _showJoinConfirmationDialog(context, ref, race, currentUserId)
            : null; // Ação nula se não houver usuário

    if (isParticipant) {
      buttonText = "Já Participando";
      onPressedAction = null;
      canInteract = false;
    } else if (isPending) {
      buttonText = "Solicitado";
      onPressedAction = null;
      canInteract = false;
    }

    // Desabilita interação também se não houver usuário logado
    if (currentUserId == null) {
      canInteract = false;
      onPressedAction = null;
      buttonText = "Faça login"; // Ou outra mensagem
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.white.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      // Adiciona InkWell para tornar o card clicável (para detalhes, por exemplo)
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // TODO: Navegar para a tela de detalhes da corrida
          print("Clicou no card da corrida: ${race.id}");
          // Navigator.push(context, MaterialPageRoute(builder: (_) => RaceDetailsView(raceId: race.id)));
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (race.imageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: CachedNetworkImage(
                  imageUrl: race.imageUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder:
                      (context, url) => const SizedBox(
                        height: 180,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryRed,
                          ),
                        ),
                      ),
                  errorWidget:
                      (context, url, error) => Container(
                        height: 180,
                        color: Colors.grey[800],
                        child: const Center(
                          child: Icon(
                            Icons.map,
                            color: AppColors.greyLight,
                            size: 50,
                          ),
                        ),
                      ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          race.title,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2, // Evita overflow
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          race.formattedDistance,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildRaceInfoRow(Icons.calendar_today, race.formattedDate),
                  _buildRaceInfoRow(
                    Icons.location_on,
                    (race.startAddress.isNotEmpty && race.endAddress.isNotEmpty)
                        ? '${race.startAddress} → ${race.endAddress}'
                        : 'De [${race.startLatitude.toStringAsFixed(2)}, ${race.startLongitude.toStringAsFixed(2)}] para [${race.endLatitude.toStringAsFixed(2)}, ${race.endLongitude.toStringAsFixed(2)}]',
                  ),
                  _buildRaceInfoRow(
                    Icons.people,
                    '${race.participants.length} participante(s)', // Simplificado
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            canInteract
                                ? AppColors.primaryRed
                                : Colors.grey[600],
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ), // Ajuste padding
                      ),
                      // Desabilita se ação estiver em loading OU se não puder interagir
                      onPressed:
                          actionState.isLoading || !canInteract
                              ? null
                              : onPressedAction,
                      child:
                          actionState.isLoading &&
                                  canInteract // Idealmente, checar se *esta* ação específica está em loading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : Text(buttonText),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Método auxiliar para linha de info (sem alterações)
  Widget _buildRaceInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryRed),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.white.withOpacity(0.9),
                fontSize: 15,
              ),
              maxLines: 2, // Permite quebrar linha
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Método para mostrar confirmação (sem alterações)
  void _showJoinConfirmationDialog(
    BuildContext context,
    WidgetRef ref,
    Race race,
    String userId,
  ) {
    // ... (código do _showJoinConfirmationDialog permanece igual)
    if (race.isPrivate) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              backgroundColor: AppColors.white,
              title: const Text(
                'Solicitar Participação',
                style: TextStyle(color: AppColors.black),
              ),
              content: Text(
                'Esta é uma corrida privada. Deseja solicitar participação em "${race.title}"?',
                style: TextStyle(color: AppColors.black),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: AppColors.primaryRed),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: AppColors.white,
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    final success = await ref
                        .read(raceNotifierProvider.notifier)
                        .addParticipationRequest(race.id, userId);
                    if (context.mounted && success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Solicitação enviada!'),
                          backgroundColor: Colors.orangeAccent,
                        ),
                      );
                    }
                  },
                  child: const Text('Solicitar'),
                ),
              ],
            ),
      );
    } else {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              backgroundColor: AppColors.white,
              title: const Text(
                'Confirmar participação',
                style: TextStyle(color: AppColors.black),
              ),
              content: Text(
                'Deseja participar da corrida "${race.title}"?',
                style: TextStyle(color: AppColors.black),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: AppColors.primaryRed),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: AppColors.white,
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    final success = await ref
                        .read(raceNotifierProvider.notifier)
                        .addParticipant(race.id, userId);
                    if (context.mounted && success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Você está participando de "${race.title}"',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: const Text('Confirmar'),
                ),
              ],
            ),
      );
    }
  }
}

// --- Widget Separado para o Drawer (_HomeDrawer) ---
// (O código do _HomeDrawer permanece o mesmo da correção anterior,
//  com o 'const' removido do construtor)
class _HomeDrawer extends ConsumerWidget {
  const _HomeDrawer(); // <-- 'const' REMOVIDO

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authServiceProvider).logout();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthMainView()),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao fazer logout: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Drawer(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          userAsync.when(
            data:
                (user) => UserAccountsDrawerHeader(
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withOpacity(0.8),
                  ),
                  accountName: Text(
                    user?.name ?? 'Carregando...',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  accountEmail: Text(user?.email ?? ''),
                  currentAccountPicture: CircleAvatar(
                    backgroundColor: AppColors.white,
                    child:
                        user?.profileImageUrl != null &&
                                user!.profileImageUrl!.isNotEmpty
                            ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: user.profileImageUrl!,
                                placeholder:
                                    (context, url) =>
                                        const CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                errorWidget:
                                    (context, url, error) => const Icon(
                                      Icons.person,
                                      color: AppColors.primaryRed,
                                      size: 40,
                                    ),
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            )
                            : const Icon(
                              Icons.person,
                              color: AppColors.primaryRed,
                              size: 40,
                            ),
                  ),
                ),
            loading:
                () => DrawerHeader(
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withOpacity(0.8),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.white),
                  ),
                ),
            error:
                (err, stack) => DrawerHeader(
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withOpacity(0.8),
                  ),
                  child: const Center(
                    child: Text(
                      "Erro ao carregar usuário",
                      style: TextStyle(color: AppColors.white),
                    ),
                  ),
                ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  icon: Icons.home,
                  title: 'Início',
                  onTap: () => Navigator.pop(context),
                ),
                _buildDrawerItem(
                  icon: Icons.person,
                  title: 'Meu Perfil',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ProfileView()),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.flag,
                  title: 'Minhas Corridas',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/my-races');
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.group,
                  title: 'Meus Grupos',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/groups');
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.leaderboard,
                  title: 'Estatísticas',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/stats');
                  },
                ),
                const Divider(color: AppColors.white),
                _buildDrawerItem(
                  icon: Icons.settings,
                  title: 'Configurações',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/settings');
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.help,
                  title: 'Ajuda',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/help');
                  },
                ),
                const Divider(color: AppColors.white),
                _buildDrawerItem(
                  icon: Icons.logout,
                  title: 'Sair',
                  onTap: () => _logout(context, ref),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Friends Run v1.0',
              style: TextStyle(color: AppColors.white.withOpacity(0.6)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.white),
      title: Text(title, style: const TextStyle(color: AppColors.white)),
      onTap: onTap,
    );
  }
}
