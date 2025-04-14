import 'package:friends_run/models/user/app_user.dart';
import 'package:flutter/foundation.dart';

class Race {
  final String id;
  final String title;
  final double distance;
  final DateTime date;
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
  final AppUser owner;
  final String ownerId;
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
  }) : assert(owner.uid == ownerId, 'ownerId must match owner.id');

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
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    
    return '$day/$month/$year - $hour:$minute';
  }

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
      owner: owner ?? this.owner,
      ownerId: ownerId ?? this.ownerId,
      groupId: groupId ?? this.groupId,
      isPrivate: isPrivate ?? this.isPrivate,
    );
  }

  factory Race.fromJson(Map<String, dynamic> json) {
    return Race(
      id: json['id'] as String,
      title: json['title'] as String,
      distance: (json['distance'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      participants: (json['participants'] as List<dynamic>?)
          ?.map((e) => AppUser.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      pendingParticipants: (json['pendingParticipants'] as List<dynamic>?)
          ?.map((e) => AppUser.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      startLatitude: (json['startLatitude'] as num).toDouble(),
      startLongitude: (json['startLongitude'] as num).toDouble(),
      endLatitude: (json['endLatitude'] as num).toDouble(),
      endLongitude: (json['endLongitude'] as num).toDouble(),
      startAddress: json['startAddress'] as String,
      endAddress: json['endAddress'] as String,
      imageUrl: json['imageUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      owner: AppUser.fromJson(json['owner'] as Map<String, dynamic>),
      ownerId: json['ownerId'] as String,
      groupId: json['groupId'] as String?,
      isPrivate: json['isPrivate'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'distance': distance,
      'date': date.toIso8601String(),
      'participants': participants.map((e) => e.toJson()).toList(),
      'pendingParticipants': pendingParticipants.map((e) => e.toJson()).toList(),
      'startLatitude': startLatitude,
      'startLongitude': startLongitude,
      'endLatitude': endLatitude,
      'endLongitude': endLongitude,
      'startAddress': startAddress,
      'endAddress': endAddress,
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'owner': owner.toJson(),
      'ownerId': ownerId,
      'groupId': groupId,
      'isPrivate': isPrivate,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is Race &&
        other.id == id &&
        other.title == title &&
        other.distance == distance &&
        other.date == date &&
        listEquals(other.participants, participants) &&
        listEquals(other.pendingParticipants, pendingParticipants) &&
        other.startLatitude == startLatitude &&
        other.startLongitude == startLongitude &&
        other.endLatitude == endLatitude &&
        other.endLongitude == endLongitude &&
        other.startAddress == startAddress &&
        other.endAddress == endAddress &&
        other.imageUrl == imageUrl &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.owner == owner &&
        other.ownerId == ownerId &&
        other.groupId == groupId &&
        other.isPrivate == isPrivate;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      title,
      distance,
      date,
      Object.hashAll(participants),
      Object.hashAll(pendingParticipants),
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
      startAddress,
      endAddress,
      imageUrl,
      createdAt,
      updatedAt,
      owner,
      ownerId,
      groupId,
      isPrivate,
    );
  }
}