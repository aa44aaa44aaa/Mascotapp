import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';

const MAPBOX_ACCESS_TOKEN =
    'pk.eyJ1IjoiYWE0NGFhYTQ0YWFhIiwiYSI6ImNtMXNsa2NvNDA0dzQyb3E0am4zdTc5ZmcifQ.DkLqjouazVETO5EfYKTmhw';

class EditPetScreen extends StatefulWidget {
  final String petId;

  const EditPetScreen({super.key, required this.petId});

  @override
  _EditPetScreenState createState() => _EditPetScreenState();
}

class _EditPetScreenState extends State<EditPetScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  bool showUserTooltip = false;
  String? petName, petType, petBreed, petStatus, location;
  DateTime? birthDate;
  int? ageYears;
  int? ageMonths;
  bool _knowsExactDate = true;
  File? _petImage;
  bool _isSterilized = false;
  bool _isVaccinated = false;
  final picker = ImagePicker();
  Map<String, dynamic>? petData;
  double? lat;
  double? long;
  LatLng? userLocation;
  String? userProfilePicUrl = 'assets/default_profile.png';

  MapController mapController = MapController();

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      if (pickedFile != null) {
        _petImage = File(pickedFile.path);
      }
    });
  }

  Future<void> _getPetData() async {
    DocumentSnapshot petDoc =
        await _firestore.collection('pets').doc(widget.petId).get();
    setState(() {
      petData = petDoc.data() as Map<String, dynamic>;
      petName = petData!['petName'];
      petType = petData!['petType'];
      petBreed = petData!['petBreed'];
      petStatus = petData!['estado'];
      birthDate = (petData!['birthDate'] as Timestamp).toDate();
      _knowsExactDate = true; // Asume que inicialmente conoce la fecha exacta
      lat = petData!['lat'] ?? null;
      long = petData!['long'] ?? null;
      _isSterilized = petData!['esterilizado'] ?? false;
      _isVaccinated = petData!['vacunado'] ?? false;
      location = petData!['location'] ?? null;
    });
  }

  Future<void> _updatePet() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      try {
        String? imageUrl = petData!['petImageUrl'];
        if (_petImage != null) {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('pet_images')
              .child('${widget.petId}.webp');
          final uploadTask = await storageRef.putFile(_petImage!);

          if (uploadTask.state == TaskState.success) {
            imageUrl = await storageRef.getDownloadURL();
          } else {
            throw Exception('Failed to upload pet image.');
          }
        }

        DateTime birthDateToSave;
        if (_knowsExactDate && birthDate != null) {
          birthDateToSave = birthDate!;
        } else if (ageYears != null && ageMonths != null) {
          birthDateToSave = DateTime.now()
              .subtract(Duration(days: (ageYears! * 365) + (ageMonths! * 30)));
        } else {
          throw Exception(
              'Debe proporcionar una fecha de nacimiento o una edad válida.');
        }

        // Actualización de la mascota con los nuevos campos
        await _firestore.collection('pets').doc(widget.petId).update({
          'petName': petName,
          'petType': petType,
          'petBreed': petBreed,
          'birthDate': birthDateToSave,
          'petImageUrl': imageUrl,
          'estado': petStatus,
          if (lat != null && long != null) 'lat': lat, // Guardar lat y long
          if (lat != null && long != null) 'long': long,
          if (location != null) 'location': location,
          if (petStatus == 'adopcion') 'esterilizado': _isSterilized,
          if (petStatus == 'adopcion') 'vacunado': _isVaccinated,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AwesomeSnackbarContent(
              title: 'Perfecto!',
              message:
                  'Se actualizó correctamente la información de su mascota.',
              contentType: ContentType.success,
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        );

        Navigator.of(context).pop();
      } catch (e) {
        print(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            elevation: 0,
            content: AwesomeSnackbarContent(
              title: 'Error',
              message: '$e',
              contentType: ContentType.failure,
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmDeletePet() async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('¿Estás seguro?'),
          content: const Text('¿Desea eliminar esta mascota?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sí'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      _deletePet();
    }
  }

  Future<void> _deletePet() async {
    try {
      // Iniciar una referencia a la colección de 'posts' de la mascota
      final QuerySnapshot petPostsSnapshot = await _firestore
          .collection('posts')
          .where('petId', isEqualTo: widget.petId)
          .get();

      WriteBatch batch = _firestore.batch(); // Batch de Firestore

      // Iterar sobre cada post relacionado con la mascota
      for (DocumentSnapshot doc in petPostsSnapshot.docs) {
        final postData = doc.data() as Map<String, dynamic>;

        // Verificar si el post tiene una imagen y eliminarla de Firebase Storage
        if (postData['postImageUrl'] != null &&
            postData['postImageUrl'].isNotEmpty) {
          final String imageUrl = postData['postImageUrl'];
          final Reference imageRef =
              FirebaseStorage.instance.refFromURL(imageUrl);

          await imageRef.delete(); // Eliminar la imagen de Firebase Storage
        }

        // Eliminar el post del batch
        batch.delete(doc.reference);
      }

      // Eliminar la mascota
      batch.delete(_firestore.collection('pets').doc(widget.petId));

      // Commit del batch (eliminar mascota y posts)
      await batch.commit();

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AwesomeSnackbarContent(
            title: 'Eliminado',
            message:
                'Mascota, sus posts y sus imágenes eliminados correctamente',
            contentType: ContentType.failure,
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      );

      // Volver a la pantalla anterior
      Navigator.of(context).pop();
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AwesomeSnackbarContent(
            title: 'Error',
            message: 'Error: $e',
            contentType: ContentType.failure,
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      );
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
                          child: userMarker(),
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
          // Ensure that place_type is a list and then check if it contains 'place'
          final place = data['features'].firstWhere(
            (feature) => (feature['place_type'] is List &&
                feature['place_type'].contains('place')),
            orElse: () => null,
          );
          if (place != null) {
            setState(() {
              location = place['text']; // Guardar el nombre de la ciudad
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
  void initState() {
    super.initState();
    _getUserLocation();
    _getPetData();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    User? user = _auth.currentUser;
    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(user!.uid).get();
    setState(() {
      userProfilePicUrl =
          userDoc['profileImageUrl'] ?? 'assets/default_profile.png';
    });
  }

  @override
  Widget userMarker() {
    return Tooltip(
      message: showUserTooltip ? '¡Estás aquí!' : '', // Mensaje del tooltip
      triggerMode: TooltipTriggerMode.tap,
      child: CircleAvatar(
        radius: 25, // Tamaño del avatar del usuario
        backgroundImage: userProfilePicUrl != null
            ? CachedNetworkImageProvider(userProfilePicUrl!)
            : const AssetImage('assets/default_profile.png') as ImageProvider,
        child: Container(
          decoration: BoxDecoration(
            border:
                Border.all(color: Colors.blueAccent, width: 4), // Borde azul
            borderRadius: BorderRadius.circular(50),
          ),
        ),
      ),
    );
  }

  Widget build(BuildContext context) {
    if (petData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Editar Mascota'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Mascota'),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.delete_forever,
              color: Colors.red,
            ),
            onPressed: _confirmDeletePet,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: <Widget>[
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: _petImage != null
                      ? FileImage(_petImage!)
                      : petData!['petImageUrl'] != null
                          ? NetworkImage(petData!['petImageUrl'])
                          : null,
                  child: _petImage == null && petData!['petImageUrl'] == null
                      ? const Icon(Icons.camera_alt, size: 50)
                      : null,
                ),
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                initialValue: petName,
                decoration: const InputDecoration(labelText: 'Nombre'),
                onSaved: (value) => petName = value,
                validator: (value) {
                  if (value!.isEmpty) return 'Ingrese el nombre de su mascota';
                  return null;
                },
              ),
              TextFormField(
                initialValue: petType,
                decoration: const InputDecoration(labelText: 'Tipo'),
                onSaved: (value) => petType = value,
                validator: (value) {
                  if (value!.isEmpty) return 'Ingrese el tipo de su mascota';
                  return null;
                },
              ),
              TextFormField(
                initialValue: petBreed,
                decoration: const InputDecoration(labelText: 'Raza'),
                onSaved: (value) => petBreed = value,
                validator: (value) {
                  if (value!.isEmpty) return 'Ingrese la raza de su mascota';
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              // Selector de estado de la mascota (DropdownButtonFormField)
              DropdownButtonFormField<String>(
                value: petStatus,
                decoration:
                    const InputDecoration(labelText: 'Estado de la mascota'),
                items: [
                  DropdownMenuItem(value: 'nada', child: const Text('Ninguno')),
                  DropdownMenuItem(
                      value: 'adopcion', child: const Text('En Adopción')),
                  DropdownMenuItem(
                      value: 'perdido', child: const Text('Perdido')),
                  DropdownMenuItem(
                      value: 'enmemoria', child: const Text('En Memoria')),
                ],
                onChanged: (String? newValue) {
                  setState(() {
                    petStatus = newValue;
                  });
                },
                onSaved: (value) => petStatus = value,
              ),
              const SizedBox(height: 16.0),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('Conozco la fecha exacta'),
                      value: true,
                      groupValue: _knowsExactDate,
                      onChanged: (bool? value) {
                        setState(() {
                          _knowsExactDate = value!;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('No sé la fecha exacta'),
                      value: false,
                      groupValue: _knowsExactDate,
                      onChanged: (bool? value) {
                        setState(() {
                          _knowsExactDate = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              if (_knowsExactDate)
                TextFormField(
                  decoration:
                      const InputDecoration(labelText: 'Fecha de nacimiento'),
                  readOnly: true,
                  onTap: () async {
                    FocusScope.of(context).requestFocus(FocusNode());
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: birthDate ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null && picked != birthDate) {
                      setState(() {
                        birthDate = picked;
                      });
                    }
                  },
                  validator: (value) {
                    if (birthDate == null)
                      return 'Ingrese la fecha de nacimiento';
                    return null;
                  },
                  controller: TextEditingController(
                    text: birthDate != null
                        ? DateFormat('yyyy-MM-dd').format(birthDate!)
                        : '',
                  ),
                ),
              if (!_knowsExactDate)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(labelText: 'Años'),
                        keyboardType: TextInputType.number,
                        onSaved: (value) => ageYears = int.tryParse(value!),
                        validator: (value) {
                          if (value!.isEmpty) return 'Ingresa los años';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16.0),
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(labelText: 'Meses'),
                        keyboardType: TextInputType.number,
                        onSaved: (value) => ageMonths = int.tryParse(value!),
                        validator: (value) {
                          if (value!.isEmpty) return 'Ingresa los meses';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16.0),
              // Campo de ubicación si la mascota está en adopción o perdida
              if (petStatus == 'perdido' || petStatus == 'adopcion')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Ubicación:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          lat != null && long != null
                              ? '(${lat?.toStringAsFixed(2)}, ${long?.toStringAsFixed(2)})'
                              : 'No seleccionada',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Nombre de la ubicación:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            location != null ? '$location' : 'No seleccionada',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              if (petStatus == 'perdido' || petStatus == 'adopcion')
                ElevatedButton(
                  onPressed: _selectLocationOnMap,
                  child: const Text('Seleccionar en el Mapa'),
                ),
              // Checkboxes de esterilizado y vacunado si la mascota está en adopción
              if (petStatus == 'adopcion')
                Column(
                  children: [
                    CheckboxListTile(
                      title: const Text('¿Está esterilizado?'),
                      value: _isSterilized,
                      onChanged: (bool? value) {
                        setState(() {
                          _isSterilized = value!;
                        });
                      },
                    ),
                    CheckboxListTile(
                      title: const Text('¿Está vacunado?'),
                      value: _isVaccinated,
                      onChanged: (bool? value) {
                        setState(() {
                          _isVaccinated = value!;
                        });
                      },
                    ),
                  ],
                ),
              const SizedBox(height: 16.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _updatePet,
                      child: const Text('Actualizar'),
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  //Expanded(
                  //  child: ElevatedButton(
                  //    onPressed: _confirmDeletePet,
                  //    style: ElevatedButton.styleFrom(
                  //      backgroundColor: Colors.red,
                  //    ),
                  //    child: const Text('Eliminar'),
                  //  ),
                  //),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
