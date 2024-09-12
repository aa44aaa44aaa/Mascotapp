  import 'package:flutter/material.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:firebase_storage/firebase_storage.dart';
  import 'package:cached_network_image/cached_network_image.dart';
  import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
  import 'dart:async';
  import '../pets/pet_profile.dart';
  import 'package:timeago/timeago.dart' as timeago;
  import '../services/notification_service.dart';

  class FeedScreen extends StatefulWidget {
    const FeedScreen({super.key});

    @override
    _FeedScreenState createState() => _FeedScreenState();
  }

  class _FeedScreenState extends State<FeedScreen> {
    final NotificationService _notificationService = NotificationService();
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    final FirebaseAuth _auth = FirebaseAuth.instance;
    static const int _initialPageSize = 2;
    static const int _subsequentPageSize = 2;

    final PagingController<DocumentSnapshot?, DocumentSnapshot>
        _pagingController = PagingController(firstPageKey: null);

    String? _currentUserRole;

    @override
    void initState() {
      _pagingController.addPageRequestListener((pageKey) {
        _fetchPage(pageKey);
      });
      // Configurar timeago en español
      timeago.setLocaleMessages('es', timeago.EsMessages());

      Future<void> _getCurrentUserRole() async {
        var currentUser = _auth.currentUser;
        if (currentUser != null) {
          DocumentSnapshot userDoc =
              await _firestore.collection('users').doc(currentUser.uid).get();
          setState(() {
            _currentUserRole = userDoc['rol'];
          });
        }

        // Obtener el rol del usuario logueado
      }

      _getCurrentUserRole();

      super.initState();
    }

    Future<void> _getCurrentUserRole() async {
      var currentUser = _auth.currentUser;
      if (currentUser != null) {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(currentUser.uid).get();
        setState(() {
          _currentUserRole = userDoc['rol'];
        });
      }
    }

    Future<void> _fetchPage(DocumentSnapshot? pageKey) async {
      try {
        QuerySnapshot newPage;
        if (pageKey == null) {
          newPage = await _firestore
              .collection('posts')
              .orderBy('timestamp', descending: true)
              .limit(_initialPageSize)
              .get();
        } else {
          newPage = await _firestore
              .collection('posts')
              .orderBy('timestamp', descending: true)
              .startAfterDocument(pageKey)
              .limit(_subsequentPageSize)
              .get();
        }

        final isLastPage = newPage.docs.length <
            (pageKey == null ? _initialPageSize : _subsequentPageSize);
        if (isLastPage) {
          _pagingController.appendLastPage(newPage.docs);
        } else {
          final nextPageKey = newPage.docs.last;
          _pagingController.appendPage(newPage.docs, nextPageKey);
        }
      } catch (error) {
        _pagingController.error = error;
      }
    }

    @override
    Widget build(BuildContext context) {
      return PagedListView<DocumentSnapshot?, DocumentSnapshot>(
        pagingController: _pagingController,
        builderDelegate: PagedChildBuilderDelegate<DocumentSnapshot>(
          firstPageProgressIndicatorBuilder: (context) => _buildInitialLoading(),
          newPageProgressIndicatorBuilder: (context) =>
              const Center(child: CircularProgressIndicator()),
          itemBuilder: (context, document, index) {
            var postId = document.id;
            return StreamBuilder<DocumentSnapshot>(
              stream: _firestore.collection('posts').doc(postId).snapshots(),
              builder: (context, postSnapshot) {
                if (postSnapshot.connectionState == ConnectionState.waiting) {
                  return _buildPostPlaceholder(); // Mostrar placeholder si aún se están cargando los datos
                }

                // Verifica si el documento existe antes de acceder a los datos
                if (!postSnapshot.hasData || postSnapshot.data == null) {
                  return _buildPostPlaceholder(); // Si no hay datos, mostrar un placeholder
                }

                var postData = postSnapshot.data!.data() as Map<String, dynamic>?;

                // Verifica si los datos del post no son nulos
                if (postData == null) {
                  return _buildPostPlaceholder(); // Si no hay datos válidos, retornar placeholder
                }
                var post = postSnapshot.data!.data() as Map<String, dynamic>;
                var petId = post['petId'];
                var postedBy = post['postedby'];
                var currentUser = _auth.currentUser;

                bool likedByCurrentUser =
                    post['likes'].contains(currentUser?.uid);
                int likeCount = post['likes'].length;
                var timestamp = post['timestamp'].toDate();
                var timeAgo = timeago.format(timestamp, locale: 'es');

                return FutureBuilder<DocumentSnapshot>(
                  future: _firestore.collection('pets').doc(petId).get(),
                  builder: (context, petSnapshot) {
                    if (!petSnapshot.hasData) {
                      return _buildPostPlaceholder();
                    }
                    var pet = petSnapshot.data!.data() as Map<String, dynamic>;
                    var isVerified = pet['verified'] ?? false;
                    var estado = pet['estado'] ?? '';

                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore.collection('users').doc(postedBy).get(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData) {
                          return _buildPostPlaceholder();
                        }
                        var user =
                            userSnapshot.data!.data() as Map<String, dynamic>;
                        var role = user['rol'] ?? '';

                        Color? labelColor;
                        IconData? icon;
                        String? labelText;

                        switch (estado) {
                          case 'perdido':
                            labelColor = Colors.red;
                            icon = Icons.location_off;
                            labelText = 'Me perdí :(';
                            break;
                          case 'enmemoria':
                            labelColor = Colors.blueAccent;
                            icon = Icons.book;
                            labelText = 'En memoria';
                            break;
                          case 'adopcion':
                            labelColor = Colors.brown;
                            icon = Icons.pets;
                            labelText = 'En adopción';
                            break;
                          default:
                            labelColor = null;
                            icon = null;
                            labelText = null;
                            break;
                        }

                        return Card(
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
                                                PetProfileScreen(petId: petId),
                                          ),
                                        );
                                      },
                                      child: CircleAvatar(
                                        backgroundImage: pet['petImageUrl'] !=
                                                null
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
                                        if (isVerified) ...[
                                          const SizedBox(width: 5),
                                          const Tooltip(
                                            message: 'Mascota Verificada',
                                            child: Icon(Icons.verified,
                                                color: Colors.blue, size: 16),
                                          ),
                                        ],
                                      ],
                                    ),
                                    subtitle: Row(
                                      children: [
                                        Text('@${user['username']}'),
                                        if (role == 'refugio') ...[
                                          const SizedBox(width: 5),
                                          const Icon(Icons.pets,
                                              color: Colors.brown,
                                              size: 16), // Patita icono
                                        ],
                                        if (role == 'admin') ...[
                                          const SizedBox(width: 5),
                                          const Icon(Icons.verified_user,
                                              color: Colors.red,
                                              size: 16), // Patita icono
                                        ],
                                      ],
                                    ),
                                    trailing: (currentUser?.uid == postedBy ||
                                            _currentUserRole == 'admin')
                                        ? PopupMenuButton<String>(
                                            onSelected: (String value) {
                                              if (value == 'delete') {
                                                _deletePost(postId);
                                              }
                                            },
                                            itemBuilder: (BuildContext context) {
                                              return [
                                                const PopupMenuItem(
                                                  value: 'delete',
                                                  child: Text(
                                                      'Eliminar publicación'),
                                                ),
                                              ];
                                            },
                                            icon: const Icon(Icons.more_vert),
                                          )
                                        : null,
                                  ),
                                  GestureDetector(
                                    onDoubleTap: () {
                                      _toggleLikePost(postId, currentUser!.uid,
                                          likedByCurrentUser, postedBy);
                                      _showLikeAnimation(
                                          postId, likedByCurrentUser);
                                    },
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        SizedBox(
                                          width: double.infinity,
                                          child: CachedNetworkImage(
                                            imageUrl: post['postImageUrl'],
                                            placeholder: (context, url) =>
                                                const Center(
                                                    child:
                                                        CircularProgressIndicator()),
                                            errorWidget: (context, url, error) =>
                                                const Icon(Icons.error),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        if (_animationStates[postId] != null)
                                          _buildLikeAnimation(
                                              _animationStates[postId]!),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(post['text'] ?? ''),
                                  ),
                                  ButtonBar(
                                    children: [
                                      Text(timeAgo),
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
                                              postId,
                                              currentUser!.uid,
                                              likedByCurrentUser,
                                              postedBy);
                                        },
                                      ),
                                      Text('$likeCount Me gusta'),
                                      IconButton(
                                        icon: const Icon(Icons.comment),
                                        onPressed: () {
                                          _showCommentDialog(
                                              context, postId, postedBy);
                                        },
                                      ),
                                    ],
                                  ),
                                  _buildCommentsSection(postId),
                                ],
                              ),
                              if (labelText != null &&
                                  labelColor != null &&
                                  icon != null)
                                Positioned(
                                  top: 0,
                                  right: 16,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: labelColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(icon, color: Colors.white, size: 16),
                                        const SizedBox(width: 4),
                                        Text(
                                          labelText,
                                          style: const TextStyle(
                                              color: Colors.white, fontSize: 12),
                                        ),
                                      ],
                                    ),
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
          },
        ),
      );
    }

    Widget _buildInitialLoading() {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando publicaciones...'),
          ],
        ),
      );
    }

    Widget _buildPostPlaceholder() {
      return Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.grey[300],
              ),
              title: Container(
                width: 100,
                height: 10,
                color: Colors.grey[300],
              ),
              subtitle: Container(
                width: 150,
                height: 10,
                color: Colors.grey[300],
              ),
            ),
            Container(
              width: double.infinity,
              height: 200,
              color: Colors.grey[300],
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                width: double.infinity,
                height: 10,
                color: Colors.grey[300],
              ),
            ),
            ButtonBar(
              children: [
                IconButton(
                  icon: Icon(Icons.favorite_border, color: Colors.grey[300]),
                  onPressed: null,
                ),
                IconButton(
                  icon: Icon(Icons.comment, color: Colors.grey[300]),
                  onPressed: null,
                ),
              ],
            ),
          ],
        ),
      );
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
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.5,
            minChildSize: 0.25,
            maxChildSize: 1.0,
            builder: (BuildContext context, ScrollController scrollController) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    TextField(
                      onChanged: (value) {
                        comment = value;
                      },
                      decoration: const InputDecoration(
                          hintText: 'Escribe tu comentario'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (comment.isNotEmpty) {
                          final currentUser = FirebaseAuth.instance.currentUser;

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
                          await _notificationService.sendCommentNotification(
                              postId, currentUser.uid, postOwnerId);

                          Navigator.of(context).pop();
                        }
                      },
                      child: const Text('Comentar'),
                    ),
                    Expanded(
                      child: _buildFullCommentsSection(postId),
                    ),
                  ],
                ),
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
                  return ListTile(
                    title: Text(comment['comment']),
                    subtitle: Text('@${user['username']}'),
                  );
                },
              );
            },
          );
        },
      );
    }

    Widget _buildFullCommentsSection(String postId) {
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
                future:
                    _firestore.collection('users').doc(comment['userId']).get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  var user = userSnapshot.data!.data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(comment['comment']),
                    subtitle: Text('@${user['username']}'),
                  );
                },
              );
            },
          );
        },
      );
    }

    void _deletePost(String postId) async {
      try {
        // Obtén el documento del post para acceder a la URL de la imagen
        DocumentSnapshot postSnapshot =
            await _firestore.collection('posts').doc(postId).get();
        String? imageUrl = postSnapshot['postImageUrl'];

        if (imageUrl != null && imageUrl.isNotEmpty) {
          // Eliminar la imagen de Firebase Storage
          Reference storageRef = FirebaseStorage.instance.refFromURL(imageUrl);
          await storageRef.delete();
        }

        // Eliminar el post de Firestore
        await _firestore.collection('posts').doc(postId).delete();

        // Eliminar el post del PagingController para que desaparezca de la vista
        _pagingController.itemList?.removeWhere((doc) => doc.id == postId);
        _pagingController.notifyListeners();
      } catch (error) {
        print('Error al eliminar el post: $error');
      }
    }

    final Map<String, AnimationState> _animationStates = {};

    void _showLikeAnimation(String postId, bool likedByCurrentUser) {
      setState(() {
        _animationStates[postId] = AnimationState(
          visible: true,
          color: likedByCurrentUser ? Colors.grey : Colors.red,
          icon: likedByCurrentUser ? Icons.favorite_border : Icons.favorite,
        );
      });

      Timer(const Duration(milliseconds: 1500), () {
        setState(() {
          _animationStates[postId] =
              _animationStates[postId]!.copyWith(visible: false);
        });
      });
    }

    Widget _buildLikeAnimation(AnimationState state) {
      return TweenAnimationBuilder<Color?>(
        tween: ColorTween(
            begin: state.color,
            end: state.visible ? state.color : Colors.transparent),
        duration: const Duration(milliseconds: 1000),
        builder: (context, color, child) {
          return AnimatedOpacity(
            opacity: state.visible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 500),
            child: Icon(
              state.icon,
              color: color,
              size: 100,
            ),
          );
        },
      );
    }
  }

  class AnimationState {
    final bool visible;
    final Color color;
    final IconData icon;

    AnimationState(
        {required this.visible, required this.color, required this.icon});

    AnimationState copyWith({bool? visible, Color? color, IconData? icon}) {
      return AnimationState(
        visible: visible ?? this.visible,
        color: color ?? this.color,
        icon: icon ?? this.icon,
      );
    }
  }
