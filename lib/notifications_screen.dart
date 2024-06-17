import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'single_post_screen.dart';  // Importar SinglePostScreen

class NotificationsScreen extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;
    if (user == null) {
      return Center(child: Text('Please log in'));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Notificaciones'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('notifications')
            .where('recipient', isEqualTo: user.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            print('An error occurred: ${snapshot.error}');
            return Center(child: Text('An error occurred: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No hay nada por aquí aún...'));
          }

          var notifications = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              var notificationData = notifications[index].data();
              if (notificationData == null) {
                return ListTile(
                  title: Text('Notification data is null'),
                );
              }
              var notification = notificationData as Map<String, dynamic>;

              return Dismissible(
                key: Key(notifications[index].id),
                onDismissed: (direction) {
                  // Delete the notification from Firestore
                  _firestore.collection('notifications').doc(notifications[index].id).delete();

                  // Show a snackbar to confirm deletion
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Notification dismissed')),
                  );
                },
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.only(left: 16.0),
                  child: Icon(
                    Icons.delete,
                    color: Colors.white,
                  ),
                ),
                secondaryBackground: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: EdgeInsets.only(right: 16.0),
                  child: Icon(
                    Icons.delete,
                    color: Colors.white,
                  ),
                ),
                child: FutureBuilder<DocumentSnapshot>(
                  future: _firestore.collection('users').doc(notification['sender']).get(),
                  builder: (context, userSnapshot) {
                    if (userSnapshot.connectionState == ConnectionState.waiting) {
                      return ListTile(
                        title: Text('Loading...'),
                        subtitle: Text('Loading...'),
                      );
                    }

                    if (userSnapshot.hasError) {
                      return ListTile(
                        title: Text('Error loading user'),
                        subtitle: Text('${userSnapshot.error}'),
                      );
                    }

                    if (!userSnapshot.hasData || userSnapshot.data == null) {
                      return ListTile(
                        title: Text('Unknown user'),
                        subtitle: Text('Unable to load sender information'),
                      );
                    }

                    var senderData = userSnapshot.data!.data();
                    if (senderData == null) {
                      return ListTile(
                        title: Text('Sender data is null'),
                      );
                    }
                    var sender = senderData as Map<String, dynamic>;

                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore.collection('posts').doc(notification['postId']).get(),
                      builder: (context, postSnapshot) {
                        if (postSnapshot.connectionState == ConnectionState.waiting) {
                          return ListTile(
                            title: Text('Loading...'),
                            subtitle: Text('Loading...'),
                          );
                        }

                        if (postSnapshot.hasError) {
                          return ListTile(
                            title: Text('Error loading post'),
                            subtitle: Text('${postSnapshot.error}'),
                          );
                        }

                        if (!postSnapshot.hasData || postSnapshot.data == null) {
                          return ListTile(
                            title: Text('Unknown post'),
                            subtitle: Text('Unable to load post information'),
                          );
                        }

                        var postData = postSnapshot.data!.data();
                        if (postData == null) {
                          return ListTile(
                            title: Text('Post data is null'),
                          );
                        }
                        var post = postData as Map<String, dynamic>;

                        return ListTile(
                          title: Text(notification['type'] == 'like'
                              ? 'Ha dado like a tu post'
                              : 'Ha comentado tu post'),
                          subtitle: Text('@${sender['username']}'),
                          trailing: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SinglePostScreen(postId: notification['postId']),
                                ),
                              );
                            },
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  image: CachedNetworkImageProvider(post['postImageUrl']),
                                  fit: BoxFit.cover,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          onTap: () {
                            // Mark notification as read
                            _firestore.collection('notifications').doc(notifications[index].id).update({
                              'isRead': true,
                            });
                          },
                        );
                      },
                    );
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
