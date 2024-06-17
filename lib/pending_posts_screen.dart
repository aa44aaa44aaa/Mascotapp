import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PendingPostsScreen extends StatefulWidget {
  @override
  _PendingPostsScreenState createState() => _PendingPostsScreenState();
}

class _PendingPostsScreenState extends State<PendingPostsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _approvePost(DocumentSnapshot post) async {
    // Move post to the 'posts' collection
    await _firestore.collection('posts').add({
      'postedby': post['postedby'],
      'petId': post['petId'],
      'postImageUrl': post['postImageUrl'],
      'text': post['text'],
      'timestamp': FieldValue.serverTimestamp(),
      'likes': [],
    });

    // Delete post from 'pending_posts' collection
    await _firestore.collection('pending_posts').doc(post.id).delete();

    setState(() {});
  }

  Future<List<DocumentSnapshot>> _loadPendingPosts() async {
    User? user = _auth.currentUser;
    if (user == null) {
      return [];
    }

    QuerySnapshot querySnapshot = await _firestore.collection('pending_posts').where('status', isEqualTo: 'pending').get();
    List<DocumentSnapshot> pendingPosts = querySnapshot.docs;

    List<DocumentSnapshot> filteredPosts = [];
    for (var post in pendingPosts) {
      DocumentSnapshot petSnapshot = await _firestore.collection('pets').doc(post['petId']).get();
      if (petSnapshot.exists && petSnapshot['owner'] == user.uid) {
        filteredPosts.add(post);
      }
    }

    return filteredPosts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Posts Pendientes'),
      ),
      body: FutureBuilder<List<DocumentSnapshot>>(
        future: _loadPendingPosts(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final pendingPosts = snapshot.data!;

          if (pendingPosts.isEmpty) {
            return Center(
              child: Text('No hay fotos por aprobar aún.'),
            );
          }

          return ListView.builder(
            itemCount: pendingPosts.length,
            itemBuilder: (context, index) {
              final post = pendingPosts[index];

              return Card(
                margin: EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    if (post['postImageUrl'] != null)
                      CachedNetworkImage(
                        imageUrl: post['postImageUrl'],
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    ListTile(
                      title: Text(post['text'] ?? ''),
                      subtitle: FutureBuilder<DocumentSnapshot>(
                        future: _firestore.collection('users').doc(post['postedby']).get(),
                        builder: (context, userSnapshot) {
                          if (!userSnapshot.hasData) {
                            return Text('Cargando...');
                          }
                          final user = userSnapshot.data;
                          return Text('Enviado por: ${user!['username']}');
                        },
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.check),
                        onPressed: () => _approvePost(post),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
