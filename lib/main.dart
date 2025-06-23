import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'CartScreen.dart';
import 'HomeScreen.dart';

import 'OrderScreen.dart';
import 'ProfilePage.dart';
import 'models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => CartService()),
        ChangeNotifierProvider(create: (context) => RestaurantService()),
        ChangeNotifierProvider(create: (context) => AuthService()), // Keep AuthService here
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Delivery App',
      debugShowCheckedModeBanner: false,
      home: const MainNavigationWrapper(), // Directly set MainNavigationWrapper as home
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
    );
  }
}


// New AuthWrapper widget to handle initial navigation based on auth state


class AuthService with ChangeNotifier {
  User? _currentUser;

  AuthService() {
    // Listen to authentication state changes
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _currentUser = user;
      notifyListeners(); // Notify all listeners when the user changes
    });
  }

  User? get currentUser => _currentUser;

  // You can add login/logout methods here if they are not handled elsewhere
  Future<void> signIn(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      // Handle login errors
      print(e);
      rethrow;
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }
}




class MainNavigationWrapper extends StatefulWidget {
  /// Which tab to show first; defaults to 0 (Home).
  final int initialIndex;

  const MainNavigationWrapper({
    Key? key,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper>
    with TickerProviderStateMixin {
  late int _currentIndex;
  late List<AnimationController> _animationControllers;
  late List<Animation<double>> _animations;

  // Screens are now stateless as HomeScreen gets its restaurant from Provider
  late final List<Widget> _screens = [
    const HomeScreen(),
    const CartScreen(), // Assuming CartScreen is accessible
    const OrdersScreen(), // Assuming OrdersScreen is accessible
    const ProfileScreen(), // Assuming ProfileScreen is accessible
  ];

  @override
  void initState() {
    super.initState();

    // Start on the tab passed in from widget.initialIndex,
    // clamped to the valid range.
    _currentIndex = widget.initialIndex.clamp(0, _screens.length - 1);

    // Create one controller per tab icon for the pop/scale effect.
    _animationControllers = List.generate(
      _screens.length,
          (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 250),
      ),
    );

    _animations = _animationControllers
        .map((controller) => Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOut),
    ))
        .toList();

    // Animate the initially selected tab.
    _animationControllers[_currentIndex].forward();
  }

  @override
  void dispose() {
    for (final controller in _animationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;

    setState(() {
      // Reverse the old tab’s animation
      _animationControllers[_currentIndex].reverse();
      _currentIndex = index;
      // Play the new tab’s animation
      _animationControllers[_currentIndex].forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Read cart item count from the provider
    final cartItemCount = context.watch<CartService>().items.fold<int>(
      0,
          (sum, item) => sum + item.quantity,
    );

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: colorScheme.primary,
          unselectedItemColor: Colors.grey[600],
          selectedLabelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.5,
            color: colorScheme.primary,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.5,
            color: Colors.grey[600],
          ),
          items: [
            _buildNavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Home',
              index: 0,
              theme: theme,
            ),
            _buildNavItem(
              icon: Icons.shopping_cart_outlined,
              activeIcon: Icons.shopping_cart_rounded,
              label: 'Cart',
              index: 1,
              theme: theme,
              itemCount: cartItemCount,
            ),
            _buildNavItem(
              icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long_rounded,
              label: 'Orders',
              index: 2,
              theme: theme,
            ),
            _buildNavItem(
              icon: Icons.person_outlined,
              activeIcon: Icons.person_rounded,
              label: 'Profile',
              index: 3,
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required ThemeData theme,
    int? itemCount,
  }) {
    return BottomNavigationBarItem(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _animations[index],
            builder: (context, child) {
              return Transform.scale(
                scale: _animations[index].value,
                child: Icon(icon),
              );
            },
          ),
          if (itemCount != null && itemCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  itemCount > 9 ? '9+' : itemCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      activeIcon: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _animations[index],
            builder: (context, child) {
              return Transform.scale(
                scale: _animations[index].value,
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Icon(activeIcon, color: theme.colorScheme.primary),
                ),
              );
            },
          ),
          if (itemCount != null && itemCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  itemCount > 9 ? '9+' : itemCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      label: label,
    );
  }
}



class CartService with ChangeNotifier {
  List<CartItem> _items = [];
  String? _currentRestaurantId;

  static const String _cartKey = 'cart_items';
  static const String _restaurantKey = 'current_restaurant';

  List<CartItem> get items => List.unmodifiable(_items);
  String? get currentRestaurantId => _currentRestaurantId;

  CartService() {
    _loadCart();
  }



  Future<void> _loadCart() async {
    final prefs = await SharedPreferences.getInstance();
    final cartJson = prefs.getString(_cartKey);
    _currentRestaurantId = prefs.getString(_restaurantKey);

    if (cartJson != null) {
      final List<dynamic> jsonList = json.decode(cartJson);
      _items = jsonList
          .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    }
  }

  Future<void> _saveCart() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _items.map((item) => item.toJson()).toList();
    await prefs.setString(_cartKey, json.encode(jsonList));

