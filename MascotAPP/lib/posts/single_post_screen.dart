import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../user/user_profile.dart';

class SinglePostScreen extends StatefulWidget {
  final String postId;

  const SinglePostScreen({super.key, required this.postId});

  @override
  _SinglePostScreenState createState() => _SinglePostScreenState();
}

class _SinglePostScreenState extends State<SinglePostScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final currentUser = FirebaseAuth.instance.currentUser;

  late Future<DocumentSnapshot> postFuture;
  bool inAdoption = false;

  @override
  void initState() {
    super.initState();
    postFuture = _firestore.collection('posts').doc(widget.postId).get();
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
    setState(() {
      postFuture = _firestore.collection('posts').doc(widget.postId).get();
    });
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
                    decoration: const InputDecoration(hintText: 'Enter your comment'),
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
                    child: const Text('Submit'),
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
              future: _firestore.collection('users').doc(comment['userId']).get(),
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
      stream: _firestore.collection('posts').doc(postId).collection('comments').orderBy('timestamp', descending: true).snapshots(),
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
              future: _firestore.collection('users').doc(comment['userId']).get(),
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

                  var owner = ownerSnapshot.data!.data() as Map<String, dynamic>;

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
                                        builder: (context) => UserProfileScreen(userId: postedBy),
                                      ),
                                    );
                                  },
                                  child: CircleAvatar(
                                    backgroundImage: pet['petImageUrl'] != null
                                        ? CachedNetworkImageProvider(pet['petImageUrl'])
                                        : const AssetImage('assets/default_profile.png') as ImageProvider,
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
                                  placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                  errorWidget: (context, url, error) => const Icon(Icons.error),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => UserProfileScreen(userId: postedBy),
                                      ),
                                    );
                                  },
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundImage: owner['profileImageUrl'] != null
                                            ? CachedNetworkImageProvider(owner['profileImageUrl'])
                                            : const AssetImage('assets/default_profile.png') as ImageProvider,
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
                                      likedByCurrentUser ? Icons.favorite : Icons.favorite_outline,
                                      color: likedByCurrentUser ? Colors.red : null,
                                    ),
                                    onPressed: () {
                                      _toggleLikePost(widget.postId, currentUser!.uid, likedByCurrentUser, postedBy);
                                    },
                                  ),
                                  Text('$likeCount likes'),
                                  IconButton(
                                    icon: const Icon(Icons.comment),
                                    onPressed: () {
                                      _showCommentDialog(context, widget.postId, postedBy);
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
                                  color: Colors.brown,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.pets, color: Colors.white, size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      '¡Adóptame!',
                                      style: TextStyle(color: Colors.white, fontSize: 12),
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
