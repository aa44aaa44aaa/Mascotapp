import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart'; // Importa url_launcher para abrir WhatsApp

class AdoptionRequestsScreen extends StatelessWidget {
  const AdoptionRequestsScreen({Key? key}) : super(key: key);

  Future<List<DocumentSnapshot>> _fetchAdoptionRequests() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('ApplyAdopt')
          .where('idRefugio', isEqualTo: user.uid)
          .orderBy('fecsolicitud', descending: true)
          .get();
      return querySnapshot.docs;
    }
    return [];
  }

  Future<Map<String, dynamic>?> _fetchPetData(String petId) async {
    try {
      DocumentSnapshot petSnapshot =
          await FirebaseFirestore.instance.collection('pets').doc(petId).get();

      if (petSnapshot.exists) {
        return petSnapshot.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print("Error fetching pet data: $e");
      return null;
    }
  }

  Future<void> _launchWhatsApp(String phoneNumber, String message) async {
    final whatsappUrl1 =
        'whatsapp://send?phone=$phoneNumber?text=${Uri.encodeComponent(message)}';
    final whatsappUrl = Uri.parse(whatsappUrl1);
    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl);
    } else {
      throw 'Could not launch $whatsappUrl';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitudes de Adopción'),
      ),
      body: FutureBuilder<List<DocumentSnapshot>>(
        future: _fetchAdoptionRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No hay solicitudes de adopción'),
            );
          }

          var requests = snapshot.data!;

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              var request = requests[index];
              var data = request.data() as Map<String, dynamic>;
              var timeAgoString = timeago.format(data['fecsolicitud'].toDate());

              return FutureBuilder<Map<String, dynamic>?>(
                future: _fetchPetData(data['idMascota']),
                builder: (context, petSnapshot) {
                  if (!petSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var petData = petSnapshot.data ?? {};
                  var petImageUrl = petData['petImageUrl'] as String?;
                  var petName = petData['petName'] as String? ?? 'Desconocido';

                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: petImageUrl != null
                            ? CachedNetworkImageProvider(petImageUrl)
                            : const AssetImage('assets/default_pet.png')
                                as ImageProvider,
                        radius: 30,
                        onBackgroundImageError: (_, __) =>
                            const Icon(Icons.pets),
                      ),
                      title: Text(data['nombreComp'] ?? 'Solicitante'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mascota: $petName'),
                          Text('Hace: $timeAgoString'),
                        ],
                      ),
                      trailing: data['revisado']
                          ? const Icon(Icons.check, color: Colors.green)
                          : const Icon(Icons.info, color: Colors.orange),
                      onTap: () {
                        // Acción al seleccionar una solicitud
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('Detalles de Solicitud'),
                              content: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Nombre: ${data['nombreComp']}'),
                                  Text('RUT: ${data['rut']}'),
                                  Text('Teléfono: ${data['numTel']}'),
                                  Text('Dirección: ${data['dir']}'),
                                  const SizedBox(height: 10),
                                  ElevatedButton(
                                    onPressed: () {
                                      FirebaseFirestore.instance
                                          .collection('ApplyAdopt')
                                          .doc(request.id)
                                          .update({'revisado': true});
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('Marcar como revisado'),
                                  ),
                                  const SizedBox(height: 10),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      _launchWhatsApp(
                                        data['numTel'],
                                        'Hola ${data['nombreComp']}, te escribo por tu solicitud de adopción para la mascota $petName.',
                                      );
                                    },
                                    icon: const Icon(Icons.phone),
                                    label:
                                        const Text('Comunicarse al WhatsApp'),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('Cerrar'),
                                ),
                              ],
                            );
                          },
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