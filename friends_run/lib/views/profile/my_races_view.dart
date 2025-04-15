import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- Importações Essenciais ---
import 'package:friends_run/core/providers/auth_provider.dart';
import 'package:friends_run/core/providers/race_provider.dart';
import 'package:friends_run/core/utils/colors.dart';

// --- Importações de Widgets da UI ---
// import 'package:friends_run/views/home/widgets/home_drawer.dart'; // Não é mais necessário aqui
import 'package:friends_run/views/home/widgets/empty_list_message.dart'; // Usando o widget genérico
import 'package:friends_run/views/home/widgets/race_card.dart';
import 'package:friends_run/views/home/widgets/races_error.dart';

//---------------------------------------------------
//       VISÃO "MINHAS CORRIDAS" (Com Botão Voltar)
//---------------------------------------------------

class MyRacesView extends ConsumerWidget {
  const MyRacesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final myRacesAsync = ref.watch(myRacesProvider);

    ref.listen<RaceActionState>(raceNotifierProvider, (_, next) {
      if (next.error != null && next.error!.isNotEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
        ref.read(raceNotifierProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      // drawer: const HomeDrawer(), // <-- REMOVIDO: Não há mais botão para abrir
      appBar: AppBar(
        // --- MODIFICADO: Botão de Voltar ---
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          tooltip: 'Voltar', // Boa prática para acessibilidade
          onPressed: () {
            // Verifica se é possível voltar na pilha de navegação
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop(); // Volta para a tela anterior
            }
            // Adicionar um fallback aqui se necessário (ex: ir para home)
            // else { Navigator.pushReplacementNamed(context, '/home'); }
          },
        ),
        // --- FIM DA MODIFICAÇÃO ---
        title: const Text(
          'Minhas Corridas',
          style: TextStyle(color: AppColors.white),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: myRacesAsync.when(
        data: (races) {
          final currentUser = currentUserAsync.valueOrNull;
          if (currentUser == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'Faça login para ver as corridas em que você está participando.',
                  style: TextStyle(color: AppColors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (races.isEmpty) {
            return const EmptyListMessage(
              message: 'Você ainda não está participando de nenhuma corrida.',
              icon: Icons.inbox_outlined,
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myRacesProvider);
              await Future.delayed(const Duration(milliseconds: 500));
            },
            color: AppColors.primaryRed,
            backgroundColor: AppColors.background,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              itemCount: races.length,
              itemBuilder: (context, index) {
                return RaceCard(race: races[index]);
              },
            ),
          );
        },
        loading:
            () => const Center(
              child: CircularProgressIndicator(color: AppColors.primaryRed),
            ),
        error:
            (error, stackTrace) => RacesErrorWidget(
              error: error,
              onRetry: () => ref.invalidate(myRacesProvider),
            ),
      ),
    );
  }
}
