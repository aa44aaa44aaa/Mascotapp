import 'package:Mascotapp/utils/mascotapp_colors.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importar FirebaseAuth
import '../posts/create_post_friend.dart';
import '../user/user_profile.dart';
import '../posts/single_post_screen.dart';
import '../applications/applyadopt_screen.dart';
import '../admin/mascota_edit.dart';
import 'edit_pet.dart';
import '../services/notification_service.dart';
import '../utils/mascotapp_colors.dart';

class PetProfileScreen extends StatefulWidget {
  final String petId;

  const PetProfileScreen({super.key, required this.petId});

  @override
  _PetProfileScreenState createState() => _PetProfileScreenState();
}

class _PetProfileScreenState extends State<PetProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final NotificationService _notificationService = NotificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? currentUser;
  bool isOwner = false;
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    _getCurrentUser(); // Llamar a la función para obtener el usuario actual
    _checkIfAdmin(); // Verificar si el usuario actual es administrador
  }

  Future<void> _checkIfAdmin() async {
    // Verificar si el usuario actual es administrador
    String currentUserId = _auth.currentUser!.uid;
    DocumentSnapshot currentUserDoc =
        await _firestore.collection('users').doc(currentUserId).get();
    setState(() {
      isAdmin = currentUserDoc['rol'] ==
          'admin'; // Verifica el rol del usuario actual
    });
  }

  Future<void> _getCurrentUser() async {
    User? user = FirebaseAuth.instance.currentUser;
    DocumentSnapshot petDoc =
        await _firestore.collection('pets').doc(widget.petId).get();
    String ownerId = petDoc['owner'];

    setState(() {
      currentUser = user;
      isOwner = user != null &&
          user.uid == ownerId; // Verifica si el usuario es el dueño
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleFanStatus() async {
    String currentUserId = _auth.currentUser!.uid; // ID del usuario actual
    DocumentSnapshot petDoc =
        await _firestore.collection('pets').doc(widget.petId).get();
    List fans = petDoc['fans'] ?? []; // Lista de fans actual

    // Obtener el nombre de la mascota para usarlo en la notificación
    String petName =
        petDoc['petName'] ?? 'La mascota'; // Asegurarse de que el nombre exista

    if (fans.contains(currentUserId)) {
      // Si ya es fan, lo eliminamos de la lista
      await _firestore.collection('pets').doc(widget.petId).update({
        'fans': FieldValue.arrayRemove([currentUserId]),
      });
    } else {
      // Si no es fan, lo añadimos a la lista
      await _firestore.collection('pets').doc(widget.petId).update({
        'fans': FieldValue.arrayUnion([currentUserId]),
      });

      // Enviar la notificación con el nombre de la mascota
      await _notificationService.sendFanNotification(
          petDoc['owner'], // ID del propietario de la mascota como destinatario
          "$petName tiene un nuevo fan!", // Texto de la notificación
          widget.petId, // ID de la mascota
          currentUserId // ID del remitente (usuario actual)
          );
    }

    setState(() {}); // Actualiza el estado para reflejar cambios en la UI
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

  void _navigateToAdminEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PetAdminEditScreen(
          petId: widget.petId, // Aquí ya tienes el petId definido en el widget
          userId: currentUser!.uid, // Pasas el userId del administrador actual
        ),
      ),
    );
  }

  void _navigateToOwnerEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPetScreen(
          petId: widget.petId, // Aquí ya tienes el petId definido en el widget
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil de Mascota'),
        actions: [
          if (isAdmin && !isOwner)
            IconButton(
              icon:
                  const Icon(Icons.verified_user, color: MascotAppColors.admin),
              onPressed: _navigateToAdminEditProfile,
            ),
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _navigateToOwnerEditProfile,
            ),
        ],
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

          // Verifica si el campo 'fans' no existe y lo agrega como una lista vacía
          if (pet['fans'] == null) {
            FirebaseFirestore.instance
                .collection('pets')
                .doc(widget.petId)
                .update({'fans': []});
          }

          var ownerId = pet['owner'];
          var isVerified = pet['verified'] ?? false;
          var estado = pet['estado'];
          var textoestado = pet['textoestado'] ?? '';
          var location = pet['location'];

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
              ageString += '\n';
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
                borderColor = MascotAppColors.refugio;
                icon = Icons.volunteer_activism;
                message = 'Estoy en adopción!';
                break;
            }
          }
          List fans = pet['fans'] ?? [];
          bool isFan = fans.contains(_auth.currentUser!.uid);

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Lado izquierdo (más grande)
                      Expanded(
                        flex: 2, // 3 partes del total
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (message != null && icon != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    message!,
                                    style: TextStyle(
                                      color: borderColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(icon, color: borderColor),
                                ],
                              ),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 60,
                                  backgroundImage: pet['petImageUrl'] != null
                                      ? CachedNetworkImageProvider(
                                          pet['petImageUrl'])
                                      : const AssetImage(
                                              'assets/default_pet.png')
                                          as ImageProvider,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: borderColor, width: 6),
                                      borderRadius: BorderRadius.circular(60),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    pet['petName'],
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 3,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                if (isVerified) ...[
                                  const SizedBox(width: 8),
                                  const Tooltip(
                                    message: 'Mascota Verificada',
                                    triggerMode: TooltipTriggerMode.tap,
                                    child: Icon(Icons.verified,
                                        color: Colors.blue, size: 24),
                                  ),
                                ],
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    '${pet['petType']} ${pet['petBreed']}',
                                    style: const TextStyle(fontSize: 18),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 3,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(ownerId)
                                  .get(),
                              builder: (context, userSnapshot) {
                                if (!userSnapshot.hasData) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }

                                var owner = userSnapshot.data!.data()
                                    as Map<String, dynamic>;
                                var ownerProfileImageUrl =
                                    owner['profileImageUrl'];
                                var ownerRole = owner['rol'];

                                return GestureDetector(
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
                                        backgroundImage: ownerProfileImageUrl !=
                                                null
                                            ? CachedNetworkImageProvider(
                                                ownerProfileImageUrl)
                                            : const AssetImage(
                                                    'assets/default_profile.png')
                                                as ImageProvider,
                                      ),
                                      const SizedBox(width: 1),
                                      Flexible(
                                        child: Text(
                                          ' @${owner['username']}',
                                          style: const TextStyle(fontSize: 18),
                                        ),
                                      ),
                                      if (ownerRole == 'refugio') ...[
                                        const SizedBox(width: 1),
                                        const Tooltip(
                                          message: 'Refugio Verificado',
                                          triggerMode: TooltipTriggerMode.tap,
                                          child: const Icon(Icons.pets,
                                              color: MascotAppColors.refugio,
                                              size: 18),
                                        ),
                                      ],
                                      if (ownerRole == 'admin') ...[
                                        const SizedBox(width: 1),
                                        const Icon(Icons.verified_user,
                                            color: MascotAppColors.admin,
                                            size: 18),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Lado derecho (más pequeño)
                      Expanded(
                        flex: 1, // 1 parte del total
                        child: Column(
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                if (estado == 'adopcion') ...[
                                  Column(
                                    children: [
                                      const Icon(Icons.vaccines,
                                          color: Colors.green, size: 32),
                                      Text(
                                          'Vacunado: ${pet['vacunado'] == true ? 'Sí' : 'No'}'),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Column(
                                    children: [
                                      const Icon(Icons.local_hospital,
                                          color: Colors.blue, size: 32),
                                      Text(
                                          'Esterilizado: ${pet['esterilizado'] == true ? 'Sí' : 'No'}'),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Column(
                                  children: [
                                    const Icon(Icons.cake,
                                        color: Colors.red, size: 32),
                                    Text(
                                      'Edad: $ageString',
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Column(
                                  children: [
                                    const Icon(Icons.favorite,
                                        color: Colors.red, size: 32),
                                    Text(
                                        '${fans.length} ${fans.length == 1 ? 'Fan' : 'Fans'}'),
                                  ],
                                ),
                              ],
                            ),
                            if (currentUser != null &&
                                currentUser!.uid != ownerId) ...[
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: _toggleFanStatus,
                                icon: Icon(
                                  isFan
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: Colors.red,
                                ),
                                label: Text(
                                  isFan ? 'Eres Fan' : 'Ser Fan',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (location != null && estado != 'nada')
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_pin,
                            color: Colors.red, size: 25),
                        Text(location),
                      ],
                    ),
                  if (estado == 'adopcion') ...[
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ApplyAdoptScreen(petId: widget.petId),
                          ),
                        );
                      },
                      child: const Text('Quiero Adoptar'),
                    ),
                  ],
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Publicaciones',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                          var post =
                              posts[index].data() as Map<String, dynamic>;

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
            ),
          );
        },
      ),
    );
  }
}
