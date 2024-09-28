import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../services/functions_services.dart'; // Importa el servicio de funciones
import '../services/notification_service.dart'; // Importa el servicio de notificaciones
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';

class AdoptionRequestsScreen extends StatefulWidget {
  const AdoptionRequestsScreen({Key? key}) : super(key: key);

  @override
  _AdoptionRequestsScreenState createState() => _AdoptionRequestsScreenState();
}

class _AdoptionRequestsScreenState extends State<AdoptionRequestsScreen> {
  bool _isLoading = false; // Indicador de carga
  final FunctionsServices _functionsServices =
      FunctionsServices(); // Instancia del servicio

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

  Future<void> _sendReviewNotification(
      String idSolicitante, String petName) async {
    try {
      final NotificationService notificationService = NotificationService();
      await notificationService.sendCustomNotification(
        'Tu solicitud de adopción para $petName ha sido revisada, espera a ser contactado.',
        '1',
        idSolicitante,
      );
    } catch (e) {
      print("Error sending notification: $e");
    }
  }

  Future<void> _markAsReviewed(
      DocumentSnapshot request, String idSolicitante, String petName) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('ApplyAdopt')
          .doc(request.id)
          .update({'revisado': true});

      await _sendReviewNotification(idSolicitante, petName);
    } catch (e) {
      print("Error marking as reviewed: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });

      Navigator.of(context).pop();
    }
  }

  Future<void> _deleteRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance
          .collection('ApplyAdopt')
          .doc(requestId)
          .delete();
    } catch (e) {
      print("Error deleting request: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitudes de Adopción'),
      ),
      body: Stack(
        children: [
          FutureBuilder<List<DocumentSnapshot>>(
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
                  var timeAgoString = timeago
                      .format(data['fecsolicitud'].toDate(), locale: 'es');

                  return Dismissible(
                    key: Key(request.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      alignment: Alignment.centerRight,
                      child: const Icon(
                        Icons.delete,
                        color: Colors.white,
                      ),
                    ),
                    onDismissed: (direction) {
                      _deleteRequest(request.id);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: AwesomeSnackbarContent(
                            title: 'Exito',
                            message: 'Solicitud eliminada con éxito!',
                            contentType: ContentType.success,
                          ),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                        ),
                      );
                    },
                    child: FutureBuilder<Map<String, dynamic>?>(
                      future: _fetchPetData(data['idMascota']),
                      builder: (context, petSnapshot) {
                        if (!petSnapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        var petData = petSnapshot.data ?? {};
                        var petImageUrl = petData['petImageUrl'] as String?;
                        var petName =
                            petData['petName'] as String? ?? 'Desconocido';

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
                                Text('$timeAgoString'),
                              ],
                            ),
                            trailing: data['revisado']
                                ? const Icon(Icons.check, color: Colors.green)
                                : const Icon(Icons.info, color: Colors.orange),
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title: const Text('Detalles de Solicitud'),
                                    content: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('Nombre: ${data['nombreComp']}'),
                                        Text('RUT: ${data['rut']}'),
                                        Text('Teléfono: ${data['numTel']}'),
                                        Text('Dirección: ${data['dir']}'),
                                        if (!data['revisado']) ...[
                                          ElevatedButton(
                                            onPressed: () {
                                              _markAsReviewed(
                                                request,
                                                data['idSolicitante'],
                                                petName,
                                              );
                                            },
                                            child: const Text(
                                                'Marcar como revisado'),
                                          ),
                                          const SizedBox(height: 10),
                                        ],
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            _functionsServices.launchWhatsApp(
                                              data['numTel'],
                                              'Hola ${data['nombreComp']}, te escribo por tu solicitud de adopción para la mascota $petName.',
                                            );
                                          },
                                          icon: const Icon(Icons.phone),
                                          label: const Text(
                                              'Comunicarse al WhatsApp'),
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
                    ),
                  );
                },
              );
            },
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
