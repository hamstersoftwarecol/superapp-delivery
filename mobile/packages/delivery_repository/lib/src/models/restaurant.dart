import 'package:equatable/equatable.dart';

class MenuItem extends Equatable {
  const MenuItem({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.priceCents,
    this.description,
    this.imageUrl,
    this.thumbnailUrl,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
    id: json['id'] as int,
    restaurantId: json['restaurant_id'] as int,
    name: json['name'] as String,
    description: json['description'] as String?,
    priceCents: json['price_cents'] as int,
    imageUrl: json['image_url'] as String?,
    thumbnailUrl: json['thumbnail_url'] as String?,
  );

  final int id;
  final int restaurantId;
  final String name;
  final String? description;
  final int priceCents;

  /// Full-size photo and the small square one for lists. `null` without a photo.
  final String? imageUrl;
  final String? thumbnailUrl;

  @override
  List<Object?> get props => [
    id,
    restaurantId,
    name,
    description,
    priceCents,
    imageUrl,
    thumbnailUrl,
  ];
}

class Restaurant extends Equatable {
  const Restaurant({
    required this.id,
    required this.name,
    required this.address,
    required this.deliveryFeeCents,
    required this.isOpen,
    this.description,
    this.imageUrl,
    this.thumbnailUrl,
    this.menuItems = const [],
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) => Restaurant(
    id: json['id'] as int,
    name: json['name'] as String,
    description: json['description'] as String?,
    address: json['address'] as String,
    deliveryFeeCents: json['delivery_fee_cents'] as int,
    isOpen: json['is_open'] as bool,
    imageUrl: json['image_url'] as String?,
    thumbnailUrl: json['thumbnail_url'] as String?,
    menuItems: [
      for (final item in (json['menu_items'] as List? ?? const []))
        MenuItem.fromJson(item as Map<String, dynamic>),
    ],
  );

  final int id;
  final String name;
  final String? description;
  final String address;
  final int deliveryFeeCents;
  final bool isOpen;

  /// Cover photo and its small square version. `null` without a photo.
  final String? imageUrl;
  final String? thumbnailUrl;
  final List<MenuItem> menuItems;

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    address,
    deliveryFeeCents,
    isOpen,
    imageUrl,
    thumbnailUrl,
    menuItems,
  ];
}
