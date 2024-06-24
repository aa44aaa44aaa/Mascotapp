import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'dart:async';
import 'pet_profile.dart';

class FeedScreen extends StatefulWidget {
  @override
  _FeedScreenState createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const int _initialPageSize = 2;
  static const int _subsequentPageSize = 2;

  final PagingController<DocumentSnapshot?, DocumentSnapshot> _pagingController =
      PagingController(firstPageKey: null);

  @override
  void initState() {
    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });
    super.initState();
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

      final isLastPage = newPage.docs.length < (pageKey == null ? _initialPageSize : _subsequentPageSize);
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
        newPageProgressIndicatorBuilder: (context) => Center(child: CircularProgressIndicator()),
        itemBuilder: (context, document, index) {
          var postId = document.id;
          return StreamBuilder<DocumentSnapshot>(
            stream: _firestore.collection('posts').doc(postId).snapshots(),
            builder: (context, postSnapshot) {
              if (!postSnapshot.hasData) {
                return _buildPostPlaceholder();
              }
              var post = postSnapshot.data!.data() as Map<String, dynamic>;
              var petId = post['petId'];
              var postedBy = post['postedby'];
              var currentUser = _auth.currentUser;

              bool likedByCurrentUser = post['likes'].contains(currentUser?.uid);
              int likeCount = post['likes'].length;

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
                      var user = userSnapshot.data!.data() as Map<String, dynamic>;

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
                                          builder: (context) => PetProfileScreen(petId: petId),
                                        ),
                                      );
                                    },
                                    child: CircleAvatar(
                                      backgroundImage: pet['petImageUrl'] != null
                                          ? CachedNetworkImageProvider(pet['petImageUrl'])
                                          : AssetImage('assets/default_profile.png') as ImageProvider,
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Text(pet['petName']),
                                      if (isVerified) ...[
                                        SizedBox(width: 8),
                                        Tooltip(
                                          message: 'Mascota Verificada',
                                          child: Icon(Icons.verified, color: Colors.blue, size: 16),
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: Text('@${user['username']}'),
                                  trailing: currentUser?.uid == postedBy
                                      ? PopupMenuButton<String>(
                                          onSelected: (String value) {
                                            if (value == 'delete') {
                                              _deletePost(postId);
                                            }
                                          },
                                          itemBuilder: (BuildContext context) {
                                            return [
                                              PopupMenuItem(
                                                value: 'delete',
                                                child: Text('Eliminar publicación'),
                                              ),
                                            ];
                                          },
                                          icon: Icon(Icons.more_vert),
                                        )
                                      : null,
                                ),
                                GestureDetector(
                                  onDoubleTap: () {
                                    _toggleLikePost(postId, currentUser!.uid, likedByCurrentUser, postedBy);
                                    _showLikeAnimation(postId, likedByCurrentUser);
                                  },
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        child: CachedNetworkImage(
                                          imageUrl: post['postImageUrl'],
                                          placeholder: (context, url) => Center(child: CircularProgressIndicator()),
                                          errorWidget: (context, url, error) => Icon(Icons.error),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      if (_animationStates[postId] != null)
                                        _buildLikeAnimation(_animationStates[postId]!),
                                    ],
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
                                        likedByCurrentUser ? Icons.favorite : Icons.favorite_outline,
                                        color: likedByCurrentUser ? Colors.red : null,
                                      ),
                                      onPressed: () {
                                        _toggleLikePost(postId, currentUser!.uid, likedByCurrentUser, postedBy);
                                      },
                                    ),
                                    Text('$likeCount likes'),
                                    IconButton(
                                      icon: Icon(Icons.comment),
                                      onPressed: () {
                                        _showCommentDialog(context, postId, postedBy);
                                      },
                                    ),
                                  ],
                                ),
                                _buildCommentsSection(postId),
                              ],
                            ),
                            if (labelText != null && labelColor != null && icon != null)
                              Positioned(
                                top: 0,
                                right: 16,
                                child: Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: labelColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(icon, color: Colors.white, size: 16),
                                      SizedBox(width: 4),
                                      Text(
                                        labelText,
                                        style: TextStyle(color: Colors.white, fontSize: 12),
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
    return Center(
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

  void _toggleLikePost(String postId, String userId, bool likedByCurrentUser, String postOwnerId) async {
    final postRef = _firestore.collection('posts').doc(postId);
    final notificationRef = _firestore.collection('notifications');

    if (likedByCurrentUser) {
      await postRef.update({
        'likes': FieldValue.arrayRemove([userId]),
      });
    } else {
      await postRef.update({
        'likes': FieldValue.arrayUnion([userId]),
      });

      final existingLikeNotification = await notificationRef
          .where('recipient', isEqualTo: postOwnerId)
          .where('sender', isEqualTo: userId)
          .where('postId', isEqualTo: postId)
          .where('type', isEqualTo: 'like')
          .limit(1)
          .get();

      if (existingLikeNotification.docs.isEmpty) {
        await notificationRef.add({
          'recipient': postOwnerId,
          'type': 'like',
          'postId': postId,
          'sender': userId,
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    }
    setState(() {});
  }

  void _showCommentDialog(BuildContext context, String postId, String postOwnerId) {
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
                    decoration: InputDecoration(hintText: 'Escribe tu comentario'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (comment.isNotEmpty) {
                        final currentUser = FirebaseAuth.instance.currentUser;

                        await _firestore.collection('posts').doc(postId).collection('comments').add({
                          'comment': comment,
                          'timestamp': FieldValue.serverTimestamp(),
                          'userId': currentUser!.uid,
                        });

                        final existingCommentNotification = await _firestore.collection('notifications')
                            .where('recipient', isEqualTo: postOwnerId)
                            .where('sender', isEqualTo: currentUser.uid)
                            .where('postId', isEqualTo: postId)
                            .where('type', isEqualTo: 'comment')
                            .limit(1)
                            .get();

                        if (existingCommentNotification.docs.isEmpty) {
                          await _firestore.collection('notifications').add({
                            'recipient': postOwnerId,
                            'type': 'comment',
                            'postId': postId,
                            'sender': currentUser.uid,
                            'isRead': false,
                            'timestamp': FieldValue.serverTimestamp(),
                          });
                        }

                        Navigator.of(context).pop();
                      }
                    },
                    child: Text('Comentar'),
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
      stream: _firestore.collection('posts').doc(postId).collection('comments').orderBy('timestamp', descending: true).limit(2).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        var comments = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: comments.length,
          itemBuilder: (context, index) {
            var comment = comments[index].data() as Map<String, dynamic>;
            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(comment['userId']).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
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
      stream: _firestore.collection('posts').doc(postId).collection('comments').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        var comments = snapshot.data!.docs;

        return ListView.builder(
          itemCount: comments.length,
          itemBuilder: (context, index) {
            var comment = comments[index].data() as Map<String, dynamic>;
            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(comment['userId']).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
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
    await _firestore.collection('posts').doc(postId).delete();
  }

  Map<String, AnimationState> _animationStates = {};

  void _showLikeAnimation(String postId, bool likedByCurrentUser) {
    setState(() {
      _animationStates[postId] = AnimationState(
        visible: true,
        color: likedByCurrentUser ? Colors.grey : Colors.red,
        icon: likedByCurrentUser ? Icons.favorite_border : Icons.favorite,
      );
    });

    Timer(Duration(milliseconds: 1500), () {
      setState(() {
        _animationStates[postId] = _animationStates[postId]!.copyWith(visible: false);
      });
    });
  }

  Widget _buildLikeAnimation(AnimationState state) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(begin: state.color, end: state.visible ? state.color : Colors.transparent),
      duration: Duration(milliseconds: 1000),
      builder: (context, color, child) {
        return AnimatedOpacity(
          opacity: state.visible ? 1.0 : 0.0,
          duration: Duration(milliseconds: 500),
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

  AnimationState({required this.visible, required this.color, required this.icon});

  AnimationState copyWith({bool? visible, Color? color, IconData? icon}) {
    return AnimationState(
      visible: visible ?? this.visible,
      color: color ?? this.color,
      icon: icon ?? this.icon,
    );
  }
}
