import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:timeago/timeago.dart' as timeago_es;
import '../posts/single_post_screen.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import '../pets/pet_profile.dart';
import '../utils/mascotapp_colors.dart';

class NotificationsScreen extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  NotificationsScreen({Key? key}) : super(key: key) {
    timeago.setLocaleMessages('es', timeago_es.EsMessages());
  }

  IconData _getIconForNotification(String iconCode) {
    switch (iconCode) {
      case '1':
        return Icons.pets; // Ícono de patita
      case '2':
        return Icons.mail; // Ícono de correo
      case '3':
        return Icons.group; // Ícono de dos personas
      default:
        return Icons.notification_important; // Ícono por defecto si no coincide
    }
  }

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;
    if (user == null) {
      return const Center(child: Text('Please log in'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('notifications')
            .where('recipient', isEqualTo: user.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            debugPrint('An error occurred: ${snapshot.error}');
            return Center(child: Text('An error occurred: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay nada por aquí aún...'));
          }

          var notifications = snapshot.data!.docs;

          notifications.forEach((doc) {
            var notificationData = doc.data() as Map<String, dynamic>;
            var timestamp = notificationData['timestamp'] as Timestamp;
            if (timestamp
                .toDate()
                .isBefore(DateTime.now().subtract(const Duration(days: 14)))) {
              _firestore.collection('notifications').doc(doc.id).delete();
            }
          });

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              var notificationData =
                  notifications[index].data() as Map<String, dynamic>;
              var timestamp = notificationData['timestamp'] as Timestamp;

              if (!notificationData['isRead']) {
                _firestore
                    .collection('notifications')
                    .doc(notifications[index].id)
                    .update({
                  'isRead': true,
                });
              }

              return Dismissible(
                key: Key(notifications[index].id),
                onDismissed: (direction) {
                  _firestore
                      .collection('notifications')
                      .doc(notifications[index].id)
                      .delete();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: AwesomeSnackbarContent(
                        title: 'Notificacion Eliminada',
                        message: 'Borrada exitosamente.',
                        contentType: ContentType.failure,
                      ),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                    ),
                  );
                },
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 16.0),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                secondaryBackground: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16.0),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                child: FutureBuilder<DocumentSnapshot>(
                  future: _firestore
                      .collection('users')
                      .doc(notificationData['sender'])
                      .get(),
                  builder: (context, userSnapshot) {
                    if (userSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const ListTile(
                        title: Text('Loading...'),
                        subtitle: Text('Loading...'),
                      );
                    }

                    if (userSnapshot.hasError) {
                      return ListTile(
                        title: const Text('Error loading user'),
                        subtitle: Text('${userSnapshot.error}'),
                      );
                    }

                    // Verificar que el documento exista y no sea nulo
                    if (!userSnapshot.hasData ||
                        userSnapshot.data == null ||
                        !userSnapshot.data!.exists) {
                      return const ListTile(
                        title: Text('Unknown user'),
                        subtitle: Text('Unable to load sender information'),
                      );
                    }

                    var senderData =
                        userSnapshot.data!.data() as Map<String, dynamic>;

                    // Verificación para notificación de tipo "fan"
                    if (notificationData['type'] == 'fan') {
                      // Verificar que el campo 'MascotaId' exista y no sea nulo
                      String mascotaId =
                          (notificationData['MascotaId'] ?? '') as String;

                      // Si el MascotaId es una cadena vacía, se ignora la notificación
                      if (mascotaId.isEmpty) {
                        return const ListTile(
                          title: Text('Invalid notification'),
                          subtitle: Text('Missing MascotaId'),
                        );
                      }

                      return FutureBuilder<DocumentSnapshot>(
                        future:
                            _firestore.collection('pets').doc(mascotaId).get(),
                        builder: (context, petSnapshot) {
                          if (petSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const ListTile(
                              title: Text('Loading...'),
                              subtitle: Text('Loading...'),
                            );
                          }

                          if (petSnapshot.hasError) {
                            return ListTile(
                              title: const Text('Error loading pet'),
                              subtitle: Text('${petSnapshot.error}'),
                            );
                          }

                          // Verificar que el documento exista y no sea nulo
                          if (!petSnapshot.hasData ||
                              petSnapshot.data == null ||
                              !petSnapshot.data!.exists) {
                            return const ListTile(
                              title: Text('Unknown pet'),
                              subtitle: Text('Unable to load pet information'),
                            );
                          }

                          var petData =
                              petSnapshot.data!.data() as Map<String, dynamic>;

                          // Verificar que la imagen de perfil existe y no es nula
                          String profileImageUrl = petData['petImageUrl'] ?? '';

                          return ListTile(
                            leading: Icon(
                              _getIconForNotification(
                                  notificationData['icon'] ?? ''),
                              size: 40,
                            ),
                            title: Text(
                                notificationData['text'] ?? 'Sin descripción'),
                            subtitle: Text(
                              timeago.format(timestamp.toDate(), locale: 'es'),
                            ),
                            trailing: profileImageUrl.isNotEmpty
                                ? Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      image: DecorationImage(
                                        image: CachedNetworkImageProvider(
                                            profileImageUrl),
                                        fit: BoxFit.cover,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  )
                                : const Icon(Icons
                                    .pets), // Icono por defecto si no hay imagen
                            onTap: () {
                              // Navegar al perfil de la mascota al hacer clic
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PetProfileScreen(
                                      petId: notificationData['MascotaId']),
                                ),
                              );
                            },
                          );
                        },
                      );
                    } else if (notificationData['type'] == 'custom') {
                      return ListTile(
                        leading: Icon(
                          _getIconForNotification(
                              notificationData['icon'] ?? ''),
                          size: 40,
                        ),
                        title:
                            Text(notificationData['text'] ?? 'Sin descripción'),
                        subtitle: Text(
                          timeago.format(timestamp.toDate(), locale: 'es'),
                        ),
                        onTap: () {
                          // Puedes manejar una acción específica si lo necesitas
                        },
                      );
                    } else {
                      return FutureBuilder<DocumentSnapshot>(
                        future: _firestore
                            .collection('posts')
                            .doc(notificationData['postId'])
                            .get(),
                        builder: (context, postSnapshot) {
                          if (postSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const ListTile(
                              title: Text('Loading...'),
                              subtitle: Text('Loading...'),
                            );
                          }

                          if (postSnapshot.hasError) {
                            return ListTile(
                              title: const Text('Error loading post'),
                              subtitle: Text('${postSnapshot.error}'),
                            );
                          }

                          // Verificar que el documento exista y no sea nulo
                          if (!postSnapshot.hasData ||
                              postSnapshot.data == null ||
                              !postSnapshot.data!.exists) {
                            return const ListTile(
                              title: Text('Unknown post'),
                              subtitle: Text('Unable to load post information'),
                            );
                          }

                          var postData =
                              postSnapshot.data!.data() as Map<String, dynamic>;

                          // Verificar que la URL de la imagen del post exista y no sea nula
                          String postImageUrl = postData['postImageUrl'] ?? '';

                          return ListTile(
                            leading: Icon(
                              notificationData['type'] == 'like'
                                  ? Icons.favorite
                                  : Icons.comment,
                              size: 40,
                              color: notificationData['type'] == 'like'
                                  ? MascotAppColors.like
                                  : Colors.blue,
                            ),
                            title: Text(notificationData['type'] == 'like'
                                ? 'Ha dado like a tu post'
                                : 'Ha comentado tu post'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '@${senderData['username'] ?? 'Desconocido'}'),
                                Text(timeago.format(timestamp.toDate(),
                                    locale: 'es')),
                              ],
                            ),
                            trailing: postImageUrl.isNotEmpty
                                ? GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              SinglePostScreen(
                                                  postId: notificationData[
                                                      'postId']),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        image: DecorationImage(
                                          image: CachedNetworkImageProvider(
                                              postImageUrl),
                                          fit: BoxFit.cover,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  )
                                : const Icon(Icons
                                    .image_not_supported), // Icono por defecto si no hay imagen
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SinglePostScreen(
                                      postId: notificationData['postId']),
                                ),
                              );
                            },
                          );
                        },
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
