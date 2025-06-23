import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'HomeScreen.dart';
import 'main.dart';



class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _slideAnimation;
  String? _selectedPaymentMethod;
  final TextEditingController _notesController = TextEditingController();
  bool _isPlacingOrder = false;
  final _formKey = GlobalKey<FormState>();


  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnimation = Tween<double>(begin: 1.2, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();
    _loadUserAddresses(); // Add this line
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _userAddresses = [];
  Map<String, dynamic>? _selectedAddress;

  Future<void> _loadUserAddresses() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.email)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final addresses = List<Map<String, dynamic>>.from(data['savedAddresses'] ?? []);

        setState(() {
          _userAddresses = addresses;
          // Set default address if available
          _selectedAddress = addresses.firstWhere(
                (addr) => addr['isDefault'] == true,
            orElse: () => addresses.isNotEmpty ? addresses[0] : {},
          );
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading addresses: $e')),
      );
    }
  }

  void _showAddressSelection() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Delivery Address'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _userAddresses.length,
            itemBuilder: (context, index) {
              final address = _userAddresses[index];
              return RadioListTile<Map<String, dynamic>>(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      address['label'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${address['street']}, ${address['city']}, ${address['state']} ${address['zip']}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    if (address['isDefault'] == true)
                      const Text('Default', style: TextStyle(color: Colors.green)),
                  ],
                ),
                value: address,
                groupValue: _selectedAddress,
                onChanged: (value) {
                  setState(() => _selectedAddress = value);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showPaymentSelection() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Payment Method'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Cash on Delivery'),
              value: 'cash',
              groupValue: _selectedPaymentMethod,
              onChanged: (value) {
                setState(() => _selectedPaymentMethod = value);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Credit/Debit Card'),
              value: 'card',
              groupValue: _selectedPaymentMethod,
              onChanged: (value) {
                setState(() => _selectedPaymentMethod = value);
                Navigator.pop(context);
                _showCardPaymentDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showCardPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Card Payment'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Card Number',
                  hintText: '1234 5678 9012 3456',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter card number';
                  }
                  return null;
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Expiry Date',
                        hintText: 'MM/YY',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter expiry date';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'CVV',
                        hintText: '123',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter CVV';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment successful')),
                );
              }
            },
            child: const Text('Pay'),
          ),
        ],
      ),
    );
  }

  Future<void> _placeOrder() async {
    if (_selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment method')),
      );
      return;
    }

    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a delivery address')),
      );
      return;
    }

    setState(() => _isPlacingOrder = true);

    final cartService = Provider.of<CartService>(context, listen: false);
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to place an order')),
      );
      setState(() => _isPlacingOrder = false);
      return;
    }

    try {
      // Calculate totals
      final subtotal = cartService.items.fold(
          0.0, (sum, item) => sum + (item.price * item.quantity));
      const deliveryFee = 2.99;
      final tax = subtotal * 0.1;
      final total = subtotal + deliveryFee + tax;

      // Create order ID first with explicit type
      final String orderId = 'ORD-${DateTime.now().millisecondsSinceEpoch}';

      // Create order data with explicit types
      final Map<String, dynamic> orderData = {
        'customerId': user.uid,
        'customerEmail': user.email ?? '',
        'customerNotes': _notesController.text,
        'deliveryAddress': _getUserAddress(),
        'items': cartService.items.map((item) => {
          'itemId': item.id,
          'name': item.name,
          'price': item.price,
          'quantity': item.quantity,
          'options': item.selectedOptions,
          'imageUrl': item.imageUrl,
        }).toList(),
        'orderId': orderId, // Using the pre-declared String
        'paymentMethod': _selectedPaymentMethod!,
        'paymentStatus': _selectedPaymentMethod == 'cash' ? 'pending' : 'paid',
        'restaurantId': cartService.currentRestaurantId ?? '',
        'restaurantName': 'Restaurant Name',
        'riderId': '',
        'riderPaymentAmount': 2.50,
        'status': 'pending',
        'subtotal': subtotal,
        'deliveryFee': deliveryFee,
        'tax': tax,
        'totalAmount': total,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': user.uid,
      };

      // Save to Firebase
      await FirebaseFirestore.instance
          .collection('Orders')
          .doc(orderId) // Use the String directly here
          .set(orderData);

      // Clear cart on success
      cartService.clearCart();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order placed successfully!')),
      );

      // Navigate to order confirmation
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OrderConfirmationScreen(
            orderId: orderId, // Use the String variable
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to place order: ${e.toString()}')),
      );
    } finally {
      setState(() => _isPlacingOrder = false);
    }
  }
  Map<String, dynamic> _getUserAddress() {
    if (_selectedAddress == null) {
      return {
        'street': 'No address selected',
        'city': '',
        'state': '',
        'zipCode': '',
        'phone': '',
        'instructions': '',
      };
    }

    return {
      'street': _selectedAddress!['street'] ?? '',
      'city': _selectedAddress!['city'] ?? '',
      'state': _selectedAddress!['state'] ?? '',
      'zipCode': _selectedAddress!['zip']?.toString() ?? '',
      'phone': '', // You might want to add phone to your address model
      'instructions': '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final cartService = Provider.of<CartService>(context);
    final cartItems = cartService.items;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Calculate prices
    final subtotal = cartItems.fold(
        0.0, (double sum, CartItem item) => sum + (item.price * item.quantity));
    const deliveryFee = 2.99;
    final tax = subtotal * 0.1;
    final total = subtotal + deliveryFee + tax;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Cart'),
        centerTitle: true,
        actions: [
          if (cartItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _showClearCartDialog,
            ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _fadeController,
        builder: (context, child) {
          return Transform.scale(
            scale: _slideAnimation.value,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height,
                ),
                child: Column(
                  children: [
                    if (cartItems.isEmpty)
                      _buildEmptyCart(),
                    if (cartItems.isNotEmpty)
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: cartItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final item = cartItems[index];
                          return _buildCartItem(item, colorScheme, cartService);
                        },
                      ),
                    if (cartItems.isNotEmpty)
                      _buildCheckoutCard(theme, subtotal, deliveryFee, tax, total),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCartItem(CartItem item, ColorScheme colorScheme, CartService cartService) {
    return Dismissible(
      key: Key(item.id),
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete, color: colorScheme.error),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) => _removeItem(item, cartService),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item.imageUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[200],
                    child: const Icon(Icons.fastfood),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (item.selectedOptions.isNotEmpty)
                      Text(
                        item.selectedOptions.join(', '),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(item.price * item.quantity).toStringAsFixed(2)} QAR',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: () => _updateQuantity(item, -1, cartService),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(item.quantity.toString()),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () => _updateQuantity(item, 1, cartService),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildCheckoutCard(ThemeData theme, double subtotal, double deliveryFee, double tax, double total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Add address selection tile
          ListTile(
            leading: const Icon(Icons.location_on),
            title: Text(
              _selectedAddress == null
                  ? 'Select Delivery Address'
                  : _selectedAddress!['label'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: _selectedAddress == null
                ? const Text('No address selected')
                : Text(
                '${_selectedAddress!['street']}, ${_selectedAddress!['city']}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showAddressSelection,
          ),
          const Divider(height: 1),

          _buildPriceRow('Subtotal', subtotal),
          _buildPriceRow('Delivery Fee', deliveryFee),
          _buildPriceRow('Tax (10%)', tax),
          const Divider(height: 24),
          _buildPriceRow(
            'Total',
            total,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),

          const SizedBox(height: 16),

          // Payment method selection
          ListTile(
            leading: const Icon(Icons.payment),
            title: Text(
              _selectedPaymentMethod == null
                  ? 'Select Payment Method'
                  : _selectedPaymentMethod == 'cash'
                  ? 'Cash on Delivery'
                  : 'Credit/Debit Card',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showPaymentSelection,
          ),

          // Customer notes
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Special Instructions',
              hintText: 'Any special requests?',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),

          const SizedBox(height: 16),

          // Checkout button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              onPressed: _selectedPaymentMethod == null || _selectedAddress == null
                  ? null
                  : _isPlacingOrder
                  ? null
                  : _placeOrder,
              child: _isPlacingOrder
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                'Place Order',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 20),
          const Text(
            'Your Cart is Empty',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Browse restaurants and add items to get started',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount, {TextStyle? style}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: style ??
                const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
          ),
          Text(
            '${amount.toStringAsFixed(2)} QAR',
            style: style ??
                const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  void _updateQuantity(CartItem item, int change, CartService cartService) {
    final newQuantity = item.quantity + change;
    if (newQuantity > 0) {
      cartService.updateQuantity(item, newQuantity);
    } else {
      cartService.removeItem(item);
    }
  }

  void _removeItem(CartItem item, CartService cartService) {
    cartService.removeItem(item);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed ${item.name} from cart'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            try {
              cartService.addItem(item);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(e.toString())),
              );
            }
          },
        ),
      ),
    );
  }

  void _showClearCartDialog() {
    final cartService = Provider.of<CartService>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cart?'),
        content: const Text('Are you sure you want to remove all items from your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              cartService.clearCart();
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}





class OrderConfirmationScreen extends StatefulWidget {
  final String orderId;

  const OrderConfirmationScreen({Key? key, required this.orderId})
      : super(key: key);

  @override
  _OrderConfirmationScreenState createState() =>
      _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 5), () {
      // 🎯 Navigate into your MAIN shell with Orders tab selected
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => MainNavigationWrapper(initialIndex: 2),
        ),
            (route) => false,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order Confirmation')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            const Text(
              'Thank You!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Your order #${widget.orderId} has been placed',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 30),
            const Text(
              'Redirecting to your orders...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}


