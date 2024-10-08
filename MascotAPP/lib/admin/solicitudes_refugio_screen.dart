import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../services/functions_services.dart'; // Importa el servicio de funciones
import '../services/notification_service.dart';
import '../user/user_profile.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import '../services/email_service.dart';

class RefugeRequestsScreen extends StatefulWidget {
  const RefugeRequestsScreen({Key? key}) : super(key: key);

  @override
  _RefugeRequestsScreenState createState() => _RefugeRequestsScreenState();
}

class _RefugeRequestsScreenState extends State<RefugeRequestsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _currentUserRole;
  bool _isLoading = false;

  // Instancia del servicio de funciones
  final FunctionsServices _functionsServices = FunctionsServices();

  @override
  void initState() {
    super.initState();
    _checkAdminRole();
  }

  Future<void> _checkAdminRole() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      setState(() {
        _currentUserRole = userDoc['rol'];
      });
    }
  }

  Future<List<DocumentSnapshot>> _fetchRefugeRequests() async {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('ApplyRefugio')
        .orderBy('fecsolicitud', descending: true)
        .get();
    return querySnapshot.docs;
  }

  Future<void> _markAsReviewed(DocumentSnapshot request) async {
    setState(() {
      _isLoading = true;
    });
    try {
      await FirebaseFirestore.instance
          .collection('ApplyRefugio')
          .doc(request.id)
          .update({'revisado': true});
    } catch (e) {
      print("Error marking as reviewed: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
      Navigator.of(context).pop(); // Cierra el diálogo
    }
  }

  Future<void> _deleteRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance
          .collection('ApplyRefugio')
          .doc(requestId)
          .delete();
    } catch (e) {
      print("Error deleting request: $e");
    }
  }

  Future<void> _sendReviewNotification(String idSolicitante) async {
    try {
      final NotificationService notificationService = NotificationService();
      await notificationService.sendCustomNotification(
        'Felicitaciones! Tu solicitud para ser refugio fue aprobada. Gracias por ser parte de esto ❤️',
        '2',
        idSolicitante,
      );
    } catch (e) {
      print("Error sending notification: $e");
    }
  }

  Future<void> _convertToRefuge(String userId, DocumentSnapshot request) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Actualiza el rol del usuario a 'refugio'
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'rol': 'refugio'});

      // Recupera el perfil y el email del usuario de Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      // Asegúrate de que los campos existen antes de acceder a ellos
      final profileName = userDoc.get('profileName') ?? 'Nombre no disponible';
      final refugeEmail = userDoc.get('email') ?? 'Correo no disponible';

      // Obtén los valores de latitud, longitud y la dirección del refugio desde el documento de solicitud
      final lat = request.get('lat');
      final long = request.get('long');
      final dirRefugio = request.get('dirRefugio') ?? 'Dirección no disponible';

      // Actualiza los campos 'lat', 'long', y 'location' en el perfil del usuario
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'lat': lat ??
            FieldValue.delete(), // Crea si no existe, o elimina si es null
        'long': long ??
            FieldValue.delete(), // Crea si no existe, o elimina si es null
        'location': dirRefugio, // Crea el campo 'location' con 'dirRefugio'
      });

      // Muestra mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AwesomeSnackbarContent(
            title: 'Éxito!',
            message: 'Usuario convertido en refugio',
            contentType: ContentType.success,
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      );

      // Marca la solicitud como revisada
      _markAsReviewed(request);

      // Envía notificación de revisión
      _sendReviewNotification(userId);

      // Envía un email de notificación
      final emailService = EmailService();
      await emailService.sendApprovedRefugioNotificationEmail(
          profileName, refugeEmail);
    } catch (e) {
      print("Error converting to refuge: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AwesomeSnackbarContent(
            title: 'Error al convertir en refugio',
            message: '$e',
            contentType: ContentType.failure,
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });

      // Cierra el diálogo
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserRole != 'admin') {
      return const Scaffold(
        body: Center(
          child: Text(
              'Acceso denegado: Solo los administradores pueden ver esta página.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitudes para ser refugio'),
      ),
      body: Stack(
        children: [
          FutureBuilder<List<DocumentSnapshot>>(
            future: _fetchRefugeRequests(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text('No hay solicitudes de refugio'),
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
                            title: 'Exitoso',
                            message: 'Solicitud eliminada',
                            contentType: ContentType.success,
                          ),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                        ),
                      );
                    },
                    child: Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        leading: const Icon(Icons.pets), // Icono
                        title: Text(
                          '${data['nomRefugio'] ?? 'Desconocido'}',
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['nomRepresentante'] ?? 'Desconocido'),
                            Text('Teléfono: ${data['telRepresentante']}'),
                            Text('$timeAgoString'),
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
                                    Text(
                                        'Nombre del Refugio: ${data['nomRefugio']}'),
                                    Text(
                                        'Representante: ${data['nomRepresentante']}'),
                                    Text('RUT: ${data['rutRepresentante']}'),
                                    Text(
                                        'Teléfono: ${data['telRepresentante']}'),
                                    Text('Dirección: ${data['dirRefugio']}'),
                                    Text(
                                        'Cantidad de Animales: ${data['cantAnimales']}'),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        // Llama a la función de WhatsApp
                                        _functionsServices.launchWhatsApp(
                                          data['telRepresentante'],
                                          'Hola ${data['nomRepresentante']}, te escribo respecto a tu solicitud de refugio para ${data['nomRefugio']}.',
                                        );
                                      },
                                      icon: const Icon(Icons.phone),
                                      label:
                                          const Text('Contactar por WhatsApp'),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                UserProfileScreen(
                                                    userId: data['IDUsuario']),
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                          Icons.supervised_user_circle),
                                      label: const Text('Ver Perfil'),
                                    ),
                                    const SizedBox(height: 10),
                                    if (!data['revisado']) ...[
                                      ElevatedButton(
                                        onPressed: () {
                                          // Convertir en refugio
                                          _convertToRefuge(
                                              data['IDUsuario'], request);
                                        },
                                        child:
                                            const Text('Convertir en refugio'),
                                      ),
                                    ],
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
