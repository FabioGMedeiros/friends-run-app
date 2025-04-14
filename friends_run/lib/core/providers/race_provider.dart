import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:friends_run/core/services/race_service.dart';
import 'package:friends_run/models/race/race_model.dart';
import 'package:friends_run/models/user/app_user.dart';

final raceProvider = StateNotifierProvider<RaceNotifier, RaceState>((ref) {
  return RaceNotifier(RaceService());
});

class RaceNotifier extends StateNotifier<RaceState> {
  final RaceService _raceService;

  RaceNotifier(this._raceService) : super(RaceState.initial());

  Future<void> loadRaces() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // Lógica para carregar corridas iniciais se necessário
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Stream<List<Race>> racesStream() {
    return _raceService.racesStream;
  }

  Stream<List<Race>> racesByGroup(String groupId) {
    return _raceService.getRacesByGroup(groupId);
  }

  Stream<List<Race>> racesByOwner(String ownerId) {
    return _raceService.getRacesByOwner(ownerId);
  }

  Stream<List<Race>> racesByParticipant(String userId) {
    return _raceService.getRacesByParticipant(userId);
  }

  Future<Race> createRace({
    required String title,
    required DateTime date,
    required String startAddress,
    required String endAddress,
    required AppUser owner,
    bool isPrivate = false,
    String? groupId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
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
      
      state = state.copyWith(isLoading: false);
      return createdRace;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> updateRace(Race race) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      await _raceService.updateRace(race);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteRace(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      await _raceService.deleteRace(id);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> addParticipant(String raceId, String userId) async {
    try {
      await _raceService.addParticipant(raceId, userId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> removeParticipant(String raceId, String userId) async {
    try {
      await _raceService.removeParticipant(raceId, userId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> addParticipationRequest(String raceId, String userId) async {
    try {
      await _raceService.addParticipationRequest(raceId, userId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> approveParticipant(String raceId, String userId) async {
    try {
      await _raceService.approveParticipant(raceId, userId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }
}

class RaceState {
  final List<Race> races;
  final bool isLoading;
  final String? error;

  RaceState({
    required this.races,
    required this.isLoading,
    this.error,
  });

  factory RaceState.initial() {
    return RaceState(
      races: [],
      isLoading: false,
      error: null,
    );
  }

  RaceState copyWith({
    List<Race>? races,
    bool? isLoading,
    String? error,
  }) {
    return RaceState(
      races: races ?? this.races,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}