import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:friends_run/models/race/race_model.dart';
import 'package:geolocator/geolocator.dart';

class RaceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'races';

  // CREATE - Adicionar nova corrida
  Future<Race> createRace(Race race) async {
    try {
      final docRef = await _firestore.collection(_collectionName).add(race.toJson());
      return race.copyWith(id: docRef.id);
    } catch (e) {
      throw Exception('Failed to create race: $e');
    }
  }

  // READ - Obter corrida por ID
  Future<Race> getRace(String id) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(id).get();
      if (doc.exists) {
        return Race.fromJson(doc.data()!..['id'] = doc.id);
      }
      throw Exception('Race not found');
    } catch (e) {
      throw Exception('Failed to get race: $e');
    }
  }

  // UPDATE - Atualizar corrida
  Future<void> updateRace(Race race) async {
    try {
      await _firestore.collection(_collectionName).doc(race.id).update(race.toJson());
    } catch (e) {
      throw Exception('Failed to update race: $e');
    }
  }

  // DELETE - Remover corrida
  Future<void> deleteRace(String id) async {
    try {
      await _firestore.collection(_collectionName).doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete race: $e');
    }
  }

  // LISTEN - Stream de todas corridas
  Stream<List<Race>> get racesStream {
    return _firestore.collection(_collectionName)
      .orderBy('date', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
        .map((doc) => Race.fromJson(doc.data()..['id'] = doc.id))
        .toList());
  }

  // Consulta por grupo
  Stream<List<Race>> getRacesByGroup(String groupId) {
    return _firestore.collection(_collectionName)
      .where('groupId', isEqualTo: groupId)
      .orderBy('date', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
        .map((doc) => Race.fromJson(doc.data()..['id'] = doc.id))
        .toList());
  }

  // Consulta por usuário (criador)
  Stream<List<Race>> getRacesByOwner(String ownerId) {
    return _firestore.collection(_collectionName)
      .where('ownerId', isEqualTo: ownerId)
      .orderBy('date', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
        .map((doc) => Race.fromJson(doc.data()..['id'] = doc.id))
        .toList());
  }

  // Consulta por participante
  Stream<List<Race>> getRacesByParticipant(String userId) {
    return _firestore.collection(_collectionName)
      .where('participants', arrayContains: userId)
      .orderBy('date', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
        .map((doc) => Race.fromJson(doc.data()..['id'] = doc.id))
        .toList());
  }

  // Adicionar participante
  Future<void> addParticipant(String raceId, String userId) async {
    try {
      await _firestore.collection(_collectionName).doc(raceId).update({
        'participants': FieldValue.arrayUnion([userId])
      });
    } catch (e) {
      throw Exception('Failed to add participant: $e');
    }
  }

  // Remover participante
  Future<void> removeParticipant(String raceId, String userId) async {
    try {
      await _firestore.collection(_collectionName).doc(raceId).update({
        'participants': FieldValue.arrayRemove([userId])
      });
    } catch (e) {
      throw Exception('Failed to remove participant: $e');
    }
  }

  // Adicionar solicitação de participação
  Future<void> addParticipationRequest(String raceId, String userId) async {
    try {
      await _firestore.collection(_collectionName).doc(raceId).update({
        'pendingParticipants': FieldValue.arrayUnion([userId])
      });
    } catch (e) {
      throw Exception('Failed to add participation request: $e');
    }
  }

  // Aprovar participante
  Future<void> approveParticipant(String raceId, String userId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final docRef = _firestore.collection(_collectionName).doc(raceId);
        transaction.update(docRef, {
          'pendingParticipants': FieldValue.arrayRemove([userId]),
          'participants': FieldValue.arrayUnion([userId]),
        });
      });
    } catch (e) {
      throw Exception('Failed to approve participant: $e');
    }
  }

  Future<List<Race>> getNearbyRaces(Position userPosition, {double radiusInKm = 10.0}) async {
    // Calcula os limites geográficos
    final lat = userPosition.latitude;
    final lng = userPosition.longitude;
    
    // Aproximação de 1 grau = ~111km
    final degree = radiusInKm / 111.0;
    final lowerLat = lat - degree;
    final upperLat = lat + degree;
    final lowerLng = lng - degree;
    final upperLng = lng + degree;

    try {
      // Consulta no Firestore por corridas dentro do retângulo aproximado
      final query = _firestore.collection(_collectionName)
        .where('startLatitude', isGreaterThanOrEqualTo: lowerLat)
        .where('startLatitude', isLessThanOrEqualTo: upperLat)
        .where('startLongitude', isGreaterThanOrEqualTo: lowerLng)
        .where('startLongitude', isLessThanOrEqualTo: upperLng);

      final snapshot = await query.get();

      // Filtra os resultados para obter apenas os dentro do raio exato
      final races = snapshot.docs.map((doc) {
        return Race.fromJson(doc.data()..['id'] = doc.id);
      }).toList();

      return races.where((race) {
        final distance = Geolocator.distanceBetween(
          userPosition.latitude,
          userPosition.longitude,
          race.startLatitude,
          race.startLongitude,
        ) / 1000; // Converte para km
        
        return distance <= radiusInKm;
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch nearby races: $e');
    }
  }
}