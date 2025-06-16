import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
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

  Future<void> _sendMessage({
    required String recipientId,
    required String content,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      await _firestore.collection('messages').add({
        'senderId': currentUser.uid,
        'recipientId': recipientId,
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false, // Solo el destinatario necesita este campo
        // Eliminamos el campo 'type' ya que no lo necesitaremos
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mensaje enviado exitosamente')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar mensaje: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildMessageList(String type) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('messages')
          .where(
            type == 'sent' ? 'senderId' : 'recipientId',
            isEqualTo: currentUser.uid,
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(type);
        }

        // Filtrar y ordenar localmente
        final messages =
            snapshot.data!.docs
                .map((doc) => doc.data() as Map<String, dynamic>)
                .toList()
              ..sort(
                (a, b) => (b['createdAt'] as Timestamp).compareTo(
                  a['createdAt'] as Timestamp,
                ),
              );

        return ListView.builder(
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final doc =
                snapshot.data!.docs[index]; // Obtenemos el documento completo
            final messageData = doc.data() as Map<String, dynamic>;
            return _buildMessageItem(
              messageData,
              type,
              doc.id,
            ); // Pasamos el ID
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String type) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.message, size: 50, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            type == 'sent'
                ? 'No has enviado mensajes'
                : 'No tienes mensajes recibidos',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(
    Map<String, dynamic> messageData,
    String type,
    String messageId,
  ) {
    final isUnread = type == 'received' && !messageData['read'];

    return FutureBuilder(
      future: Future.wait([
        _firestore.collection('users').doc(messageData['senderId']).get(),
        _firestore.collection('users').doc(messageData['recipientId']).get(),
      ]),
      builder: (context, AsyncSnapshot<List<DocumentSnapshot>> userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const ListTile(title: Text('Cargando...'));
        }

        final sender = userSnapshot.data![0].data() as Map<String, dynamic>;
        final recipient = userSnapshot.data![1].data() as Map<String, dynamic>;

        return GestureDetector(
          onTap: () {
            if (isUnread) {
              _markAsRead(messageId); // Usamos el ID que recibimos
            }
          },
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isUnread
                ? Colors.blue[50]
                : null, // Fondo azul claro para no leídos
            elevation: isUnread ? 4 : 1, // Mayor elevación para no leídos
            shape: RoundedRectangleBorder(
              side: isUnread
                  ? BorderSide(color: Colors.blue, width: 2)
                  : BorderSide.none,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: CircleAvatar(
                backgroundColor: isUnread ? Colors.blue : Colors.grey,
                child: Icon(
                  type == 'sent' ? Icons.outbox : Icons.inbox,
                  color: Colors.white,
                ),
              ),
              title: Text(
                type == 'sent'
                    ? 'Para: ${recipient['nombre']} ${recipient['apellido']}'
                    : 'De: ${sender['nombre']} ${sender['apellido']}',
                style: TextStyle(
                  fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                  color: isUnread ? Colors.blue[800] : Colors.black,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    messageData['content'],
                    style: TextStyle(
                      fontWeight: isUnread
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat(
                          'dd/MM/yyyy HH:mm',
                        ).format(messageData['createdAt'].toDate()),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      if (isUnread) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'NUEVO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _markAsRead(String messageId) async {
    try {
      await _firestore.collection('messages').doc(messageId).update({
        'read': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al marcar como leído: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mensajes'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.outbox), text: 'Enviados'),
            Tab(icon: Icon(Icons.inbox), text: 'Recibidos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildMessageList('sent'), _buildMessageList('received')],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : () => _showNewMessageDialog(),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.send),
      ),
    );
  }

  void _showNewMessageDialog() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    String? selectedUserId;
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            // Cambiado a setStateDialog para evitar confusión
            return AlertDialog(
              title: const Text('Nuevo Mensaje'),
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
                        if (!snapshot.hasData) {
                          return const CircularProgressIndicator();
                        }
                        return DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Seleccionar Usuario',
                          ),
                          items: snapshot.data!.docs.map((userDoc) {
                            final userData =
                                userDoc.data() as Map<String, dynamic>;
                            return DropdownMenuItem(
                              value: userDoc.id,
                              child: Text(
                                '${userData['nombre']} ${userData['apellido']}',
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setStateDialog(() {
                              // Usar setStateDialog para actualizar el estado del diálogo
                              selectedUserId = value;
                            });
                          },
                          validator: (value) =>
                              value == null ? 'Selecciona un usuario' : null,
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    // Campo de mensaje
                    TextFormField(
                      controller: messageController,
                      decoration: const InputDecoration(
                        labelText: 'Mensaje',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
                      onChanged: (value) {
                        setStateDialog(
                          () {},
                        ); // Actualizar estado cuando cambia el texto
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Escribe un mensaje';
                        }
                        return null;
                      },
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
                  onPressed:
                      selectedUserId == null || messageController.text.isEmpty
                      ? null
                      : () {
                          _sendMessage(
                            recipientId: selectedUserId!,
                            content: messageController.text,
                          ).then((_) {
                            messageController.clear();
                            Navigator.pop(context);
                          });
                        },
                  child: const Text('Enviar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
