import 'package:aplicacion1/categories_screen.dart';
import 'package:aplicacion1/exchanges_screen.dart';
import 'package:aplicacion1/firebase_options.dart';
import 'package:aplicacion1/inventory_screen.dart';
import 'package:aplicacion1/products_screen.dart';
import 'package:aplicacion1/users_screen.dart';
import 'package:aplicacion1/user_products_screen.dart';
import 'package:aplicacion1/assign_product_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    FirebaseUIAuth.configureProviders([EmailAuthProvider()]);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
      ),
      initialRoute: FirebaseAuth.instance.currentUser == null
          ? '/sign-in'
          : '/profile',
      routes: {
        '/sign-in': (context) => SignInScreen(
          providers: [EmailAuthProvider()],
          actions: [
            AuthStateChangeAction<SignedIn>((context, state) {
              Navigator.pushReplacementNamed(context, '/profile');
            }),
            AuthStateChangeAction<UserCreated>((context, state) {
              Navigator.pushReplacementNamed(context, '/profile');
            }),
          ],
        ),
        '/profile': (context) => const CustomProfileScreen(),
        '/users': (context) => const UsersScreen(),
        '/categories': (context) => const CategoriesScreen(),
        '/products': (context) => const ProductsScreen(),
        '/exchanges': (context) => const ExchangeScreen(),
        // '/messages': (context) =>
        //     const MessagesScreen(), // Nueva ruta para mensajes
        // '/ratings': (context) =>
        //     const RatingsScreen(), // Nueva ruta para valoraciones
        '/assign-product': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return AssignProductScreen(
            productId: args['productId'],
            productName: args['productName'],
          );
        },
        '/inventory': (context) => const InventoryScreen(),
      },
    );
  }
}

class CustomProfileScreen extends StatelessWidget {
  const CustomProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/sign-in');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Sección de información del perfil
              SizedBox(
                height: 200,
                child: ProfileScreen(
                  providers: [EmailAuthProvider()],
                  actions: [
                    SignedOutAction((context) {
                      Navigator.pushReplacementNamed(context, '/sign-in');
                    }),
                  ],
                ),
              ),

              // Botones de navegación
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 1.3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    _buildMenuButton(
                      context,
                      icon: Icons.people,
                      label: 'Usuarios',
                      onPressed: () {
                        Navigator.pushNamed(context, '/users');
                      },
                    ),
                    _buildMenuButton(
                      context,
                      icon: Icons.shopping_bag,
                      label: 'Productos',
                      onPressed: () {
                        Navigator.pushNamed(context, '/products');
                      },
                    ),
                    _buildMenuButton(
                      context,
                      icon: Icons.category,
                      label: 'Categorías',
                      onPressed: () {
                        Navigator.pushNamed(context, '/categories');
                      },
                    ),
                    _buildMenuButton(
                      context,
                      icon: Icons.swap_horiz,
                      label: 'Intercambios',
                      onPressed: () {
                        Navigator.pushNamed(context, '/exchanges');
                      },
                    ),
                    _buildMenuButton(
                      context,
                      icon: Icons.message,
                      label: 'Mensajes',
                      onPressed: () {
                        Navigator.pushNamed(context, '/messages');
                      },
                    ),
                    _buildMenuButton(
                      context,
                      icon: Icons.star,
                      label: 'Valoraciones',
                      onPressed: () {
                        Navigator.pushNamed(context, '/ratings');
                      },
                    ),
                    _buildMenuButton(
                      context,
                      icon: Icons.warehouse,
                      label: 'Inventario',
                      onPressed: () {
                        Navigator.pushNamed(context, '/inventory');
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
  }) {
    return Material(
      borderRadius: BorderRadius.circular(12),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 36,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
