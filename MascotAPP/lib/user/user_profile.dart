import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'user_edit.dart';
import '../pets/pet_profile.dart';
import '../admin/user_edit.dart';
import 'amigos_screen.dart';
import '../services/email_service.dart';

class UserProfileScreen extends StatefulWidget {
  final String? userId;

  const UserProfileScreen({super.key, this.userId});

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? profileImageUrl, username, profileName, bio, userRole;
  List<DocumentSnapshot>? pets;
  int friendCount = 0;
  bool isOwner = false;
  bool isAdmin = false;
  bool isFriend = false;
  bool requestSent = false;
  String? requestId; // Para almacenar el ID de la solicitud enviada

  @override
  void initState() {
    super.initState();
    _checkFriendStatus(); // Verifica si ya son amigos o si hay una solicitud
    _loadUserProfile();
    _loadUserPets();
    _loadFriendCount();
    _checkIfAdmin();
  }

  Future<void> _loadUserProfile() async {
    String userId = widget.userId ?? _auth.currentUser!.uid;
    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(userId).get();
    setState(() {
      profileImageUrl = userDoc['profileImageUrl'];
      username = userDoc['username'];
      profileName = userDoc['profileName'];
      bio = userDoc['bio'];
      userRole = userDoc['rol'];
      isOwner = userId == _auth.currentUser!.uid;
    });
  }

  Future<void> _checkIfAdmin() async {
    String currentUserId = _auth.currentUser!.uid;
    DocumentSnapshot currentUserDoc =
        await _firestore.collection('users').doc(currentUserId).get();
    setState(() {
      isAdmin = currentUserDoc['rol'] == 'admin';
    });
  }

  Future<void> _loadFriendCount() async {
    String userId = widget.userId ?? _auth.currentUser!.uid;
    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(userId).get();
    List<dynamic> friends = userDoc['friends'] ?? [];
    setState(() {
      friendCount = friends.length;
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

  // Verificar si ya son amigos o si hay una solicitud enviada
  Future<void> _checkFriendStatus() async {
    String userId = widget.userId ?? _auth.currentUser!.uid;
    String currentUserId = _auth.currentUser!.uid;

    // Verificar si ya hay una solicitud pendiente
    QuerySnapshot requestQuery = await _firestore
        .collection('friend_requests')
        .where('fromUserId', isEqualTo: currentUserId)
        .where('toUserId', isEqualTo: userId)
        .get();

    if (requestQuery.docs.isNotEmpty) {
      setState(() {
        requestSent = true;
        requestId = requestQuery.docs.first.id; // Guardar el ID de la solicitud
      });
    }

    // Verificar si ya son amigos
    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(userId).get();
    List<dynamic> friends = userDoc['friends'] ?? [];
    if (friends.contains(currentUserId)) {
      setState(() {
        isFriend = true;
      });
      return; // Ya es amigo, no se necesita verificar solicitudes
    }
  }

  void _navigateToEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UserEditScreen(),
      ),
    ).then((_) => _loadUserProfile());
  }

