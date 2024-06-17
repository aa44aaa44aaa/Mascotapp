import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'pet_profile.dart';

class FeedScreen extends StatefulWidget {
  @override
  _FeedScreenState createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('posts').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        var posts = snapshot.data!.docs;

        if (posts.isEmpty) {
          return Center(child: Text('No posts available.'));
        }

        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            var post = posts[index].data() as Map<String, dynamic>;
            var postId = posts[index].id;
            var petId = post['petId'];
            var postedBy = post['postedby'];
            var currentUser = _auth.currentUser;

            bool likedByCurrentUser = post['likes'].contains(currentUser?.uid);
            int likeCount = post['likes'].length;

            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('pets').doc(petId).get(),
              builder: (context, petSnapshot) {
                if (!petSnapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                var pet = petSnapshot.data!.data() as Map<String, dynamic>;
                var ownerId = pet['owner'];
                var isVerified = pet['verified'] ?? false;

                return FutureBuilder<DocumentSnapshot>(
                  future: _firestore.collection('users').doc(postedBy).get(),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }
                    var user = userSnapshot.data!.data() as Map<String, dynamic>;

                    return Card(
                      child: Column(
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
                          Container(
                            width: double.infinity,
                            child: CachedNetworkImage(
                              imageUrl: post['postImageUrl'],
                              placeholder: (context, url) => Center(child: CircularProgressIndicator()),
                              errorWidget: (context, url, error) => Icon(Icons.error),
                              fit: BoxFit.cover,
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

  void _toggleLikePost(String postId, String userId, bool likedByCurrentUser, String postOwnerId) async {
    final postRef = _firestore.collection('posts').doc(postId);
    if (likedByCurrentUser) {
      await postRef.update({
        'likes': FieldValue.arrayRemove([userId]),
      });
    } else {
      await postRef.update({
        'likes': FieldValue.arrayUnion([userId]),
      });

      await _firestore.collection('notifications').add({
        'recipient': postOwnerId,
        'type': 'like',
        'postId': postId,
        'sender': userId,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
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
                    decoration: InputDecoration(hintText: 'Enter your comment'),
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

                        await _firestore.collection('notifications').add({
                          'recipient': postOwnerId,
                          'type': 'comment',
                          'postId': postId,
                          'sender': currentUser.uid,
                          'isRead': false,
                          'timestamp': FieldValue.serverTimestamp(),
                        });

                        Navigator.of(context).pop();
                      }
                    },
                    child: Text('Submit'),
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
}
