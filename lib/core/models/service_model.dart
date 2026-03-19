class ServiceModel {
  final String id;
  final String name;
  final double price;
  final String category; // 'base', 'add_on', 'interior'
  final String description;
  final Map<String, double> vehicleTypePrices;

  ServiceModel({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    this.description = '',
    this.vehicleTypePrices = const {},
  });

  factory ServiceModel.fromMap(Map<String, dynamic> map, String id) {
    return ServiceModel(
      id: id,
      name: map['name'] ?? '',
      price: (map['price'] as num).toDouble(),
      category: map['category'] ?? 'base',
      description: map['description'] ?? '',
      vehicleTypePrices:
          Map<String, double>.from(map['vehicleTypePrices'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'category': category,
      'description': description,
      'vehicleTypePrices': vehicleTypePrices,
    };
  }
}
