import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:timeago/timeago.dart' as timeago_es;
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../user/user_profile.dart'; // Importar la pantalla de perfil

class FriendRequestsPage extends StatefulWidget {
  @override
  _FriendRequestsPageState createState() => _FriendRequestsPageState();
}

class _FriendRequestsPageState extends State<FriendRequestsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    timeago.setLocaleMessages(
        'es', timeago_es.EsMessages()); // Configurar timeago en español
  }

  Future<List<Map<String, dynamic>>> _fetchFriendRequests() async {
    if (_currentUser != null) {
      QuerySnapshot requestQuery = await _firestore
          .collection('friend_requests')
          .where('toUserId', isEqualTo: _currentUser!.uid)
          .get();

      List<Map<String, dynamic>> friendRequests = [];

      for (var requestDoc in requestQuery.docs) {
        var requestData = requestDoc.data() as Map<String, dynamic>;
        var fromUserId = requestData['fromUserId'];

        // Obtener información del usuario que envió la solicitud
        DocumentSnapshot fromUserDoc =
            await _firestore.collection('users').doc(fromUserId).get();

        friendRequests.add({
          'fromUserId': fromUserId,
          'toUserId': requestData['toUserId'],
          'timestamp': requestData['timestamp'],
          'fromUserName': fromUserDoc['username'],
          'profileName': fromUserDoc['profileName'], // Añadido profileName
          'profileImageUrl': fromUserDoc['profileImageUrl'],
          'fromUserRole': fromUserDoc['rol'], // Añadido rol
          'requestId': requestDoc.id, // id de la solicitud
        });
      }

      return friendRequests;
    }
    return [];
  }

  void _acceptRequest(String fromUserId, String requestId) async {
    if (_currentUser != null) {
      // Añadir el fromUserId a la lista de amigos del toUserId
      await _firestore.collection('users').doc(_currentUser!.uid).update({
        'friends': FieldValue.arrayUnion([fromUserId])
      });

      // Añadir el toUserId a la lista de amigos del fromUserId
      await _firestore.collection('users').doc(fromUserId).update({
        'friends': FieldValue.arrayUnion([_currentUser!.uid])
      });

      // Eliminar la solicitud de amistad
      await _firestore.collection('friend_requests').doc(requestId).delete();

      // Mostrar Snackbar de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AwesomeSnackbarContent(
            title: '¡Solicitud aceptada!',
            message: 'Has aceptado la solicitud de amistad.',
            contentType: ContentType.success,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
        ),
      );

      setState(() {});
    }
  }

  void _rejectRequest(String requestId) async {
    // Eliminar la solicitud de amistad
    await _firestore.collection('friend_requests').doc(requestId).delete();

    // Mostrar Snackbar de rechazo
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: AwesomeSnackbarContent(
          title: 'Solicitud rechazada',
          message: 'Has rechazado la solicitud de amistad.',
          contentType: ContentType.warning,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
      ),
    );

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Solicitudes de Amistad'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchFriendRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error al cargar las solicitudes'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No tienes solicitudes de amistad'));
          } else {
            List<Map<String, dynamic>> friendRequests = snapshot.data!;

            return ListView.builder(
              itemCount: friendRequests.length,
              itemBuilder: (context, index) {
                var request = friendRequests[index];
                var timeAgo =
                    timeago.format(request['timestamp'].toDate(), locale: 'es');
                var fromUserRole = request['fromUserRole'];

                return ListTile(
                  leading: CachedNetworkImage(
                    imageUrl: request['profileImageUrl'],
                    imageBuilder: (context, imageProvider) => CircleAvatar(
                      radius: 30, // Tamaño más grande de la imagen
                      backgroundImage: imageProvider,
                    ),
                    placeholder: (context, url) => CircularProgressIndicator(),
                    errorWidget: (context, url, error) => Icon(Icons.error),
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          '@${request['fromUserName']}',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                      if (fromUserRole == 'refugio') ...[
                        const SizedBox(width: 4),
                        const Tooltip(
                          message: 'Refugio Verificado',
                          triggerMode: TooltipTriggerMode.tap,
                          child:
                              Icon(Icons.pets, color: Colors.brown, size: 18),
                        ),
                      ],
                      if (fromUserRole == 'admin') ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_user,
                            color: Colors.red, size: 18),
                      ],
                    ],
                  ),
                  subtitle:
                      Text('Te ha enviado una solicitud de amistad!\n$timeAgo'),
                  onTap: () {
                    _showRequestOptions(
                        context,
                        request[
                            'profileName'], // Mostrar el nombre real en el diálogo
                        request['fromUserName'],
                        request['fromUserId'],
                        request['requestId']);
                  },
                );
              },
            );
          }
        },
      ),
    );
  }

  void _showRequestOptions(BuildContext context, String profileName,
      String username, String fromUserId, String requestId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
              'Solicitud de $profileName'), // Cambiar a profileName en lugar de username
          content:
              Text('¿Deseas aceptar la solicitud de amistad de $profileName?'),
          actions: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfileScreen(
                        userId: fromUserId), // Navegar a la pantalla de perfil
                  ),
                );
              },
              icon: const Icon(Icons.supervised_user_circle),
              label: const Text('Ver Perfil'),
            ),
            TextButton(
              onPressed: () {
                _acceptRequest(fromUserId, requestId);
                Navigator.of(context).pop();
              },
              child: Text('Aceptar'),
            ),
            TextButton(
              onPressed: () {
                _rejectRequest(requestId);
                Navigator.of(context).pop();
              },
              child: Text('Rechazar'),
            ),
          ],
        );
      },
    );
  }
}
