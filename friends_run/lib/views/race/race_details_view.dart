import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import 'package:friends_run/models/race/race_model.dart';
import 'package:friends_run/core/providers/race_provider.dart';
import 'package:friends_run/core/providers/auth_provider.dart';
import 'package:friends_run/core/providers/location_provider.dart';
import 'package:friends_run/core/utils/colors.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RaceDetailsView extends ConsumerWidget {
  final String raceId;

  const RaceDetailsView({required this.raceId, super.key});

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    Widget valueWidget,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryRed),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.greyLight,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                valueWidget,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapView(Race race) {
    final startPoint = LatLng(race.startLatitude, race.startLongitude);
    final endPoint = LatLng(race.endLatitude, race.endLongitude);
    final markers = {
      Marker(
        markerId: const MarkerId('start'),
        position: startPoint,
        infoWindow: const InfoWindow(title: 'Início'),
      ),
      Marker(
        markerId: const MarkerId('end'),
        position: endPoint,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Fim'),
      ),
    };

    var bounds = LatLngBounds(
      southwest: LatLng(
        startPoint.latitude < endPoint.latitude
            ? startPoint.latitude
            : endPoint.latitude,
        startPoint.longitude < endPoint.longitude
            ? startPoint.longitude
            : endPoint.longitude,
      ),
      northeast: LatLng(
        startPoint.latitude > endPoint.latitude
            ? startPoint.latitude
            : endPoint.latitude,
        startPoint.longitude > endPoint.longitude
            ? startPoint.longitude
            : endPoint.longitude,
      ),
    );

    if (startPoint == endPoint) {
      const delta = 0.002;
      bounds = LatLngBounds(
        southwest: LatLng(startPoint.latitude - delta, startPoint.longitude - delta),
        northeast: LatLng(startPoint.latitude + delta, startPoint.longitude + delta),
      );
    }

    final mapControllerCompleter = Completer<GoogleMapController>();

    return SizedBox(
      height: 250,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GoogleMap(
          markers: markers,
          initialCameraPosition: CameraPosition(
            target: LatLng(
              (startPoint.latitude + endPoint.latitude) / 2,
              (startPoint.longitude + endPoint.longitude) / 2,
            ),
            zoom: 14,
          ),
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
          zoomGesturesEnabled: true,
          scrollGesturesEnabled: true,
          tiltGesturesEnabled: false,
          rotateGesturesEnabled: true,
          mapToolbarEnabled: false,
          mapType: MapType.normal,
          onMapCreated: (controller) {
            if (!mapControllerCompleter.isCompleted) {
              mapControllerCompleter.complete(controller);
            }
            Future.delayed(const Duration(milliseconds: 100), () {
              controller.animateCamera(
                CameraUpdate.newLatLngBounds(bounds, 60.0),
              );
            });
          },
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, WidgetRef ref, Race race) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final actionState = ref.watch(raceNotifierProvider);

    return currentUserAsync.when(
      data: (currentUser) {
        if (currentUser == null) {
          return SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.login, size: 20),
              label: const Text("Faça login para interagir"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.greyDark,
                foregroundColor: AppColors.white.withOpacity(0.8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {},
            ),
          );
        }

        final currentUserId = currentUser.uid;
        final isParticipant = race.participants.any((p) => p.uid == currentUserId);
        final isPending = race.pendingParticipants.any((p) => p.uid == currentUserId);
        final isOwner = race.ownerId == currentUserId;

        String buttonText = "";
        Color buttonColor = AppColors.greyDark;
        IconData buttonIcon = Icons.help_outline;
        VoidCallback? onPressedAction;
        bool canInteract = false;

        if (isOwner) {
          buttonText = "Você é o Dono";
          buttonIcon = Icons.shield_outlined;
          buttonColor = AppColors.underBackground;
        } else if (isParticipant) {
          buttonText = "Sair da Corrida";
          buttonColor = Colors.redAccent.shade700;
          buttonIcon = Icons.directions_run;
          onPressedAction = () async {
            bool? confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Confirmar Saída'),
                content: Text('Tem certeza que deseja sair da corrida "${race.title}"?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      'Sair',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              final success = await ref
                  .read(raceNotifierProvider.notifier)
                  .leaveRace(race.id, currentUserId);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Você saiu da corrida."),
                    backgroundColor: Colors.blueGrey,
                  ),
                );
                ref.invalidate(raceDetailsProvider(race.id));
                ref.invalidate(nearbyRacesProvider);
              }
            }
          };
          canInteract = true;
        } else if (isPending) {
          buttonText = "Solicitação Pendente";
          buttonIcon = Icons.hourglass_top_outlined;
        } else {
          buttonText = race.isPrivate ? "Solicitar Participação" : "Participar da Corrida";
          buttonColor = AppColors.primaryRed;
          buttonIcon = race.isPrivate ? Icons.vpn_key_outlined : Icons.add_circle_outline;
          onPressedAction = () {
            if (race.isPrivate) {
              ref
                  .read(raceNotifierProvider.notifier)
                  .addParticipationRequest(race.id, currentUserId)
                  .then((success) {
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Solicitação enviada!'),
                      backgroundColor: Colors.orangeAccent,
                    ),
                  );
                  ref.invalidate(raceDetailsProvider(race.id));
                }
              });
            } else {
              ref
                  .read(raceNotifierProvider.notifier)
                  .addParticipant(race.id, currentUserId)
                  .then((success) {
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Você agora participa de "${race.title}"!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  ref.invalidate(raceDetailsProvider(race.id));
                  ref.invalidate(nearbyRacesProvider);
                }
              });
            }
          };
          canInteract = true;
        }

        final isLoading = actionState.isLoading;

        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: isLoading && canInteract
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(buttonIcon, size: 20),
            label: Text(
              buttonText,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              disabledBackgroundColor: buttonColor.withOpacity(0.5),
              disabledForegroundColor: Colors.white.withOpacity(0.7),
            ),
            onPressed: isLoading || !canInteract || onPressedAction == null
                ? null
                : onPressedAction,
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryRed),
      ),
      error: (err, stack) => Center(
        child: Text(
          "Erro ao carregar dados do usuário: $err",
          style: const TextStyle(color: Colors.redAccent),
        ),
      ),
    );
  }

  Widget _buildParticipantItem(
    BuildContext context,
    WidgetRef ref,
    String userId,
    String ownerId,
  ) {
    final userAsync = ref.watch(userProvider(userId));

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return ListTile(
            dense: true,
            leading: const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.greyDark,
              child: Icon(Icons.question_mark, size: 18),
            ),
            title: const Text(
              'Usuário não encontrado',
              style: TextStyle(
                color: AppColors.greyLight,
                fontStyle: FontStyle.italic,
                fontSize: 14,
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.greyDark,
                backgroundImage: user.profileImageUrl!.isNotEmpty
                    ? CachedNetworkImageProvider(user.profileImageUrl ?? '')
                    : null,
                child: user.profileImageUrl!.isEmpty
                    ? const Icon(
                        Icons.person,
                        size: 18,
                        color: AppColors.greyLight,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  user.name.isNotEmpty ? user.name : 'Usuário Anônimo',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (user.uid == ownerId)
                Tooltip(
                  message: "Organizador",
                  child: Icon(
                    Icons.shield_outlined,
                    size: 18,
                    color: AppColors.primaryRed.withOpacity(0.8),
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9.0),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.greyDark,
            ),
            const SizedBox(width: 12),
            Container(
              height: 10,
              width: 100,
              color: AppColors.greyDark.withOpacity(0.5),
            ),
          ],
        ),
      ),
      error: (err, stack) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5.0),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.redAccent,
                child: Icon(Icons.error_outline, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Text(
                'Erro ao carregar',
                style: TextStyle(color: Colors.redAccent, fontSize: 14),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final raceAsync = ref.watch(raceDetailsProvider(raceId));

    ref.listen<RaceActionState>(raceNotifierProvider, (_, next) {
      if (next.error != null && next.error!.isNotEmpty) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
        ref.read(raceNotifierProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          raceAsync.maybeWhen(
            data: (race) => race?.title ?? 'Detalhes da Corrida',
            orElse: () => 'Carregando...',
          ),
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: raceAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primaryRed),
          ),
          error: (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 50,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Erro ao carregar corrida:\n$error",
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text("Tentar Novamente"),
                    onPressed: () => ref.invalidate(raceDetailsProvider(raceId)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: AppColors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          data: (race) {
            if (race == null) {
              return const Center(
                child: Text(
                  "Corrida não encontrada.",
                  style: TextStyle(color: AppColors.greyLight, fontSize: 16),
                ),
              );
            }

            final ownerNameWidget = Consumer(
              builder: (context, ownerRef, child) {
                final ownerAsync = ownerRef.watch(userProvider(race.ownerId));
                return ownerAsync.when(
                  data: (ownerUser) => Text(
                    ownerUser?.name ?? 'Organizador não encontrado',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  loading: () => const Text(
                    'Carregando...',
                    style: TextStyle(
                      color: AppColors.greyLight,
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  error: (e, s) => const Text(
                    'Erro',
                    style: TextStyle(color: Colors.redAccent, fontSize: 15),
                  ),
                );
              },
            );

            double? distanceToRaceStartKm;
            final currentLocationAsync = ref.watch(currentLocationProvider);
            if (currentLocationAsync is AsyncData<Position?> &&
                currentLocationAsync.value != null) {
              distanceToRaceStartKm = Geolocator.distanceBetween(
                    currentLocationAsync.value!.latitude,
                    currentLocationAsync.value!.longitude,
                    race.startLatitude,
                    race.startLongitude,
                  ) /
                  1000.0;
            }

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 80.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (race.imageUrl != null && race.imageUrl!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12.0),
                        child: Hero(
                          tag: 'race_image_${race.id}',
                          child: CachedNetworkImage(
                            imageUrl: race.imageUrl!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              height: 200,
                              color: AppColors.underBackground,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primaryRed,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              height: 200,
                              color: AppColors.underBackground,
                              child: const Center(
                                child: Icon(
                                  Icons.running_with_errors_rounded,
                                  color: AppColors.greyLight,
                                  size: 50,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Text(
                    race.title,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          context,
                          Icons.calendar_today_outlined,
                          "Data e Hora",
                          Text(
                            race.formattedDate,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const Divider(
                          color: AppColors.greyDark,
                          height: 16,
                          thickness: 0.5,
                        ),
                        _buildInfoRow(
                          context,
                          Icons.straighten_outlined,
                          "Distância Total",
                          Text(
                            race.formattedDistance,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const Divider(
                          color: AppColors.greyDark,
                          height: 16,
                          thickness: 0.5,
                        ),
                        _buildInfoRow(
                          context,
                          Icons.flag_outlined,
                          "Início",
                          Text(
                            race.startAddress.isNotEmpty
                                ? race.startAddress
                                : "Endereço não disponível",
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const Divider(
                          color: AppColors.greyDark,
                          height: 16,
                          thickness: 0.5,
                        ),
                        _buildInfoRow(
                          context,
                          Icons.location_on_outlined,
                          "Fim",
                          Text(
                            race.endAddress.isNotEmpty
                                ? race.endAddress
                                : "Endereço não disponível",
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const Divider(
                          color: AppColors.greyDark,
                          height: 16,
                          thickness: 0.5,
                        ),
                        _buildInfoRow(
                          context,
                          Icons.person_outline,
                          "Organizador",
                          ownerNameWidget,
                        ),
                        const Divider(
                          color: AppColors.greyDark,
                          height: 16,
                          thickness: 0.5,
                        ),
                        if (distanceToRaceStartKm != null) ...[
                          _buildInfoRow(
                            context,
                            Icons.social_distance_outlined,
                            "Distância de Você",
                            Text(
                              "${distanceToRaceStartKm.toStringAsFixed(1)} km",
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const Divider(
                            color: AppColors.greyDark,
                            height: 16,
                            thickness: 0.5,
                          ),
                        ],
                        _buildInfoRow(
                          context,
                          race.isPrivate ? Icons.lock_outline : Icons.lock_open_outlined,
                          "Visibilidade",
                          Text(
                            race.isPrivate ? 'Privada' : 'Pública',
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Mapa da Rota:",
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildMapView(race),
                  const SizedBox(height: 24),
                  Text(
                    "Participantes (${race.participants.length}):",
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.underBackground.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: race.participants.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              "Nenhum participante confirmado ainda.",
                              style: TextStyle(color: AppColors.greyLight),
                            ),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: race.participants
                                .map(
                                  (participant) => _buildParticipantItem(
                                    context,
                                    ref,
                                    participant.uid,
                                    race.ownerId,
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 30),
                  _buildActionButton(context, ref, race),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}