  void _navigateToAdminEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserAdminEditScreen(userId: widget.userId!),
      ),
    ).then((_) => _loadUserProfile());
  }

  // Enviar solicitud de amistad
  Future<void> _sendFriendRequest() async {
    String currentUserId = _auth.currentUser!.uid;
    String userId = widget.userId ?? _auth.currentUser!.uid;

    // Verifica si ya existe una solicitud pendiente
    var existingRequest = await _firestore
        .collection('friend_requests')
        .where('fromUserId', isEqualTo: currentUserId)
        .where('toUserId', isEqualTo: userId)
        .get();

    if (existingRequest.docs.isEmpty) {
      DocumentReference requestRef =
          await _firestore.collection('friend_requests').add({
        'fromUserId': currentUserId,
        'toUserId': userId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        requestSent = true;
        requestId = requestRef.id; // Guardar el ID de la solicitud
      });

      // Obtener el nombre de usuario del remitente
      var senderDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      String senderUsername = senderDoc.data()?['username'] ?? 'Usuario';

      // Obtener el nombre del destinatario
      var recipientDoc = await _firestore.collection('users').doc(userId).get();
      String recipientName = recipientDoc.data()?['profileName'] ?? 'Usuario';

      // Obtener el correo electrónico del destinatario
      String recipientEmail = recipientDoc.data()?['email'];

      // Enviar el correo de notificación
      final emailService = EmailService();
      await emailService.sendFriendNotificationEmail(
          senderUsername, // Nombre del usuario que envía la solicitud
          recipientName, // Nombre del destinatario de la solicitud
          recipientEmail // Correo electrónico del destinatario
          );

      _showSnackbar(
        'Solicitud enviada',
        'La solicitud de amistad ha sido enviada con éxito.',
        ContentType.success,
      );
    } else {
      _showSnackbar(
        'Ya enviada',
        'Ya existe una solicitud de amistad pendiente.',
        ContentType.warning,
      );
    }
  }

  // Eliminar solicitud de amistad
  Future<void> _cancelFriendRequest() async {
    if (requestId != null) {
      await _firestore.collection('friend_requests').doc(requestId).delete();

      setState(() {
        requestSent = false;
        requestId = null; // Resetear el estado
      });

      _showSnackbar(
        'Solicitud eliminada',
        'La solicitud de amistad ha sido eliminada.',
        ContentType.success,
      );
    }
  }

  // Mostrar AwesomeSnackbar
  void _showSnackbar(String title, String message, ContentType type) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: AwesomeSnackbarContent(
          title: title,
          message: message,
          contentType: type,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('@$username'),
        actions: [
          if (isAdmin && !isOwner)
            IconButton(
              icon: const Icon(Icons.verified_user, color: Colors.red),
              onPressed: _navigateToAdminEditProfile,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: profileImageUrl != null
                            ? CachedNetworkImageProvider(profileImageUrl!)
                            : const AssetImage('assets/default_profile.png')
                                as ImageProvider,
                      ),
                      if (isOwner)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _navigateToEditProfile,
                            child: const CircleAvatar(
                              radius: 15,
                              backgroundColor: Colors.blue,
                              child: Icon(Icons.edit,
                                  color: Colors.white, size: 15),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(
                    width: 10), // Espacio pequeño entre imagen y texto
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            profileName ?? '',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(
                              width: 8), // Espacio entre el nombre y la patita
                          if (userRole ==
                              'refugio') // Mostrar la patita si el rol es "refugio"
                            const Tooltip(
                              message: 'Refugio Verificado de MascotApp',
                              triggerMode: TooltipTriggerMode.tap,
                              child: Icon(Icons.pets,
                                  color: Colors.brown, size: 24),
                            ),
                          if (userRole ==
                              'admin') // Mostrar la patita si el rol es "refugio"
                            const Tooltip(
                              message: 'Administrador de MascotApp',
                              triggerMode: TooltipTriggerMode.tap,
                              child: Icon(Icons.verified_user,
                                  color: Colors.red, size: 24),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        bio ?? '',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          // Navegar a la pantalla de "Mis Amigos"
                          String userId =
                              widget.userId ?? _auth.currentUser!.uid;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  FriendsScreen(currentUserId: userId),
                            ),
                          );
                        },
                        child: Column(
                          children: [
                            Icon(Icons.group,
                                size: 30, color: Colors.grey[700]),
                            const SizedBox(height: 4),
                            Text(
                              '$friendCount amigos',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(
                          height: 10), // Espacio entre el contador y el botón
                      if (!isOwner && !isFriend)
                        ElevatedButton.icon(
                          onPressed: requestSent
                              ? _cancelFriendRequest
                              : _sendFriendRequest,
                          icon: Icon(requestSent
                              ? Icons.group_remove
                              : Icons.person_add),
                          label: Text(requestSent ? 'Quitar' : 'Añadir'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(150, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Mascotas (${pets?.length ?? 0})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                                : const AssetImage('assets/default_pet.png')
                                    as ImageProvider,
                          ),
                          title: Row(
                            children: [
                              Text(pet['petName'] + ' '),
                              if (pet['verified'] == true)
                                const Icon(Icons.verified,
                                    color: Colors.blue, size: 16),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${pet['petType']} ${pet['petBreed']}'),
                              if (pet['estado'] != null)
                                _buildEstadoTag(pet['estado']),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    PetProfileScreen(petId: pets![index].id),
                              ),
                            );
                          },
                        );
                      },
                    )
                  : const Center(child: CircularProgressIndicator()),
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
      case 'adopcion':
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
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
