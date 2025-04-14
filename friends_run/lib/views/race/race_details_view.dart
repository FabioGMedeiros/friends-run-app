import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart'; // Para distância do usuário

// Models e Providers
import 'package:friends_run/models/race/race_model.dart';
import 'package:friends_run/core/providers/race_provider.dart';
import 'package:friends_run/core/providers/auth_provider.dart';
import 'package:friends_run/core/providers/location_provider.dart'; // Para distância do usuário

// Utils e outros Widgets
import 'package:friends_run/core/utils/colors.dart';
// Importe widgets reutilizáveis, se tiver (ex: InfoRow)

// Provider para buscar detalhes da corrida (JÁ DEFINIDO em race_provider.dart)
// final raceDetailsProvider = FutureProvider.family.autoDispose<Race?, String>(...);

class RaceDetailsView extends ConsumerWidget {
  final String raceId;

  const RaceDetailsView({required this.raceId, super.key});

  // Helper para construir linha de informação (similar ao do RaceCard)
  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    // Adiciona um pouco mais de padding e formatação diferente
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
                Text(
                  value,
                  style: const TextStyle(color: AppColors.white, fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper para construir o mapa estático ou interativo simples
  Widget _buildMapView(Race race) {
    final LatLng startPoint = LatLng(race.startLatitude, race.startLongitude);
    final LatLng endPoint = LatLng(race.endLatitude, race.endLongitude);
    final Set<Marker> markers = {
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

    // Calcula limites para centralizar o mapa
    LatLngBounds bounds = LatLngBounds(
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

    // Correção para ponto único (início e fim iguais)
    if (startPoint == endPoint) {
      // Cria um limite pequeno ao redor do ponto único
      bounds = LatLngBounds(
        southwest: LatLng(
          startPoint.latitude - 0.001,
          startPoint.longitude - 0.001,
        ),
        northeast: LatLng(
          startPoint.latitude + 0.001,
          startPoint.longitude + 0.001,
        ),
      );
    }

    return SizedBox(
      height: 250,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GoogleMap(
          markers: markers,
          initialCameraPosition: CameraPosition(
            target: bounds.northeast,
            zoom: 14,
          ), // Posição inicial centralizada
          // Desabilita controles e gestos para um mapa mais "estático"
          // myLocationEnabled: false,
          // myLocationButtonEnabled: false,
          zoomControlsEnabled: true, // Permite zoom
          zoomGesturesEnabled: true,
          scrollGesturesEnabled: true,
          tiltGesturesEnabled: false,
          rotateGesturesEnabled: true,
          mapToolbarEnabled: false, // Remove botões do Google Maps
          onMapCreated: (controller) {
            // Anima a câmera para ajustar aos limites após a criação
            Future.delayed(const Duration(milliseconds: 50), () {
              controller.animateCamera(
                CameraUpdate.newLatLngBounds(bounds, 50.0),
              ); // Padding 50
            });
          },
        ),
      ),
    );
  }

  // Helper para o botão de Ação (Participar/Solicitar/Sair)
  Widget _buildActionButton(BuildContext context, WidgetRef ref, Race race) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final actionState = ref.watch(raceNotifierProvider);

    return currentUserAsync.when(
      data: (currentUser) {
        if (currentUser == null) {
          return ElevatedButton.icon(
            icon: const Icon(Icons.login),
            label: const Text("Faça login para interagir"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.greyDark,
            ),
            onPressed: () {
              /* TODO: Navegar para login */
            },
          );
        }

        final currentUserId = currentUser.uid;
        final bool isParticipant = race.participants.any(
          (p) => p.uid == currentUserId,
        );
        final bool isPending = race.pendingParticipants.any(
          (p) => p.uid == currentUserId,
        );
        final bool isOwner = race.ownerId == currentUserId;

        String buttonText = "";
        Color buttonColor = AppColors.greyDark;
        IconData buttonIcon = Icons.help_outline; // Ícone padrão
        VoidCallback? onPressedAction;
        bool canInteract = false; // Flag se o botão deve ser ativo

        if (isOwner) {
          // TODO: Adicionar opções para o dono (Editar/Excluir/Gerenciar Pendentes)
          buttonText = "Você é o Dono";
          buttonIcon = Icons.shield_outlined;
          // onPressedAction = () { /* Abrir menu de gerenciamento? */ };
        } else if (isParticipant) {
          buttonText = "Sair da Corrida";
          buttonColor = Colors.redAccent.shade700; // Cor diferente para sair
          buttonIcon = Icons.logout;
          onPressedAction = () async {
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
              // Invalida para atualizar estado
              ref.invalidate(nearbyRacesProvider); // Atualiza home
              ref.invalidate(
                raceDetailsProvider(race.id),
              ); // Atualiza esta tela
            }
          };
          canInteract = true; // Pode sair
        } else if (isPending) {
          buttonText = "Solicitação Pendente";
          buttonIcon = Icons.hourglass_top_outlined;
          // Opcional: Permitir cancelar solicitação?
          // onPressedAction = () async { ... lógica para cancelar ... }
        } else {
          // Não é dono, não participa, não está pendente
          buttonText =
              race.isPrivate
                  ? "Solicitar Participação"
                  : "Participar da Corrida";
          buttonColor = AppColors.primaryRed;
          buttonIcon =
              race.isPrivate ? Icons.vpn_key_outlined : Icons.directions_run;
          onPressedAction = () {
            if (race.isPrivate) {
              // Lógica para solicitar (sem diálogo aqui, chama direto)
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
                      ref.invalidate(
                        raceDetailsProvider(race.id),
                      ); // Atualiza estado do botão
                    }
                  });
            } else {
              // Lógica para participar (sem diálogo aqui, chama direto)
              ref
                  .read(raceNotifierProvider.notifier)
                  .addParticipant(race.id, currentUserId)
                  .then((success) {
                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Você agora participa de "${race.title}"!',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                      ref.invalidate(nearbyRacesProvider);
                      ref.invalidate(raceDetailsProvider(race.id));
                    }
                  });
            }
          };
          canInteract = true; // Pode participar/solicitar
        }

