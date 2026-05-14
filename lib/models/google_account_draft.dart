class GoogleAccountDraft {
  const GoogleAccountDraft({
    required this.name,
    required this.email,
    this.phone = '',
    this.countryCode = '+966',
    this.photoUrl,
  });

  final String name;
  final String email;
  final String phone;
  final String countryCode;
  final String? photoUrl;
}
