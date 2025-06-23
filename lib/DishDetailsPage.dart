import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'CartScreen.dart';
import 'models.dart';

class DishDetailPage extends StatefulWidget {
  final MenuItem dish;
  final String restaurantId;

  const DishDetailPage({
    Key? key,
    required this.dish,
    required this.restaurantId,
  }) : super(key: key);

  @override
  _DishDetailPageState createState() => _DishDetailPageState();
}

class _DishDetailPageState extends State<DishDetailPage>
    with TickerProviderStateMixin {
  Map<String, dynamic> selectedOptions = {};
  int quantity = 1;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<double>(begin: 1.2, end: 1.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );

    // Set default selections
    for (var entry in widget.dish.variants.entries) {
      final option = entry.value as Map<String, dynamic>;
      if (option['isDefault'] == true) {
        selectedOptions[entry.key] = true;
      }
    }

    // Start animations
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fadeController.forward();
      _slideController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  double get totalPrice {
    double total = widget.dish.basePrice;
    for (var entry in widget.dish.variants.entries) {
      if (selectedOptions[entry.key] == true) {
        final option = entry.value as Map<String, dynamic>;
        total += (option['priceDelta'] as num).toDouble();
      }
    }
    return total * quantity;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.black.withOpacity(0.5),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: Colors.black.withOpacity(0.5),
              child: IconButton(
                icon: const Icon(Icons.favorite_border, color: Colors.white),
                onPressed: () {},
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background Image
          SizedBox(
            height: screenWidth * 0.8,
            width: double.infinity,
            child: PageView.builder(
              itemCount: widget.dish.imageUrls.length,
              itemBuilder: (context, index) => Image.network(
                widget.dish.imageUrls[index],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey[200],
                  child: const Center(child: Icon(Icons.fastfood, size: 50)),
                ),
              ),
            ),
          ),

          // Content
          DraggableScrollableSheet(
            initialChildSize: 0.65,
            minChildSize: 0.65,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return AnimatedBuilder(
                animation: _slideController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _slideAnimation.value,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(30)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        controller: scrollController,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Container(
                                  width: 60,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Dish Name and Price
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.dish.name,
                                      style: const TextStyle(
                                        fontSize: 25,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color:
                                          theme.primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '\$${totalPrice.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: theme.primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 8),

                              // Description
                              Text(
                                widget.dish.description,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                  height: 1.5,
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Dietary Tags
                              if (widget.dish.dietaryTags.isNotEmpty)
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: widget.dish.dietaryTags.entries
                                      .where((e) => e.value)
                                      .map((e) => Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.green[50],
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                  color: Colors.green[100]!),
                                            ),
                                            child: Text(
                                              e.key,
                                              style: TextStyle(
                                                color: Colors.green[800],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ))
                                      .toList(),
                                ),

                              const SizedBox(height: 20),

                              // Customization Section
                              if (widget.dish.variants.isNotEmpty) ...[
                                const Text(
                                  'Customization Options',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ...widget.dish.variants.entries.map((variant) {
                                  final option =
                                      variant.value as Map<String, dynamic>;
                                  final name = option['name']?.toString() ?? '';
                                  final priceDelta =
                                      (option['priceDelta'] as num?)
                                              ?.toDouble() ??
                                          0.0;
                                  final isSelected =
                                      selectedOptions[variant.key] == true;

                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? theme.primaryColor.withOpacity(0.05)
                                          : Colors.grey[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? theme.primaryColor
                                            : Colors.grey[200]!,
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 8),
                                      title: Text(
                                        name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: isSelected
                                              ? theme.primaryColor
                                              : Colors.grey[800],
                                        ),
                                      ),
                                      subtitle: Text(
                                        priceDelta > 0
                                            ? '+\$${priceDelta.toStringAsFixed(2)}'
                                            : 'Included',
                                        style: TextStyle(
                                          color: priceDelta > 0
                                              ? Colors.green
                                              : Colors.grey,
                                        ),
                                      ),
                                      trailing: Transform.scale(
                                        scale: 0.8,
                                        child: Switch(
                                          value: isSelected,
                                          onChanged: (value) {
                                            setState(() {
                                              selectedOptions[variant.key] =
                                                  value;
                                            });
                                          },
                                          activeColor: theme.primaryColor,
                                          activeTrackColor: theme.primaryColor
                                              .withOpacity(0.3),
                                        ),
                                      ),
                                      onTap: () {
                                        setState(() {
                                          selectedOptions[variant.key] =
                                              !isSelected;
                                        });
                                      },
                                    ),
                                  );
                                }).toList(),
                                const SizedBox(height: 20),
                              ],

                              // Quantity Selector
                              const Text(
                                'Quantity',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.remove),
                                      onPressed: () {
                                        if (quantity > 1) {
                                          setState(() => quantity--);
                                        }
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20),
                                    child: Text(
                                      quantity.toString(),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: theme.primaryColor,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.add,
                                          color: Colors.white),
                                      onPressed: () {
                                        setState(() => quantity++);
                                      },
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // Add to Cart Button
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          theme.primaryColor.withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 18),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                  // In DishDetailPage.dart
// Replace the onPressed in the Add to Cart button with:
                                  onPressed: () {
                                    final cartService =
                                        Provider.of<CartService>(context,
                                            listen: false);
                                    cartService.addToCart(
                                      widget.dish,
                                      widget.restaurantId,
                                      quantity,
                                      selectedOptions,
                                    );

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Added ${widget.dish.name} to cart'),
                                        behavior: SnackBarBehavior.floating,
                                        action: SnackBarAction(
                                          label: 'View Cart',
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (context) =>
                                                      const CartScreen()),
                                            );
                                          },
                                        ),
                                      ),
                                    );

                                    Navigator.pop(context);
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.shopping_cart),
                                      SizedBox(width: 10),
                                      Text(
                                        'Add to Cart',
                                        style: TextStyle(fontSize: 18),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
