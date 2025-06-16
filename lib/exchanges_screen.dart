import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ExchangeScreen extends StatefulWidget {
  const ExchangeScreen({super.key});

  @override
  State<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends State<ExchangeScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;
  int _currentTabIndex = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _initializeFirestore();
  }

  void _initializeFirestore() {
    _firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _createExchange({
    required String recipientId,
    required String productId,
    required int quantity,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      await _firestore.collection('intercambios').add({
        'senderId': currentUser.uid,
        'receiverId': recipientId,
        'productId': productId,
        'quantity': quantity,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Intercambio creado exitosamente')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al crear intercambio: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildExchangeList(String type) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('intercambios').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Filtramos y ordenamos localmente
        final filteredDocs =
            snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data[type == 'sent' ? 'senderId' : 'receiverId'] ==
                  currentUser.uid;
            }).toList()..sort((a, b) {
              final aDate =
                  (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp;
              final bDate =
                  (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp;
              return bDate.compareTo(aDate);
            });

        if (filteredDocs.isEmpty) return _buildEmptyState(type);

        return ListView.builder(
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildExchangeItem(doc, data, type);
          },
        );
      },
    );
  }

  Widget _buildExchangeItem(
    DocumentSnapshot doc,
    Map<String, dynamic> data,
    String type,
  ) {
    return FutureBuilder(
      future: Future.wait([
        _firestore.collection('users').doc(data['senderId']).get(),
        _firestore.collection('users').doc(data['receiverId']).get(),
        _firestore.collection('productos').doc(data['productId']).get(),
      ]),
      builder: (context, AsyncSnapshot<List<DocumentSnapshot>> userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingTile();
        }
        if (userSnapshot.hasError) return _buildErrorTile();

        final sender =
            userSnapshot.data?[0].data() as Map<String, dynamic>? ?? {};
        final receiver =
            userSnapshot.data?[1].data() as Map<String, dynamic>? ?? {};
        final product =
            userSnapshot.data?[2].data() as Map<String, dynamic>? ?? {};

        return _buildExchangeCard(
          data: data,
          product: product,
          sender: sender,
          receiver: receiver,
          type: type,
          exchangeId: doc.id,
        );
      },
    );
  }

  Widget _buildEmptyState(String type) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.swap_horiz, size: 50, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            type == 'sent'
                ? 'No has enviado intercambios'
                : 'No tienes intercambios recibidos',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    String exchangeId,
    Map<String, dynamic> exchangeData,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.check, color: Colors.green),
          onPressed: () => _updateExchangeStatus(
            exchangeId,
            'accepted',
            exchangeData['productId'],
            exchangeData['quantity'],
            exchangeData['senderId'],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.red),
          onPressed: () => _updateExchangeStatus(
            exchangeId,
            'rejected',
            exchangeData['productId'],
            exchangeData['quantity'],
            exchangeData['senderId'],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingTile() {
    return const ListTile(
      leading: CircularProgressIndicator(),
      title: Text('Cargando...'),
    );
  }

  Widget _buildErrorTile() {
    return const ListTile(
      leading: Icon(Icons.error, color: Colors.red),
      title: Text('Error al cargar datos'),
    );
  }

  Widget _buildExchangeCard({
    required Map<String, dynamic> data,
    required Map<String, dynamic> product,
    required Map<String, dynamic> sender,
    required Map<String, dynamic> receiver,
    required String type,
    required String exchangeId,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(
          product['nombre']?.toString() ?? 'Producto desconocido',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cantidad: ${data['quantity'] ?? 'N/A'}'),
            Text('Estado: ${_getStatusText(data['status'])}'),
            Text('Fecha: ${_formatDate(data['createdAt'])}'),
            Text(
              type == 'sent'
                  ? 'Para: ${receiver['nombre']} ${receiver['apellido']}'
                  : 'De: ${sender['nombre']} ${sender['apellido']}',
            ),
          ],
        ),
        trailing: type == 'received' && data['status'] == 'pending'
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => _updateExchangeStatus(
                      exchangeId,
                      'accepted',
                      data['productId'],
                      data['quantity'],
                      data['senderId'],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => _updateExchangeStatus(
                      exchangeId,
                      'rejected',
                      data['productId'],
                      data['quantity'],
                      data['senderId'],
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'accepted':
        return 'Aceptado';
      case 'rejected':
        return 'Rechazado';
      default:
        return 'Desconocido';
    }
  }

  String _formatDate(dynamic timestamp) {
    try {
      return DateFormat('dd/MM/yyyy').format((timestamp as Timestamp).toDate());
    } catch (e) {
      return 'Fecha inválida';
    }
  }

  Future<void> _updateExchangeStatus(
    String exchangeId,
    String newStatus,
    String productId,
    int quantity,
    String senderId,
  ) async {
    setState(() => _isLoading = true);

    try {
      final batch = _firestore.batch();
      final exchangeRef = _firestore.collection('intercambios').doc(exchangeId);

      batch.update(exchangeRef, {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (newStatus == 'accepted') {
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          final userProductRef = _firestore
              .collection('user_products')
              .where('userId', isEqualTo: currentUser.uid)
              .where('productId', isEqualTo: productId)
              .limit(1);

          final snapshot = await userProductRef.get();
          if (snapshot.docs.isNotEmpty) {
            batch.update(snapshot.docs.first.reference, {
              'cantidad': FieldValue.increment(quantity),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } else {
            batch.set(_firestore.collection('user_products').doc(), {
              'userId': currentUser.uid,
              'productId': productId,
              'cantidad': quantity,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      if (newStatus == 'rejected') {
        final senderProductRef = _firestore
            .collection('user_products')
            .where('userId', isEqualTo: senderId)
            .where('productId', isEqualTo: productId)
            .limit(1);

        final snapshot = await senderProductRef.get();
        if (snapshot.docs.isNotEmpty) {
          batch.update(snapshot.docs.first.reference, {
            'cantidad': FieldValue.increment(quantity),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Intercambio ${_getStatusText(newStatus)}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Intercambios'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.upload), text: 'Enviados'),
            Tab(icon: Icon(Icons.download), text: 'Recibidos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildExchangeList('sent'), _buildExchangeList('received')],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _showNewExchangeDialog,
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.add),
      ),
    );
  }

  void _showNewExchangeDialog() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    showDialog(
      context: context,
      builder: (context) {
        String? selectedUserId;
        String? selectedProductId;
        int quantity = 1;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Nuevo Intercambio'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Selector de usuario
                    StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('users')
                          .where(
                            FieldPath.documentId,
                            isNotEqualTo: currentUser.uid,
                          )
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Text('Error al cargar usuarios');
                        }
                        if (!snapshot.hasData) {
                          return const CircularProgressIndicator();
                        }
                        return DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Seleccionar Usuario',
                            border: OutlineInputBorder(),
                          ),
                          items: snapshot.data!.docs.map((doc) {
                            final user = doc.data() as Map<String, dynamic>;
                            return DropdownMenuItem(
                              value: doc.id,
                              child: Text(
                                '${user['nombre']} ${user['apellido']}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) =>
                              setState(() => selectedUserId = value),
                          validator: (value) =>
                              value == null ? 'Selecciona un usuario' : null,
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // Selector de producto
                    StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('user_products')
                          .where('userId', isEqualTo: currentUser.uid)
                          .where('cantidad', isGreaterThan: 0)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Text('Error al cargar productos');
                        }
                        if (!snapshot.hasData) {
                          return const CircularProgressIndicator();
                        }
                        return DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Seleccionar Producto',
                            border: OutlineInputBorder(),
                          ),
                          items: snapshot.data!.docs.map<DropdownMenuItem<String>>((
                            doc,
                          ) {
                            final up = doc.data() as Map<String, dynamic>;
                            return DropdownMenuItem<String>(
                              value:
                                  up['productId']
                                      as String, // Aseguramos que es String
                              child: FutureBuilder<DocumentSnapshot>(
                                future: _firestore
                                    .collection('productos')
                                    .doc(
                                      up['productId'] as String,
                                    ) // Aseguramos que es String
                                    .get(),
                                builder: (context, productSnapshot) {
                                  if (productSnapshot.hasError) {
                                    return const Text(
                                      'Error al cargar producto',
                                    );
                                  }
                                  if (!productSnapshot.hasData) {
                                    return const Text('Cargando...');
                                  }
                                  final product =
                                      productSnapshot.data!.data()
                                          as Map<String, dynamic>?;
                                  return Text(
                                    '${product?['nombre'] ?? 'Producto'} (${up['cantidad']} disp.)',
                                    overflow: TextOverflow.ellipsis,
                                  );
                                },
                              ),
                            );
                          }).toList(),
                          onChanged: (value) =>
                              setState(() => selectedProductId = value),
                          validator: (value) =>
                              value == null ? 'Selecciona un producto' : null,
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // Campo de cantidad
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Cantidad',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      initialValue: '1',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingresa una cantidad';
                        }
                        final qty = int.tryParse(value) ?? 0;
                        if (qty <= 0) {
                          return 'La cantidad debe ser mayor a 0';
                        }
                        return null;
                      },
                      onChanged: (value) => quantity = int.tryParse(value) ?? 1,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: selectedUserId == null || selectedProductId == null
                      ? null
                      : () {
                          _createExchange(
                            recipientId: selectedUserId!,
                            productId: selectedProductId!,
                            quantity: quantity,
                          ).then((_) => Navigator.pop(context));
                        },
                  child: const Text('Enviar Intercambio'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
