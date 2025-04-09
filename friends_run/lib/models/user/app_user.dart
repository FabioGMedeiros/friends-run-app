class AppUser {
  final String uid;
  final String name;
  final String email;
  final String? profileImageUrl;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.profileImageUrl,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'],
      name: map['name'],
      email: map['email'],
      profileImageUrl: map['profileImageUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'profileImageUrl': profileImageUrl,
    };
  }
}
