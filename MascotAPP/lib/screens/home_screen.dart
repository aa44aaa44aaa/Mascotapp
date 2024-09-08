import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../applications/applyrefugioscreen.dart';
import '../login/login_screen.dart';
import '../user/user_profile.dart';
import '../user/user_edit.dart';
import '../posts/create_post.dart';
import 'notifications_screen.dart';
import 'pets_screen.dart';
import 'feed_screen.dart';
import 'adoptar_screen.dart';
import 'pending_posts_screen.dart';
//import 'package:Mascotapp/mini_games_screen.dart';

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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadNotifications();
    _checkIfPetOwner();
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
    setState(() {});
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  final List<Widget> _screens = [
    const FeedScreen(),
    const CreatePostScreen(),
    const PetsScreen(),
    const AdoptarScreen(),
    //const MiniGamesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _buildDrawer(),
      appBar: AppBar(
        title: const Text('MascotAPP'),
        automaticallyImplyLeading: false,
        actions: [
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
                if (userRole == 'refugio') // Verificamos si el rol es "refugio"
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Icon(
                      Icons.pets, // Icono de la patita
                      color: Colors.orange,
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
            icon: Icon(Icons.camera_alt),
            label: 'Crear Post',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pets),
            label: 'Mis Mascotas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.volunteer_activism),
            label: 'Adoptar',
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
