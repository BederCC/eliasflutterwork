import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AssignProductScreen extends StatefulWidget {
  final String productId;
  final String productName;

  const AssignProductScreen({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  State<AssignProductScreen> createState() => _AssignProductScreenState();
}

class _AssignProductScreenState extends State<AssignProductScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );
  String? _selectedUserId;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final snapshot = await _firestore.collection('users').get();
    setState(() {
      _users = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': '${data['nombre']} ${data['apellido']}',
          'email': data['email'],
        };
      }).toList();
    });
  }

  Future<void> _assignProduct() async {
    if (_selectedUserId == null || _quantityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un usuario y cantidad')),
      );
      return;
    }

    final quantity = int.tryParse(_quantityController.text) ?? 0;
    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La cantidad debe ser mayor a 0')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Verificar si ya existe una asignación
      final existingAssignment = await _firestore
          .collection('user_products')
          .where('userId', isEqualTo: _selectedUserId)
          .where('productId', isEqualTo: widget.productId)
          .get();

      if (existingAssignment.docs.isNotEmpty) {
        // Actualizar cantidad existente
        await _firestore
            .collection('user_products')
            .doc(existingAssignment.docs.first.id)
            .update({
              'cantidad': FieldValue.increment(quantity),
              'updatedAt': FieldValue.serverTimestamp(),
            });
      } else {
        // Crear nueva asignación
        await _firestore.collection('user_products').add({
          'userId': _selectedUserId,
          'productId': widget.productId,
          'cantidad': quantity,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Producto asignado exitosamente')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al asignar producto: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Asignar ${widget.productName}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Seleccionar usuario:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            DropdownButtonFormField<String>(
              value: _selectedUserId,
              items: _users.map((user) {
                return DropdownMenuItem<String>(
                  value: user['id'] as String,
                  child: Text('${user['name']} (${user['email']})'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedUserId = value;
                });
              },
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            const Text(
              'Cantidad a asignar:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _quantityController,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _assignProduct,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Asignar Producto'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
