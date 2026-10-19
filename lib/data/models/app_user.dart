class AppUser {
  const AppUser({required this.id, required this.username, this.fullName});

  final String id;
  final String username;
  final String? fullName;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        username: json['username'] as String,
        fullName: json['full_name'] as String?,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'username': username, 'full_name': fullName};
}