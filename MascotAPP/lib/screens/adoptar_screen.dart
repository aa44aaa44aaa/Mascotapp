import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../pets/pet_profile.dart';
import '../utils/mascotapp_colors.dart';

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
              var location = pet['location'];

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
                                    color: MascotAppColors.refugio, size: 16),
                            ],
                          ),
                          Row(children: [
                            Icon(Icons.location_pin,
                                color: Colors.red, size: 16),
                            Text(location),
                          ]),
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
