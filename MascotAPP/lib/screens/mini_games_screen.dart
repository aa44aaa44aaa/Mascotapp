import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../minigames-private/memory_game.dart';

class MiniGamesScreen extends StatelessWidget {
  const MiniGamesScreen({super.key});

  Future<String?> _getPetImageUrl(BuildContext context) async {
    final _auth = FirebaseAuth.instance;
    User? user = _auth.currentUser;
    if (user == null) return null;
    final _firestore = FirebaseFirestore.instance;
    var snapshot = await _firestore
        .collection('pets')
        .where('owner', isEqualTo: user.uid)
        .get();
    if (snapshot.docs.isNotEmpty) {
      var pet = snapshot.docs.first.data();
      return pet['petImageUrl'];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minijuegos'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Juego de Memoria'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const MemoryGameScreen()),
              );
            },
          )
          // Agrega más minijuegos aquí
        ],
      ),
    );
  }
}
