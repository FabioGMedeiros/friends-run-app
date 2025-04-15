import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:friends_run/core/providers/auth_provider.dart'; // Assumindo que userProvider está aqui
import 'package:friends_run/core/utils/colors.dart';
import 'package:friends_run/models/user/app_user.dart'; // Suas cores

class RaceParticipantsList extends ConsumerWidget {
  final List<AppUser> participants;
  final String ownerId;

  const RaceParticipantsList({
    required this.participants,
    required this.ownerId,
    super.key,
  });

  // O _buildParticipantItem agora mora aqui (ou pode ser um widget separado)
  Widget _buildParticipantItem(
    BuildContext context,
    WidgetRef ref,
    String userId,
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
                backgroundImage:
                    user.profileImageUrl != null &&
                            user.profileImageUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(user.profileImageUrl!)
                        : null,
                child:
                    user.profileImageUrl == null ||
                            user.profileImageUrl!.isEmpty
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
      loading:
          () => Padding(
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
      error:
          (err, stack) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5.0),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.redAccent,
                  child: Icon(
                    Icons.error_outline,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Erro ao carregar',
                  style: TextStyle(color: Colors.redAccent, fontSize: 14),
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Participantes (${participants.length}):",
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.underBackground.withOpacity(0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child:
              participants.isEmpty
                  ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      "Nenhum participante confirmado ainda.",
                      style: TextStyle(color: AppColors.greyLight),
                    ),
                  )
                  : Column(
                    mainAxisSize: MainAxisSize.min,
                    // Usa o ref do build para chamar _buildParticipantItem
                    children:
                        participants
                            .map(
                              (p) => _buildParticipantItem(context, ref, p.uid),
                            )
                            .toList(),
                  ),
        ),
      ],
    );
  }
}
