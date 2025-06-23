// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
//
// import 'HomeScreen.dart';
//
// class VariantSelectionDialog extends StatefulWidget {
//   final Dish dish;
//
//   const VariantSelectionDialog({Key? key, required this.dish}) : super(key: key);
//
//   @override
//   State<VariantSelectionDialog> createState() => _VariantSelectionDialogState();
// }
//
// class _VariantSelectionDialogState extends State<VariantSelectionDialog> {
//   Variant? selectedVariant;
//   late List<Variant> variantOptions;
//
//   @override
//   void initState() {
//     super.initState();
//
//     // If your Dish.variants is a Map<String, Variant>, get the .values iterable:
//     final allVariants = widget.dish.variants.values;
//
//     // Build a “none”/“Standard” option plus every available variant:
//     variantOptions = allVariants.isNotEmpty
//         ? [
//       Variant(
//         id: 'none',
//         name: 'Standard',
//         priceDelta: 0.0,
//         isAvailable: true,
//         isDefault: true,
//       ),
//       // Only include those variants in the map whose isAvailable == true:
//       ...allVariants.where((v) => v.isAvailable),
//     ]
//         : <Variant>[];
//
//     // Preselect the first (either “Standard” or first real variant)
//     selectedVariant = variantOptions.isNotEmpty ? variantOptions.first : null;
//   }
//
//   double get totalPrice =>
//       widget.dish.basePrice + (selectedVariant?.priceDelta ?? 0.0);
//
//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Container(
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(16),
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             _buildHeader(),
//             _buildContent(),
//             _buildActionButtons(),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildHeader() {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.red[700],
//         borderRadius: const BorderRadius.only(
//           topLeft: Radius.circular(16),
//           topRight: Radius.circular(16),
//         ),
//       ),
//       child: Text(
//         'Customize ${widget.dish.name}',
//         style: const TextStyle(
//           color: Colors.white,
//           fontSize: 18,
//           fontWeight: FontWeight.bold,
//         ),
//         textAlign: TextAlign.center,
//       ),
//     );
//   }
//
//   Widget _buildContent() {
//     return Padding(
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           if (variantOptions.isNotEmpty) _buildVariantSelector(),
//           const SizedBox(height: 16),
//           _buildTotalPrice(),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildVariantSelector() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Text(
//           'SELECT OPTION',
//           style: TextStyle(
//             color: Colors.red,
//             fontWeight: FontWeight.bold,
//             fontSize: 12,
//           ),
//         ),
//         const SizedBox(height: 8),
//         Container(
//           decoration: BoxDecoration(
//             border: Border.all(color: Colors.red[300]!),
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: DropdownButtonHideUnderline(
//             child: DropdownButton<Variant>(
//               isExpanded: true,
//               value: selectedVariant,
//               icon: Icon(Icons.arrow_drop_down, color: Colors.red[700]),
//               style: TextStyle(
//                 color: Colors.red[900],
//                 fontSize: 14,
//               ),
//               dropdownColor: Colors.white,
//               items: variantOptions.map((variant) {
//                 return DropdownMenuItem<Variant>(
//                   value: variant,
//                   child: Padding(
//                     padding: const EdgeInsets.symmetric(horizontal: 8),
//                     child: Text(
//                       variant.priceDelta > 0
//                           ? '${variant.name} (+\$${variant.priceDelta.toStringAsFixed(2)})'
//                           : variant.name,
//                       style: TextStyle(
//                         color: Colors.red[800],
//                         fontWeight: variant.isDefault
//                             ? FontWeight.bold
//                             : FontWeight.normal,
//                       ),
//                     ),
//                   ),
//                 );
//               }).toList(),
//               onChanged: (variant) {
//                 setState(() {
//                   selectedVariant = variant;
//                 });
//               },
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildTotalPrice() {
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
//       decoration: BoxDecoration(
//         color: Colors.red[50],
//         borderRadius: BorderRadius.circular(8),
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           const Text(
//             'TOTAL',
//             style: TextStyle(
//               color: Colors.red,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           Text(
//             '\$${totalPrice.toStringAsFixed(2)}',
//             style: TextStyle(
//               color: Colors.red[900],
//               fontWeight: FontWeight.bold,
//               fontSize: 18,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildActionButtons() {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       child: Row(
//         children: [
//           if (widget.dish.variants.isNotEmpty) ...[
//             Expanded(
//               child: OutlinedButton(
//                 style: OutlinedButton.styleFrom(
//                   foregroundColor: Colors.red,
//                   side: BorderSide(color: Colors.red[700]!),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   padding: const EdgeInsets.symmetric(vertical: 12),
//                 ),
//                 onPressed: () => Navigator.pop(context),
//                 child: const Text('CANCEL'),
//               ),
//             ),
//             const SizedBox(width: 16),
//           ],
//           Expanded(
//             child: ElevatedButton(
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.red[700],
//                 foregroundColor: Colors.white,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 padding: const EdgeInsets.symmetric(vertical: 12),
//               ),
//               onPressed: () {
//                 final cartProvider =
//                 Provider.of<CartProvider>(context, listen: false);
//
//                 // Wrap the selectedVariant in a List<Variant>, unless it's "none"
//                 final List<Variant> variantsToAdd = [];
//                 if (selectedVariant != null &&
//                     selectedVariant!.id != 'none') {
//                   variantsToAdd.add(selectedVariant!);
//                 }
//
//                 // Now call addToCart; the provider merges duplicates automatically
//                 cartProvider.addToCart(
//                   widget.dish,
//                   variants: variantsToAdd,
//                 );
//
//                 Navigator.pop(context);
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(
//                     content: Text('${widget.dish.name} added to cart'),
//                     backgroundColor: Colors.red[700],
//                   ),
//                 );
//               },
//               child: const Text('ADD TO CART'),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
