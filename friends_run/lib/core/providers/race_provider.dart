import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:friends_run/core/services/race_service.dart';
import 'package:friends_run/models/race/race_model.dart';
import 'package:friends_run/models/user/app_user.dart';
import 'package:meta/meta.dart'; // Para @immutable

//----------------------------------------------------------------------
// 1. Estado para Ações (Loading/Error)
//----------------------------------------------------------------------
@immutable // Boa prática para estados Riverpod
class RaceActionState {
  final bool isLoading;
  final String? error;

  // Construtor privado para garantir o uso do factory e copyWith
  const RaceActionState._({this.isLoading = false, this.error});

  // Estado inicial
  factory RaceActionState.initial() => const RaceActionState._();

  // Método para criar cópias do estado, útil para atualizações
  RaceActionState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false, // Flag para limpar erro explicitamente
  }) {
    return RaceActionState._(
      isLoading: isLoading ?? this.isLoading,
      // Se clearError for true, define error como null,
      // caso contrário, usa o novo erro ou mantém o antigo.
      error: clearError ? null : (error ?? this.error),
    );
  }

  // Sobrescrever == e hashCode é importante para Riverpod saber se o estado mudou
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RaceActionState &&
          runtimeType == other.runtimeType &&
          isLoading == other.isLoading &&
          error == other.error;

  @override
  int get hashCode => isLoading.hashCode ^ error.hashCode;
}

//----------------------------------------------------------------------
// 2. O Notifier Refatorado
//    Gerencia o RaceActionState e expõe métodos de ação e streams.
//----------------------------------------------------------------------
class RaceNotifier extends StateNotifier<RaceActionState> {
  final RaceService _raceService;

  // O Notifier agora gerencia RaceActionState
  RaceNotifier(this._raceService) : super(RaceActionState.initial());

  // --- Métodos que expõem Streams do Serviço ---
  // As Views usarão StreamProviders para consumir estes.
  Stream<List<Race>> racesStream() => _raceService.racesStream;
  Stream<List<Race>> racesByGroup(String groupId) => _raceService.getRacesByGroup(groupId);
  Stream<List<Race>> racesByOwner(String ownerId) => _raceService.getRacesByOwner(ownerId);

  // ATENÇÃO: Este stream depende da correção/clarificação sobre o armazenamento de participantes
  // Se 'participants' for um array de IDs, está ok. Se for array de Mapas, não funcionará.
  Stream<List<Race>> racesByParticipant(String userId) => _raceService.getRacesByParticipant(userId);

  // --- Métodos de Ação (modificam dados e gerenciam estado isLoading/error) ---

  Future<Race?> createRace({ // Retorna a Race criada ou null em erro
    required String title,
    required DateTime date,
    required String startAddress,
    required String endAddress,
    required AppUser owner,
    bool isPrivate = false,
    String? groupId,
  }) async {
    // Inicia loading, limpa erro anterior
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final createdRace = await _raceService.createRace(
        title: title,
        date: date,
        startAddress: startAddress,
        endAddress: endAddress,
        owner: owner,
        isPrivate: isPrivate,
        groupId: groupId,
      );
      // Sucesso: para loading
      state = state.copyWith(isLoading: false);
      return createdRace;
    } catch (e) {
      // Erro: para loading, registra o erro
      state = state.copyWith(isLoading: false, error: "Erro ao criar corrida: ${e.toString()}");
      return null; // Indica falha
    }
  }

  Future<bool> updateRace(Race race) async { // Retorna true em sucesso, false em erro
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _raceService.updateRace(race);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: "Erro ao atualizar corrida: ${e.toString()}");
      return false;
    }
  }

  Future<bool> leaveRace(String raceId, String userId) async {
    // Poderia definir um estado de loading específico para esta ação se necessário
    // state = state.copyWith(isLoading: true, clearError: true); // Ou usar um loading específico
     state = state.copyWith(clearError: true); // Limpa erro anterior
    try {
      await _raceService.leaveRace(raceId, userId);
      // state = state.copyWith(isLoading: false);
      // Poderia adicionar uma mensagem de sucesso ao estado se desejado
      // state = state.copyWith(successMessage: "Você saiu da corrida.");
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: "Erro ao sair da corrida: ${e.toString().replaceFirst("Exception: ", "")}");
      return false;
    }
  }

  Future<bool> deleteRace(String id) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _raceService.deleteRace(id);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: "Erro ao deletar corrida: ${e.toString()}");
      return false;
    }
  }

  // --- Métodos de Ação para Participantes ---
  // (Estes não precisam necessariamente de isLoading global, a menos que a UI precise disso)

  Future<bool> addParticipant(String raceId, String userId) async {
     // Opcional: gerenciar loading/error se a UI precisar de feedback imediato
     // state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _raceService.addParticipant(raceId, userId);
      // state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      // Apenas registra o erro no estado se quiser mostrar globalmente
      state = state.copyWith(error: "Erro ao adicionar participante: ${e.toString()}");
       // state = state.copyWith(isLoading: false, error: ...); // se gerenciar loading
      return false;
    }
  }

  Future<bool> removeParticipant(String raceId, String userId) async {
    try {
      await _raceService.removeParticipant(raceId, userId);
      return true;
    } catch (e) {
      state = state.copyWith(error: "Erro ao remover participante: ${e.toString()}");
      return false;
    }
  }

  Future<bool> addParticipationRequest(String raceId, String userId) async {
     try {
      await _raceService.addParticipationRequest(raceId, userId);
      return true;
    } catch (e) {
      state = state.copyWith(error: "Erro ao solicitar participação: ${e.toString()}");
      return false;
    }
  }

   Future<bool> approveParticipant(String raceId, String userId) async {
     try {
      await _raceService.approveParticipant(raceId, userId);
      return true;
    } catch (e) {
      state = state.copyWith(error: "Erro ao aprovar participante: ${e.toString()}");
      return false;
    }
  }

  // Método para limpar o erro manualmente, se necessário
  void clearError() {
    if (state.error != null) {
      state = state.copyWith(clearError: true);
    }
  }
}

