import 'package:flutter/foundation.dart';
import 'package:friends_run/core/services/race_service.dart';
import 'package:friends_run/models/race/race_model.dart';
import 'package:friends_run/models/user/app_user.dart';

class RaceProvider with ChangeNotifier {
  final RaceService _raceService = RaceService();
  List<Race> _races = [];
  bool _isLoading = false;
  String? _error;

  List<Race> get races => _races;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadRaces() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Aqui você pode carregar as corridas iniciais se necessário
      // Ou apenas configurar os listeners
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Stream<List<Race>> getRacesStream() {
    return _raceService.racesStream;
  }

  Stream<List<Race>> getRacesByGroup(String groupId) {
    return _raceService.getRacesByGroup(groupId);
  }

  Stream<List<Race>> getRacesByOwner(String ownerId) {
    return _raceService.getRacesByOwner(ownerId);
  }

  Stream<List<Race>> getRacesByParticipant(String userId) {
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
    _isLoading = true;
    notifyListeners();

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
      _error = null;
      return createdRace;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateRace(Race race) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _raceService.updateRace(race);
      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteRace(String id) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _raceService.deleteRace(id);
      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addParticipant(String raceId, String userId) async {
    try {
      await _raceService.addParticipant(raceId, userId);
      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    }
  }

  Future<void> removeParticipant(String raceId, String userId) async {
    try {
      await _raceService.removeParticipant(raceId, userId);
      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    }
  }

  Future<void> addParticipationRequest(String raceId, String userId) async {
    try {
      await _raceService.addParticipationRequest(raceId, userId);
      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    }
  }

  Future<void> approveParticipant(String raceId, String userId) async {
    try {
      await _raceService.approveParticipant(raceId, userId);
      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    }
  }
}
