import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Models e Providers
import 'package:friends_run/models/race/race_model.dart';
import 'package:friends_run/models/group/race_group.dart';
import 'package:friends_run/models/user/app_user.dart'; // Adicionado do novo código
import 'package:friends_run/core/providers/race_provider.dart';
import 'package:friends_run/core/providers/auth_provider.dart';
import 'package:friends_run/core/providers/group_provider.dart';
import 'package:friends_run/core/services/group_service.dart'; // Adicionado do novo código
import 'package:friends_run/core/providers/location_provider.dart'; // Adicionado do novo código (embora não usado diretamente aqui, pode ser dependência)

// Utils e Widgets
import 'package:friends_run/core/utils/colors.dart';
import 'package:friends_run/views/home/widgets/race_card.dart';
// import 'package:Maps_flutter/Maps_flutter.dart'; // Removido - Mapa não é mais exibido aqui

// Provider para buscar as corridas de um grupo específico (igual)
final groupRacesProvider = StreamProvider.autoDispose
    .family<List<Race>, String>((ref, groupId) {
      if (groupId.isEmpty) return Stream.value([]);
      final raceService = ref.watch(raceServiceProvider);
      // Garanta que getRacesByGroup existe no RaceService
      return raceService.getRacesByGroup(groupId);
    });

class GroupDetailsView extends ConsumerWidget {
  final String groupId;
  const GroupDetailsView({required this.groupId, super.key});

  // --- Helpers de Construção da UI ---

  // Helper _buildInfoRow (Mantido do código antigo)
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

  // Helper _buildMapView (Removido - Conforme código novo)

