class UserGroupRelation {
  final String userId;
  final String groupId;
  final bool isAdmin;
  final bool isApproved;
  final DateTime joinedAt;

  UserGroupRelation({
    required this.userId,
    required this.groupId,
    this.isAdmin = false,
    this.isApproved = true,
    required this.joinedAt,
  });

  factory UserGroupRelation.fromJson(Map<String, dynamic> json) {
    return UserGroupRelation(
      userId: json['userId'] as String,
      groupId: json['groupId'] as String,
      isAdmin: json['isAdmin'] as bool? ?? false,
      isApproved: json['isApproved'] as bool? ?? true,
      joinedAt: DateTime.parse(json['joinedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'groupId': groupId,
      'isAdmin': isAdmin,
      'isApproved': isApproved,
      'joinedAt': joinedAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is UserGroupRelation &&
        other.userId == userId &&
        other.groupId == groupId &&
        other.isAdmin == isAdmin &&
        other.isApproved == isApproved &&
        other.joinedAt == joinedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      userId,
      groupId,
      isAdmin,
      isApproved,
      joinedAt,
    );
  }
}