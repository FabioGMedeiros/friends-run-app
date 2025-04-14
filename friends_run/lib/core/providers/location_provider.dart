import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:friends_run/core/services/location_service.dart';
import 'package:friends_run/models/race/race_model.dart';   // Import Race model
// Import o provider do RaceService que definimos antes
import 'package:friends_run/core/providers/race_provider.dart';

// --- Service Provider ---
// Provider para LocationService (se não estiver definido em outro lugar)
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

// --- Data Providers ---

// Provider para obter a localização atual (FutureProvider)
// Busca a localização automaticamente quando 'ouvido' pela primeira vez ou invalidado.
final currentLocationProvider = FutureProvider<Position?>((ref) async {
  // Depende do serviço de localização
  final locationService = ref.watch(locationServiceProvider);
  try {
    print("currentLocationProvider: Tentando obter localização...");
    final position = await locationService.getCurrentLocation();
    print("currentLocationProvider: Localização obtida: $position");
    return position;
  } catch (e) {
    print("currentLocationProvider: Erro ao obter localização: $e");
    // Você pode logar o stackTrace aqui se precisar: print(stackTrace);
    // Lança o erro para que o .when() na UI possa tratá-lo.
    // Ou retorna null se preferir tratar a falha como 'sem dados'.
    // Lançar o erro é geralmente melhor para indicar explicitamente a falha.
    throw Exception("Falha ao obter localização: $e");
    // return null; // Alternativa: retornar null
  }
});

// Provider para obter as corridas próximas (FutureProvider)
// DEPENDE do resultado do currentLocationProvider
final nearbyRacesProvider = FutureProvider<List<Race>>((ref) async {
  print("nearbyRacesProvider: Executando...");
  // Ouve o resultado do provider de localização.
  // Usar ref.watch aqui garante que este provider re-execute se a localização mudar/for invalidada.
  final locationAsyncValue = ref.watch(currentLocationProvider);
  // Depende do serviço de corrida
  final raceService = ref.watch(raceServiceProvider);

  // Espera a localização estar disponível e sem erro
  // O .when aqui dentro de um FutureProvider transforma o estado do provider dependente
  // no resultado deste Future.
  return locationAsyncValue.when(
    data: (position) {
      // Se a posição for nula (caso currentLocationProvider retorne null em erro)
      if (position == null) {
        print("nearbyRacesProvider: Posição nula recebida. Retornando lista vazia.");
        // Se currentLocationProvider retornou null, não podemos buscar corridas.
        return <Race>[]; // Retorna lista vazia.
      }
      // Se temos a posição, busca as corridas
      print("nearbyRacesProvider: Buscando corridas para a posição: $position");
      return raceService.getNearbyRaces(position);
    },
    error: (err, stack) {
      // Se o currentLocationProvider falhou, repassa o erro.
      print("nearbyRacesProvider: Erro recebido do currentLocationProvider: $err");
      // Lança o erro para que o .when() na UI (que ouve nearbyRacesProvider) possa tratá-lo.
      throw Exception("Não foi possível buscar corridas pois a localização falhou: $err");
    },
    loading: () {
      // Se a localização ainda está carregando, este provider também fica "carregando".
      // Não retornamos um valor ainda, o FutureProvider gerencia isso.
      // A UI que ouve nearbyRacesProvider mostrará seu próprio estado de loading.
      print("nearbyRacesProvider: Aguardando localização...");
      // Para garantir que o Future não complete enquanto espera, retornamos um Future que não resolve.
      // Isso mantém o estado de loading do nearbyRacesProvider.
      return Future.delayed(const Duration(days: 1), () => <Race>[]); // Ou use um Completer
    },
  );
});


/* O código anterior com StateNotifier não é mais necessário com esta abordagem

final locationProvider = StateNotifierProvider<LocationNotifier, AsyncValue<Position>>((ref) {
  return LocationNotifier(LocationService());
});

class LocationNotifier extends StateNotifier<AsyncValue<Position>> {
  final LocationService _locationService;
  LocationNotifier(this._locationService) : super(const AsyncValue.loading());
  Future<void> getCurrentLocation() async {
    // ...
  }
}

*/