  // Helper _buildMemberItem (Mantido do código antigo - mais completo)
  Widget _buildMemberItem(
    BuildContext context,
    WidgetRef ref,
    String userId,
    String adminId,
  ) {
    final userAsync = ref.watch(userProvider(userId));
    return userAsync.when(
      data: (user) {
        if (user == null) return const ListTile( dense: true, leading: CircleAvatar(radius: 18, backgroundColor: AppColors.greyDark), title: Text('Usuário não encontrado', style: TextStyle(color: AppColors.greyLight, fontStyle: FontStyle.italic, fontSize: 14)) );

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.greyDark,
                backgroundImage:
                    (user.profileImageUrl != null &&
                            user.profileImageUrl!.isNotEmpty)
                        ? CachedNetworkImageProvider(user.profileImageUrl!)
                        : null,
                child:
                    (user.profileImageUrl == null ||
                            user.profileImageUrl!.isEmpty)
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
              if (user.uid == adminId)
                Tooltip(
                  message: "Admin",
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
          (e, s) => Padding(
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
                  'Erro',
                  style: TextStyle(color: Colors.redAccent, fontSize: 14),
                ),
              ],
            ),
          ),
    );
  }

  // --- Helper _buildPendingItem (Adicionado do código novo) ---
   Widget _buildPendingItem( BuildContext context, WidgetRef ref, String pendingUserId, RaceGroup group) {
     // Observa o estado de ação global para desabilitar botões durante QUALQUER ação
     final bool isLoadingAction = ref.watch(raceNotifierProvider).isLoading; // Ou usar um notifier de grupo dedicado
     // Observa os dados do usuário pendente
     final userAsync = ref.watch(userProvider(pendingUserId));

     return userAsync.when(
       data: (user) {
         if (user == null) {
           return const ListTile(
              dense: true,
              leading: CircleAvatar(radius: 18, backgroundColor: AppColors.greyDark),
              title: Text('Usuário pendente não encontrado', style: TextStyle(color: AppColors.greyLight, fontStyle: FontStyle.italic, fontSize: 14))
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
                      (user.profileImageUrl != null &&
                              user.profileImageUrl!.isNotEmpty)
                          ? CachedNetworkImageProvider(user.profileImageUrl!)
                          : null,
                  child:
                      (user.profileImageUrl == null ||
                              user.profileImageUrl!.isEmpty)
                          ? const Icon(
                            Icons.person_outline, // Ícone diferente para pendente?
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
               // Botão Aceitar
               SizedBox( width: 36, height: 36, child: IconButton(
                   icon: const Icon(Icons.check_circle_outline, color: Colors.greenAccent), iconSize: 22, tooltip: "Aprovar", padding: EdgeInsets.zero,
                   onPressed: isLoadingAction ? null : () async {
                      try {
                          // Usa o groupServiceProvider importado
                          await ref.read(groupServiceProvider).approveMember(group.id, pendingUserId);
                          if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${user.name} aprovado(a)!'), backgroundColor: Colors.green));
                          ref.invalidate(groupDetailsProvider(group.id)); // Atualiza listas
                      } catch (e) {
                          if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao aprovar: ${e.toString().replaceFirst("Exception: ", "")}"), backgroundColor: Colors.redAccent));
                      }
                   },
                )),
               const SizedBox(width: 4),
               // Botão Rejeitar
               SizedBox( width: 36, height: 36, child: IconButton(
                   icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent), iconSize: 22, tooltip: "Rejeitar", padding: EdgeInsets.zero,
                   onPressed: isLoadingAction ? null : () async {
                       try {
                            // Usa o groupServiceProvider importado
                           await ref.read(groupServiceProvider).removeOrRejectMember(group.id, pendingUserId, isPending: true);
                           if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Solicitação de ${user.name} rejeitada.'), backgroundColor: Colors.orange));
                           ref.invalidate(groupDetailsProvider(group.id)); // Atualiza listas
                       } catch (e) {
                          if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao rejeitar: ${e.toString().replaceFirst("Exception: ", "")}"), backgroundColor: Colors.redAccent));
                       }
                   },
                )),
             ],
           ),
         );
       },
       loading: () => Padding(
          padding: const EdgeInsets.symmetric(vertical: 9.0),
          child: Row(
             children: [
               const CircleAvatar( radius: 18, backgroundColor: AppColors.greyDark),
               const SizedBox(width: 12),
               Container( height: 10, width: 100, color: AppColors.greyDark.withOpacity(0.5)),
             ],
           ),
       ),
       error: (err, stack) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5.0),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.redAccent,
                  child: Icon( Icons.error_outline, size: 18, color: Colors.white ),
                ),
                const SizedBox(width: 12),
                const Text( 'Erro', style: TextStyle(color: Colors.redAccent, fontSize: 14), ),
              ],
            ),
        ),
     );
   }


  // Helper para o botão de Ação do Grupo (Versão do código novo)
  Widget _buildGroupActionButton(BuildContext context, WidgetRef ref, RaceGroup group) {
      final currentUserAsync = ref.watch(currentUserProvider);
      // Usando loading GERAL. Idealmente teria um state específico para ações de grupo.
      final bool isLoadingAction = ref.watch(raceNotifierProvider).isLoading; // Pode precisar mudar se tiver groupActionNotifier

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
                    onPressed: () {
                      // TODO: Navegar para a tela de Login
                       ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text("TODO: Navegar para Login")),
                       );
                    },
                  ),
                );
             }

             final String currentUserId = currentUser.uid;
             final bool isAdmin = group.adminId == currentUserId;
             final bool isMember = group.memberIds.contains(currentUserId);
             final bool isPending = group.pendingMemberIds.contains(currentUserId);

             String buttonText = "";
             Color buttonColor = AppColors.greyDark;
             IconData? buttonIcon;
             VoidCallback? onPressed;
             bool canInteract = false; // Flag para saber se o botão deve ser interativo

             // Lógica para definir texto, cor, ícone e ação do botão
             if (isAdmin) {
                 buttonText = "Gerenciar"; // Alterado pelo novo código
                 buttonIcon = Icons.settings; // Alterado pelo novo código
                 buttonColor = AppColors.primaryRed; // Alterado pelo novo código
                 onPressed = () {
                     // TODO: Navegar para tela de gerenciamento de membros/grupo?
                     ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text("Tela de gerenciamento (TODO)")),
                     );
                 };
                 canInteract = true; // Admin pode ter ações
             } else if (isMember) {
                 buttonText = "Sair do Grupo";
                 buttonColor = Colors.redAccent.shade700;
                 buttonIcon = Icons.exit_to_app;
                 onPressed = () async {
                   // Confirmação antes de sair (lógica do código antigo)
                   bool? confirm = await showDialog<bool>(
                     context: context,
                     builder: (ctx) => AlertDialog(
                       title: const Text("Confirmar Saída"),
                       content: Text("Tem certeza que deseja sair do grupo \"${group.name}\"?"),
                       actions: [
                         TextButton( onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar") ),
                         TextButton(
                           onPressed: () => Navigator.pop(ctx, true),
                           child: const Text( "Sair", style: TextStyle(color: Colors.red)),
                         ),
                       ],
                     ),
                   );
                   if (confirm == true && context.mounted) {
                     try {
                       // Chama o serviço diretamente (ou via notifier se criado)
                       await ref.read(groupServiceProvider).leaveGroup(group.id, currentUserId);
                       ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar( content: Text("Você saiu do grupo."), backgroundColor: Colors.blueGrey ),
                       );
                       ref.invalidate(userGroupsProvider); // Atualiza a lista de grupos do usuário
                       ref.invalidate(groupDetailsProvider(group.id)); // Atualiza esta tela
                       // Pode ser necessário voltar para a lista de grupos:
                       // if(context.mounted) Navigator.pop(context);
                     } catch (e) {
                       ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(
                           content: Text("Erro ao sair do grupo: ${e.toString().replaceFirst("Exception: ", "")}"),
                           backgroundColor: Colors.redAccent,
                         ),
                       );
                     }
                   }
                 };
                 canInteract = true;
             } else if (isPending) {
                 buttonText = "Solicitação Enviada";
                 buttonIcon = Icons.hourglass_top;
                 // Opcional: Botão para cancelar solicitação
                 // onPressed = () async { ... ref.read(groupServiceProvider).cancelRequest(...) ... };
                 // canInteract = true; // Habilitaria o botão se tivesse ação de cancelar
             } else { // Não é membro nem pendente (Visitante)
                 if (group.isPublic) {
                     buttonText = "Solicitar Entrada";
                     buttonColor = AppColors.primaryRed;
                     buttonIcon = Icons.person_add_alt_1;
                     onPressed = () async {
                       try {
                         // Chama o serviço diretamente (lógica do código antigo)
                         await ref.read(groupServiceProvider).requestToJoinGroup(group.id, currentUserId);
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar( content: Text('Solicitação enviada!'), backgroundColor: Colors.orangeAccent ),
                         );
                         ref.invalidate(groupDetailsProvider(group.id)); // Atualiza para mostrar como pendente
                       } catch (e) {
                         ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(
                             content: Text("Erro ao solicitar entrada: ${e.toString().replaceFirst("Exception: ", "")}"),
                             backgroundColor: Colors.redAccent,
                           ),
                         );
                       }
                     };
                     canInteract = true;
                 } else {
                    buttonText = "Grupo Privado";
                    buttonIcon = Icons.lock;
                 }
             }

             // Construção final do botão
              return SizedBox(
                 width: double.infinity,
                 child: ElevatedButton.icon(
                    icon: isLoadingAction && canInteract
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : (buttonIcon != null ? Icon(buttonIcon, size: 20) : const SizedBox.shrink()), // Garante que icon não é null ou usa SizedBox
                    label: Text(buttonText, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      disabledBackgroundColor: buttonColor.withOpacity(0.5), // Cor desabilitada mais clara
                      disabledForegroundColor: Colors.white.withOpacity(0.7),
                    ),
                    // Desabilita se estiver carregando OU se não houver ação interativa definida
                    onPressed: isLoadingAction || !canInteract ? null : onPressed,
                 ),
              );
         },
         loading: () => const Center(child: SizedBox(height: 50, child: CircularProgressIndicator(color: AppColors.primaryRed))), // Placeholder enquanto usuário carrega
         error: (e,s) => const Center(child: Text("Erro ao verificar usuário.", style: TextStyle(color: Colors.redAccent))),
      );
   }


  // --- Build Principal ---
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Observa detalhes do grupo
    final groupAsync = ref.watch(groupDetailsProvider(groupId));
    // Observa usuário logado para determinar se é admin (conforme novo código)
    final currentUserId = ref.watch(currentUserProvider).asData?.value?.uid;

    // Listener de erro para ações (Mantido)
    ref.listen<RaceActionState>(raceNotifierProvider, (_, next) {
      if (next.error != null && next.error!.isNotEmpty) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text("Erro: ${next.error!}"),
             backgroundColor: Colors.redAccent,
           ),
         );
      }
      // Adicionar listeners para sucesso se necessário
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          groupAsync.maybeWhen(
            data: (g) => g?.name ?? 'Grupo',
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
        // TODO: Adicionar ações de Admin aqui (ex: Editar Grupo, usando o botão 'Gerenciar' ou um ícone extra)
      ),
      body: SafeArea(
        child: groupAsync.when(
          loading:
              () => const Center(
                child: CircularProgressIndicator(color: AppColors.primaryRed),
              ),
          error:
              (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon( Icons.error_outline, color: Colors.redAccent, size: 50 ),
                      const SizedBox(height: 16),
                      Text(
                        "Erro ao carregar grupo:\n$error",
                        style: const TextStyle( color: Colors.redAccent, fontSize: 16 ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text("Tentar Novamente"),
                        onPressed: () => ref.invalidate(groupDetailsProvider(groupId)),
                        style: ElevatedButton.styleFrom( backgroundColor: AppColors.primaryRed, foregroundColor: AppColors.white ),
                      ),
                    ],
                  ),
                ),
              ),
          data: (group) {
            if (group == null) {
              return const Center(
                child: Text(
                  "Grupo não encontrado.",
                  style: TextStyle(color: AppColors.greyLight, fontSize: 16),
                ),
              );
            }

            // Determina se o usuário atual é admin (conforme novo código)
            final bool isCurrentUserAdmin = currentUserId != null && currentUserId == group.adminId;

            // Widget para nome do Admin (Mantido do código antigo)
            final adminNameWidget = Consumer(
              builder: (context, ownerRef, child) {
                final ownerAsync = ownerRef.watch(userProvider(group.adminId));
                return ownerAsync.when(
                  data: (ownerUser) => Text(
                        ownerUser?.name ?? '...',
                        style: const TextStyle( color: AppColors.white, fontSize: 15 ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  loading: () => const Text( '...', style: TextStyle( color: AppColors.greyLight, fontSize: 15 ) ),
                  error: (e, s) => const Text( 'Erro', style: TextStyle(color: Colors.redAccent, fontSize: 15) ),
                );
              },
            );

            // Lista de Corridas do Grupo (Mantido)
            final groupRacesAsync = ref.watch(groupRacesProvider(groupId));

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 30.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Informações do Grupo ---
                  // Esta Row estava no código antigo. Certifique-se de preenchê-la
                  // com os widgets corretos (Avatar, Nome, Descrição, etc.)
                  // usando _buildInfoRow ou widgets diretos.
                  Row(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                        // Exemplo: CircleAvatar para imagem do grupo (se houver)
                        // CircleAvatar(radius: 30, ...),
                        // const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                                Text(group.name, style: const TextStyle(color: AppColors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                                if (group.description!.isNotEmpty) ...[
                                   const SizedBox(height: 6),
                                   Text(group.description!, style: const TextStyle(color: AppColors.greyLight, fontSize: 14)),
                                ],
                                const SizedBox(height: 12),
                                // Usando _buildInfoRow para Admin e Visibilidade
                                _buildInfoRow(context, Icons.shield_outlined, "Admin", adminNameWidget),
                                _buildInfoRow(
                                   context,
                                   group.isPublic ? Icons.lock_open_outlined : Icons.lock_outline,
                                   "Visibilidade",
                                   Text(group.isPublic ? "Público" : "Privado", style: const TextStyle(color: AppColors.white, fontSize: 15)),
                                ),
                                // Adicionar outras informações se necessário (ex: Data de criação)
                             ],
                           ),
                        ),
                     ],
                  ),
                  const SizedBox(height: 24),

                  // --- Botão de Ação Principal ---
                  _buildGroupActionButton(context, ref, group),
                  const SizedBox(height: 24),

                  // --- Lista de Membros Confirmados ---
                  Text(
                    "Membros (${group.memberIds.length}):",
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric( horizontal: 12, vertical: 8 ),
                    decoration: BoxDecoration(
                      color: AppColors.underBackground.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: group.memberIds.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text( "Nenhum membro ainda.", style: TextStyle(color: AppColors.greyLight) ),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: group.memberIds.map( (userId) => _buildMemberItem( context, ref, userId, group.adminId ) ).toList(),
                        ),
                  ),
                  const SizedBox(height: 24),

                  // --- Seção de Membros Pendentes (APENAS para Admin - Adicionado do código novo) ---
                  if (isCurrentUserAdmin && group.pendingMemberIds.isNotEmpty) ...[
                     Text("Solicitações Pendentes (${group.pendingMemberIds.length}):", style: const TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                     const SizedBox(height: 12),
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                       // Estilo um pouco diferente para destacar
                       decoration: BoxDecoration(
                         color: AppColors.underBackground.withOpacity(0.5),
                         borderRadius: BorderRadius.circular(8),
                         border: Border.all(color: Colors.orangeAccent.withOpacity(0.5)) // Borda para destaque
                       ),
                       child: Column(
                         mainAxisSize: MainAxisSize.min,
                         // Usa o novo helper _buildPendingItem
                         children: group.pendingMemberIds.map((userId) => _buildPendingItem(context, ref, userId, group)).toList(),
                       ),
                     ),
                     const SizedBox(height: 24),
                  ] else if (isCurrentUserAdmin) ... [ // Se for admin mas não houver pendentes
                      const Text("Solicitações Pendentes:", style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.underBackground.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8)
                        ),
                        child: const Text(
                          "Nenhuma solicitação pendente.",
                          style: TextStyle(color: AppColors.greyLight, fontStyle: FontStyle.italic),
                          textAlign: TextAlign.center
                        )
                      ),
                      const SizedBox(height: 24),
                  ],
                  // --- Fim Seção Pendentes ---


                  // --- Lista de Corridas do Grupo ---
                  const Text(
                    "Corridas do Grupo:",
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  groupRacesAsync.when(
                    data: (races) {
                      if (races.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.underBackground.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "Nenhuma corrida agendada para este grupo.",
                            style: TextStyle( color: AppColors.greyLight, fontStyle: FontStyle.italic ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      // Usando Column + map é bom para listas não muito grandes que não precisam de virtualização
                      return Column(
                         children: races.map((race) => Padding(
                              padding: const EdgeInsets.only(bottom: 12.0), // Espaço entre cards
                              child: RaceCard(race: race), // Reutiliza o RaceCard
                         )).toList(),
                      );
                      /* Ou usando ListView.builder se a lista puder ser muito grande:
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: races.length,
                        itemBuilder: (ctx, index) => Padding(
                           padding: const EdgeInsets.only(bottom: 12.0), // Espaço entre cards
                           child: RaceCard(race: races[index]),
                        ),
                      );
                      */
                    },
                    loading:
                        () => const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20.0),
                            child: CircularProgressIndicator( color: AppColors.primaryRed ),
                          ),
                        ),
                    error:
                        (e, s) => Container(
                           width: double.infinity,
                           padding: const EdgeInsets.all(16),
                           decoration: BoxDecoration( color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                           child: Text( "Erro ao carregar corridas: $e", style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center ),
                        ),
                  ),
                  const SizedBox(height: 20), // Espaço extra no final
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}