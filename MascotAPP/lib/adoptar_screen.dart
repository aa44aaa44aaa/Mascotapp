import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'pet_profile.dart';

class AdoptarScreen extends StatelessWidget {
  const AdoptarScreen({super.key});

  String calculateAge(Timestamp birthDate) {
    DateTime birth = birthDate.toDate();
    DateTime now = DateTime.now();
    int years = now.year - birth.year;
    int months = now.month - birth.month;
    if (now.day < birth.day) {
      months--;
    }
    if (months < 0) {
      years--;
      months += 12;
    }
    return years > 0 ? '$years años, $months meses' : '$months meses';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SvgPicture.asset(
              'assets/adopt.svg',
              height: 50.0, // Ajusta el tamaño según sea necesario
            ),
            Text(
              'Mascotas en adopción',
              style: TextStyle(
                fontSize:
                    20.0, // Ajusta el tamaño de la fuente según sea necesario
              ),
            ),
          ],
        ),
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('pets')
            .where('estado', isEqualTo: 'adopcion')
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var pets = snapshot.data!.docs;

          if (pets.isEmpty) {
            return const Center(child: Text('No hay mascotas en adopción.'));
          }

          return ListView.builder(
            itemCount: pets.length,
            itemBuilder: (context, index) {
              var pet = pets[index].data() as Map<String, dynamic>;
              var ownerId = pet['owner'];
              var textoestado = pet['textoestado'];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(ownerId)
                    .get(),
                builder: (context, ownerSnapshot) {
                  if (!ownerSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var owner =
                      ownerSnapshot.data!.data() as Map<String, dynamic>;
                  var ownerName = owner['username'];
                  var ownerRole = owner['rol'];
                  var petAge = calculateAge(pet['birthDate']);

                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: pet['petImageUrl'] != null
                            ? CachedNetworkImageProvider(pet['petImageUrl'])
                            : const AssetImage('assets/default_pet.png')
                                as ImageProvider,
                      ),
                      title: Text(pet['petName']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${pet['petType']} - $petAge\nPor: @$ownerName',
                                style: const TextStyle(height: 1.5),
                              ),
                              if (ownerRole ==
                                  'refugio') // Añadir patita si el rol es refugio
                                const Icon(Icons.pets,
                                    color: Colors.brown, size: 16),
                            ],
                          ),
                          Text(textoestado),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                PetProfileScreen(petId: pets[index].id),
                          ),
                        );
                      },
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

class PetProfileScreen extends StatelessWidget {
  final String petId;

  const PetProfileScreen({super.key, required this.petId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Perfil de la Mascota'),
      ),
      body: Center(
        child: Text('Perfil de la mascota con ID: $petId'),
      ),
    );
  }
}
