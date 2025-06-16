import 'package:aplicacion1/products_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aplicacion1/assign_product_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _updateProductQuantity(
    String userProductId,
    int newQuantity,
  ) async {
    if (newQuantity < 0) return;

    try {
      await _firestore.collection('user_products').doc(userProductId).update({
        'cantidad': newQuantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar: ${e.toString()}')),
      );
    }
  }

  Future<void> _removeProduct(String userProductId) async {
    try {
      await _firestore.collection('user_products').doc(userProductId).delete();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('Debes iniciar sesión para ver el inventario'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Inventario'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProductsScreen()),
              );
            },
            tooltip: 'Agregar nuevo producto',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar en inventario',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('user_products')
                  .where('userId', isEqualTo: currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.inventory,
                          size: 50,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text('No tienes productos en tu inventario'),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ProductsScreen(),
                              ),
                            );
                          },
                          child: const Text('Agregar productos'),
                        ),
                      ],
                    ),
                  );
                }

                final userProducts = snapshot.data!.docs;

                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: _getProductDetails(userProducts),
                  builder: (context, productSnapshot) {
                    if (productSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!productSnapshot.hasData) {
                      return const Center(
                        child: Text('Error al cargar detalles'),
                      );
                    }

                    final inventoryItems = productSnapshot.data!;

                    // Filtrar por búsqueda
                    final filteredItems = _searchQuery.isEmpty
                        ? inventoryItems
                        : inventoryItems
                              .where(
                                (item) => item['productName']
                                    .toLowerCase()
                                    .contains(_searchQuery),
                              )
                              .toList();

                    return ListView.builder(
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        final quantity = item['quantity'] as int;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ListTile(
                            title: Text(item['productName']),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text('Cantidad: $quantity'),
                                if (item['productDescription'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      item['productDescription'],
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, size: 20),
                                  onPressed: () => _updateProductQuantity(
                                    item['userProductId'],
                                    quantity - 1,
                                  ),
                                ),
                                Container(
                                  width: 30,
                                  alignment: Alignment.center,
                                  child: Text('$quantity'),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add, size: 20),
                                  onPressed: () => _updateProductQuantity(
                                    item['userProductId'],
                                    quantity + 1,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () =>
                                      _removeProduct(item['userProductId']),
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AssignProductScreen(
                                    productId: item['productId'],
                                    productName: item['productName'],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getProductDetails(
    List<QueryDocumentSnapshot> userProducts,
  ) async {
    final productDetails = <Map<String, dynamic>>[];

    for (final userProduct in userProducts) {
      final userProductData = userProduct.data() as Map<String, dynamic>;
      final productDoc = await _firestore
          .collection('productos')
          .doc(userProductData['productId'])
          .get();

      if (productDoc.exists) {
        final productData = productDoc.data() as Map<String, dynamic>;
        productDetails.add({
          'userProductId': userProduct.id,
          'productId': userProductData['productId'],
          'productName': productData['nombre'],
          'productDescription': productData['descripcion'],
          'quantity': userProductData['cantidad'],
        });
      }
    }

    // Ordenar alfabéticamente
    productDetails.sort((a, b) => a['productName'].compareTo(b['productName']));

    return productDetails;
  }
}
