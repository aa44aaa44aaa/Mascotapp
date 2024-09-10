import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../notifications/notification_service.dart';

class ApplyRefugioScreen extends StatefulWidget {
  const ApplyRefugioScreen({super.key});

  @override
  _ApplyRefugioScreenState createState() => _ApplyRefugioScreenState();
}

class _ApplyRefugioScreenState extends State<ApplyRefugioScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  bool _isRefugio = false;
  bool _isAdmin = false;
  bool _hasSubmitted = false;
  String? _uid;

  // Form fields
  final TextEditingController _nomRefugioController = TextEditingController();
  final TextEditingController _dirRefugioController = TextEditingController();
  final TextEditingController _nomRepresentanteController =
      TextEditingController();
  final TextEditingController _rutRepresentanteController =
      TextEditingController();
  final TextEditingController _telRepresentanteController =
      TextEditingController();
  final TextEditingController _cantAnimalesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkIfSubmitted();
  }

  Future<void> _loadUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      setState(() {
        _uid = user.uid;
        _isRefugio = userDoc['rol'] == 'refugio';
        _isAdmin = userDoc['rol'] == 'admin';
      });
    }
  }

  Future<void> _checkIfSubmitted() async {
    User? user = _auth.currentUser;
    if (user != null) {
      QuerySnapshot submissions = await _firestore
          .collection('ApplyRefugio')
          .where('IDUsuario', isEqualTo: user.uid)
          .get();
      if (submissions.docs.isNotEmpty) {
        setState(() {
          _hasSubmitted = true;
        });
      }
    }
  }

  Future<void> _submitApplication() async {
    if (_formKey.currentState!.validate()) {
      await _firestore.collection('ApplyRefugio').add({
        'nomRefugio': _nomRefugioController.text,
        'dirRefugio': _dirRefugioController.text,
        'nomRepresentante': _nomRepresentanteController.text,
        'rutRepresentante': _formatRut(_rutRepresentanteController.text),
        'telRepresentante': _telRepresentanteController.text,
        'cantAnimales': int.parse(_cantAnimalesController.text),
        'fecsolicitud': DateTime.now(),
        'IDUsuario': _uid,
        'revisado': false,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud enviada con éxito!')),
      );

      // Enviar notificación personalizada
      final NotificationService notificationService = NotificationService();
      await notificationService.sendCustomNotification(
        'Recibimos tu solicitud para ser refugio! El equipo de MascotAPP está revisandola.',
        '0xe18d', // Código del icono de pets
        _uid!,
      );

      setState(() {
        _hasSubmitted = true;
      });
    }
  }

  // Formatear RUT
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

  // Validar RUT
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

  // Validar número chileno
  bool _validarNumeroChileno(String numero) {
    final regex = RegExp(r'^\+569\d{8}$'); // Formato "+569XXXXXXXX"
    return regex.hasMatch(numero);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ser Refugio'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isRefugio
            ? _buildRefugioMessage()
            : _isAdmin
                ? _buildAdminMessage()
                : _hasSubmitted
                    ? _buildSubmittedMessage()
                    : _buildForm(),
      ),
    );
  }

  Widget _buildRefugioMessage() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pets, size: 100, color: Colors.orange),
          SizedBox(height: 16),
          Text(
            'Ya eres refugio! Gracias por contribuir con nuestra comunidad.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminMessage() {
    return const Center(
      child: Text(
        'Eres admin!',
        style: TextStyle(fontSize: 20, color: Colors.green),
      ),
    );
  }

  Widget _buildSubmittedMessage() {
    return const Center(
      child: Text(
        'Su solicitud está en revisión!',
        style: TextStyle(fontSize: 20, color: Colors.blue),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          TextFormField(
            controller: _nomRefugioController,
            decoration: const InputDecoration(labelText: 'Nombre del refugio'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Este campo es obligatorio';
              }
              return null;
            },
          ),
          TextFormField(
            controller: _dirRefugioController,
            decoration:
                const InputDecoration(labelText: 'Dirección del refugio'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Este campo es obligatorio';
              }
              return null;
            },
          ),
          TextFormField(
            controller: _nomRepresentanteController,
            decoration:
                const InputDecoration(labelText: 'Nombre del representante'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Este campo es obligatorio';
              }
              return null;
            },
          ),
          TextFormField(
            controller: _rutRepresentanteController,
            decoration:
                const InputDecoration(labelText: 'RUT del representante'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Este campo es obligatorio';
              }
              if (!_validarRut(value)) {
                return 'RUT inválido';
              }
              return null;
            },
          ),
          TextFormField(
            controller: _telRepresentanteController,
            decoration:
                const InputDecoration(labelText: 'Teléfono del representante'),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Este campo es obligatorio';
              }
              if (!_validarNumeroChileno(value)) {
                return 'Teléfono inválido, debe ser en formato +569XXXXXXXX';
              }
              return null;
            },
          ),
          TextFormField(
            controller: _cantAnimalesController,
            decoration:
                const InputDecoration(labelText: 'Cantidad de animales'),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Este campo es obligatorio';
              }
              if (int.tryParse(value) == null) {
                return 'Debe ser un número válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _submitApplication,
            child: const Text('Enviar Solicitud'),
          ),
        ],
      ),
    );
  }
}
