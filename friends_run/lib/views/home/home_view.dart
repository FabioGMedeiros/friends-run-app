import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:friends_run/core/providers/location_provider.dart'; // Necessário para o botão refresh e error widget
import 'package:friends_run/core/providers/race_provider.dart';
import 'package:friends_run/core/utils/colors.dart';
import 'package:friends_run/views/home/widgets/empty_races.dart';
import 'package:friends_run/views/home/widgets/home_drawer.dart';
import 'package:friends_run/views/home/widgets/race_card.dart';
import 'package:friends_run/views/home/widgets/races_error.dart';
import 'package:friends_run/views/race/create_race_view.dart';

class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  // O método _logout foi movido para dentro do HomeDrawer

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Ouve o provider de corridas próximas (sem alteração)
    final nearbyRacesAsync = ref.watch(nearbyRacesProvider);

    // 2. Listener para erros de AÇÃO da corrida (join/leave, etc.) - Permanece aqui para feedback global
    ref.listen<RaceActionState>(raceNotifierProvider, (_, next) {
      if (next.error != null && next.error!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.redAccent,
          ),
        );
        // Limpa o erro no notifier para não mostrar o snackbar repetidamente
        // É importante ter um estado para saber se o erro já foi mostrado
        // ou limpar o erro após um tempo/outra ação.
        // Uma forma simples é limpar logo após mostrar:
        ref.read(raceNotifierProvider.notifier).clearError();
      }
      // Poderia adicionar um listener para 'success' aqui também, se desejado
      // if (next.successMessage != null && next.successMessage!.isNotEmpty) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(
      //       content: Text(next.successMessage!),
      //       backgroundColor: Colors.green,
      //     ),
      //   );
      //   ref.read(raceNotifierProvider.notifier).clearSuccessMessage(); // Limpar similar ao erro
      // }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      // 3. Usa o componente HomeDrawer importado
      drawer: const HomeDrawer(), // Drawer agora é um componente separado
      appBar: AppBar(
        leading: Builder(
          // Builder ainda necessário para obter o context correto para Scaffold.of
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          'Corridas Próximas',
          style: TextStyle(color: AppColors.white),
        ),
        backgroundColor: AppColors.background,
        elevation: 0, // Remove a sombra padrão da AppBar
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.white),
            tooltip: "Atualizar localização e corridas",
            onPressed: () {
              // 4. Invalida o provider de localização para refazer a busca (sem alteração)
              ref.invalidate(currentLocationProvider);
              // Invalidar o de localização geralmente invalida o de corridas automaticamente
              // devido à dependência no nearbyRacesProvider.
              // Se não invalidar automaticamente, descomente a linha abaixo:
              // ref.invalidate(nearbyRacesProvider);
            },
          ),
        ],
      ),
      body: nearbyRacesAsync.when(
        data: (races) {
          // 5. Usa o componente EmptyRacesMessage se a lista estiver vazia
          if (races.isEmpty) {
            return const EmptyRacesMessage();
          }
          // 6. Constrói a lista usando o componente RaceCard
          return RefreshIndicator(
            // Opcional: Adiciona RefreshIndicator para puxar para atualizar
            onRefresh: () async {
               ref.invalidate(currentLocationProvider);
               // Aguarda um pouco para dar tempo da localização atualizar e
               // o nearbyRacesProvider ser reavaliado. Não é ideal,
               // o ideal seria o nearbyRacesProvider retornar um Future.
               await Future.delayed(const Duration(milliseconds: 500));
            },
            color: AppColors.primaryRed,
            backgroundColor: AppColors.background,
            child: ListView.builder( // Usa ListView.builder que é mais eficiente
              physics: const AlwaysScrollableScrollPhysics( // Garante scroll mesmo com poucos itens
                 parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.only(top: 8, bottom: 80), // Padding inferior para não cobrir com FAB
              itemCount: races.length,
              itemBuilder: (context, index) {
                // Passa a corrida para o componente RaceCard
                return RaceCard(race: races[index]);
              },
              // Não precisa mais do separatorBuilder se usar apenas builder e
              // o próprio Card tiver margem vertical
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryRed),
        ),
        // 7. Usa o componente RacesErrorWidget para mostrar erros ao carregar corridas
        error: (error, stackTrace) => RacesErrorWidget(
          error: error,
          onRetry: () => ref.invalidate(currentLocationProvider), // Ação de retry
        ),
      ),
      // 8. FAB permanece aqui, pois é uma ação principal da HomeView
      floatingActionButton: _buildFAB(context),
    );
  }

  // FAB (sem alterações, exceto talvez a navegação para CreateRaceView)
  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton.extended(
      backgroundColor: AppColors.primaryRed,
      foregroundColor: AppColors.white,
      icon: const Icon(Icons.add_location_alt),
      label: const Text('Criar Corrida'),
      onPressed: () {
         Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateRaceView(),
            ),
          );
        // O código anterior com showModalBottomSheet foi removido,
        // pois o FAB agora vai direto para a tela de criação.
        // Se precisar do bottom sheet novamente, pode adaptá-lo.
      },
    );
  }

  // Os métodos _buildRaceCard, _buildRaceInfoRow e _showJoinConfirmationDialog
  // foram movidos para dentro do componente RaceCard
}