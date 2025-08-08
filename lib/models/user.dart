class User {
  final int? userId;
  final String username;
  final String email;
  final String passwordHash;
  final String fullName;
  final String? profilePicture;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLogin;
  final bool isActive;

  User({
    this.userId,
    required this.username,
    required this.email,
    required this.passwordHash,
    required this.fullName,
    this.profilePicture,
    required this.createdAt,
    this.updatedAt,
    this.lastLogin,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'username': username,
      'email': email,
      'password_hash': passwordHash,
      'full_name': fullName,
      'profile_picture': profilePicture,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
      'is_active': isActive ? 1 : 0,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      userId: map['user_id'],
      username: map['username'],
      email: map['email'],
      passwordHash: map['password_hash'],
      fullName: map['full_name'],
      profilePicture: map['profile_picture'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt:
          map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      lastLogin:
          map['last_login'] != null ? DateTime.parse(map['last_login']) : null,
      isActive: map['is_active'] == 1,
    );
  }
}
