import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'user_edit.dart'; // Importar la pantalla de edición de perfil
import 'pet_profile.dart'; // Importar la pantalla del perfil de la mascota

class UserProfileScreen extends StatefulWidget {
  final String? userId;

  UserProfileScreen({this.userId});

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? profileImageUrl, username, profileName, bio;
  List<DocumentSnapshot>? pets;
  bool isOwner = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadUserPets();
  }

  Future<void> _loadUserProfile() async {
    String userId = widget.userId ?? _auth.currentUser!.uid;
    DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
    setState(() {
      profileImageUrl = userDoc['profileImageUrl'];
      username = userDoc['username'];
      profileName = userDoc['profileName'];
      bio = userDoc['bio'];
      isOwner = userId == _auth.currentUser!.uid;
    });
  }

  Future<void> _loadUserPets() async {
    String userId = widget.userId ?? _auth.currentUser!.uid;
    QuerySnapshot petsQuery = await _firestore
        .collection('pets')
        .where('owner', isEqualTo: userId)
        .get();
    setState(() {
      pets = petsQuery.docs;
    });
  }

  void _navigateToEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserEditScreen(),
      ),
    ).then((_) => _loadUserProfile());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('@$username'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: profileImageUrl != null
                        ? CachedNetworkImageProvider(profileImageUrl!)
                        : AssetImage('assets/default_profile.png') as ImageProvider,
                  ),
                  if (isOwner)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _navigateToEditProfile,
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: Colors.blue,
                          child: Icon(Icons.edit, color: Colors.white, size: 15),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              profileName ?? '',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              bio ?? '',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'Mascotas (${pets?.length ?? 0})',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: pets != null
                  ? ListView.builder(
                      itemCount: pets!.length,
                      itemBuilder: (context, index) {
                        var pet = pets![index].data() as Map<String, dynamic>;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: pet['petImageUrl'] != null
                                ? CachedNetworkImageProvider(pet['petImageUrl'])
                                : AssetImage('assets/default_pet.png') as ImageProvider,
                          ),
                          title: Row(
                            children: [
                              Text(pet['petName']),
                              if (pet['verified'] == true)
                                Icon(Icons.verified, color: Colors.blue, size: 16),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${pet['petType']} ${pet['petBreed']}'),
                              if (pet['estado'] != null) _buildEstadoTag(pet['estado']),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PetProfileScreen(petId: pets![index].id),
                              ),
                            );
                          },
                        );
                      },
                    )
                  : Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoTag(String estado) {
    Color bgColor;
    String text;
    IconData icon;

    switch (estado) {
      case 'enadopcion':
        bgColor = Colors.brown;
        text = 'En adopción';
        icon = Icons.pets;
        break;
      case 'enmemoria':
        bgColor = Colors.lightBlueAccent;
        text = 'En memoria';
        icon = Icons.book;
        break;
      case 'perdido':
        bgColor = Colors.red;
        text = 'Me perdí :(';
        icon = Icons.location_off;
        break;
      default:
        return SizedBox.shrink(); // No mostrar nada si el estado es vacío o no reconocido
    }

    return Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
