import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';

// Providers necessários
import 'package:friends_run/core/providers/auth_provider.dart';
import 'package:friends_run/core/providers/race_provider.dart';
import 'package:friends_run/models/user/app_user.dart';
import 'package:friends_run/core/utils/colors.dart';
import 'package:friends_run/core/utils/validationsUtils.dart'; // Importe suas validações

// Provider inicial do mapa
final initialMapPositionProvider = FutureProvider<CameraPosition>((ref) async {
  Position? position;
  try {
    position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  } catch (e) {
    print("Erro ao obter localização inicial: $e. Usando posição padrão.");
  }
  return CameraPosition(
    target: LatLng(
      position?.latitude ?? -23.55052, // SP Lat
      position?.longitude ?? -46.63330, // SP Lng
    ),
    zoom: 14.0,
  );
});

class CreateRaceView extends ConsumerStatefulWidget {
  const CreateRaceView({super.key});

  @override
  ConsumerState<CreateRaceView> createState() => _CreateRaceViewState();
}

class _CreateRaceViewState extends ConsumerState<CreateRaceView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _startAddressController = TextEditingController();
  final _endAddressController = TextEditingController();

  DateTime? _selectedDateTime;
  bool _isPrivate = false;
  LatLng? _startLatLng;
  LatLng? _endLatLng;
  final Set<Marker> _markers = {};
  final Completer<GoogleMapController> _mapControllerCompleter = Completer();
  GoogleMapController? _mapController;

  // Estados de loading
  bool _isGeocodingStart = false;
  bool _isGeocodingEnd = false;
  bool _isReverseGeocodingStart = false;
  bool _isReverseGeocodingEnd = false;

  double? _calculatedDistanceKm;

  @override
  void dispose() {
    _titleController.dispose();
    _startAddressController.dispose();
    _endAddressController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // --- Funções Auxiliares ---

  void _updateDistance() {
    if (_startLatLng != null && _endLatLng != null) {
      double distanceInMeters = Geolocator.distanceBetween(
        _startLatLng!.latitude, _startLatLng!.longitude,
        _endLatLng!.latitude, _endLatLng!.longitude,
      );
      if (mounted) {
        setState(() => _calculatedDistanceKm = distanceInMeters / 1000.0);
      }
    } else {
      if (mounted) {
        setState(() => _calculatedDistanceKm = null);
      }
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initial = _selectedDateTime ?? now;
    final validInitial = initial.isBefore(now) ? now : initial;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: validInitial,
      firstDate: now.subtract(const Duration(days: 1)), // Permite dia atual
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime ?? now),
      );
      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year, pickedDate.month, pickedDate.day,
            pickedTime.hour, pickedTime.minute,
          );
        });
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    if (!_mapControllerCompleter.isCompleted) {
      _mapControllerCompleter.complete(controller);
    }
    _mapController = controller;
    print("Mapa criado!");
  }

  // --- Lógica de Interação Mapa/Endereço ---

  Future<void> _reverseGeocodeAndUpdateField(LatLng point, {required bool isStartPoint}) async {
    final controller = isStartPoint ? _startAddressController : _endAddressController;
    if (mounted) {
      setState(() {
        if (isStartPoint) _isReverseGeocodingStart = true; else _isReverseGeocodingEnd = true;
      });
    }
    String addressText = "Endereço não encontrado";
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(point.latitude, point.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        addressText = [p.street, p.subLocality, p.locality, p.administrativeArea, p.postalCode]
            .where((s) => s != null && s.isNotEmpty).join(', ');
         if (addressText.isEmpty) addressText = "Detalhes do endereço não disponíveis";
      }
    } catch (e) {
      print("Erro na geocodificação reversa: $e");
      addressText = "Erro ao buscar endereço";
    } finally {
      if (mounted) {
        setState(() {
          controller.text = addressText;
          if (isStartPoint) _isReverseGeocodingStart = false; else _isReverseGeocodingEnd = false;
        });
      }
    }
  }

  void _updateMapMarker(LatLng position, {required bool isStartPoint, String? address}) {
    final markerId = MarkerId(isStartPoint ? 'start' : 'end');
    final newMarker = Marker(
       markerId: markerId,
       position: position,
       infoWindow: InfoWindow(title: isStartPoint ? 'Ponto de Início' : 'Ponto de Chegada', snippet: address),
       icon: BitmapDescriptor.defaultMarkerWithHue(isStartPoint ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed),
       draggable: true,
       onDragEnd: (newPos) => _onMarkerDragEnd(markerId.value, newPos),
     );
      if(mounted){
        setState(() {
           _markers.removeWhere((m) => m.markerId == markerId);
           _markers.add(newMarker);
        });
      }
  }

  void _onMapTap(LatLng point) async {
    final actionState = ref.read(raceNotifierProvider);
    if (actionState.isLoading) return;
    bool isStartPoint = _startLatLng == null || (_endLatLng != null);
    if (_startLatLng != null && _endLatLng != null) {
      isStartPoint = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Redefinindo Ponto Inicial. Toque novamente para o Ponto Final.')),
      );
      setState(() {
        _endLatLng = null;
        _markers.removeWhere((m) => m.markerId.value == 'end');
        _endAddressController.clear();
        _calculatedDistanceKm = null;
      });
    }
    if(isStartPoint) _startLatLng = point; else _endLatLng = point;
    _updateMapMarker(point, isStartPoint: isStartPoint, address: isStartPoint ? _startAddressController.text : _endAddressController.text);
    await _reverseGeocodeAndUpdateField(point, isStartPoint: isStartPoint);
    _animateCameraToBounds();
    _updateDistance();
   }

  void _onMarkerDragEnd(String markerIdValue, LatLng newPosition) async {
    bool isStartPoint = markerIdValue == 'start';
    if (isStartPoint) _startLatLng = newPosition; else _endLatLng = newPosition;
    _updateMapMarker(newPosition, isStartPoint: isStartPoint, address: isStartPoint ? _startAddressController.text : _endAddressController.text);
    await _reverseGeocodeAndUpdateField(newPosition, isStartPoint: isStartPoint);
    _updateDistance();
  }

  Future<void> _geocodeAddress({required bool isStartPoint}) async {
    final addressController = isStartPoint ? _startAddressController : _endAddressController;
    final address = addressController.text.trim();
    if (address.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Digite um endereço para buscar.')));
       return;
    }

    if(mounted) setState(() => isStartPoint ? _isGeocodingStart = true : _isGeocodingEnd = true);

    LatLng? foundLatLng;
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
         final location = locations.first;
         foundLatLng = LatLng(location.latitude, location.longitude);
         if(isStartPoint) _startLatLng = foundLatLng; else _endLatLng = foundLatLng;
         _updateMapMarker(foundLatLng, isStartPoint: isStartPoint, address: address);
         if(mounted) setState(() {});
         _mapController?.animateCamera(CameraUpdate.newLatLngZoom(foundLatLng, 15.0));
         _animateCameraToBounds();
      } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Endereço "$address" não encontrado.')));
      }
    } catch (e) {
       print("Erro na geocodificação: $e");
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao buscar coordenadas: ${e.toString()}')));
    } finally {
      if(mounted) setState(() => isStartPoint ? _isGeocodingStart = false : _isGeocodingEnd = false);
    }
     _updateDistance();
  }

  void _clearMarkers() {
    setState(() {
      _startLatLng = null;
      _endLatLng = null;
      _markers.clear();
      _startAddressController.clear();
      _endAddressController.clear();
       _calculatedDistanceKm = null;
    });
  }

  void _animateCameraToBounds() {
    if (_mapController == null ) return;
    if (_startLatLng != null && _endLatLng != null) {
       LatLngBounds bounds;
       if (_startLatLng!.latitude > _endLatLng!.latitude) {
         bounds = LatLngBounds(southwest: _endLatLng!, northeast: _startLatLng!);
       } else {
         bounds = LatLngBounds(southwest: _startLatLng!, northeast: _endLatLng!);
       }
       _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60.0));
    }
    else if (_startLatLng != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(_startLatLng!, 15.0));
    } else if (_endLatLng != null) {
       _mapController!.animateCamera(CameraUpdate.newLatLngZoom(_endLatLng!, 15.0));
    }
  }

  String _formatAddress(String address) {
    if (address.isEmpty) return '';
    String formatted = address;
    final replacements = {
      RegExp(r'\b(rua)\b', caseSensitive: false): 'R.',
      RegExp(r'\b(avenida)\b', caseSensitive: false): 'Av.',
      RegExp(r'\b(alameda)\b', caseSensitive: false): 'Al.',
      RegExp(r'\b(travessa)\b', caseSensitive: false): 'Tv.',
      RegExp(r'\b(praça)\b', caseSensitive: false): 'Pç.',
      RegExp(r'\b(praca)\b', caseSensitive: false): 'Pç.',
      RegExp(r'\b(estrada)\b', caseSensitive: false): 'Estr.',
      RegExp(r'\b(rodovia)\b', caseSensitive: false): 'Rod.',
      RegExp(r'\b(largo)\b', caseSensitive: false): 'Lg.',
    };
    replacements.forEach((regex, replacement) {
      formatted = formatted.replaceAllMapped(regex, (match) => replacement);
    });
    return formatted.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<void> _createRace() async {
      FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
     if (_selectedDateTime == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione a data e hora da corrida!')));
       return;
     }

    final currentUserAsync = ref.read(currentUserProvider);
    final AppUser? currentUser = currentUserAsync.asData?.value;
    if (currentUser == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao obter usuário.')));
       return;
     }

    final formattedStartAddress = _formatAddress(_startAddressController.text);
    final formattedEndAddress = _formatAddress(_endAddressController.text);

    final success = await ref.read(raceNotifierProvider.notifier).createRace(
          title: _titleController.text.trim(),
          date: _selectedDateTime!,
          startAddress: formattedStartAddress,
          endAddress: formattedEndAddress,
          owner: currentUser,
          isPrivate: _isPrivate,
          groupId: null,
        );

    if (success != null && mounted) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Corrida criada!'), backgroundColor: Colors.green));
       Navigator.pop(context);
    }
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(raceNotifierProvider);
    final initialCameraPositionAsync = ref.watch(initialMapPositionProvider);

    ref.listen<RaceActionState>(raceNotifierProvider, (_, next) {
       if (next.error != null && next.error!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: AppColors.primaryRed),
        );
        ref.read(raceNotifierProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Criar Nova Corrida', style: TextStyle(color: AppColors.white)),
        backgroundColor: AppColors.background,
         leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: actionState.isLoading ? null : () => Navigator.pop(context),
        ),
        actions: [
           if (_markers.isNotEmpty)
             IconButton(
               tooltip: "Limpar marcadores e endereços",
               icon: const Icon(Icons.layers_clear, color: Colors.orangeAccent),
               onPressed: actionState.isLoading ? null : _clearMarkers,
             ),
        ],
      ),
      body: IgnorePointer(
        ignoring: actionState.isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Título ---
                TextFormField(
                    controller: _titleController,
                    enabled: !actionState.isLoading,
                    style: const TextStyle(color: AppColors.white),
                    // --- PREENCHENDO O PLACEHOLDER ---
                    decoration: InputDecoration(
                       labelText: 'Título da Corrida *',
                       labelStyle: const TextStyle(color: AppColors.greyLight),
                       filled: true,
                       fillColor: AppColors.underBackground,
                       border: OutlineInputBorder(
                           borderRadius: BorderRadius.circular(8),
                           borderSide: BorderSide.none
                       ),
                       contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    // ------------------------------------
                    validator: (value) => value == null || value.trim().isEmpty ? 'Título é obrigatório' : null,
                 ),
                const SizedBox(height: 16),

                // --- Data/Hora ---
                ListTile(
                     // --- PREENCHENDO O PLACEHOLDER ---
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                     tileColor: AppColors.underBackground,
                     contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                     leading: const Icon(Icons.calendar_today, color: AppColors.primaryRed),
                     title: Text(
                       _selectedDateTime == null
                           ? 'Data e Hora da Corrida *'
                           : DateFormat('dd/MM/yyyy \'às\' HH:mm').format(_selectedDateTime!),
                       style: TextStyle(color: _selectedDateTime == null ? AppColors.greyLight: AppColors.white, fontSize: 16),
                     ),
                     trailing: const Icon(Icons.edit, color: AppColors.greyLight, size: 18),
                     onTap: actionState.isLoading ? null : _pickDateTime,
                     // ------------------------------------
                 ),
                const SizedBox(height: 20),

                // --- Distância ---
                if (_calculatedDistanceKm != null)
                   Padding(
                     // --- PREENCHENDO O PLACEHOLDER ---
                     padding: const EdgeInsets.only(bottom: 16.0),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                          const Icon(Icons.straighten, color: AppColors.primaryRed, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "Distância: ${_calculatedDistanceKm!.toStringAsFixed(1)} km",
                            style: const TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                       ],
                     ),
                     // ------------------------------------
                   ),

                // --- Endereços ---
                const Text("Endereços (Início e Fim):", style: TextStyle(color: AppColors.white, fontSize: 16)),
                const SizedBox(height: 12),
                 TextFormField( // Início
                    controller: _startAddressController,
                    enabled: !actionState.isLoading,
                    style: const TextStyle(color: AppColors.white),
                    // --- PREENCHENDO O PLACEHOLDER ---
                    decoration: InputDecoration(
                       hintText: 'Ex: Pq. Ibirapuera ou R. Paulista, 100',
                       hintStyle: TextStyle(color: AppColors.greyLight.withOpacity(0.7)),
                       labelText: 'Endereço de Início *',
                        labelStyle: const TextStyle(color: AppColors.greyLight),
                        prefixIcon: const Icon(Icons.flag, color: AppColors.primaryRed),
                        suffixIcon: _isGeocodingStart
                           ? const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryRed)))
                           : IconButton(
                               tooltip: "Buscar localização no mapa",
                               icon: const Icon(Icons.location_searching, color: AppColors.greyLight),
                               onPressed: () => _geocodeAddress(isStartPoint: true),
                             ),
                        filled: true, fillColor: AppColors.underBackground,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                     ),
                    // ------------------------------------
                     validator: ValidationUtils.validateAddress,
                  ),
                  const SizedBox(height: 12),
                  TextFormField( // Fim
                    controller: _endAddressController,
                     enabled: !actionState.isLoading,
                     style: const TextStyle(color: AppColors.white),
                     // --- PREENCHENDO O PLACEHOLDER ---
                     decoration: InputDecoration(
                        hintText: 'Ex: Metrô Consolação ou Av. Brasil, 500',
                        hintStyle: TextStyle(color: AppColors.greyLight.withOpacity(0.7)),
                       labelText: 'Endereço de Chegada *',
                       labelStyle: const TextStyle(color: AppColors.greyLight),
                        prefixIcon: const Icon(Icons.location_on, color: AppColors.primaryRed),
                         suffixIcon: _isGeocodingEnd
                           ? const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryRed)))
                           : IconButton(
                               tooltip: "Buscar localização no mapa",
                               icon: const Icon(Icons.location_searching, color: AppColors.greyLight),
                               onPressed: () => _geocodeAddress(isStartPoint: false),
                             ),
                        filled: true, fillColor: AppColors.underBackground,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                     ),
                     // ------------------------------------
                     validator: ValidationUtils.validateAddress,
                  ),
                   const SizedBox(height: 20),

                // --- Mapa ---
                 const Text("Mapa Interativo:", style: TextStyle(color: AppColors.white, fontSize: 16)),
                 Padding(
                    // --- PREENCHENDO O PLACEHOLDER ---
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                      _markers.isEmpty
                        ? "Busque pelos endereços ou toque no mapa."
                        : _markers.length == 1 ? "Defina o segundo endereço ou toque/arraste." : "Arraste os marcadores para ajustar.",
                      style: const TextStyle(color: AppColors.greyLight, fontStyle: FontStyle.italic)
                    ),
                    // ------------------------------------
                  ),
                 const SizedBox(height: 8),
                 SizedBox(
                   height: 250,
                   child: ClipRRect(
                     borderRadius: BorderRadius.circular(12),
                     // --- PREENCHENDO O PLACEHOLDER ---
                     child: initialCameraPositionAsync.when(
                        data: (initialPosition) => GoogleMap(
                           onMapCreated: _onMapCreated,
                           initialCameraPosition: initialPosition,
                           markers: _markers,
                           onTap: _onMapTap,
                           mapType: MapType.normal,
                           myLocationEnabled: true,
                           myLocationButtonEnabled: true,
                           zoomControlsEnabled: true,
                         ),
                        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryRed)),
                        error: (err, stack) => Center(child: Text("Erro ao carregar mapa: $err", style: const TextStyle(color: Colors.redAccent)))
                      ),
                     // ------------------------------------
                   ),
                 ),
                 const SizedBox(height: 20),

                 // --- Opção Privada ---
                 SwitchListTile(
                      // --- PREENCHENDO O PLACEHOLDER ---
                      title: const Text("Corrida Privada?", style: TextStyle(color: AppColors.white)),
                      subtitle: Text(
                         _isPrivate ? "Apenas convidados poderão ver." : "Visível para todos.",
                         style: const TextStyle(color: AppColors.greyLight)
                      ),
                      value: _isPrivate,
                      onChanged: actionState.isLoading ? null : (value) {
                        setState(() { _isPrivate = value; });
                      },
                      activeColor: AppColors.primaryRed,
                       tileColor: AppColors.underBackground,
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12.0),
                      // ------------------------------------
                  ),
                 const SizedBox(height: 30),

                // --- Botão Criar ---
                 ElevatedButton.icon(
                       // --- PREENCHENDO O PLACEHOLDER ---
                       icon: const Icon(Icons.check, color: AppColors.white),
                       label: const Text('Criar Corrida', style: TextStyle(fontSize: 16, color: AppColors.white)),
                       onPressed: actionState.isLoading? null : _createRace,
                       style: ElevatedButton.styleFrom(
                           backgroundColor: AppColors.primaryRed,
                           padding: const EdgeInsets.symmetric(vertical: 15),
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                       ),
                       // ------------------------------------
                  ),
                 if(actionState.isLoading)
                    const Padding(
                       // --- PREENCHENDO O PLACEHOLDER ---
                       padding: EdgeInsets.only(top: 16.0),
                       child: Center(child: CircularProgressIndicator(color: AppColors.primaryRed)),
                       // ------------------------------------
                     )

              ],
            ),
          ),
        ),
      ),
    );
  }
}