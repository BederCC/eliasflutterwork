import 'package:aplicacion1/assign_product_screen.dart';
import 'package:aplicacion1/exchanges_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  String? _selectedCategoryId;
  String? _editingProductId;
  bool _isLoading = false;
  bool _isFormOpen = false;
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final snapshot = await _firestore.collection('categorias').get();
    setState(() {
      _categories = snapshot.docs.map((doc) {
        return {'id': doc.id, 'nombre': doc['nombre']};
      }).toList();
    });
  }

  void _openProductForm() {
    if (_isFormOpen || !mounted) return;

    setState(() => _isFormOpen = true);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildProductForm(),
    ).whenComplete(() {
      if (mounted) {
        setState(() => _isFormOpen = false);
      }
    });
  }

  void _editProduct(DocumentSnapshot productDoc) {
    if (_isFormOpen || !mounted) return;

    _editingProductId = productDoc.id;
    final productData = productDoc.data() as Map<String, dynamic>;

    _nameController.text = productData['nombre'] ?? '';
    _descriptionController.text = productData['descripcion'] ?? '';
    _priceController.text = productData['precio']?.toString() ?? '';
    _selectedCategoryId = productData['categoriaId'];

    _openProductForm();
  }

  // En products_screen.dart, modifica el método _createOrUpdateProduct
  Future<void> _createOrUpdateProduct() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final price = double.tryParse(_priceController.text) ?? 0;

    if (name.isEmpty) {
      _showSnackBar('El nombre del producto es requerido');
      return;
    }

    if (_selectedCategoryId == null) {
      _showSnackBar('Debes seleccionar una categoría');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = {
        'nombre': name,
        'precio': price,
        'categoriaId': _selectedCategoryId,
        'ownerId': currentUser.uid, // Asignar al usuario actual
        'cantidad': 10, // Cantidad inicial
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (description.isNotEmpty) {
        data['descripcion'] = description;
      }

      if (_editingProductId == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await _firestore.collection('productos').add(data);
      } else {
        await _firestore
            .collection('productos')
            .doc(_editingProductId)
            .update(data);
      }

      _clearForm();
      _showSnackBar(
        _editingProductId == null ? 'Producto creado' : 'Producto actualizado',
      );
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteProduct(String productId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text('¿Estás seguro de eliminar este producto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await _firestore.collection('productos').doc(productId).delete();
      _showSnackBar('Producto eliminado');
    } catch (e) {
      _showSnackBar('Error al eliminar: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _clearForm() {
    _editingProductId = null;
    _selectedCategoryId = null;
    _nameController.clear();
    _descriptionController.clear();
    _priceController.clear();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Widget _buildProductForm() {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 16,
        left: 16,
        right: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _editingProductId == null ? 'Nuevo Producto' : 'Editar Producto',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre del producto',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedCategoryId,
            decoration: const InputDecoration(
              labelText: 'Categoría',
              border: OutlineInputBorder(),
            ),
            items: _categories.map<DropdownMenuItem<String>>((category) {
              return DropdownMenuItem<String>(
                value: category['id'] as String,
                child: Text(category['nombre'] as String),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedCategoryId = value;
              });
            },
            validator: (value) =>
                value == null ? 'Selecciona una categoría' : null,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Descripción',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _priceController,
            decoration: const InputDecoration(
              labelText: 'Precio',
              border: OutlineInputBorder(),
              prefixText: '\$',
            ),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isLoading ? null : _clearForm,
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _isLoading ? null : _createOrUpdateProduct,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(
                        _editingProductId == null ? 'Guardar' : 'Actualizar',
                      ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos/Servicios'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _openProductForm),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('productos')
            .orderBy('nombre')
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
                  const Text('No hay productos registrados'),
                  TextButton(
                    onPressed: _openProductForm,
                    child: const Text('Agregar primer producto'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final productDoc = snapshot.data!.docs[index];
              final productData = productDoc.data() as Map<String, dynamic>;

              return FutureBuilder<DocumentSnapshot>(
                future: _firestore
                    .collection('categorias')
                    .doc(productData['categoriaId'])
                    .get(),
                builder: (context, categorySnapshot) {
                  final categoryName = categorySnapshot.hasData
                      ? (categorySnapshot.data!.data()
                            as Map<String, dynamic>)['nombre']
                      : 'Categoría no encontrada';

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      title: Text(productData['nombre']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Categoría: $categoryName'),
                          if (productData['descripcion'] != null)
                            Text(productData['descripcion']),
                          Text(
                            'Precio: \$${productData['precio']?.toStringAsFixed(2) ?? '0.00'}',
                          ),
                        ],
                      ),
                      // En el ListTile del producto, modifica el trailing:
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.person_add,
                              color: Colors.blue,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AssignProductScreen(
                                    productId: productDoc.id,
                                    productName: productData['nombre'],
                                  ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteProduct(productDoc.id),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _editProduct(productDoc),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