        // Estado de carregamento global do Notifier
        final isLoading = actionState.isLoading;

        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon:
                isLoading && canInteract
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
              backgroundColor: canInteract ? buttonColor : AppColors.greyDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ).copyWith(
              // Garante a cor correta no estado desabilitado
              backgroundColor: MaterialStateProperty.resolveWith<Color?>((
                Set<MaterialState> states,
              ) {
                if (states.contains(MaterialState.disabled)) {
                  // Cor diferente para "Dono" vs "Pendente/Participando"
                  if (isOwner)
                    return AppColors.underBackground; // Mais sutil para dono
                  return AppColors.greyDark.withAlpha(
                    200,
                  ); // Cinza para outros desabilitados
                }
                return canInteract
                    ? buttonColor
                    : AppColors.greyDark; // Cor ativa ou cinza padrão
              }),
              foregroundColor: MaterialStateProperty.resolveWith<Color?>((
                Set<MaterialState> states,
              ) {
                if (states.contains(MaterialState.disabled)) {
                  if (isOwner)
                    return AppColors.greyLight; // Texto mais claro para dono
                  return AppColors.white.withAlpha(
                    150,
                  ); // Texto apagado para outros
                }
                return AppColors.white; // Texto normal
              }),
            ),
            onPressed:
                isLoading || !canInteract || onPressedAction == null
                    ? null
                    : onPressedAction,
          ),
        );
      },
      loading:
          () => const Center(
            child: CircularProgressIndicator(color: AppColors.primaryRed),
          ),
      error:
          (err, stack) => Text(
            "Erro ao carregar usuário: $err",
            style: const TextStyle(color: Colors.redAccent),
          ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ouve o provider de detalhes da corrida específica
    final raceAsync = ref.watch(raceDetailsProvider(raceId));

    // Listener para erros de AÇÃO (join, leave, etc.)
    ref.listen<RaceActionState>(raceNotifierProvider, (_, next) {
      if (next.error != null && next.error!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.redAccent,
          ),
        );
        ref.read(raceNotifierProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        // Mostra título dinâmico baseado no estado da corrida
        title: Text(
          raceAsync.maybeWhen(
            data: (race) => race?.title ?? 'Detalhes da Corrida',
            orElse: () => 'Carregando Corrida...',
          ),
          style: const TextStyle(color: AppColors.white),
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
        // TODO: Adicionar ações para o dono (editar/excluir)?
      ),
      body: raceAsync.when(
        loading:
            () => const Center(
              child: CircularProgressIndicator(color: AppColors.primaryRed),
            ),
        error:
            (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Erro ao carregar detalhes da corrida:\n$error",
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ),
        data: (race) {
          // Se a corrida não for encontrada no Firestore
          if (race == null) {
            return const Center(
              child: Text(
                "Corrida não encontrada.",
                style: TextStyle(color: AppColors.greyLight),
              ),
            );
          }

          // Calcula distância do usuário até o início (se localização disponível)
          final currentLocationAsync = ref.watch(currentLocationProvider);
          double? distanceToRaceStartKm;
          if (currentLocationAsync is AsyncData<Position?> &&
              currentLocationAsync.value != null) {
            distanceToRaceStartKm =
                Geolocator.distanceBetween(
                  currentLocationAsync.value!.latitude,
                  currentLocationAsync.value!.longitude,
                  race.startLatitude,
                  race.startLongitude,
                ) /
                1000.0;
          }

          // Conteúdo principal da tela
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Imagem da Corrida ---
                if (race.imageUrl != null && race.imageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12.0),
                    child: Hero(
                      // Mantém Hero se usar na lista
                      tag: 'race_image_${race.id}',
                      child: CachedNetworkImage(
                        imageUrl: race.imageUrl!,
                        height: 200, // Altura ligeiramente maior
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder:
                            (context, url) => Container(
                              height: 200,
                              color: AppColors.underBackground,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primaryRed,
                                ),
                              ),
                            ),
                        errorWidget:
                            (context, url, error) => Container(
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
                if (race.imageUrl != null && race.imageUrl!.isNotEmpty)
                  const SizedBox(height: 20), // Espaço após imagem
                // --- Título Grande ---
                Text(
                  race.title,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // --- Bloco de Informações ---
                _buildInfoRow(
                  context,
                  Icons.calendar_today_outlined,
                  "Data e Hora",
                  race.formattedDate,
                ),
                _buildInfoRow(
                  context,
                  Icons.straighten_outlined,
                  "Distância Total",
                  race.formattedDistance,
                ),
                _buildInfoRow(
                  context,
                  Icons.flag_outlined,
                  "Início",
                  race.startAddress,
                ),
                _buildInfoRow(
                  context,
                  Icons.location_on_outlined,
                  "Fim",
                  race.endAddress,
                ),
                _buildInfoRow(
                  context,
                  Icons.person_outline,
                  "Organizador",
                  race.owner.uid,
                ), // Mostra ID, precisa buscar nome
                _buildInfoRow(
                  context,
                  Icons.people_outline,
                  "Participantes",
                  "${race.participants.length} confirmado(s)",
                ),
                if (distanceToRaceStartKm != null)
                  _buildInfoRow(
                    context,
                    Icons.social_distance_outlined,
                    "Distância de Você",
                    "${distanceToRaceStartKm.toStringAsFixed(1)} km",
                  ),
                _buildInfoRow(
                  context,
                  race.isPrivate
                      ? Icons.lock_outline
                      : Icons.lock_open_outlined,
                  "Visibilidade",
                  race.isPrivate
                      ? 'Privada (requer solicitação)'
                      : 'Pública (entrada livre)',
                ),
                const SizedBox(height: 20),

                // --- Mapa ---
                const Text(
                  "Mapa da Rota:",
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _buildMapView(race), // Usa o helper do mapa
                const SizedBox(height: 24),

                // --- Lista de Participantes (Placeholder) ---
                const Text(
                  "Participantes:",
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                // TODO: Implementar busca e exibição dos detalhes dos participantes
                // Necessário criar o 'participantsDetailsProvider' e usar .when() aqui
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.underBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    race.participants.isEmpty
                        ? "Nenhum participante confirmado ainda."
                        : "${race.participants.length} participante(s) confirmado(s).\n(Exibição detalhada a implementar)", // Mostra contagem por enquanto
                    style: const TextStyle(color: AppColors.greyLight),
                  ),
                ),
                const SizedBox(height: 30),

                // --- Botão de Ação ---
                _buildActionButton(context, ref, race), // Usa o helper do botão
              ],
            ),
          );
        },
      ),
    );
  }
}