//----------------------------------------------------------------------
// 3. Providers Globais
//----------------------------------------------------------------------

// Provider para o RaceService (singleton)
final raceServiceProvider = Provider<RaceService>((ref) {
  // Se RaceService tiver dependências, injete-as aqui.
  // Ex: final googleMapsService = ref.watch(googleMapsServiceProvider);
  // return RaceService(googleMapsService);
  return RaceService(); // Assumindo que não tem dependências agora
});

// Provider para o RaceNotifier
// Gerencia RaceActionState e fornece acesso aos métodos de ação.
final raceNotifierProvider = StateNotifierProvider<RaceNotifier, RaceActionState>((ref) {
  final raceService = ref.watch(raceServiceProvider);
  return RaceNotifier(raceService);
});

// --- Providers para consumir os Streams de Dados ---

// Provider para o stream de todas as corridas públicas/disponíveis
final allRacesStreamProvider = StreamProvider.autoDispose<List<Race>>((ref) {
  // Ouve o notifier para re-executar se necessário (embora o stream em si já atualize)
  ref.watch(raceNotifierProvider);
  // Acessa o stream através do notifier (ou diretamente do serviço)
  return ref.read(raceNotifierProvider.notifier).racesStream();
  // Alternativa: direto do serviço
  // return ref.read(raceServiceProvider).racesStream;
});

// Provider para o stream de corridas de um grupo específico
final groupRacesStreamProvider = StreamProvider.family.autoDispose<List<Race>, String>((ref, groupId) {
   ref.watch(raceNotifierProvider);
   return ref.read(raceNotifierProvider.notifier).racesByGroup(groupId);
});

// Provider para o stream de corridas criadas por um usuário
final ownerRacesStreamProvider = StreamProvider.family.autoDispose<List<Race>, String>((ref, ownerId) {
   ref.watch(raceNotifierProvider);
   return ref.read(raceNotifierProvider.notifier).racesByOwner(ownerId);
});

// Provider para o stream de corridas em que um usuário participa
// LEMBRETE: Depende da correção/clarificação sobre o armazenamento de participantes.
final participantRacesStreamProvider = StreamProvider.family.autoDispose<List<Race>, String>((ref, userId) {
   ref.watch(raceNotifierProvider);
   return ref.read(raceNotifierProvider.notifier).racesByParticipant(userId);
});


// Provider para buscar os detalhes de UMA corrida específica (como um Future)
// Útil para a tela de detalhes, onde talvez você não precise de um stream constante.
final raceDetailsProvider = FutureProvider.family.autoDispose<Race?, String>((ref, raceId) async {
  // Não precisa ouvir o notifier aqui, apenas o serviço
  final raceService = ref.watch(raceServiceProvider);
  try {
    return await raceService.getRace(raceId);
  } catch (e) {
    // Você pode logar o erro ou retornar null/lançar uma exceção específica
    print("Erro ao buscar detalhes da corrida $raceId: $e");
    return null; // Ou rethrow; dependendo de como a UI tratará o erro
  }
});

/*
// Alternativa: Provider para buscar detalhes como Stream (se precisar de updates em tempo real na tela de detalhes)
final raceDetailsStreamProvider = StreamProvider.family.autoDispose<Race?, String>((ref, raceId) {
  final raceService = ref.watch(raceServiceProvider);
  // Precisaria de um método no RaceService tipo: Stream<Race?> getRaceStream(String id)
  // return raceService.getRaceStream(raceId);
});
*/