import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ProfilePage.dart';
import 'models.dart';






// Main HomeScreen Widget
class HomeScreen extends StatefulWidget {
  final int initialIndex;

  const HomeScreen({
    Key? key,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentIndex;
  List<MenuItem> menuItems = [];
  List<Map<String, dynamic>> categories = [];
  bool isLoading = false;

  String? selectedCategoryId;
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadCategories();

    // Add listener for restaurant changes
    final restaurantService = Provider.of<RestaurantService>(context, listen: false);
    restaurantService.addListener(_onRestaurantChanged);

    // Load initial data if restaurant is already selected
    if (restaurantService.selectedRestaurantId != null) {
      _loadMenuItems();
    }
  }

  @override
  void dispose() {
    // Remove listener when screen is disposed
    final restaurantService = Provider.of<RestaurantService>(context, listen: false);
    restaurantService.removeListener(_onRestaurantChanged);
    super.dispose();
  }

  void _onRestaurantChanged() {
    if (mounted) {
      setState(() {
        // Reset category filter when restaurant changes
        selectedCategoryId = null;
        searchQuery = '';
        _searchController.clear();
      });
      _loadMenuItems(); // Reload menu items when restaurant changes
    }
  }

  Future<void> _loadCategories() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('MenuCategories')
          .where('isActive', isEqualTo: true)
          .orderBy('sortOrder')
          .get();

      if (mounted) {
        setState(() {
          categories = snap.docs.map((d) => d.data()).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load categories: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadMenuItems() async {
    final restaurantService = Provider.of<RestaurantService>(context, listen: false);
    if (restaurantService.selectedRestaurantId == null) return;

    if (mounted) {
      setState(() => isLoading = true);
    }

    try {
      final restDoc = await FirebaseFirestore.instance
          .collection('Restaurants')
          .doc(restaurantService.selectedRestaurantId)
          .get();

      final rest = restDoc.data() ?? {};
      final availMap = (rest['availableMenuItems'] as Map<String, dynamic>?) ?? {};

      final availIds = availMap.entries
          .where((e) => (e.value['isAvailable'] ?? false) == true)
          .map((e) => e.key)
          .toList();

      if (availIds.isEmpty) {
        if (mounted) {
          setState(() {
            menuItems = [];
            isLoading = false;
          });
        }
        return;
      }

      final snap = await FirebaseFirestore.instance
          .collection('MenuItems')
          .where(FieldPath.documentId, whereIn: availIds)
          .get();

      final items = snap.docs
          .map((d) => MenuItem.fromFirestore(d.data() as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          menuItems = items;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          menuItems = [];
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading menu: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _showRestaurantSelection() async {
    final restaurantService = Provider.of<RestaurantService>(context, listen: false); //
    final cartService = Provider.of<CartService>(context, listen: false); //
    final authService = Provider.of<AuthService>(context, listen: false); // Read AuthService
    final bool hasItemsInCart = cartService.items.isNotEmpty; //
    final String? currentRestaurantId = restaurantService.selectedRestaurantId;

    if (hasItemsInCart && authService.currentUser != null) {
      final bool? shouldProceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Switch Restaurant?'),
          content: const Text('Your current cart will be cleared when switching restaurants.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear & Switch', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (shouldProceed != true) return;
    }

    // Show the restaurant selection bottom sheet
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,  // This is crucial for full height
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,  // 90% of screen height
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Select Restaurant',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Restaurant list
            Expanded(
              child: FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance.collection('Restaurants').get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No restaurants available'));
                  }

                  final restaurants = snapshot.data!.docs;
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: restaurants.length,
                    separatorBuilder: (_, __) => const Divider(height: 16),
                    itemBuilder: (context, index) => _buildRestaurantTile(
                      context,
                      restaurants[index],
                      currentRestaurantId,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantTile(
      BuildContext context,
      DocumentSnapshot document,
      String? currentRestaurantId,
      ) {
    final data = document.data() as Map<String, dynamic>;
    final restaurantId = document.id;
    final isOpen = data['isOpen'] == true;
    final isCurrent = currentRestaurantId == restaurantId;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: _buildRestaurantLogo(data['logoUrl']?.toString()),
      title: Text(
        data['name']?.toString() ?? 'Unnamed Restaurant',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isCurrent ? Theme.of(context).primaryColor : null,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data['address']?.toString() ?? 'No address provided'),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.circle,
                size: 10,
                color: isOpen ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 6),
              Text(
                isOpen ? 'Open Now' : 'Closed',
                style: TextStyle(
                  color: isOpen ? Colors.green : Colors.red,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: isCurrent
          ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor)
          : const Icon(Icons.chevron_right, size: 28),
      onTap: () {
        final restaurantService = Provider.of<RestaurantService>(context, listen: false);
        restaurantService.selectRestaurant(
          id: restaurantId,
          name: data['name']?.toString() ?? 'Unnamed Restaurant',
          isOpen: isOpen,
        );
        Navigator.pop(context);
      },
    );
  }

  Widget _buildRestaurantLogo(String? logoUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: logoUrl?.isNotEmpty == true
          ? Image.network(
        logoUrl!,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildLogoPlaceholder(),
      )
          : _buildLogoPlaceholder(),
    );
  }

  Widget _buildLogoPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.restaurant, color: Colors.grey),
    );
  }
  Widget _buildNoRestaurant() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            const Text(
              'No Restaurant Selected',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Please select a restaurant to view its menu',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _showRestaurantSelection,
              child: const Text('Select Restaurant'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuBody() {
    final restaurantService = Provider.of<RestaurantService>(context);

    return SingleChildScrollView(
      child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search menu items...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      setState(() {
                        searchQuery = '';
                        _searchController.clear();
                      });
                    },
                  )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (txt) => setState(() => searchQuery = txt),
              ),
            ),
          ),

          // Category filter chips
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              itemBuilder: (_, i) {
                final cat = categories[i];
                final id = cat['categoryId']?.toString() ?? '';
                final name = cat['name']?.toString() ?? '';
                final img = cat['imageUrl']?.toString() ?? '';
                final isSelected = id == selectedCategoryId;

                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Container(
                    height: 60,
                    child: FilterChip(
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      avatar: img.isNotEmpty
                          ? CircleAvatar(
                        radius: 18,
                        backgroundImage: NetworkImage(img),
                        backgroundColor: Colors.transparent,
                      )
                          : null,
                      label: Text(name),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          selectedCategoryId = selected ? id : null;
                        });
                      },
                      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                      checkmarkColor: Theme.of(context).primaryColor,
                      labelStyle: TextStyle(
                        fontSize: 16,
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.grey[700],
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                    ),
                  ),
                );
              },
            ),
          ),

