import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TextEditingController _nameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _birthDateController;
  late TextEditingController _passwordController;

  DateTime? _selectedDate;
  String? _editingUserId;
  bool _isLoading = false;
  bool _isFormOpen = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _nameController = TextEditingController();
    _lastNameController = TextEditingController();
    _emailController = TextEditingController();
    _addressController = TextEditingController();
    _birthDateController = TextEditingController();
    _passwordController = TextEditingController();
  }

  void _disposeControllers() {
    _nameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _birthDateController.dispose();
    _passwordController.dispose();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _birthDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _openUserForm() {
    if (_isFormOpen || !mounted) return;

    setState(() => _isFormOpen = true);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildUserForm(),
    ).whenComplete(() {
      if (mounted) {
        setState(() => _isFormOpen = false);
      }
    });
  }

  void _editUser(DocumentSnapshot userDoc) {
    if (_isFormOpen || !mounted) return;

    _editingUserId = userDoc.id;
    final userData = userDoc.data() as Map<String, dynamic>;

    _disposeControllers();
    _initializeControllers();

    _nameController.text = userData['nombre'] ?? '';
    _lastNameController.text = userData['apellido'] ?? '';
    _emailController.text = userData['email'] ?? '';
    _addressController.text = userData['direccion'] ?? '';
    _passwordController.text = ''; // No mostramos la contraseña

    if (userData['fechaNacimiento'] != null) {
      _selectedDate = DateTime.parse(userData['fechaNacimiento']);
      _birthDateController.text = DateFormat(
        'yyyy-MM-dd',
      ).format(_selectedDate!);
    }

    _openUserForm();
  }

  Future<void> _createOrUpdateUser() async {
    if (_nameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _emailController.text.isEmpty) {
      _showSnackBar('Nombre, apellido y email son requeridos');
      return;
    }

    if (_editingUserId == null && _passwordController.text.isEmpty) {
      _showSnackBar('La contraseña es requerida para nuevos usuarios');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_editingUserId == null) {
        // Crear nuevo usuario
        final credential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );

        await _firestore.collection('users').doc(credential.user?.uid).set({
          'nombre': _nameController.text,
          'apellido': _lastNameController.text,
          'email': _emailController.text,
          'direccion': _addressController.text,
          'fechaNacimiento': _selectedDate?.toIso8601String(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Actualizar usuario existente
        await _firestore.collection('users').doc(_editingUserId).update({
          'nombre': _nameController.text,
          'apellido': _lastNameController.text,
          'email': _emailController.text,
          'direccion': _addressController.text,
          'fechaNacimiento': _selectedDate?.toIso8601String(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      _clearForm();
      _showSnackBar(
        _editingUserId == null ? 'Usuario creado' : 'Usuario actualizado',
      );
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteUser(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text('¿Estás seguro de eliminar este usuario?'),
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
      await _firestore.collection('users').doc(userId).delete();
      _showSnackBar('Usuario eliminado');
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
    _editingUserId = null;
    _selectedDate = null;
    _passwordController.clear();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Widget _buildUserForm() {
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
            _editingUserId == null ? 'Nuevo Usuario' : 'Editar Usuario',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _lastNameController,
            decoration: const InputDecoration(
              labelText: 'Apellido',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Dirección',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _birthDateController,
            decoration: const InputDecoration(
              labelText: 'Fecha de Nacimiento',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today),
            ),
            readOnly: true,
            onTap: () => _selectDate(context),
          ),
          if (_editingUserId == null) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
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
                onPressed: _isLoading ? null : _createOrUpdateUser,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(_editingUserId == null ? 'Guardar' : 'Actualizar'),
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
        title: const Text('Gestión de Usuarios'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _openUserForm),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('users').snapshots(),
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
                  const Text('No hay usuarios registrados'),
                  TextButton(
                    onPressed: _openUserForm,
                    child: const Text('Agregar primer usuario'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final userDoc = snapshot.data!.docs[index];
              final userData = userDoc.data() as Map<String, dynamic>;
              final currentUser = _auth.currentUser;
              final isCurrentUser = userDoc.id == currentUser?.uid;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('${userData['nombre']} ${userData['apellido']}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userData['email']),
                      if (userData['direccion'] != null)
                        Text(userData['direccion']),
                      if (userData['fechaNacimiento'] != null)
                        Text(
                          'Nacimiento: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(userData['fechaNacimiento']))}',
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isCurrentUser)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteUser(userDoc.id),
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _editUser(userDoc),
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
