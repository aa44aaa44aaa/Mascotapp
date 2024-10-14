import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../user/user_profile.dart'; // Importar el perfil de usuario
import '../utils/mascotapp_colors.dart';

class FriendsScreen extends StatefulWidget {
  final String currentUserId;

  const FriendsScreen({Key? key, required this.currentUserId})
      : super(key: key);

  @override
  _FriendsScreenState createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<DocumentSnapshot> _friendsList = [];

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    try {
      // Obtener el documento del usuario actual
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(widget.currentUserId).get();

      List<dynamic> friendsIds = userDoc['friends'] ?? [];

      // Obtener la información de cada amigo basado en los IDs
      if (friendsIds.isNotEmpty) {
        QuerySnapshot friendsSnapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: friendsIds)
            .get();

        setState(() {
          _friendsList = friendsSnapshot.docs;
        });
      }
    } catch (e) {
      print('Error al cargar amigos: $e');
    }
  }

  Widget _buildRoleIcon(String? userRole) {
    if (userRole == null) return const SizedBox.shrink();

    switch (userRole) {
      case 'admin':
        return const Icon(Icons.verified_user,
            color: MascotAppColors.admin, size: 20);
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
        title: const Text('Amigos'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _friendsList.isNotEmpty
            ? ListView.builder(
                itemCount: _friendsList.length,
                itemBuilder: (context, index) {
                  var friendDoc = _friendsList[index];

                  // Castear a Map<String, dynamic> para evitar el error
                  Map<String, dynamic>? friendData =
                      friendDoc.data() as Map<String, dynamic>?;
                  String? userRole =
                      friendData != null && friendData.containsKey('rol')
                          ? friendData['rol']
                          : null;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: friendData != null &&
                              friendData['profileImageUrl'] != null
                          ? CachedNetworkImageProvider(
                              friendData['profileImageUrl'])
                          : const AssetImage('assets/default_profile.png')
                              as ImageProvider,
                    ),
                    title: Row(
                      children: [
                        Text(friendData?['profileName'] ?? ''),
                        const SizedBox(width: 8),
                        _buildRoleIcon(userRole),
                      ],
                    ),
                    subtitle: Text('@${friendData?['username'] ?? ''}'),
                    onTap: () {
                      // Navegar al perfil de usuario al hacer clic
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              UserProfileScreen(userId: friendDoc.id),
                        ),
                      );
                    },
                  );
                },
              )
            : const Center(child: Text('No se encontraron amigos')),
      ),
    );
  }
}