          // Image Banner
          // Image Banner - Only show when no category is selected
          if (selectedCategoryId == null) // Add this condition
            Container(
              height: 160,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: const DecorationImage(
                  image: NetworkImage('https://lh3.googleusercontent.com/r5Nb5HFce28INXU8C4dZnRShoAtPufEJfiuv6t_XMzmBvCusyEJqCsfpx51rCrMfzGmiESNdNZt5Ru2GpXv-LVMi_tiTUpvm8EmESAk=s750'),
                  fit: BoxFit.cover,
                ),
              ),
            ),

          // Popular Dishes Section
          // Popular Dishes Section
          if (menuItems.isNotEmpty && selectedCategoryId == null) // Add this condition
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('MenuItems')
                  .where('isPopular', isEqualTo: true)
                  .where('itemId', whereIn: menuItems.map((item) => item.itemId).toList())
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const SizedBox.shrink();
                }

                final popularItems = snapshot.data!.docs
                    .map((doc) => MenuItem.fromFirestore(doc.data() as Map<String, dynamic>))
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        'Popular Dishes',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 250,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: popularItems.length,
                        itemBuilder: (context, index) {
                          final item = popularItems[index];
                          return GestureDetector(
                            onTap: () {
                              if (user != null) {
                                _navigateToDetail(item);
                              } else {
                                _showLoginPrompt();
                              }
                            },
                            child: Container(
                              width: 180,
                              margin: const EdgeInsets.only(right: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Dish Image
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                    child: Image.network(
                                      item.imageUrls.isNotEmpty
                                          ? item.imageUrls.first
                                          : 'https://via.placeholder.com/180',
                                      height: 140,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        height: 140,
                                        color: Colors.grey[200],
                                        child: const Icon(Icons.fastfood, color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                  // Dish Details
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${item.basePrice.toStringAsFixed(2)} QAR',
                                          style: TextStyle(
                                            color: Theme.of(context).primaryColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        if (item.dietaryTags.containsKey('Spicy') && item.dietaryTags['Spicy']!)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 6),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.local_fire_department_rounded,
                                                  color: Colors.red,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Spicy',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          if (selectedCategoryId == null && menuItems.isNotEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8), // Same padding as Popular Dishes
              child: Align(
                alignment: Alignment.centerLeft, // Explicit left alignment
                child: Text(
                  'All The Dishes',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          // Regular Menu Items
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Restaurants')
                .doc(restaurantService.selectedRestaurantId)
                .snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData || snap.data!.data() == null) {
                return const Center(child: CircularProgressIndicator());
              }

              final rest = snap.data!.data() as Map<String, dynamic>;
              final availMap = (rest['availableMenuItems'] as Map<String, dynamic>?) ?? {};
              final availIds = availMap.entries
                  .where((e) => (e.value['isAvailable'] ?? false) == true)
                  .map((e) => e.key)
                  .toList();

              if (rest['isOpen'] != true) {
                return _buildClosedScreen(rest);
              } else if (availIds.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.menu_book, size: 60, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text(
                        'No menu items available for this restaurant',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please check back later or select another restaurant',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                );
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('MenuItems')
                    .where('itemId', whereIn: availIds)
                    .snapshots(),
                builder: (ctx2, msnap) {
                  if (!msnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allItems = msnap.data!.docs
                      .map((d) => MenuItem.fromFirestore(d.data() as Map<String, dynamic>))
                      .where((m) =>
                  (selectedCategoryId == null || m.categoryId == selectedCategoryId) &&
                      m.name.toLowerCase().contains(searchQuery.toLowerCase()))
                      .toList();

                  if (allItems.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 60, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          const Text('No items found', style: TextStyle(fontSize: 18)),
                          const SizedBox(height: 8),
                          Text(
                            'Try adjusting your search or filters',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: allItems.length,
                    itemBuilder: (_, i) => _buildMenuItemCard(allItems[i]),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItemCard(MenuItem item) {
    final cartService = Provider.of<CartService>(context, listen: true); //
    final restaurantService = Provider.of<RestaurantService>(context); //
    final authService = Provider.of<AuthService>(context);

    // Find if the item (with its current customization) is already in the cart
    final cartItem = cartService.items.firstWhere(
          (ci) => ci.name == item.name, // Simplified matching for now
      // A more robust check would involve comparing selected options as well
      orElse: () => CartItem(
        id: '',
        name: '',
        price: 0,
        quantity: 0,
        imageUrl: '',
        selectedOptions: [],
        restaurantId: restaurantService.selectedRestaurantId ?? '',
      ),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // If the user taps anywhere on the card, check if they are logged in
          if (authService.currentUser != null) {
            _navigateToDetail(item);
          } else {
            _showLoginPrompt();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.dietaryTags.containsKey('Spicy') && item.dietaryTags['Spicy']!)
                          const Row(
                            children: [
                              Padding(
                                padding: EdgeInsets.only(bottom: 4),
                                child: Icon(
                                  Icons.local_fire_department_rounded,
                                  color: Colors.red,
                                  size: 20,
                                ),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Spicy',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.basePrice.toStringAsFixed(2)} QAR',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          item.description,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    children: [
                      if (item.imageUrls.isNotEmpty)
                        Container(
                          width: 150,
                          height: 140,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: NetworkImage(item.imageUrls.first),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Transform.translate(
                              offset: const Offset(0, 17), // Adjust to lift button over image border
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      spreadRadius: 1,
                                      blurRadius: 3,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: cartItem.quantity > 0
                                    ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove,
                                          color: Colors.white, size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        if (cartItem.quantity > 1) {
                                          cartService.updateQuantity(cartItem, cartItem.quantity - 1);
                                        } else {
                                          cartService.removeItem(cartItem);
                                        }
                                      },
                                    ),
                                    Text(
                                      cartItem.quantity.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        child: const Icon(Icons.add, color: Colors.white, size: 16),
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _showCustomizationDialog(context, item, cartItem),
                                    ),
                                  ],
                                )
                                    : // AuthProtectedCartAction ensures user is logged in before adding
                                AuthProtectedCartAction(
                                  onAuthenticated: () => _showCustomizationDialog(context, item, cartItem),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('ADD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        SizedBox(width: 2),
                                        Icon(Icons.add, color: Colors.white, size: 17),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16), // Spacing after image/button
                      const Text(
                        'customisable',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 0),
                child: Row(
                  children: [
                    IconButton(
                      iconSize: 20,
                      padding: const EdgeInsets.all(4),
                      icon: Icon(Icons.bookmark_border,
                          color: Theme.of(context).primaryColor),
                      onPressed: () {
                        // Handle bookmark action
                        // You might want to add a login check here too if bookmarking requires auth
                      },
                    ),
                    IconButton(
                      iconSize: 20,
                      padding: const EdgeInsets.all(4),
                      icon: Icon(Icons.share,
                          color: Theme.of(context).primaryColor),
                      onPressed: () {
                        // Handle share action
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Required'),
        content: const Text('You need to login to add items to your cart or customize dishes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
            ),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => MainNavigationWrapper(initialIndex: 3), // 👈 Select Profile tab
                ),
                    (route) => false,
              );
            },
            child: const Text(
              'Login',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomizationDialog(BuildContext context, MenuItem item, CartItem cartItem) async {
    // This check is redundant if _showCustomizationDialog is only called via AuthProtectedCartAction
    // or after a direct user check, but it's good for robustness.
    if (user == null) {
      _showLoginPrompt();
      return;
    }

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Customize ${item.name}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How would you like to customize this item?',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.replay),
                      label: const Text('Repeat Previous Customization'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(
                          color: Theme.of(context).primaryColor,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context, 'repeat');
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Create New Customization'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(context, 'new');
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (result == 'repeat') {
      // Logic for repeating customization (e.g., just increment quantity)
      Provider.of<CartService>(context, listen: false)
          .addToCart(item, cartItem.restaurantId, 1, // Add 1 quantity
          Map<String, dynamic>.fromIterable(cartItem.selectedOptions, key: (e) => e, value: (e) => true) // Reconstruct selected options
      );
    } else if (result == 'new') {
      _navigateToDetail(item); // Navigate to detail page for new customization
    }
  }

  void _navigateToDetail(MenuItem item) {
    final restaurantService = Provider.of<RestaurantService>(context, listen: false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DishDetailPage(
          dish: item,
          restaurantId: restaurantService.selectedRestaurantId!,
        ),
      ),
    );
  }

  Widget _buildClosedScreen(Map<String, dynamic> rest) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.access_time, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 24),
            const Text(
              'Restaurant Closed',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'This restaurant is currently closed. Please check back during their operating hours.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            if (rest['workingHours'] != null)
              Text(
                'Hours: ${rest['workingHours']?['friday']?['open']?.toString() ?? ''} - ${rest['workingHours']?['friday']?['close']?.toString() ?? ''}',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _showRestaurantSelection,
              child: const Text('Select Another Restaurant'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final restaurantService = Provider.of<RestaurantService>(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: theme.primaryColor,
        centerTitle: true,
        titleSpacing: 0,
        leadingWidth: 200,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.1),
        leading: restaurantService.selectedRestaurantId == null
            ? TextButton(
          onPressed: _showRestaurantSelection,
          child: const Text(
            'No Restaurant Selected',
            style: TextStyle(color: Colors.white),
          ),
        )
            : StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Restaurants')
              .doc(restaurantService.selectedRestaurantId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.data() == null) {
              return const SizedBox();
            }

            final rest = snapshot.data!.data() as Map<String, dynamic>;
            final name = rest['name']?.toString() ?? '';
            final landmark = (rest['address'] is Map &&
                rest['address']['landmark'] != null)
                ? rest['address']['landmark'].toString()
                : '';
            final isOpen = rest['isOpen'] == true;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _showRestaurantSelection,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.circle,
                          size: 10,
                          color: isOpen
                              ? Colors.green[200]
                              : Colors.red[200],
                        ),
                      ],
                    ),
                    if (landmark.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        landmark,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined, color: Colors.white),
            onPressed: () => Scaffold.of(context).openEndDrawer(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: restaurantService.selectedRestaurantId == null
            ? _buildNoRestaurant()
            : _buildMenuBody(),
      ),
    );
  }
}

// Dummy classes for compilation (replace with your actual implementations)
class RestaurantService extends ChangeNotifier {
  String? _selectedRestaurantId;
  String? _selectedRestaurantName;
  bool _isRestaurantOpen = false;

  String? get selectedRestaurantId => _selectedRestaurantId;
  String? get selectedRestaurantName => _selectedRestaurantName;
  bool get isRestaurantOpen => _isRestaurantOpen;

  Future<void> _loadPersistedRestaurant() async {
    // Implementation would load from SharedPreferences
  }

  Future<void> selectRestaurant({
    required String id,
    required String name,
    required bool isOpen,
  }) async {
    _selectedRestaurantId = id;
    _selectedRestaurantName = name;
    _isRestaurantOpen = isOpen;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedRestaurantId', id);
    await prefs.setString('selectedRestaurantName', name);
    await prefs.setBool('isRestaurantOpen', isOpen);

    notifyListeners(); // This is crucial
  }
}

class RestaurantSelectionDialog extends StatelessWidget {
  final String? currentRestaurantId;

  const RestaurantSelectionDialog({
    Key? key,
    this.currentRestaurantId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          const Text('Select Restaurant'),
          const SizedBox(height: 16),
          // Actual implementation would show restaurant list
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
class AuthProtectedCartAction extends StatelessWidget {
  final Widget child;
  final Function() onAuthenticated;
  final String? authMessage;

  const AuthProtectedCartAction({
    Key? key,
    required this.child,
    required this.onAuthenticated,
    this.authMessage = 'Please login to modify your cart',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleAction(context),
      child: child,
    );
  }

  void _handleAction(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Login Required'),
          content: Text(authMessage!),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: const Text('Login Now'),
            ),
          ],
        ),
      );
    } else {
      onAuthenticated();
    }
  }
}











