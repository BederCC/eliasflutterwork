# 🔄 EcoIntercambio - App de Trueque Sostenible

![Logo o Captura Principal](screenshots/demo.jpg) *[(Reemplazar con imagen real)]*

Aplicación móvil para intercambiar productos/servicios de manera sostenible, conectando usuarios con intereses comunes.

## 🌱 Entidades Principales
- **Usuarios**: Perfiles con datos personales e historial.
- **Productos/Servicios**: Items disponibles para intercambio.
- **Categorías**: Alimentos, ropa, reciclaje, etc.
- **Intercambios**: Registro de transacciones completadas.
- **Mensajes**: Chat integrado entre usuarios.
- **Valoraciones**: Sistema de reputación post-intercambio.

## 🛠 Tecnologías
- **Frontend**: Flutter (Dart)
- **Backend**: Firebase
  - Autenticación (Firebase Auth)
  - Base de datos: Firestore
  - Almacenamiento: Firebase Storage *(si aplica)*

## 📦 Estructura del Proyecto
```plaintext
lib/
├── auth/                     # Autenticación
├── screens/                  # Pantallas principales
│   ├── categories_screen.dart
│   ├── exchanges_screen.dart
│   ├── inventory_screen.dart
│   ├── messages_screen.dart
│   ├── products_screen.dart
│   ├── ratings_screen.dart
│   ├── users_screen.dart
│   ├── user_products_screen.dart
│   └── assign_product_screen.dart
├── models/                  # Entidades (User, Product, etc.)
├── services/                # Lógica de Firebase
└── main.dart                # Punto de entrada