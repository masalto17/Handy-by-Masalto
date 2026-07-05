class AppAccount {
  const AppAccount({
    required this.id,
    required this.displayName,
    required this.email,
    required this.provider,
    required this.isGuest,
  });

  final String id;
  final String displayName;
  final String? email;
  final String provider;
  final bool isGuest;
}
