import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';
import '../services/validations_service.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import '../services/email_service.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../utils/mascotapp_colors.dart';

const MAPBOX_ACCESS_TOKEN =
    'pk.eyJ1IjoiYWE0NGFhYTQ0YWFhIiwiYSI6ImNtMXNsa2NvNDA0dzQyb3E0am4zdTc5ZmcifQ.DkLqjouazVETO5EfYKTmhw';

class ApplyRefugioScreen extends StatefulWidget {
  const ApplyRefugioScreen({super.key});

  @override
  _ApplyRefugioScreenState createState() => _ApplyRefugioScreenState();
}

class _ApplyRefugioScreenState extends State<ApplyRefugioScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  String nombreComp = '';
  String rut = '';
  String numTel = '';

  bool _isRefugio = false;
  bool _isAdmin = false;
  bool _hasSubmitted = false;
  String? _uid;

  bool _isLoading = false;

  LatLng? userLocation;
  String? selectedAddress;
  MapController mapController = MapController();
  double? lat;
  double? long;

  // Form fields
  final TextEditingController _nomRefugioController = TextEditingController();
  final TextEditingController _dirRefugioController = TextEditingController();
  final TextEditingController _nomRepresentanteController =
      TextEditingController();
  final TextEditingController _rutRepresentanteController =
      TextEditingController();
  final TextEditingController _telRepresentanteController =
      TextEditingController(text: "+56");
  final TextEditingController _cantAnimalesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _loadUserData();
    _checkIfSubmitted();
  }

  @override
  void dispose() {
    _rutRepresentanteController.dispose();
    _telRepresentanteController.dispose();
    super.dispose();
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
      setState(() {
        _isLoading = true; // Cambiamos a estado de carga
      });

      try {
        await _firestore.collection('ApplyRefugio').add({
          'nomRefugio': _nomRefugioController.text,
          'dirRefugio': _dirRefugioController.text,
          'nomRepresentante': _nomRepresentanteController.text,
          'rutRepresentante': rut,
          'telRepresentante': _telRepresentanteController.text,
          'cantAnimales': int.parse(_cantAnimalesController.text),
          'lat': lat,
          'long': long,
          'dirRefugio': selectedAddress,
          'fecsolicitud': DateTime.now(),
          'IDUsuario': _uid,
          'revisado': false,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AwesomeSnackbarContent(
              title: 'Exito',
              message: 'Solicitud enviada con éxito!',
              contentType: ContentType.success,
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        );

        // Enviar notificación personalizada
        final NotificationService notificationService = NotificationService();
        await notificationService.sendCustomNotification(
          'Recibimos tu solicitud para ser refugio! El equipo de MascotAPP está revisandola.',
          '1', // Código del icono de pets
          _uid!,
        );

        // Enviar notificación por correo
        DateTime now = DateTime.now();
        String formattedDate = DateFormat('dd/MM/yyyy').format(now);
        final emailService = EmailService();
        await emailService.sendApplyRefugioNotificationEmail(
            _nomRefugioController.text,
            _dirRefugioController.text,
            _nomRepresentanteController.text,
            rut,
            _telRepresentanteController.text,
            _cantAnimalesController.text,
            formattedDate);

        setState(() {
          _hasSubmitted = true;
        });
      } finally {
        setState(() {
          _isLoading = false; // Termina el estado de carga
        });
      }
    }
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;
    // Verificar si el servicio de ubicación está habilitado
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('El servicio de ubicación está deshabilitado.');
    }

    // Verificar permisos de ubicación
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Los permisos de ubicación están denegados.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Los permisos de ubicación están denegados permanentemente.');
    }

    // Obtener la ubicación actual del usuario
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    setState(() {
      userLocation = LatLng(position.latitude, position.longitude);
    });

    // Mover el mapa a la ubicación actual
    mapController.move(userLocation!, 13);
  }

  Future<void> _selectLocationOnMap() async {
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return SizedBox(
          height: 400,
          child: Stack(
            children: [
              FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: userLocation ?? LatLng(-33.447, -70.673),
                  initialZoom: 13,
                  onTap: (tapPosition, point) async {
                    setState(() {
                      lat = point.latitude;
                      long = point.longitude;
                      userLocation =
                          point; // Actualizar la ubicación seleccionada
                    });
                    // Llamar a la API de Mapbox para obtener el nombre de la ciudad
                    await _getCityNameFromCoordinates(lat!, long!);

                    Navigator.pop(context); // Cerrar el mapa
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://api.mapbox.com/styles/v1/{id}/tiles/{z}/{x}/{y}?access_token={accessToken}',
                    additionalOptions: const {
                      'accessToken': MAPBOX_ACCESS_TOKEN,
                      'id': 'mapbox/streets-v12',
                    },
                  ),
                  if (userLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: userLocation!,
                          width: 50,
                          height: 50,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              Positioned(
                bottom: 20, // Ajusta la distancia desde la parte inferior
                left: 20,
                right:
                    20, // Hace que el botón se ajuste al ancho del contenedor
                child: TextButton(
                  onPressed: () async {
                    if (userLocation != null) {
                      setState(() {
                        lat = userLocation!.latitude;
                        long = userLocation!.longitude;
                      });
                      // Llamar a la API de Mapbox para obtener el nombre de la ciudad con la ubicación actual
                      await _getCityNameFromCoordinates(lat!, long!);

                      Navigator.pop(context); // Cerrar el mapa
                    }
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.all(16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      side: const BorderSide(
                          color: Colors.blue), // Borde opcional
                    ),
                  ),
                  child: const Text(
                    'Seleccionar mi ubicación actual',
                    style: TextStyle(color: Colors.blue), // Color del texto
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _getCityNameFromCoordinates(double lat, double long) async {
    final url =
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$long,$lat.json?access_token=$MAPBOX_ACCESS_TOKEN';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("data: $data");

        if (data['features'].isNotEmpty) {
          // Busca el primer feature que tenga place_type como 'place'
          final place = data['features'].firstWhere(
            (feature) => (feature['place_type'] is List &&
                feature['place_type'].contains('place')),
            orElse: () => null,
          );

          if (place != null) {
            setState(() {
              selectedAddress = place['text']; // Guardar el nombre de la ciudad
            });
          }
        }
      } else {
        print('Error al obtener la ubicación: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en la solicitud de Mapbox: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Postulación a Refugio'),
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
          Row(
            children: [
              Icon(Icons.pets, color: MascotAppColors.refugio, size: 50),
              const SizedBox(width: 16),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Gracias por tu interés en ser refugio!",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),
                    Text(
                      "Necesitamos saber más de ti",
                      style: const TextStyle(
                        fontSize: 16,
                      ),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
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
            controller: _nomRepresentanteController,
            decoration: const InputDecoration(
              labelText: 'Nombre del representante',
            ),
            onChanged: (value) => nombreComp = value,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Este campo es obligatorio';
              } else if (!ValidationService.validarNombreCompleto(value)) {
                return 'Debe ingresar al menos un nombre y un apellido';
              }
              return null;
            },
          ),
          TextFormField(
            controller: _rutRepresentanteController,
            decoration:
                const InputDecoration(labelText: 'RUT del representante'),
            onChanged: (value) {
              setState(() {
                rut = ValidationService.formatRut(value);
                _rutRepresentanteController.value = TextEditingValue(
                  text: rut,
                  selection: TextSelection.collapsed(offset: rut.length),
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
            controller: _telRepresentanteController,
            decoration:
                const InputDecoration(labelText: 'Teléfono del representante'),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Este campo es obligatorio';
              } else if (!ValidationService.validarNumeroChileno(value)) {
                return 'Número inválido. Debe tener el formato "+569XXXXXXXX"';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          ListTile(
            title: const Text('Ubicación del refugio'),
            subtitle: Text(selectedAddress ?? 'Seleccionar en el mapa'),
            trailing: IconButton(
              icon: const Icon(Icons.map, size: 40),
              onPressed: _selectLocationOnMap,
            ),
            onTap:
                _selectLocationOnMap, // Esto hace que al tocar cualquier parte del ListTile se ejecute la función
          ),
          TextFormField(
            controller: _cantAnimalesController,
            decoration: const InputDecoration(
                labelText: 'Cantidad de animales (Aprox.)'),
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
            onPressed: _isLoading ? null : _submitApplication,
            child: _isLoading
                ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                : const Text('Enviar Solicitud'),
          ),
        ],
      ),
    );
  }
}
