import 'package:cloud_firestore/cloud_firestore.dart'; // Import necessário
import 'package:flutter/foundation.dart'; // Para listEquals e @immutable (opcional)
import 'package:intl/intl.dart'; // Para o getter formattedDate
import 'package:friends_run/models/user/app_user.dart';

// @immutable // Boa prática adicionar
class Race {
  final String id;
  final String title;
  final double distance;
  final DateTime date;
  // Estas listas agora conterão AppUsers "parciais" (só com ID) após fromJson
  final List<AppUser> participants;
  final List<AppUser> pendingParticipants;
  final double startLatitude;
  final double startLongitude;
  final double endLatitude;
  final double endLongitude;
  final String startAddress;
  final String endAddress;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Owner conterá um AppUser "parcial" (só com ID) após fromJson
  final AppUser owner;
  final String ownerId; // Mantemos para fácil acesso ao ID
  final String? groupId;
  final bool isPrivate;

  Race({
    required this.id,
    required this.title,
    required this.distance,
    required this.date,
    this.participants = const [],
    this.pendingParticipants = const [],
    required this.startLatitude,
    required this.startLongitude,
    required this.endLatitude,
    required this.endLongitude,
    required this.startAddress,
    required this.endAddress,
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.owner,
    required this.ownerId,
    this.groupId,
    this.isPrivate = false,
  });
  // O assert foi removido pois owner.uid pode não estar preenchido imediatamente após fromJson
  // : assert(owner.uid == ownerId, 'ownerId must match owner.uid');

  // Getters (sem alterações)
  bool get isPublic => !isPrivate;
  bool get belongsToGroup => groupId != null;

  String get formattedDistance {
    if (distance < 0.1) {
      return '${(distance * 1000).round()} m';
    } else if (distance < 1) {
      return '${(distance * 1000).toStringAsFixed(0)} m';
    } else {
      return '${distance.toStringAsFixed(1)} km';
    }
  }

  String get formattedDate {
     // Usando intl para formatação mais robusta
     // Certifique-se de ter o pacote intl: flutter pub add intl
     try {
       // Adapte o formato conforme necessário
       return DateFormat('dd/MM/yyyy - HH:mm').format(date);
     } catch (e) {
       print("Erro ao formatar data: $e");
       return "Data inválida";
     }
  }

  // copyWith (sem alterações na lógica principal, mas os tipos devem corresponder)
  Race copyWith({
    String? id,
    String? title,
    double? distance,
    DateTime? date,
    List<AppUser>? participants,
    List<AppUser>? pendingParticipants,
    double? startLatitude,
    double? startLongitude,
    double? endLatitude,
    double? endLongitude,
    String? startAddress,
    String? endAddress,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    AppUser? owner,
    String? ownerId,
    String? groupId,
    bool? isPrivate,
  }) {
    return Race(
      id: id ?? this.id,
      title: title ?? this.title,
      distance: distance ?? this.distance,
      date: date ?? this.date,
      participants: participants ?? this.participants,
      pendingParticipants: pendingParticipants ?? this.pendingParticipants,
      startLatitude: startLatitude ?? this.startLatitude,
      startLongitude: startLongitude ?? this.startLongitude,
      endLatitude: endLatitude ?? this.endLatitude,
      endLongitude: endLongitude ?? this.endLongitude,
      startAddress: startAddress ?? this.startAddress,
      endAddress: endAddress ?? this.endAddress,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      // Garante consistência entre owner e ownerId se um deles for atualizado
      owner: owner ?? this.owner,
      ownerId: ownerId ?? (owner != null ? owner.uid : this.ownerId),
      groupId: groupId ?? this.groupId,
      isPrivate: isPrivate ?? this.isPrivate,
    );
  }

