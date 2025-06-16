// user_products_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProductsScreen extends StatelessWidget {
  const UserProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Debes iniciar sesión')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Productos')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('user_products')
            .where('userId', isEqualTo: currentUser.uid)
            .where('cantidad', isGreaterThan: 0)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No tienes productos asignados'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final userProductDoc = snapshot.data!.docs[index];
              final userProductData =
                  userProductDoc.data() as Map<String, dynamic>;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('productos')
                    .doc(userProductData['productId'])
                    .get(),
                builder: (context, productSnapshot) {
                  if (productSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const ListTile(title: Text('Cargando...'));
                  }

                  if (!productSnapshot.hasData) {
                    return const ListTile(
                      title: Text('Producto no encontrado'),
                    );
                  }

                  final productData =
                      productSnapshot.data!.data() as Map<String, dynamic>;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      title: Text(productData['nombre']),
                      subtitle: Text(
                        'Cantidad: ${userProductData['cantidad']}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.swap_horiz),
                        onPressed: () {
                          // Navegar a pantalla de intercambio
                        },
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
