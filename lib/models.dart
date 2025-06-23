export 'package:zayka/DishDetailsPage.dart';
export 'main.dart';


class MenuItem {
  final String itemId;
  final String name;
  final String description;
  final double basePrice;
  final List<String> imageUrls;
  final bool isAvailable;
  final String categoryId;
  final Map<String, String> availableTimes;
  final Map<String, bool> dietaryTags;
  final Map<String, dynamic> variants;

  MenuItem({
    required this.itemId,
    required this.name,
    required this.description,
    required this.basePrice,
    required this.imageUrls,
    required this.isAvailable,
    required this.categoryId,
    required this.availableTimes,
    required this.dietaryTags,
    required this.variants,
  });

  factory MenuItem.fromFirestore(Map<String, dynamic> data) {
    return MenuItem(
      itemId: data['itemId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      basePrice: (data['basePrice'] as num?)?.toDouble() ?? 0.0,
      imageUrls: _parseImageUrls(data['imageUrl']),
      isAvailable: data['isAvailable'] as bool? ?? false,
      categoryId: data['categoryId']?.toString() ?? '',
      availableTimes: _parseAvailableTimes(data['availableTimes']),
      dietaryTags: _parseDietaryTags(data['dietaryTags']),
      variants: _parseVariants(data['variants']),
    );
  }

  static List<String> _parseImageUrls(dynamic imageData) {
    if (imageData is List) {
      return imageData.map((e) => e.toString()).toList();
    }
    if (imageData is String && imageData.isNotEmpty) {
      return [imageData];
    }
    return [];
  }

  static Map<String, String> _parseAvailableTimes(dynamic timesData) {
    final result = <String, String>{};
    if (timesData is Map) {
      timesData.forEach((k, v) {
        if (k is String && v is String) result[k] = v;
      });
    }
    return result;
  }

  static Map<String, bool> _parseDietaryTags(dynamic tagsData) {
    final result = <String, bool>{};
    if (tagsData is Map) {
      tagsData.forEach((k, v) {
        if (k is String && v is bool) result[k] = v;
      });
    }
    return result;
  }

  static Map<String, dynamic> _parseVariants(dynamic varData) {
    final result = <String, dynamic>{};
    if (varData is Map) {
      varData.forEach((k, v) {
        if (k is String && v is Map) {
          result[k] = v.cast<String, dynamic>();
        }
      });
    }
    return result;
  }
}