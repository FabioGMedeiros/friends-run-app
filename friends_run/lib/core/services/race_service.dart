import 'package:friends_run/core/services/google_maps_service.dart';
import 'package:friends_run/models/race/race_model.dart';

class RaceService {
  final GoogleMapsService _mapsService = GoogleMapsService();

  Future<List<Race>> getNearbyRaces({
    required double userLatitude,
    required double userLongitude,
    double radiusInKm = 10.0,
  }) async {
    // Implementação real buscaria da sua API
    // Esta é uma implementação mock para exemplo
    
    final mockRaces = await _generateMockRaces(
      userLatitude: userLatitude,
      userLongitude: userLongitude,
    );
    
    return mockRaces;
  }

  Future<List<Race>> _generateMockRaces({
    required double userLatitude,
    required double userLongitude,
  }) async {
    final races = <Race>[];
    
    // Gerar 3 corridas mockadas próximas ao usuário
    for (int i = 1; i <= 3; i++) {
      // Deslocar ligeiramente as coordenadas para criar corridas próximas
      final startLat = userLatitude + (0.01 * i);
      final startLng = userLongitude + (0.01 * i);
      final endLat = startLat + 0.02;
      final endLng = startLng + 0.02;
      
      final startAddress = await _mapsService.getShortAddress(startLat, startLng);
      final endAddress = await _mapsService.getShortAddress(endLat, endLng);
      
      final mapImageUrl = await _mapsService.getRouteMapImage(
        startLat: startLat,
        startLng: startLng,
        endLat: endLat,
        endLng: endLng,
        width: 600,
        height: 200,
      );
      
      races.add(Race(
        id: 'race_$i',
        title: 'Corrida ${['no Parque', 'Urbana', 'Noturna'][i-1]}',
        distance: [5.0, 10.0, 21.0][i-1],
        date: DateTime.now().add(Duration(days: i)),
        location: startAddress,
        locationDescription: '${i*2} km de você',
        participants: [15, 30, 50][i-1],
        startLatitude: startLat,
        startLongitude: startLng,
        endLatitude: endLat,
        endLongitude: endLng,
        startAddress: startAddress,
        endAddress: endAddress,
        imageUrl: mapImageUrl,
      ));
    }
    
    return races;
  }
}