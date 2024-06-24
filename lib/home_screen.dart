import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'user_profile.dart';
import 'pets_screen.dart';
import 'create_post.dart';
import 'notifications_screen.dart';
import 'feed_screen.dart';
import 'pending_posts_screen.dart';
import 'login_screen.dart';
import 'user_edit.dart'; // Importa el archivo user_edit.dart

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? profileImageUrl;
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
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      setState(() {
        profileImageUrl = userDoc['profileImageUrl'];
      });
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
      setState(() {
        _notificationCount = notifications.docs.length;
      });
    }
  }

  Future<void> _checkIfPetOwner() async {
    User? user = _auth.currentUser;
    if (user != null) {
      QuerySnapshot pets = await _firestore.collection('pets').where('ownerId', isEqualTo: user.uid).get();
      if (pets.docs.isNotEmpty) {
        setState(() {
          _isPetOwner = true;
        });
        await _loadPendingPosts();
      }
    }
  }

  Future<void> _loadPendingPosts() async {
    User? user = _auth.currentUser;
    if (user != null) {
      QuerySnapshot pendingPosts = await _firestore
          .collection('pending_posts')
          .where('petId', whereIn: (await _firestore
              .collection('pets')
              .where('ownerId', isEqualTo: user.uid)
              .get())
              .docs
              .map((doc) => doc.id)
              .toList())
          .where('status', isEqualTo: 'pending')
          .get();
      setState(() {
        _pendingPostCount = pendingPosts.docs.length;
      });
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
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  final List<Widget> _screens = [
    FeedScreen(),
    //FeedScreen(),
    CreatePostScreen(),
    PetsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _buildDrawer(),
      appBar: AppBar(
        title: Text('MascotAPP'),
        automaticallyImplyLeading: false,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.favorite),
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
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: Text(
                      '$_notificationCount',
                      style: TextStyle(
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
                  icon: Icon(Icons.camera_alt),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PendingPostsScreen(),
                      ),
                    ).then((value) => _loadPendingPosts());
                  },
                ),
                Positioned(
                  right: 11,
                  top: 11,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: Text(
                      '$_pendingPostCount',
                      style: TextStyle(
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
                  builder: (context) => UserProfileScreen(),
                ),
              );
            },
            onLongPress: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
            child: CircleAvatar(
              backgroundImage: profileImageUrl != null
                  ? CachedNetworkImageProvider(profileImageUrl!)
                  : AssetImage('assets/default_profile.png') as ImageProvider,
            ),
          ),
          SizedBox(width: 16.0),
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
          //BottomNavigationBarItem(
          //  icon: Icon(Icons.home),
          //  label: 'Feed2',
          //),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Crear Post',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pets),
            label: 'Mascotas',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
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
            leading: Icon(Icons.settings),
            title: Text('Configuración'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserEditScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.exit_to_app),
            title: Text('Salir'),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}
