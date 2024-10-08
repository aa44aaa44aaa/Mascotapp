import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../applications/applyrefugio_screen.dart';
import '../applications/solicitudes_adopt_screen.dart';
import '../login/login_screen.dart';
import '../user/user_profile.dart';
import '../user/user_edit.dart';
import '../posts/create_post.dart';
import 'notifications_screen.dart';
import 'pets_screen.dart';
import 'feed_screen.dart';
import 'personalfeed_screen.dart';
import 'adoptar_screen.dart';
import 'pending_posts_screen.dart';
import '../admin/solicitudes_refugio_screen.dart';
import 'mini_games_screen.dart';
import '../admin/user_finder.dart';
import '../admin/mascota_finder.dart';
import '../admin/admin_email_edit.dart';
import 'map_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? profileImageUrl;
  String? userRole; // Añadido el rol del usuario
  int _selectedIndex = 0;
  int _notificationCount = 0;
  int _pendingPostCount = 0;
  bool _isPetOwner = false;
  int _adoptionRequestCount = 0;
  int _adoptionFreshRequestCount = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _checkUserSession();
  }

  Future<void> _checkUserSession() async {
    User? user = _auth.currentUser;

    if (user == null) {
      _showSessionExpiredDialog();
    } else {
      _loadNotifications();
      _checkIfPetOwner();
      _loadAdoptionRequests();
      _loadAdoptionFreshRequests();
      _loadUserProfile();
    }
  }

  Future<void> _loadAdoptionRequests() async {
    User? user = _auth.currentUser;
    if (user != null) {
      QuerySnapshot requests = await _firestore
          .collection('ApplyAdopt')
          .where('idRefugio', isEqualTo: user.uid)
          .get();
      if (mounted) {
        setState(() {
          _adoptionRequestCount = requests.docs.length;
        });
      }
    }
  }

  Future<void> _loadAdoptionFreshRequests() async {
    User? user = _auth.currentUser;
    if (user != null) {
      QuerySnapshot requests = await _firestore
          .collection('ApplyAdopt')
          .where('idRefugio', isEqualTo: user.uid)
          .where('revisado', isEqualTo: false)
          .get();
      if (mounted) {
        setState(() {
          _adoptionFreshRequestCount = requests.docs.length;
        });
      }
    }
  }

  Future<void> _loadUserProfile() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          profileImageUrl = userDoc['profileImageUrl'];
          userRole = userDoc['rol']; // Obtenemos el rol del usuario
        });
      }
    }
  }

  Future<void> _loadNotifications() async {
    User? user = _auth.currentUser;
    if (user != null) {
      QuerySnapshot notifications = await _firestore
          .collection('notifications')
          .where('recipient', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .get();
      if (mounted) {
        setState(() {
          _notificationCount = notifications.docs.length;
        });
      }
    }
  }

  Future<void> _checkIfPetOwner() async {
    User? user = _auth.currentUser;
    if (user != null) {
      QuerySnapshot pets = await _firestore
          .collection('pets')
          .where('ownerId', isEqualTo: user.uid)
          .get();
      if (pets.docs.isNotEmpty) {
        if (mounted) {
          setState(() {
            _isPetOwner = true;
          });
        }
        await _loadPendingPosts();
      }
    }
  }

  Future<void> _loadPendingPosts() async {
    User? user = _auth.currentUser;
    if (user != null) {
      QuerySnapshot pendingPosts = await _firestore
          .collection('pending_posts')
          .where('petId',
              whereIn: (await _firestore
                      .collection('pets')
                      .where('ownerId', isEqualTo: user.uid)
                      .get())
                  .docs
                  .map((doc) => doc.id)
                  .toList())
          .where('status', isEqualTo: 'pending')
          .get();
      if (mounted) {
        setState(() {
          _pendingPostCount = pendingPosts.docs.length;
        });
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _refreshFeed() async {
    await _loadNotifications();
    if (_isPetOwner) {
      await _loadPendingPosts();
    }
    _loadAdoptionRequests();
    _loadAdoptionFreshRequests();
    // Aquí se invoca setState para reconstruir el widget con los nuevos datos
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  Future<void> _showSessionExpiredDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sesión expirada'),
          content:
              const Text('Su sesión ha expirado, vuelva a ingresar por favor.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  final List<Widget> _screens = [
    const FeedScreen(),
    const PersonalFeedScreen(),
    const CreatePostScreen(),
    const PetsScreen(),
    //const AdoptarScreen(),
    const MapScreen(),
    //const MiniGamesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _buildDrawer(),
      drawerEdgeDragWidth: _selectedIndex == 4
          ? 0 // Desactiva el swipe cuando estés en la pantalla de mapa
          : MediaQuery.of(context)
              .size
              .width, // Swipe activado en otras pantallas// Swipe para abrir drawer
      appBar: AppBar(
        title: const Text('MascotAPP'),
        automaticallyImplyLeading: false,
        actions: [
          if (userRole == 'refugio' || _adoptionRequestCount > 0)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.assignment),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdoptionRequestsScreen(),
                      ),
                    ).then((value) => _loadAdoptionRequests());
                  },
                ),
                if (_adoptionFreshRequestCount > 0)
                  Positioned(
                    right: 11,
                    top: 11,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      child: Text(
                        '$_adoptionFreshRequestCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.favorite),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NotificationsScreen(),
                    ),
                  ).then((value) => _loadNotifications());
                },
              ),
              if (_notificationCount > 0)
                Positioned(
                  right: 11,
                  top: 11,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: Text(
                      '$_notificationCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          if (_isPetOwner && _pendingPostCount > 0)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.camera_alt),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PendingPostsScreen(),
                      ),
                    ).then((value) => _loadPendingPosts());
                  },
                ),
                Positioned(
                  right: 11,
                  top: 11,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: Text(
                      '$_pendingPostCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserProfileScreen(),
                ),
              );
            },
            onLongPress: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
            child: Stack(
              children: [
                CircleAvatar(
                  backgroundImage: profileImageUrl != null
                      ? CachedNetworkImageProvider(profileImageUrl!)
                      : const AssetImage('assets/default_profile.png')
                          as ImageProvider,
                ),
                if (userRole == 'refugio')
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Icon(
                      Icons.pets,
                      color: Colors.orange,
                      size: 20,
                    ),
                  ),
                if (userRole == 'admin')
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Icon(
                      Icons.verified_user,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16.0),
        ],
      ),
      body: _selectedIndex == 0
          ? RefreshIndicator(
              onRefresh: _refreshFeed,
              child: _screens[_selectedIndex],
            )
          : _screens[_selectedIndex],

      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Fan & Amigos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Crear Post',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pets),
            label: 'Mis Mascotas',
          ),
          //BottomNavigationBarItem(
          //  icon: Icon(Icons.volunteer_activism),
          //  label: 'Adoptar',
          //),
          BottomNavigationBarItem(
            icon: Icon(Icons.location_city),
            label: 'Mapa',
          ),
          //BottomNavigationBarItem(
          //  icon: Icon(Icons.gamepad), // Icono de control de juego
          //  label: 'Minijuegos',
          //),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.red, // Color del icono seleccionado
        unselectedItemColor:
            Colors.grey, // Color de los iconos no seleccionados
        backgroundColor: Colors.white, // Fondo de la barra de navegación
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Text(
              'Menú',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.pets),
            title: const Text('Ser refugio!'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ApplyRefugioScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Configuración'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserEditScreen(),
                ),
              );
            },
          ),
          // Opción de Optimización de Imágenes solo para admin
          if (userRole == 'admin')
            ListTile(
              leading: const Icon(Icons.shield, color: Colors.red),
              title: const Text('Buscador de usuarios'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserSearchScreen(),
                  ),
                );
              },
            ),
          if (userRole == 'admin')
            ListTile(
              leading: const Icon(Icons.shield, color: Colors.red),
              title: const Text('Buscador de mascotas'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PetSearchScreen(),
                  ),
                );
              },
            ),
          if (userRole == 'admin')
            ListTile(
              leading: const Icon(Icons.shield, color: Colors.red),
              title: const Text('Minigames (Private)'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MiniGamesScreen(),
                  ),
                );
              },
            ),
          if (userRole == 'admin')
            ListTile(
              leading: const Icon(Icons.shield, color: Colors.red),
              title: const Text('Solicitudes de Refugio'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RefugeRequestsScreen(),
                  ),
                );
              },
            ),
          if (userRole == 'admin')
            ListTile(
              leading: const Icon(Icons.shield, color: Colors.red),
              title: const Text('Lista de correos notificaciones admin'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminEmailScreen(),
                  ),
                );
              },
            ),
          ListTile(
            leading: const Icon(Icons.exit_to_app),
            title: const Text('Salir'),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}
