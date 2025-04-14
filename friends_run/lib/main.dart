import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:friends_run/views/auth/auth_main_view.dart';
import 'package:friends_run/views/no_connection/no_connection_view.dart';
import 'core/providers/connectivity_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

void main() async {
  // Garante inicialização do Flutter
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializa o Firebase
  await Firebase.initializeApp();

  // Executa o App com o ProviderScope
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Friends Run',
      // A tela inicial agora é controlada pelo ConnectivityGate
      home: const ConnectivityGate(),
      debugShowCheckedModeBanner: false, // Mantido
      // Defina suas rotas nomeadas aqui se estiver usando Navigator.pushNamed
      // routes: {
      //   '/create-race': (context) => CreateRaceView(),
      //   '/create-group': (context) => CreateGroupView(),
      //   '/my-races': (context) => MyRacesView(),
      //   // ... outras rotas
      // },
    );
  }
}

// ConnectivityGate (sem alterações)
class ConnectivityGate extends ConsumerWidget {
  const ConnectivityGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);

    return connectivity.when(
      data: (status) {
        if (status == ConnectivityResult.none) {
          return const NoConnectionView();
        }
        // TODO: Adicionar lógica para verificar se o usuário está logado
        // usando currentUserProvider e direcionar para HomeView ou AuthMainView
        // Exemplo básico:
        // final userAsync = ref.watch(currentUserProvider);
        // return userAsync.when(
        //    data: (user) => user != null ? const HomeView() : const AuthMainView(),
        //    loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        //    error: (err, stack) => Scaffold(body: Center(child: Text("Erro Auth: $err"))), // Tela de erro auth
        // );

        // Por enquanto, mantém o comportamento original
        return const AuthMainView();
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const NoConnectionView(), // Mostra sem conexão em erro de conectividade
    );
  }
}