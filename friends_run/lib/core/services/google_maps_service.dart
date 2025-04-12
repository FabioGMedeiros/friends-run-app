import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

class GoogleMapsService {
  final String _apiKey;

  GoogleMapsService() : _apiKey = "AIzaSyB1UI408vrCdPjZAfN8b3bbr9HCnJyVhFM";

  Future<String> getRouteMapImage({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    int width = 600,
    int height = 300,
  }) async {
    try {
      // Primeiro tenta obter a rota completa
      final directionsUrl = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=$startLat,$startLng&'
        'destination=$endLat,$endLng&'
        'mode=walking&'
        'key=$_apiKey'
      );

      final response = await http.get(directionsUrl);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final points = data['routes'][0]['overview_polyline']['points'];
          final centerLat = (startLat + endLat) / 2;
          final centerLng = (startLng + endLng) / 2;
          
          return 'https://maps.googleapis.com/maps/api/staticmap?'
            'size=${width}x$height'
            '&maptype=roadmap'
            '&markers=color:green%7Clabel:S%7C$startLat,$startLng'
            '&markers=color:red%7Clabel:F%7C$endLat,$endLng'
            '&path=enc:$points'
            '&center=$centerLat,$centerLng'
            '&zoom=13'
            '&key=$_apiKey';
        }
      }
    } catch (e) {
      debugPrint('Erro ao obter rota: $e');
    }
    
    // Fallback para rota simples
    return _getSimpleRouteUrl(
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
      width: width,
      height: height,
    );
  }

  String _getSimpleRouteUrl({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    required int width,
    required int height,
  }) {
    final centerLat = (startLat + endLat) / 2;
    final centerLng = (startLng + endLng) / 2;
    
    return 'https://maps.googleapis.com/maps/api/staticmap?'
      'size=${width}x$height'
      '&maptype=roadmap'
      '&markers=color:green%7Clabel:S%7C$startLat,$startLng'
      '&markers=color:red%7Clabel:F%7C$endLat,$endLng'
      '&path=color:0x0000ff80%7Cweight:5%7C$startLat,$startLng%7C$endLat,$endLng'
      '&center=$centerLat,$centerLng'
      '&zoom=13'
      '&key=$_apiKey';
  }

  Future<String> getShortAddress(double lat, double lng) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?'
          'latlng=$lat,$lng&'
          'key=$_apiKey'
        ),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          return _simplifyAddress(data['results'][0]['formatted_address'] as String);
        }
      }
    } catch (e) {
      debugPrint('Erro ao obter endereço: $e');
    }
    
    return 'Local desconhecido';
  }

  String _simplifyAddress(String fullAddress) {
    try {
      final parts = fullAddress.split(',');
      if (parts.length > 2) {
        return '${parts[0].trim()}, ${parts[1].trim()}';
      }
      return fullAddress;
    } catch (e) {
      return fullAddress;
    }
  }
}