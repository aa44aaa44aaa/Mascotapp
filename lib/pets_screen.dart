import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'pet_register.dart';
import 'edit_pet.dart';
import 'pet_profile.dart'; // Asegúrate de tener esta importación

class PetsScreen extends StatefulWidget {
  @override
  _PetsScreenState createState() => _PetsScreenState();
}

class _PetsScreenState extends State<PetsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;
    if (user == null) {
      return Center(child: Text('Usuario no autenticado'));
    }

    return Scaffold(
      //appBar: AppBar(
      //  title: Text('Mis Mascotas'),
      //),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('pets')
            .where('owner', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          var pets = snapshot.data!.docs;

          if (pets.isEmpty) {
            return Center(
              child: Text(
                'Aún no agregas una mascota! Haz click en añadir.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: pets.length,
            itemBuilder: (context, index) {
              var pet = pets[index].data() as Map<String, dynamic>;
              var petId = pets[index].id;
              var birthDate = (pet['birthDate'] as Timestamp).toDate();
              var formattedBirthDate = DateFormat('dd-MM-yyyy').format(birthDate);
              var isVerified = pet['verified'] ?? false;

              return Card(
                child: ListTile(
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
                          ? NetworkImage(pet['petImageUrl'])
                          : AssetImage('assets/default_pet.png'),
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
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tipo: ${pet['petType']}'),
                      Text('Raza: ${pet['petBreed']}'),
                      Text('Fecha de nacimiento: $formattedBirthDate'),
                    ],
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.edit),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditPetScreen(petId: petId),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => PetRegisterScreen()),
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