  // --- fromJson Refatorado ---
  factory Race.fromJson(Map<String, dynamic> json) {
    // Função auxiliar para converter Timestamp ou String (legado) para DateTime
    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        try {
          return DateTime.parse(value); // Tenta parse de String ISO
        } catch (_) {
          // Falhou, retorna data atual como fallback
          print("Alerta: Falha ao fazer parse da String de data '$value'. Usando data atual.");
          return DateTime.now();
        }
      }
      // Tipo inesperado, retorna data atual como fallback
      print("Alerta: Tipo de data inesperado ($value). Usando data atual.");
      return DateTime.now();
    }

    // Função auxiliar para converter lista de IDs (esperado do Firestore) para lista de AppUser parciais
    List<AppUser> parseIdListToPartialAppUsers(dynamic idListData) {
      if (idListData is List) {
        return idListData
            .where((id) => id is String && id.isNotEmpty) // Garante que são Strings não vazias
            .map((id) => AppUser(uid: id, name: '', email: '')) // Cria AppUser só com ID
            .toList();
      }
      return []; // Retorna vazio se não for uma lista
    }

    // Lê o ownerId primeiro
    final ownerIdFromJson = json['ownerId'] as String? ?? '';

    return Race(
      // Adiciona o ID do documento que geralmente é passado externamente
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Sem Título',
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,

      // Usa a função auxiliar segura para datas
      date: parseDateTime(json['date']),
      createdAt: parseDateTime(json['createdAt']),
      updatedAt: parseDateTime(json['updatedAt']),

      // Usa a função auxiliar para IDs de participantes/pendentes
      participants: parseIdListToPartialAppUsers(json['participants']),
      pendingParticipants: parseIdListToPartialAppUsers(json['pendingParticipants']),

      startLatitude: (json['startLatitude'] as num?)?.toDouble() ?? 0.0,
      startLongitude: (json['startLongitude'] as num?)?.toDouble() ?? 0.0,
      endLatitude: (json['endLatitude'] as num?)?.toDouble() ?? 0.0,
      endLongitude: (json['endLongitude'] as num?)?.toDouble() ?? 0.0,
      startAddress: json['startAddress'] as String? ?? '',
      endAddress: json['endAddress'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,

      ownerId: ownerIdFromJson, // Usa o ID lido
      // Cria um AppUser parcial para o owner usando o ID lido
      owner: AppUser(uid: ownerIdFromJson, name: '', email: ''),

      groupId: json['groupId'] as String?,
      isPrivate: json['isPrivate'] as bool? ?? false,
    );
  }

  // --- toJson Refatorado ---
  Map<String, dynamic> toJson() {
    return {
      // 'id' não é incluído, pois é o ID do documento Firestore
      'title': title,
      'distance': distance,
      // Converte DateTime para Timestamp do Firestore
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      // Mapeia listas de AppUser para listas de IDs (strings)
      'participants': participants.map((user) => user.uid).toList(),
      'pendingParticipants': pendingParticipants.map((user) => user.uid).toList(),
      'startLatitude': startLatitude,
      'startLongitude': startLongitude,
      'endLatitude': endLatitude,
      'endLongitude': endLongitude,
      'startAddress': startAddress,
      'endAddress': endAddress,
      'imageUrl': imageUrl,
      // Salva apenas o ownerId, não o objeto owner completo
      'ownerId': ownerId,
      'groupId': groupId,
      'isPrivate': isPrivate,
    };
  }

  // == e hashCode precisam ser ajustados se a comparação profunda de AppUser não for mais necessária/possível
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    // Compara apenas os IDs nas listas e o ownerId
    return other is Race &&
        other.id == id &&
        other.title == title &&
        other.distance == distance &&
        other.date == date &&
        listEquals(other.participants.map((u) => u.uid).toList(), participants.map((u) => u.uid).toList()) && // Compara IDs
        listEquals(other.pendingParticipants.map((u) => u.uid).toList(), pendingParticipants.map((u) => u.uid).toList()) && // Compara IDs
        other.startLatitude == startLatitude &&
        other.startLongitude == startLongitude &&
        other.endLatitude == endLatitude &&
        other.endLongitude == endLongitude &&
        other.startAddress == startAddress &&
        other.endAddress == endAddress &&
        other.imageUrl == imageUrl &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.ownerId == ownerId && // Compara ownerId
        other.groupId == groupId &&
        other.isPrivate == isPrivate;
  }

  @override
  int get hashCode {
     // Gera hash baseado nos IDs das listas e ownerId
     return Object.hash(
      id,
      title,
      distance,
      date,
      Object.hashAll(participants.map((u) => u.uid)), // Hash dos IDs
      Object.hashAll(pendingParticipants.map((u) => u.uid)), // Hash dos IDs
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
      startAddress,
      endAddress,
      imageUrl,
      createdAt,
      updatedAt,
      ownerId, // Hash do ownerId
      groupId,
      isPrivate,
    );
  }
}