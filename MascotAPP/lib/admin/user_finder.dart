import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../user/user_profile.dart'; // Importar el perfil de usuario

class UserSearchScreen extends StatefulWidget {
  @override
  _UserSearchScreenState createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _allUsers = [];
  List<DocumentSnapshot> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _loadAllUsers();
  }

  Future<void> _loadAllUsers() async {
    QuerySnapshot querySnapshot = await _firestore.collection('users').get();
    setState(() {
      _allUsers = querySnapshot.docs;
      _filteredUsers = _allUsers;
    });
  }

  void _filterUsers(String query) {
    List<DocumentSnapshot> tempFilteredUsers = [];
    if (query.isNotEmpty) {
      tempFilteredUsers = _allUsers.where((userDoc) {
        String username = userDoc['username'].toString().toLowerCase();
        String profileName = userDoc['profileName'].toString().toLowerCase();
        return username.contains(query.toLowerCase()) ||
            profileName.contains(query.toLowerCase());
      }).toList();
    } else {
      tempFilteredUsers = _allUsers;
    }
    setState(() {
      _filteredUsers = tempFilteredUsers;
    });
  }

  Widget _buildRoleIcon(String? userRole) {
    if (userRole == null) return const SizedBox.shrink();

    switch (userRole) {
      case 'admin':
        return const Icon(Icons.verified_user, color: Colors.red, size: 20);
      case 'refugio':
        return const Icon(Icons.pets, color: Colors.orange, size: 20);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar Usuarios'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Campo de búsqueda
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar usuario',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onChanged: _filterUsers,
            ),
            const SizedBox(height: 16),
            // Lista de usuarios
            Expanded(
              child: _filteredUsers.isNotEmpty
                  ? ListView.builder(
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        var userDoc = _filteredUsers[index];
                        String userId = userDoc.id;

                        // Castear a Map<String, dynamic> para evitar el error
                        Map<String, dynamic>? userData =
                            userDoc.data() as Map<String, dynamic>?;
                        String? userRole =
                            userData != null && userData.containsKey('rol')
                                ? userData['rol']
                                : null;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: userData != null &&
                                    userData['profileImageUrl'] != null
                                ? CachedNetworkImageProvider(
                                    userData['profileImageUrl'])
                                : const AssetImage('assets/default_profile.png')
                                    as ImageProvider,
                          ),
                          title: Row(
                            children: [
                              Text(userData?['profileName'] ?? ''),
                              const SizedBox(width: 8),
                              _buildRoleIcon(userRole),
                            ],
                          ),
                          subtitle: Text('@${userData?['username'] ?? ''}'),
                          onTap: () {
                            // Navegar al perfil de usuario al hacer clic
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    UserProfileScreen(userId: userId),
                              ),
                            );
                          },
                        );
                      },
                    )
                  : const Center(child: Text('No se encontraron usuarios')),
            ),
          ],
        ),
      ),
    );
  }
}
