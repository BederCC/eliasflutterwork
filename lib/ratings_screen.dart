import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RatingsScreen extends StatefulWidget {
  const RatingsScreen({super.key});

  @override
  State<RatingsScreen> createState() => _RatingsTabsScreenState();
}

class _RatingsTabsScreenState extends State<RatingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Valoraciones'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.star_outline), text: 'Valorar'),
            Tab(icon: Icon(Icons.list_alt), text: 'Reseñas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [RateProductsTab(), ReviewsTab()],
      ),
    );
  }
}

// Pestaña para valorar productos (la que ya teníamos)
class RateProductsTab extends StatelessWidget {
  const RateProductsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('productos').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No hay productos disponibles'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final product = snapshot.data!.docs[index];
            return ProductRatingCard(
              productId: product.id,
              productData: product.data() as Map<String, dynamic>,
            );
          },
        );
      },
    );
  }
}

// Nueva pestaña para ver reseñas
class ReviewsTab extends StatelessWidget {
  const ReviewsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('productos').snapshots(),
      builder: (context, productsSnapshot) {
        if (productsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (productsSnapshot.hasError) {
          return Center(child: Text('Error: ${productsSnapshot.error}'));
        }

        if (!productsSnapshot.hasData || productsSnapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No hay productos disponibles'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: productsSnapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final product = productsSnapshot.data!.docs[index];
            final productData = product.data() as Map<String, dynamic>;

            return ProductReviewsCard(
              productId: product.id,
              productName: productData['nombre'] ?? 'Producto',
              productDescription: productData['descripcion'] ?? '',
            );
          },
        );
      },
    );
  }
}

class ProductRatingCard extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;

  const ProductRatingCard({
    required this.productId,
    required this.productData,
    super.key,
  });

  @override
  State<ProductRatingCard> createState() => _ProductRatingCardState();
}

class _ProductRatingCardState extends State<ProductRatingCard> {
  int _userRating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadUserRating();
  }

  Future<void> _loadUserRating() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ratingDoc = await FirebaseFirestore.instance
        .collection('ratings')
        .where('productId', isEqualTo: widget.productId)
        .where('userId', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (ratingDoc.docs.isNotEmpty) {
      final ratingData = ratingDoc.docs.first.data();
      setState(() {
        _userRating = ratingData['rating'] ?? 0;
        _commentController.text = ratingData['comment'] ?? '';
      });
    }
  }

  Future<void> _submitRating() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _userRating == 0) return;

    setState(() => _isSubmitting = true);

    try {
      final existingRating = await FirebaseFirestore.instance
          .collection('ratings')
          .where('productId', isEqualTo: widget.productId)
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      final ratingData = {
        'productId': widget.productId,
        'userId': user.uid,
        'rating': _userRating,
        'comment': _commentController.text,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (existingRating.docs.isEmpty) {
        ratingData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('ratings').add(ratingData);
      } else {
        await FirebaseFirestore.instance
            .collection('ratings')
            .doc(existingRating.docs.first.id)
            .update(ratingData);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valoración guardada exitosamente')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.productData['nombre'] ?? 'Producto',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(widget.productData['descripcion'] ?? ''),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    _userRating >= index + 1 ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 32,
                  ),
                  onPressed: () => setState(() => _userRating = index + 1),
                );
              }),
            ),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'Comentario (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting || _userRating == 0
                    ? null
                    : _submitRating,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('ENVIAR VALORACIÓN'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductReviewsCard extends StatelessWidget {
  final String productId;
  final String productName;
  final String productDescription;

  const ProductReviewsCard({
    required this.productId,
    required this.productName,
    required this.productDescription,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              productName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(productDescription),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('ratings')
                  .where('productId', isEqualTo: productId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text('No hay valoraciones aún'),
                  );
                }

                final ratings = snapshot.data!.docs;
                final average =
                    ratings
                        .map(
                          (r) =>
                              (r.data() as Map<String, dynamic>)['rating']
                                  as int,
                        )
                        .reduce((a, b) => a + b) /
                    ratings.length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Promedio: ${average.toStringAsFixed(1)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.star, color: Colors.amber, size: 20),
                        Text(' (${ratings.length})'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Últimas valoraciones:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...ratings.take(3).map((ratingDoc) {
                      final rating = ratingDoc.data() as Map<String, dynamic>;
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(rating['userId'])
                            .get(),
                        builder: (context, userSnapshot) {
                          if (!userSnapshot.hasData) {
                            return const SizedBox();
                          }
                          final user =
                              userSnapshot.data!.data() as Map<String, dynamic>;
                          return ListTile(
                            leading: const Icon(Icons.account_circle),
                            title: Text(
                              '${user['nombre']} ${user['apellido']}',
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: List.generate(5, (index) {
                                    return Icon(
                                      Icons.star,
                                      color: index < (rating['rating'] as int)
                                          ? Colors.amber
                                          : Colors.grey,
                                      size: 16,
                                    );
                                  }),
                                ),
                                if (rating['comment'] != null &&
                                    rating['comment'].isNotEmpty)
                                  Text(rating['comment']),
                              ],
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
