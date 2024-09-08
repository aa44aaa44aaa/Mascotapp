import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../pets/pet_register.dart';
import '../pets/edit_pet.dart';
import '../pets/pet_profile.dart';

class PetsScreen extends StatefulWidget {
  const PetsScreen({super.key});

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
      return const Center(child: Text('Usuario no autenticado'));
    }

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('pets')
            .where('owner', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var pets = snapshot.data!.docs;

          if (pets.isEmpty) {
            return const Center(
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
              var estado = pet['estado'] ?? '';

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
                          : const AssetImage('assets/default_pet.png'),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(pet['petName']),
                      if (isVerified) ...[
                        const SizedBox(width: 8),
                        const Tooltip(
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
                      if (labelText != null && labelColor != null && icon != null)
                        Container(
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
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
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
            MaterialPageRoute(builder: (context) => const PetRegisterScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
