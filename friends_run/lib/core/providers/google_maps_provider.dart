// core/providers/Maps_service_provider.dart  <-- Nome de arquivo sugerido

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:friends_run/core/services/google_maps_service.dart';

// Provider simples que cria e expõe a instância do GoogleMapsService
final googleMapsServiceProvider = Provider<GoogleMapsService>((ref) {
  // Se o seu GoogleMapsService precisar de alguma chave de API ou outra dependência,
  // você pode obtê-la aqui usando ref.read ou ref.watch de outros providers.
  // Exemplo: final apiKey = ref.watch(environmentProvider).googleMapsApiKey;
  // return GoogleMapsService(apiKey: apiKey);

  // Se não tiver dependências (ou elas forem gerenciadas internamente no serviço):
  print("[Provider] Criando instância de GoogleMapsService"); // Log para debug
  return GoogleMapsService();
});