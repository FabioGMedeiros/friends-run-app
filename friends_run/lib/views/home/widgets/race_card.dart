import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:friends_run/core/providers/auth_provider.dart';
import 'package:friends_run/core/providers/location_provider.dart'; // Para possível cálculo de distância até a corrida
import 'package:friends_run/core/providers/race_provider.dart';
import 'package:friends_run/core/utils/colors.dart';
import 'package:friends_run/models/race/race_model.dart';
import 'package:geolocator/geolocator.dart';

class RaceCard extends ConsumerWidget {
  final Race race;
  const RaceCard({required this.race, super.key});

  // Método auxiliar movido para dentro do Card
  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryRed),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.white.withAlpha(230), // (0.9 * 255).round()
                fontSize: 15,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Diálogo de confirmação movido para dentro do Card
  void _showJoinConfirmationDialog(
      BuildContext context, WidgetRef ref, String userId) {
    if (race.isPrivate) {
      // --- Lógica para Solicitar Participação (Corrida Privada) ---
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.white,
          title: const Text('Solicitar Participação', style: TextStyle(color: AppColors.black)),
          content: Text('Corrida privada. Deseja solicitar para participar de "${race.title}"?', style: const TextStyle(color: AppColors.black)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.primaryRed)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed, foregroundColor: AppColors.white),
              onPressed: () async {
                Navigator.pop(context);
                final success = await ref.read(raceNotifierProvider.notifier).addParticipationRequest(race.id, userId);
                if (context.mounted && success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Solicitação enviada!'), backgroundColor: Colors.orangeAccent),
                  );
                }
                // Erro é tratado pelo listener global na HomeView
              },
              child: const Text('Solicitar'),
            ),
          ],
        ),
      );
    } else {
      // --- Lógica para Entrar Diretamente (Corrida Pública) ---
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.white,
          title: const Text('Confirmar participação', style: TextStyle(color: AppColors.black)),
          content: Text('Deseja participar da corrida "${race.title}"?', style: const TextStyle(color: AppColors.black)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.primaryRed)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed, foregroundColor: AppColors.white),
              onPressed: () async {
                Navigator.pop(context);
                final success = await ref.read(raceNotifierProvider.notifier).addParticipant(race.id, userId);
                if (context.mounted && success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Você está participando de "${race.title}"'), backgroundColor: Colors.green),
                  );
                  // Invalida para atualizar lista de corridas onde participa (se houver)
                  // ref.invalidate(participantRacesStreamProvider(userId)); // Exemplo
                  // Também pode invalidar nearbyRacesProvider se quiser forçar refresh da home
                  ref.invalidate(nearbyRacesProvider);
                }
                // Erro é tratado pelo listener global na HomeView
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final currentUserId = currentUserAsync.asData?.value?.uid;
    final actionState = ref.watch(raceNotifierProvider); // Ouve estado de ação global

    // Lógica do botão (igual à anterior)
    // ATENÇÃO: Verifique se a forma como você obtém 'participants' e 'pendingParticipants'
    // (via Race.fromJson) está correta (lista de IDs ou lista de AppUser parciais).
    // A lógica .any() funciona se forem objetos AppUser (mesmo parciais com só ID).
    final bool isParticipant = currentUserId != null && race.participants.any((p) => p.uid == currentUserId);
    final bool isPending = currentUserId != null && race.pendingParticipants.any((p) => p.uid == currentUserId);
    bool canInteract = currentUserId != null && !isParticipant && !isPending;
    String buttonText = race.isPrivate ? "Solicitar" : "Participar";
    VoidCallback? onPressedAction = currentUserId != null
        ? () => _showJoinConfirmationDialog(context, ref, currentUserId)
        : null;

    if (isParticipant) buttonText = "Já Participando";
    if (isPending) buttonText = "Solicitado";
    if (isParticipant || isPending) {
       onPressedAction = null;
       canInteract = false;
    }
    if (currentUserId == null) {
       buttonText = "Faça login";
       canInteract = false;
       onPressedAction = null;
    }

    // Opcional: Calcular distância do usuário até o início da corrida
    final currentLocationAsync = ref.watch(currentLocationProvider);
    double? distanceToRaceStartKm;
    if (currentLocationAsync is AsyncData<Position?> && currentLocationAsync.value != null) {
       distanceToRaceStartKm = Geolocator.distanceBetween(
          currentLocationAsync.value!.latitude,
          currentLocationAsync.value!.longitude,
          race.startLatitude,
          race.startLongitude,
       ) / 1000.0;
    }


    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // Corrigido: use withAlpha para opacidade
      color: AppColors.white.withAlpha(26), // (0.1 * 255).round()
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias, // Para o InkWell respeitar as bordas
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // TODO: Implementar navegação para RaceDetailsView
          print("Clicou no card da corrida: ${race.id}");
          // Navigator.push(context, MaterialPageRoute(builder: (_) => RaceDetailsView(raceId: race.id)));
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Imagem (se houver) ---
            if (race.imageUrl != null)
              CachedNetworkImage(
                 imageUrl: race.imageUrl!,
                 height: 180,
                 width: double.infinity,
                 fit: BoxFit.cover,
                 placeholder: (context, url) => Container(
                      height: 180,
                      color: AppColors.underBackground, // Cor de fundo enquanto carrega
                      child: const Center(child: CircularProgressIndicator(color: AppColors.primaryRed)),
                 ),
                 errorWidget: (context, url, error) => Container(
                    height: 180,
                    color: AppColors.underBackground, // Cor de fundo no erro
                    child: const Center(child: Icon(Icons.image_not_supported, color: AppColors.greyLight, size: 50)),
                 ),
               ),
             // --- Conteúdo do Card ---
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Título e Distância da Corrida ---
                  Row( /* ... (igual) ... */),
                  const SizedBox(height: 12),
                  // --- Linhas de Informação ---
                  _buildInfoRow(Icons.calendar_today, race.formattedDate),
                  _buildInfoRow(Icons.location_on, '${race.startAddress} → ${race.endAddress}'),
                  // Opcional: Mostra distância DO USUÁRIO até o início
                  if(distanceToRaceStartKm != null)
                     _buildInfoRow(Icons.social_distance, '${distanceToRaceStartKm.toStringAsFixed(1)} km de distância de você'),
                   _buildInfoRow(Icons.people, '${race.participants.length} participante(s)'),
                  const SizedBox(height: 16),
                  // --- Botão de Ação ---
                  SizedBox(
                     width: double.infinity,
                     child: ElevatedButton(
                       style: ElevatedButton.styleFrom(
                         backgroundColor: canInteract ? AppColors.primaryRed : AppColors.greyDark, // Cor diferente se desabilitado
                         foregroundColor: AppColors.white,
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                         padding: const EdgeInsets.symmetric(vertical: 12),
                       ),
                       onPressed: actionState.isLoading || !canInteract ? null : onPressedAction, // Desabilita no loading GLOBAL ou se não pode interagir
                       child: actionState.isLoading && canInteract // Mostra loading apenas se PUDER interagir e estiver carregando
                           ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                           : Text(buttonText),
                     ),
                   ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}