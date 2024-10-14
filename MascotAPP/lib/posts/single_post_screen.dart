import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../user/user_profile.dart';
import '../services/notification_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../utils/mascotapp_colors.dart';

class SinglePostScreen extends StatefulWidget {
  final String postId;

  const SinglePostScreen({super.key, required this.postId});

  @override
  _SinglePostScreenState createState() => _SinglePostScreenState();
}

class _SinglePostScreenState extends State<SinglePostScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final currentUser = FirebaseAuth.instance.currentUser;
  final NotificationService _notificationService = NotificationService();

  late Future<DocumentSnapshot> postFuture;
  bool inAdoption = false;

  @override
  void initState() {
    super.initState();
    postFuture = _firestore.collection('posts').doc(widget.postId).get();
  }

  void _toggleLikePost(String postId, String userId, bool likedByCurrentUser,
      String postOwnerId) async {
    final postRef = _firestore.collection('posts').doc(postId);

    if (likedByCurrentUser) {
      await postRef.update({
        'likes': FieldValue.arrayRemove([userId]),
      });
    } else {
      await postRef.update({
        'likes': FieldValue.arrayUnion([userId]),
      });

      // Llama al servicio de notificación para enviar notificación de "like"
      await _notificationService.sendLikeNotification(
          postId, userId, postOwnerId);
    }
    setState(() {});
  }

  void _showCommentDialog(
      BuildContext context, String postId, String postOwnerId) {
    String comment = '';
    bool isLoading = false; // Indicador de carga
    final TextEditingController commentController =
        TextEditingController(); // Controlador para el TextField

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.5,
              minChildSize: 0.25,
              maxChildSize: 1.0,
              builder:
                  (BuildContext context, ScrollController scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: commentController, // Asigna el controlador
                        onChanged: (value) {
                          comment = value;
                        },
                        enabled:
                            !isLoading, // Desactiva el campo mientras carga
                        decoration: const InputDecoration(
                            hintText: 'Escribe tu comentario'),
                      ),
                      ElevatedButton(
                        onPressed: isLoading
                            ? null // Desactiva el botón cuando está cargando
                            : () async {
                                if (comment.isNotEmpty) {
                                  setState(() {
                                    isLoading =
                                        true; // Cambia a estado de carga
                                  });

                                  final currentUser =
                                      FirebaseAuth.instance.currentUser;

                                  await _firestore
                                      .collection('posts')
                                      .doc(postId)
                                      .collection('comments')
                                      .add({
                                    'comment': comment,
                                    'timestamp': FieldValue.serverTimestamp(),
                                    'userId': currentUser!.uid,
                                  });

                                  // Llama al servicio de notificación para enviar notificación de "comentario"
                                  await _notificationService
                                      .sendCommentNotification(
                                          postId, currentUser.uid, postOwnerId);

                                  // Limpia el comentario y el campo de texto
                                  setState(() {
                                    isLoading =
                                        false; // Finaliza el estado de carga
                                    comment =
                                        ''; // Limpia la variable del comentario
                                    commentController
                                        .clear(); // Limpia el campo de texto
                                  });
                                }
                              },
                        child: isLoading
                            ? const CircularProgressIndicator() // Muestra indicador de carga
                            : const Text('Comentar'),
                      ),
                      Expanded(
                        child: _buildFullCommentsSection(postId, postOwnerId),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCommentsSection(String postId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .limit(2)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var comments = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: comments.length,
          itemBuilder: (context, index) {
            var comment = comments[index].data() as Map<String, dynamic>;
            return FutureBuilder<DocumentSnapshot>(
              future:
                  _firestore.collection('users').doc(comment['userId']).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var user = userSnapshot.data!.data() as Map<String, dynamic>;

                // Aquí obtenemos la URL de la imagen de perfil y la mostramos
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '@${user['username']}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    comment['comment'],
                                    style: TextStyle(
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFullCommentsSection(String postId, String postOwnerId) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(currentUser!.uid).get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var currentUserData = userSnapshot.data!.data() as Map<String, dynamic>;
        String currentUserRole = currentUserData['rol'] ?? 'user';

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('posts')
              .doc(postId)
              .collection('comments')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            var comments = snapshot.data!.docs;

            return ListView.builder(
              itemCount: comments.length,
              itemBuilder: (context, index) {
                var comment = comments[index].data() as Map<String, dynamic>;
                return FutureBuilder<DocumentSnapshot>(
                  future: _firestore
                      .collection('users')
                      .doc(comment['userId'])
                      .get(),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    var user =
                        userSnapshot.data!.data() as Map<String, dynamic>;
                    var timestamp = comment['timestamp'] as Timestamp?;

                    // Verifica si el timestamp es nulo
                    String timeAgo;
                    if (timestamp != null) {
                      timeAgo = timeago.format(
                        timestamp.toDate(),
                        locale: 'es',
                      );
                    } else {
                      timeAgo =
                          "Hace un momento"; // Valor por defecto si timestamp es nulo
                    }

                    // Verifica si el usuario actual es el autor del comentario, el dueño del post o un administrador.
                    bool isCommentOwner = currentUser.uid == comment['userId'];
                    bool isPostOwner = currentUser.uid == postOwnerId;
                    bool isAdmin =
                        currentUserRole == 'admin'; // Verifica el rol

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UserProfileScreen(
                                      userId: comment['userId']),
                                ),
                              );
                            },
                            child: CircleAvatar(
                              radius: 20,
                              backgroundImage:
                                  NetworkImage(user['profileImageUrl']),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  UserProfileScreen(
                                                      userId:
                                                          comment['userId']),
                                            ),
                                          );
                                        },
                                        child: Text(
                                          '@${user['username']}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        comment['comment'],
                                        style: TextStyle(
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        timeAgo,
                                        style: TextStyle(
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isCommentOwner || isPostOwner || isAdmin)
                            PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'delete') {
                                  await _deleteComment(
                                      postId, comments[index].id);
                                }
                              },
                              itemBuilder: (BuildContext context) {
                                return [
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Eliminar'),
                                  ),
                                ];
                              },
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _deleteComment(String postId, String commentId) async {
    await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: postFuture,
        builder: (context, postSnapshot) {
          if (!postSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var post = postSnapshot.data!.data() as Map<String, dynamic>;
          var petId = post['petId'];
          var postedBy = post['postedby'];
          bool likedByCurrentUser = post['likes'].contains(currentUser?.uid);
          int likeCount = post['likes'].length;

          return FutureBuilder<DocumentSnapshot>(
            future: _firestore.collection('pets').doc(petId).get(),
            builder: (context, petSnapshot) {
              if (!petSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var pet = petSnapshot.data!.data() as Map<String, dynamic>;
              var ownerId = pet['owner'];
              bool isVerified = pet['verified'] ?? false;

              // Check if pet is in adoption
              inAdoption = pet['inAdoption'] ?? false;

              return FutureBuilder<DocumentSnapshot>(
                future: _firestore.collection('users').doc(postedBy).get(),
                builder: (context, ownerSnapshot) {
                  if (!ownerSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var owner =
                      ownerSnapshot.data!.data() as Map<String, dynamic>;

                  String formattedDate = DateFormat('dd-MM-yyyy HH:mm')
                      .format(post['timestamp'].toDate());

                  return SingleChildScrollView(
                    child: Card(
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                leading: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            UserProfileScreen(userId: postedBy),
                                      ),
                                    );
                                  },
                                  child: CircleAvatar(
                                    backgroundImage: pet['petImageUrl'] != null
                                        ? CachedNetworkImageProvider(
                                            pet['petImageUrl'])
                                        : const AssetImage(
                                                'assets/default_profile.png')
                                            as ImageProvider,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Text(pet['petName']),
                                    if (isVerified)
                                      const Icon(
                                        Icons.verified,
                                        color: Colors.blue,
                                        size: 16.0,
                                      ),
                                  ],
                                ),
                                subtitle: Text('Subida el: $formattedDate'),
                              ),
                              SizedBox(
                                width: double.infinity,
                                child: CachedNetworkImage(
                                  imageUrl: post['postImageUrl'],
                                  placeholder: (context, url) => const Center(
                                      child: CircularProgressIndicator()),
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.error),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            UserProfileScreen(userId: postedBy),
                                      ),
                                    );
                                  },
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundImage: owner[
                                                    'profileImageUrl'] !=
                                                null
                                            ? CachedNetworkImageProvider(
                                                owner['profileImageUrl'])
                                            : const AssetImage(
                                                    'assets/default_profile.png')
                                                as ImageProvider,
                                      ),
                                      const SizedBox(width: 8.0),
                                      Text('@${owner['username']}'),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(post['text'] ?? ''),
                              ),
                              ButtonBar(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      likedByCurrentUser
                                          ? Icons.favorite
                                          : Icons.favorite_outline,
                                      color: likedByCurrentUser
                                          ? Colors.red
                                          : null,
                                    ),
                                    onPressed: () {
                                      _toggleLikePost(
                                          widget.postId,
                                          currentUser!.uid,
                                          likedByCurrentUser,
                                          postedBy);
                                    },
                                  ),
                                  Text('$likeCount likes'),
                                  IconButton(
                                    icon: const Icon(Icons.comment),
                                    onPressed: () {
                                      _showCommentDialog(
                                          context, widget.postId, postedBy);
                                    },
                                  ),
                                ],
                              ),
                              _buildCommentsSection(widget.postId),
                            ],
                          ),
                          if (inAdoption)
                            Positioned(
                              top: 0,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: MascotAppColors.refugio,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.pets,
                                        color: Colors.white, size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      '¡Adóptame!',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
