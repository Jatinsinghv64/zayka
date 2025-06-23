// firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all restaurants
  Stream<QuerySnapshot> getRestaurants() {
    return _firestore.collection('Restaurants').snapshots();
  }

  // Get menu categories for a specific restaurant
  Stream<QuerySnapshot> getMenuCategories(String restaurantId) {
    return _firestore
        .collection('MenuCategories')
        .where('restaurantId', isEqualTo: restaurantId)
        .snapshots();
  }

  // Get menu items for a specific category
  Stream<QuerySnapshot> getMenuItems(String categoryId) {
    return _firestore
        .collection('MenuItems')
        .where('categoryId', isEqualTo: categoryId)
        .snapshots();
  }

  // Get all menu items for a restaurant
  Stream<QuerySnapshot> getAllMenuItems(String restaurantId) {
    return _firestore
        .collection('MenuItems')
        .where('restaurantId', isEqualTo: restaurantId)
        .snapshots();
  }

  // Create a new order
  Future<void> createOrder(Map<String, dynamic> orderData) async {
    await _firestore.collection('Orders').add(orderData);
  }

  // Get user orders
  Stream<QuerySnapshot> getUserOrders(String userEmail) {
    return _firestore
        .collection('Orders')
        .where('userEmail', isEqualTo: userEmail)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get user data
  Future<DocumentSnapshot> getUserData(String userEmail) async {
    return await _firestore.collection('Users').doc(userEmail).get();
  }

  // Update user data
  Future<void> updateUserData(String userEmail, Map<String, dynamic> data) async {
    await _firestore.collection('Users').doc(userEmail).update(data);
  }
}