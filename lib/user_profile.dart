import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
              child: CircleAvatar(
                radius: 50,
                backgroundImage: profileImageUrl != null
                    ? CachedNetworkImageProvider(profileImageUrl!)
                    : AssetImage('assets/default_profile.png') as ImageProvider,
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
                          subtitle: Text('${pet['petType']} ${pet['petBreed']}'),
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
}
