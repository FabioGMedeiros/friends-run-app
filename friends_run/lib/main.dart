import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Importe o App Check
import 'package:firebase_app_check/firebase_app_check.dart';

// Importe suas views e providers
import 'package:friends_run/views/auth/auth_main_view.dart';
import 'package:friends_run/views/no_connection/no_connection_view.dart';
import 'package:friends_run/core/providers/connectivity_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
// Importe os providers de autenticação se for usar no ConnectivityGate
import 'package:friends_run/core/providers/auth_provider.dart';
// Importe sua tela principal (Home) se for usar no ConnectivityGate
import 'package:friends_run/views/home/home_view.dart'; // Exemplo: ajuste o caminho

// Importe seu firebase_options.dart (gerado pelo FlutterFire CLI)
import 'firebase_options.dart';


Future<void> main() async {
  // Garante inicialização do Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Firebase usando firebase_options.dart
  await Firebase.initializeApp(
     options: DefaultFirebaseOptions.currentPlatform, // Recomendado
  );

  // ---- INÍCIO: Adicionar Ativação do App Check ----
  try {
      // ATIVA O APP CHECK ANTES DE USAR OUTROS SERVIÇOS
      // IMPORTANTE: Use AndroidProvider.debug APENAS para testes locais,
      //             emuladores ou builds de depuração.
      //             Para produção, use AndroidProvider.playIntegrity.
      //             Configure o appleProvider similarmente se for para iOS.
      await FirebaseAppCheck.instance.activate(
        // webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'), // Exemplo Web
        androidProvider: AndroidProvider.debug, // MUDE PARA .playIntegrity em produção!
        // appleProvider: AppleProvider.appAttest, // Exemplo iOS
      );
      debugPrint("Firebase App Check ativado com sucesso (modo debug).");
  } catch (e) {
     // É importante logar erros na ativação do App Check
     debugPrint("Erro ao ativar Firebase App Check: $e");
     // Considere o que fazer se o App Check falhar ao ativar.
     // Talvez mostrar uma mensagem específica ou impedir o uso de certas features.
  }
  // ---- FIM: Adicionar Ativação do App Check ----


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
      debugShowCheckedModeBanner: false,
      // Defina suas rotas nomeadas aqui se precisar
      // routes: { ... },
    );
  }
}

// ConnectivityGate (Refatorado para incluir verificação de Auth)
class ConnectivityGate extends ConsumerWidget {
  const ConnectivityGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Observa o estado da conectividade
    final connectivityStatus = ref.watch(connectivityProvider);

    return connectivityStatus.when(
      data: (status) {
        // 2. Se não há conexão, mostra tela específica
        if (status == ConnectivityResult.none) {
          debugPrint("ConnectivityGate: Sem conexão.");
          return const NoConnectionView();
        }

        // 3. Se há conexão, observa o estado de autenticação
        debugPrint("ConnectivityGate: Conectado. Verificando Auth...");
        final userAsync = ref.watch(currentUserProvider);

        return userAsync.when(
          data: (user) {
            // 4. Decide a tela baseado no usuário (logado ou não)
            if (user != null) {
               debugPrint("ConnectivityGate: Usuário logado (${user.uid}). Navegando para HomeView.");
              // Usuário está logado -> Vai para a tela principal
              return const HomeView(); // Ajuste para sua tela Home principal
            } else {
               debugPrint("ConnectivityGate: Usuário não logado. Navegando para AuthMainView.");
              // Usuário não está logado -> Vai para a tela de autenticação
              return const AuthMainView();
            }
          },
          loading: () {
             debugPrint("ConnectivityGate: Verificando estado do usuário (loading)...");
            // Mostra loading enquanto verifica o estado do usuário
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          },
          error: (err, stack) {
             debugPrint("ConnectivityGate: Erro ao verificar estado do usuário: $err");
            // TODO: Mostrar uma tela de erro mais robusta aqui seria bom
            // Por enquanto, pode ir para a tela de Auth ou mostrar erro genérico
            return Scaffold(body: Center(child: Text("Erro ao verificar autenticação: $err")));
          },
        );
      },
      loading: () {
         debugPrint("ConnectivityGate: Verificando conectividade (loading)...");
        // Mostra loading enquanto verifica a conectividade inicial
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
      error: (err, stack) {
         debugPrint("ConnectivityGate: Erro ao verificar conectividade: $err");
        // Se falhar ao verificar conectividade, assume que não tem
        return const NoConnectionView();
      },
    );
  }
}