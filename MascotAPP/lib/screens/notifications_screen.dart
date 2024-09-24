import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:timeago/timeago.dart' as timeago_es;
import '../posts/single_post_screen.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';

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

                    if (!userSnapshot.hasData || userSnapshot.data == null) {
                      return const ListTile(
                        title: Text('Unknown user'),
                        subtitle: Text('Unable to load sender information'),
                      );
                    }

                    var senderData =
                        userSnapshot.data!.data() as Map<String, dynamic>;

                    if (notificationData['type'] == 'custom') {
                      return ListTile(
                        leading: Icon(
                          _getIconForNotification(notificationData['icon']),
                          size: 40,
                        ),
                        title: Text(notificationData['text']),
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

                          if (!postSnapshot.hasData ||
                              postSnapshot.data == null) {
                            return const ListTile(
                              title: Text('Unknown post'),
                              subtitle: Text('Unable to load post information'),
                            );
                          }

                          var postData =
                              postSnapshot.data!.data() as Map<String, dynamic>;

                          return ListTile(
                            title: Text(notificationData['type'] == 'like'
                                ? 'Ha dado like a tu post'
                                : 'Ha comentado tu post'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('@${senderData['username']}'),
                                Text(timeago.format(timestamp.toDate(),
                                    locale: 'es')),
                              ],
                            ),
                            trailing: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SinglePostScreen(
                                        postId: notificationData['postId']),
                                  ),
                                );
                              },
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  image: DecorationImage(
                                    image: CachedNetworkImageProvider(
                                        postData['postImageUrl']),
                                    fit: BoxFit.cover,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
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
