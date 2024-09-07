import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importar FirebaseAuth
import 'create_post_friend.dart';
import 'user_profile.dart';
import 'single_post_screen.dart';

class PetProfileScreen extends StatefulWidget {
  final String petId;

  const PetProfileScreen({super.key, required this.petId});

  @override
  _PetProfileScreenState createState() => _PetProfileScreenState();
}

class _PetProfileScreenState extends State<PetProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  User? currentUser;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    _getCurrentUser(); // Llamar a la función para obtener el usuario actual
  }

  Future<void> _getCurrentUser() async {
    User? user = FirebaseAuth.instance.currentUser;
    setState(() {
      currentUser = user;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil de Mascota'),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('pets')
            .doc(widget.petId)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var pet = snapshot.data!.data() as Map<String, dynamic>;
          var ownerId = pet['owner'];
          var isVerified = pet['verified'] ?? false;
          var estado = pet['estado'];
          var textoestado = pet['textoestado'] ?? '';

          var birthDate = (pet['birthDate'] as Timestamp).toDate();
          var formattedBirthDate = DateFormat('dd-MM-yyyy').format(birthDate);

          var currentDate = DateTime.now();
          var ageYears = currentDate.year - birthDate.year;
          var ageMonths = currentDate.month - birthDate.month;

          if (currentDate.day < birthDate.day) {
            ageMonths--;
          }

          if (ageMonths < 0) {
            ageYears--;
            ageMonths += 12;
          }

          String ageString = '';
          if (ageYears > 0) {
            ageString += '$ageYears ${ageYears == 1 ? 'Año' : 'Años'}';
          }
          if (ageMonths > 0) {
            if (ageYears > 0) {
              ageString += ' / ';
            }
            ageString += '$ageMonths ${ageMonths == 1 ? 'Mes' : 'Meses'}';
          }

          Color borderColor = Colors.transparent;
          IconData? icon;
          String? message;

          if (estado != null) {
            switch (estado) {
              case 'perdido':
                borderColor = Colors.red;
                icon = Icons.location_off;
                message = 'Me perdí! :(';
                break;
              case 'enmemoria':
                borderColor = Colors.blueAccent;
                icon = Icons.book;
                message = 'En memoria';
                break;
              case 'adopcion':
                borderColor = Colors.brown;
                icon = Icons.pets;
                message = 'Estoy en adopción!';
                break;
            }
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      GestureDetector(
                        onTap: textoestado.isNotEmpty
                            ? () => _showMessage(textoestado)
                            : null,
                        child: CircleAvatar(
                          radius: 50,
                          backgroundImage: pet['petImageUrl'] != null
                              ? CachedNetworkImageProvider(pet['petImageUrl'])
                              : const AssetImage('assets/default_pet.png')
                                  as ImageProvider,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: borderColor, width: 4),
                              borderRadius: BorderRadius.circular(50),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (message != null && icon != null)
                  Column(
                    children: [
                      const SizedBox(height: 5),
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, color: borderColor),
                            const SizedBox(width: 4),
                            Text(
                              message,
                              style: TextStyle(
                                color: borderColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(icon, color: borderColor),
                          ],
                        ),
                      ),
                    ],
                  ),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        pet['petName'],
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 8),
                        const Tooltip(
                          message: 'Mascota Verificada',
                          child: Icon(Icons.verified,
                              color: Colors.blue, size: 24),
                        ),
                      ],
                    ],
                  ),
                ),
                Center(
                  child: Text(
                    '${pet['petType']} ${pet['petBreed']}',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                Center(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cake, size: 24),
                          Text(
                            ' $ageString',
                            style: const TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                      Text(
                        '($formattedBirthDate)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(ownerId)
                      .get(),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    var owner =
                        userSnapshot.data!.data() as Map<String, dynamic>;
                    var ownerProfileImageUrl = owner['profileImageUrl'];
                    var ownerRole = owner['rol']; // Obtén el rol del dueño

                    return Center(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  UserProfileScreen(userId: ownerId),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              backgroundImage: ownerProfileImageUrl != null
                                  ? CachedNetworkImageProvider(
                                      ownerProfileImageUrl)
                                  : const AssetImage(
                                          'assets/default_profile.png')
                                      as ImageProvider,
                            ),
                            Text(
                              ' @${owner['username']}',
                              style: const TextStyle(fontSize: 18),
                            ),
                            if (ownerRole ==
                                'refugio') // Mostrar patita si el rol es refugio
                              const Icon(Icons.pets,
                                  color: Colors.brown, size: 18),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Publicaciones',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('posts')
                      .where('petId', isEqualTo: widget.petId)
                      .get(),
                  builder: (context, postSnapshot) {
                    if (!postSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    var posts = postSnapshot.data!.docs;

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                      ),
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        var post = posts[index].data() as Map<String, dynamic>;

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    SinglePostScreen(postId: posts[index].id),
                              ),
                            );
                          },
                          child: CachedNetworkImage(
                            imageUrl: post['postImageUrl'],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator()),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.error),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: currentUser != null
          ? FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('pets')
                  .doc(widget.petId)
                  .get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Container();
                }

                var pet = snapshot.data!.data() as Map<String, dynamic>;
                var ownerId = pet['owner'];
                var currentUserId =
                    currentUser!.uid; // Usar el ID del usuario actual

                if (currentUserId == ownerId) {
                  return Container();
                }

                return FloatingActionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CreatePostFriendScreen(petId: widget.petId),
                      ),
                    );
                  },
                  child: const Icon(Icons.camera_alt),
                );
              },
            )
          : Container(),
    );
  }
}