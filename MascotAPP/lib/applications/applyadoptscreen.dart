import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

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
      TextEditingController(text: "+56 ");

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

  String _formatRut(String text) {
    text = text.replaceAll('.', '').replaceAll('-', '');
    if (text.length > 1) {
      String rutBody = text.substring(0, text.length - 1);
      String dv = text.substring(text.length - 1);
      rutBody = rutBody.replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]}.');
      return '$rutBody-$dv';
    }
    return text;
  }

  // Validar y formatear RUT en tiempo real
  bool _validarRut(String rut) {
    rut = rut.toUpperCase().replaceAll('.', '').replaceAll('-', '');
    if (rut.length < 9) return false;

    String aux = rut.substring(0, rut.length - 1);
    String dv = rut.substring(rut.length - 1);

    List<int> reversedRut = aux.split('').reversed.map(int.parse).toList();
    List<int> factors = [2, 3, 4, 5, 6, 7];

    int sum = 0;
    for (int i = 0; i < reversedRut.length; i++) {
      sum += reversedRut[i] * factors[i % factors.length];
    }

    int res = 11 - (sum % 11);

    if (res == 11) return dv == '0';
    if (res == 10) return dv == 'K';
    return res.toString() == dv;
  }

  // Método para validar el número de teléfono chileno
  bool _validarNumeroChileno(String numero) {
    final regex = RegExp(r'^\+569\d{8}$'); // Formato "+569XXXXXXXX"
    return regex.hasMatch(numero);
  }

  Future<void> _submitForm() async {
    if (!_validarNumeroChileno(_phoneController.text)) {
      _showMessage(
          'Número de teléfono inválido. Debe tener el formato "+569XXXXXXXX"');
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
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
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: _rutController,
                        decoration: const InputDecoration(labelText: 'RUT'),
                        onChanged: (value) {
                          setState(() {
                            rut = _formatRut(value);
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
                          } else if (!_validarRut(value)) {
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
                          } else if (!_validarNumeroChileno(value)) {
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
                            _submitForm();
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