    if (_currentRestaurantId != null) {
      await prefs.setString(_restaurantKey, _currentRestaurantId!);
    } else {
      await prefs.remove(_restaurantKey);
    }
  }

  void selectRestaurant(String? restaurantId, {bool clearCart = false}) {
    if (clearCart &&
        _currentRestaurantId != null &&
        restaurantId != _currentRestaurantId) {
      _items.clear();
    }
    _currentRestaurantId = restaurantId;
    notifyListeners();
    _saveCart();
  }

  void addItem(CartItem item) {
    if (_currentRestaurantId != null &&
        _currentRestaurantId != item.restaurantId) {
      throw Exception("Cannot add items from a different restaurant");
    }
    if (_currentRestaurantId == null) {
      _currentRestaurantId = item.restaurantId;
    }

    final idx = _items.indexWhere((i) =>
    i.name == item.name &&
        const ListEquality().equals(i.selectedOptions, item.selectedOptions));

    if (idx >= 0) {
      _items[idx] = _items[idx].copyWith(
        quantity: _items[idx].quantity + item.quantity,
      );
    } else {
      _items.add(item);
    }
    notifyListeners();
    _saveCart();
  }

  void addToCart(
      MenuItem dish,
      String restaurantId,
      int quantity,
      Map<String, dynamic> selectedOptions,
      ) {
    // Ensure user is logged in before adding to cart
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    // Prevent mixing restaurants
    if (_currentRestaurantId != null && _currentRestaurantId != restaurantId) {
      throw Exception(
          "Cannot add items from a different restaurant. Clear cart first.");
    }
    if (_currentRestaurantId == null) {
      _currentRestaurantId = restaurantId;
    }

    // Build options list
    final optionsList = selectedOptions.entries
        .where((e) => e.value == true)
        .map((e) => e.key)
        .toList();

    // Check if identical item exists
    final idx = _items.indexWhere((i) =>
    i.name == dish.name &&
        const ListEquality().equals(i.selectedOptions, optionsList));

    if (idx >= 0) {
      // Increase quantity
      _items[idx] = _items[idx].copyWith(
        quantity: _items[idx].quantity + quantity,
      );
    } else {
      // Add new item
      final price = _calculateTotalPrice(dish, selectedOptions);
      _items.add(CartItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: dish.name,
        price: price,
        quantity: quantity,
        imageUrl: dish.imageUrls.isNotEmpty ? dish.imageUrls.first : '',
        selectedOptions: optionsList,
        restaurantId: restaurantId,
      ));
    }

    notifyListeners();
    _saveCart();
  }

  void updateQuantity(CartItem item, int newQuantity) {
    final idx = _items.indexWhere((i) => i.id == item.id);
    if (idx >= 0) {
      _items[idx] = _items[idx].copyWith(quantity: newQuantity);
      notifyListeners();
      _saveCart();
    }
  }

  void removeItem(CartItem item) {
    _items.removeWhere((i) => i.id == item.id);
    if (_items.isEmpty) {
      _currentRestaurantId = null;
    }
    notifyListeners();
    _saveCart();
  }

  void clearCart() {
    _items.clear();
    _currentRestaurantId = null;
    notifyListeners();
    _saveCart();
  }

  bool canAddItemFrom(String restaurantId) {
    return _currentRestaurantId == null || _currentRestaurantId == restaurantId;
  }

  double _calculateTotalPrice(
      MenuItem dish,
      Map<String, dynamic> selectedOptions,
      ) {
    double total = dish.basePrice;
    for (final entry in dish.variants.entries) {
      if (selectedOptions[entry.key] == true) {
        total += (entry.value['priceDelta'] as num).toDouble();
      }
    }
    return total;
  }
}


class CartItem {
  final String id;
  final String name;
  final double price;
  int quantity;
  final String imageUrl;
  final List<String> selectedOptions; // Changed from 'options' to 'selectedOptions'
  final String restaurantId;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.imageUrl,
    required this.selectedOptions, // Changed parameter name
    required this.restaurantId,
  });

  CartItem copyWith({
    String? id,
    String? name,
    double? price,
    int? quantity,
    String? imageUrl,
    List<String>? selectedOptions, // Changed parameter name
    String? restaurantId,
  }) {
    return CartItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      selectedOptions: selectedOptions ?? this.selectedOptions, // Changed
      restaurantId: restaurantId ?? this.restaurantId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
      'imageUrl': imageUrl,
      'selectedOptions': selectedOptions, // Changed
      'restaurantId': restaurantId,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'],
      name: json['name'],
      price: json['price'],
      quantity: json['quantity'],
      imageUrl: json['imageUrl'],
      selectedOptions: List<String>.from(json['selectedOptions']), // Changed
      restaurantId: json['restaurantId'],
    );
  }
}
class CartBadge extends StatelessWidget {
  final int count;
  final Widget child;

  const CartBadge({
    super.key,
    required this.count,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (count > 0)
          Positioned(
            right: -8,
            top: -8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                count > 9 ? '9+' : count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
