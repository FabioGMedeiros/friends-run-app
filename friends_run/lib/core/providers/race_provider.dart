import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:friends_run/core/services/race_service.dart';
import 'package:friends_run/models/race/race_model.dart';
import 'package:friends_run/models/user/app_user.dart';
import 'package:meta/meta.dart';

//----------------------------------------------------------------------
// 0. Enum for Race Action Types
//----------------------------------------------------------------------
enum RaceActionType {
  join,     // Para entrar em corrida pública
  leave,    // Para sair da corrida
  request,  // Para solicitar entrada em corrida privada
  approve,  // Para aprovar participante (se houver botão)
  create,   // Para criar corrida
  update,   // Para atualizar corrida
  delete,   // Para deletar corrida
  none      // Nenhuma ação específica em andamento
}

//----------------------------------------------------------------------
// 1. State for Actions (Loading/Error/ActionType)
//----------------------------------------------------------------------
@immutable
class RaceActionState {
  final bool isLoading;
  final String? error;
  final RaceActionType actionType;

  // Private constructor
  const RaceActionState._({
    this.isLoading = false,
    this.error,
    this.actionType = RaceActionType.none,
  });

  // Initial state
  factory RaceActionState.initial() => const RaceActionState._();

  // Copy with method
  RaceActionState copyWith({
    bool? isLoading,
    String? error,
    RaceActionType? actionType,
    bool clearError = false,
  }) {
    return RaceActionState._(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      actionType: actionType ?? this.actionType,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RaceActionState &&
          runtimeType == other.runtimeType &&
          isLoading == other.isLoading &&
          error == other.error &&
          actionType == other.actionType;

  @override
  int get hashCode =>
      isLoading.hashCode ^ error.hashCode ^ actionType.hashCode;
}

//----------------------------------------------------------------------
// 2. Refactored Notifier
//    Manages RaceActionState and exposes action methods and streams
//----------------------------------------------------------------------
class RaceNotifier extends StateNotifier<RaceActionState> {
  final RaceService _raceService;

  RaceNotifier(this._raceService) : super(RaceActionState.initial());

  // --- Stream Methods ---
  Stream<List<Race>> racesStream() => _raceService.racesStream;
  Stream<List<Race>> racesByGroup(String groupId) => _raceService.getRacesByGroup(groupId);
  Stream<List<Race>> racesByOwner(String ownerId) => _raceService.getRacesByOwner(ownerId);
  Stream<List<Race>> racesByParticipant(String userId) => _raceService.getRacesByParticipant(userId);

  // --- Action Methods ---

  Future<Race?> createRace({
    required String title,
    required DateTime date,
    required String startAddress,
    required String endAddress,
    required AppUser owner,
    bool isPrivate = false,
    String? groupId,
  }) async {
    state = state.copyWith(
      isLoading: true,
      actionType: RaceActionType.create,
      clearError: true
    );
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
      state = state.copyWith(isLoading: false, actionType: RaceActionType.none);
      return createdRace;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        actionType: RaceActionType.none,
        error: "Erro ao criar corrida: ${e.toString()}"
      );
      return null;
    }
  }

  Future<bool> updateRace(Race race) async {
    state = state.copyWith(
      isLoading: true,
      actionType: RaceActionType.update,
      clearError: true
    );
    try {
      await _raceService.updateRace(race);
      state = state.copyWith(isLoading: false, actionType: RaceActionType.none);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        actionType: RaceActionType.none,
        error: "Erro ao atualizar corrida: ${e.toString()}"
      );
      return false;
    }
  }

  Future<bool> leaveRace(String raceId, String userId) async {
    state = state.copyWith(
      isLoading: true,
      actionType: RaceActionType.leave,
      clearError: true
    );
    try {
      await _raceService.leaveRace(raceId, userId);
      state = state.copyWith(isLoading: false, actionType: RaceActionType.none);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        actionType: RaceActionType.none,
        error: "Erro ao sair da corrida: ${e.toString().replaceFirst("Exception: ", "")}"
      );
      return false;
    }
  }

  Future<bool> deleteRace(String id) async {
    state = state.copyWith(
      isLoading: true,
      actionType: RaceActionType.delete,
      clearError: true
    );
    try {
      await _raceService.deleteRace(id);
      state = state.copyWith(isLoading: false, actionType: RaceActionType.none);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        actionType: RaceActionType.none,
        error: "Erro ao deletar corrida: ${e.toString()}"
      );
      return false;
    }
  }

  Future<bool> addParticipant(String raceId, String userId) async {
    state = state.copyWith(
      isLoading: true,
      actionType: RaceActionType.join,
      clearError: true
    );
    try {
      await _raceService.addParticipant(raceId, userId);
      state = state.copyWith(isLoading: false, actionType: RaceActionType.none);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        actionType: RaceActionType.none,
        error: "Erro ao adicionar participante: ${e.toString()}"
      );
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
    state = state.copyWith(
      isLoading: true,
      actionType: RaceActionType.request,
      clearError: true
    );
    try {
      await _raceService.addParticipationRequest(raceId, userId);
      state = state.copyWith(isLoading: false, actionType: RaceActionType.none);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        actionType: RaceActionType.none,
        error: "Erro ao solicitar participação: ${e.toString()}"
      );
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

  void clearError() {
    if (state.error != null) {
      state = state.copyWith(clearError: true);
    }
  }
}

//----------------------------------------------------------------------
// 3. Global Providers
//----------------------------------------------------------------------

// Provider for RaceService
final raceServiceProvider = Provider<RaceService>((ref) {
  return RaceService();
});

// Provider for RaceNotifier
final raceNotifierProvider = StateNotifierProvider<RaceNotifier, RaceActionState>((ref) {
  final raceService = ref.watch(raceServiceProvider);
  return RaceNotifier(raceService);
});

// --- Stream Providers ---
final allRacesStreamProvider = StreamProvider.autoDispose<List<Race>>((ref) {
  ref.watch(raceNotifierProvider);
  return ref.read(raceNotifierProvider.notifier).racesStream();
});

final groupRacesStreamProvider = StreamProvider.family.autoDispose<List<Race>, String>((ref, groupId) {
  ref.watch(raceNotifierProvider);
  return ref.read(raceNotifierProvider.notifier).racesByGroup(groupId);
});

final ownerRacesStreamProvider = StreamProvider.family.autoDispose<List<Race>, String>((ref, ownerId) {
  ref.watch(raceNotifierProvider);
  return ref.read(raceNotifierProvider.notifier).racesByOwner(ownerId);
});

final participantRacesStreamProvider = StreamProvider.family.autoDispose<List<Race>, String>((ref, userId) {
  ref.watch(raceNotifierProvider);
  return ref.read(raceNotifierProvider.notifier).racesByParticipant(userId);
});

// --- Race Details Provider ---
final raceDetailsProvider = FutureProvider.family.autoDispose<Race?, String>((ref, raceId) async {
  final raceService = ref.watch(raceServiceProvider);
  try {
    return await raceService.getRace(raceId);
  } catch (e) {
    print("Erro ao buscar detalhes da corrida $raceId: $e");
    return null;
  }
});