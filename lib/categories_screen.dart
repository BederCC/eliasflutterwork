import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String? _editingCategoryId;
  bool _isLoading = false;
  bool _isFormOpen = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _openCategoryForm() {
    if (_isFormOpen || !mounted) return;

    setState(() => _isFormOpen = true);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildCategoryForm(),
    ).whenComplete(() {
      if (mounted) {
        setState(() => _isFormOpen = false);
      }
    });
  }

  void _editCategory(DocumentSnapshot categoryDoc) {
    if (_isFormOpen || !mounted) return;

    _editingCategoryId = categoryDoc.id;
    final categoryData = categoryDoc.data() as Map<String, dynamic>;

    _nameController.text = categoryData['nombre'] ?? ''; // Manejo de null
    _descriptionController.text =
        categoryData['descripcion'] ?? ''; // Manejo de null

    _openCategoryForm();
  }

  Future<void> _createOrUpdateCategory() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    if (name.isEmpty) {
      _showSnackBar('El nombre de la categoría es requerido');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = {'nombre': name, 'updatedAt': FieldValue.serverTimestamp()};

      // Solo agregar descripción si no está vacía
      if (description.isNotEmpty) {
        data['descripcion'] = description;
      }

      if (_editingCategoryId == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await _firestore.collection('categorias').add(data);
      } else {
        await _firestore
            .collection('categorias')
            .doc(_editingCategoryId)
            .update(data);
      }

      _clearForm();
      _showSnackBar(
        _editingCategoryId == null
            ? 'Categoría creada'
            : 'Categoría actualizada',
      );
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteCategory(String categoryId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text('¿Estás seguro de eliminar esta categoría?'),
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
      await _firestore.collection('categorias').doc(categoryId).delete();
      _showSnackBar('Categoría eliminada');
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
    _editingCategoryId = null;
    _nameController.clear();
    _descriptionController.clear();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Widget _buildCategoryForm() {
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
            _editingCategoryId == null ? 'Nueva Categoría' : 'Editar Categoría',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre de la categoría',
              border: OutlineInputBorder(),
            ),
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
                onPressed: _isLoading ? null : _createOrUpdateCategory,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(
                        _editingCategoryId == null ? 'Guardar' : 'Actualizar',
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
        title: const Text('Gestión de Categorías'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _openCategoryForm),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('categorias').snapshots(),
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
                  const Text('No hay categorías registradas'),
                  TextButton(
                    onPressed: _openCategoryForm,
                    child: const Text('Agregar primera categoría'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final categoryDoc = snapshot.data!.docs[index];
              final categoryData = categoryDoc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(
                    categoryData['nombre'] ?? 'Sin nombre',
                  ), // Manejo de null
                  subtitle: Text(
                    categoryData['descripcion'] ?? '',
                  ), // Manejo de null
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteCategory(categoryDoc.id),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _editCategory(categoryDoc),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
