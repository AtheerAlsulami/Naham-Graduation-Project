class DeliveryAddressModel {
  const DeliveryAddressModel({
    required this.country,
    required this.address,
    required this.city,
    required this.postcode,
    this.label = 'Home',
  });

  final String country;
  final String address;
  final String city;
  final String postcode;
  final String label;

  DeliveryAddressModel copyWith({
    String? country,
    String? address,
    String? city,
    String? postcode,
    String? label,
  }) {
    return DeliveryAddressModel(
      country: country ?? this.country,
      address: address ?? this.address,
      city: city ?? this.city,
      postcode: postcode ?? this.postcode,
      label: label ?? this.label,
    );
  }
}
