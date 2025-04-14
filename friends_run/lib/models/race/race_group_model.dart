import 'package:friends_run/models/user/app_user.dart';
import 'package:flutter/foundation.dart';

class RaceGroup {
  final String id;
  final String name;
  final String description;
  final AppUser admin;
  final List<AppUser> members;
  final List<AppUser> pendingMembers;
  final List<String> raceIds;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPublic;

  RaceGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.admin,
    this.members = const [],
    this.pendingMembers = const [],
    this.raceIds = const [],
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
    this.isPublic = false,
  });

  bool get isPrivate => !isPublic;

  bool isMember(String userId) {
    return members.any((user) => user.uid == userId) || admin.uid == userId;
  }

  bool isAdmin(String userId) {
    return admin.uid == userId;
  }

  bool hasPendingRequest(String userId) {
    return pendingMembers.any((user) => user.uid == userId);
  }

  factory RaceGroup.fromJson(Map<String, dynamic> json) {
    return RaceGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      admin: AppUser.fromJson(json['admin'] as Map<String, dynamic>),
      members: (json['members'] as List<dynamic>?)
          ?.map((e) => AppUser.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      pendingMembers: (json['pendingMembers'] as List<dynamic>?)
          ?.map((e) => AppUser.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      raceIds: (json['raceIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      imageUrl: json['imageUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isPublic: json['isPublic'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'admin': admin.toJson(),
      'members': members.map((e) => e.toJson()).toList(),
      'pendingMembers': pendingMembers.map((e) => e.toJson()).toList(),
      'raceIds': raceIds,
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isPublic': isPublic,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is RaceGroup &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.admin == admin &&
        listEquals(other.members, members) &&
        listEquals(other.pendingMembers, pendingMembers) &&
        listEquals(other.raceIds, raceIds) &&
        other.imageUrl == imageUrl &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.isPublic == isPublic;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      description,
      admin,
      Object.hashAll(members),
      Object.hashAll(pendingMembers),
      Object.hashAll(raceIds),
      imageUrl,
      createdAt,
      updatedAt,
      isPublic,
    );
  }
}