import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../services/validations_service.dart';
import '../services/notification_service.dart'; // Importa el servicio de notificaciones
import '../services/email_service.dart';

class ApplyAdoptScreen extends StatefulWidget {
  final String petId;

  const ApplyAdoptScreen({super.key, required this.petId});

  @override
  _ApplyAdoptScreenState createState() => _ApplyAdoptScreenState();
}

class _ApplyAdoptScreenState extends State<ApplyAdoptScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _rutController = TextEditingController();
  final TextEditingController _phoneController =
      TextEditingController(text: "+56");

  String nombreComp = '';
  String rut = '';
  String numTel = '';
  String dir = '';
  bool hasSentRequest = false;

  @override
  void initState() {
    super.initState();
    _checkExistingRequest();
  }

  @override
  void dispose() {
    _rutController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendAdoptNotification(
      String idSolicitante, String petName) async {
    try {
      final NotificationService notificationService = NotificationService();
      await notificationService.sendCustomNotification(
        'Enviaste una solicitud de adopción para $petName',
        '1',
        idSolicitante,
      );
    } catch (e) {
      print("Error sending notification: $e");
    }
  }

  Future<void> _checkExistingRequest() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    final existingRequest = await FirebaseFirestore.instance
        .collection('ApplyAdopt')
        .where('idSolicitante', isEqualTo: userId)
        .where('idMascota', isEqualTo: widget.petId)
        .get();

    if (existingRequest.docs.isNotEmpty) {
      setState(() {
        hasSentRequest = true;
      });
    }
  }

  Future<void> _submitForm(String petNameNotifica) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
          'No se pudo obtener la información del usuario. Por favor, inicia sesión.');
      return;
    }

    final userId = user.uid;
    final petRef =
        FirebaseFirestore.instance.collection('pets').doc(widget.petId);
    final petData = await petRef.get();
    final petOwnerId = petData['owner'];

    await FirebaseFirestore.instance.collection('ApplyAdopt').add({
      'nombreComp': nombreComp,
      'rut': rut,
      'numTel': _phoneController.text,
      'dir': dir,
      'idSolicitante': userId,
      'idRefugio': petOwnerId,
      'idMascota': widget.petId,
      'revisado': false,
      'fecsolicitud': Timestamp.now(),
    });

    // Enviar notificación por correo
    final emailService = EmailService();
    await emailService.sendAdoptNotificationEmail(petNameNotifica, nombreComp);

    await _sendAdoptNotification(userId, petNameNotifica);

    _showMessage(
        'Hemos enviado tus datos al refugio, espera a que te contacten.');
    setState(() {
      hasSentRequest = true;
    });
  }

  void _showMessage(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: Text(message),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adopción')),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('pets')
            .doc(widget.petId)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var pet = snapshot.data!.data() as Map<String, dynamic>;

          if (hasSentRequest) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pets, size: 100, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    '¡Ya enviaste una solicitud!',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const Text(
                    'Debes esperar a que el refugio te contacte',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: pet['petImageUrl'] != null
                          ? NetworkImage(pet['petImageUrl'])
                          : const AssetImage('assets/placeholder.png')
                              as ImageProvider,
                    ),
                    const SizedBox(width: 16),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pet['petName'],
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            softWrap: true,
                            overflow: TextOverflow.visible,
                          ),
                          Text('${pet['petType']} - ${pet['petBreed']}'),
                          Row(children: [
                            Icon(Icons.location_pin,
                                color: Colors.red, size: 16),
                            Text(pet['location']),
                          ]),
                        ],
                      ),
                    ),
                    if (pet['vacunado'] == true)
                      Icon(Icons.vaccines, color: Colors.green, size: 20),
                    if (pet['vacunado'] == true) const SizedBox(width: 8),
                    if (pet['esterilizado'] == true)
                      Icon(Icons.local_hospital, color: Colors.blue, size: 20),
                  ],
                ),
                const SizedBox(height: 20),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Nombre Completo',
                        ),
                        onChanged: (value) => nombreComp = value,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Este campo es obligatorio';
                          } else if (!ValidationService.validarNombreCompleto(
                              value)) {
                            return 'Debe ingresar al menos un nombre y un apellido';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: _rutController,
                        decoration: const InputDecoration(labelText: 'RUT'),
                        onChanged: (value) {
                          setState(() {
                            rut = ValidationService.formatRut(value);
                            _rutController.value = TextEditingValue(
                              text: rut,
                              selection:
                                  TextSelection.collapsed(offset: rut.length),
                            );
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Este campo es obligatorio';
                          } else if (!ValidationService.validarRut(value)) {
                            return 'RUT inválido';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Número de Teléfono',
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Este campo es obligatorio';
                          } else if (!ValidationService.validarNumeroChileno(
                              value)) {
                            return 'Número inválido. Debe tener el formato "+569XXXXXXXX"';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        decoration:
                            const InputDecoration(labelText: 'Dirección'),
                        onChanged: (value) => dir = value,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Este campo es obligatorio';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            _submitForm(pet['petName']);
                          }
                        },
                        child: const Text('Enviar Solicitud'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
