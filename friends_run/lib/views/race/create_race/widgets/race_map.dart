import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:friends_run/core/utils/colors.dart';

class RaceMap extends ConsumerWidget {
  final Set<Marker> markers;
  final int markersCount;
  final Function(LatLng) onMapTap;
  final Function(GoogleMapController) onMapCreated;
  final AsyncValue<CameraPosition> initialCameraPosition;

  const RaceMap({
    super.key,
    required this.markers,
    required this.markersCount,
    required this.onMapTap,
    required this.onMapCreated,
    required this.initialCameraPosition,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Mapa Interativo:", 
          style: TextStyle(color: AppColors.white, fontSize: 16)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(
            markers.isEmpty
                ? "Busque pelos endereços ou toque no mapa."
                : markersCount == 1 
                    ? "Defina o segundo endereço ou toque/arraste." 
                    : "Arraste os marcadores para ajustar.",
            style: const TextStyle(color: AppColors.greyLight, fontStyle: FontStyle.italic),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 250,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: initialCameraPosition.when(
              data: (initialPosition) => GoogleMap(
                onMapCreated: onMapCreated,
                initialCameraPosition: initialPosition,
                markers: markers,
                onTap: onMapTap,
                mapType: MapType.normal,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: true,
              ),
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primaryRed)),
              error: (err, stack) => Center(
                child: Text(
                  "Erro ao carregar mapa: $err", 
                  style: const TextStyle(color: Colors.redAccent)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}