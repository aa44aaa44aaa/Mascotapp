import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';

const MAPBOX_ACCESS_TOKEN =
    'pk.eyJ1IjoiYWE0NGFhYTQ0YWFhIiwiYSI6ImNtMXNsa2NvNDA0dzQyb3E0am4zdTc5ZmcifQ.DkLqjouazVETO5EfYKTmhw';

class PetRegisterScreen extends StatefulWidget {
  const PetRegisterScreen({super.key});

  @override
  _PetRegisterScreenState createState() => _PetRegisterScreenState();
}

class _PetRegisterScreenState extends State<PetRegisterScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;
  bool _photoError = false;
  double _opacity = 1.0;
  bool showUserTooltip = false;
  String? userProfilePicUrl = 'assets/default_profile.png';
  String? petName,
      petType,
      petBreed,
      petStatus = 'nada',
      lostLocation,
      location;
  DateTime? birthDate;
  int? ageYears;
  int? ageMonths;
  File? _petImage;
  bool _knowsExactDate = true;
  String? userRole;
  double? lat;
  double? long;
  LatLng? userLocation;
  MapController mapController = MapController();
  bool locationSelected =
      false; // Nueva variable para controlar si la ubicación fue seleccionada.
  String? errorMessage; // Para mostrar el mensaje de error.

  // Nuevas variables booleanas para "Esterilizado" y "Vacunado"
  bool _isSterilized = false;
  bool _isVaccinated = false;

  final picker = ImagePicker();
  List<String> animalTypes = [];
  Map<String, List<String>> animalBreeds = {};
  List<String> breedOptions = [];

  @override
  void initState() {
    super.initState();
    _loadAnimalData();
    _getUserLocation();
    _loadUserRole();
  }

  Future<void> _loadAnimalData() async {
    String data = await rootBundle.loadString('assets/animales.json');
    final jsonResult = json.decode(data);
    setState(() {
      for (var animal in jsonResult['animales']) {
        animalTypes.add(animal['nombre']);
        animalBreeds[animal['nombre']] = List<String>.from(animal['razas']);
      }
    });
  }

  Future<void> _loadUserRole() async {
    User? user = _auth.currentUser;
    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(user!.uid).get();
    setState(() {
      userProfilePicUrl = userDoc['profileImageUrl'] ??
          'assets/default_profile.png'; // Asignamos la imagen o una por defecto
      userRole = userDoc['rol'];
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      );
      if (croppedFile != null) {
        setState(() {
          _petImage = File(croppedFile.path);
          _photoError = false;
        });
      }
    }
  }

  void _nextPage() {
    if (_currentPage == 0 && _petImage == null) {
      setState(() {
        _photoError = true;
      });
    } else if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Validar que la ubicación se haya seleccionado si el estado es adopción o perdido
      if ((petStatus == 'adopcion' || petStatus == 'perdido') &&
          (lat == null || long == null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AwesomeSnackbarContent(
              title: 'Error',
              message: 'Debes seleccionar una ubicación en el mapa.',
              contentType: ContentType.failure,
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        );
        return; // Salir de la función si no hay ubicación seleccionada
      }

      if (_currentPage < 2) {
        _pageController.nextPage(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _registerPet();
      }

      _animateMessage();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _animateMessage();
    }
  }

  Future<void> _registerPet() async {
    if (_petImage != null) {
      setState(() {
        _isLoading = true;
      });
      try {
        User? user = _auth.currentUser;

        String? imageUrl;
        if (_petImage != null) {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('pet_images')
              .child('${user!.uid}-${petName!}.webp');
          final uploadTask = await storageRef.putFile(_petImage!);

          if (uploadTask.state == TaskState.success) {
            imageUrl = await storageRef.getDownloadURL();
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

        // Registrar mascota con todos los datos incluyendo ubicación, esterilizado y vacunado
        await _firestore.collection('pets').add({
          'owner': user!.uid,
          'petName': petName,
          'petType': petType,
          'petBreed': petBreed,
          'birthDate': birthDateToSave,
          'petImageUrl': imageUrl,
          'estado': petStatus,
          'verified': false,
          if (lat != null && long != null) 'lat': lat, // Guardar lat y long
          if (lat != null && long != null) 'long': long,
          if (location != null) 'location': location,
          if (petStatus == 'adopcion') 'esterilizado': _isSterilized,
          if (petStatus == 'adopcion') 'vacunado': _isVaccinated,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AwesomeSnackbarContent(
              title: 'Éxito',
              message: 'Mascota registrada exitosamente.',
              contentType: ContentType.success,
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        );

        Navigator.of(context).pop();
      } catch (e) {
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
      } finally {
        setState(() {
          _isLoading = false;
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

  void _animateMessage() {
    setState(() {
      _opacity = 0.0;
    });

    Future.delayed(Duration(milliseconds: 300), () {
      setState(() {
        _opacity = 1.0;
      });
    });
  }

  String _getMessageForPage(int page) {
    switch (page) {
      case 0:
        return '¡Bien! Comencemos a crear el perfil de tu mascota. Selecciona la foto donde se vea más lindo y dime su nombre.';
      case 1:
        return '¡Qué linda mascota! Cuéntame más sobre tu mascota.';
      case 2:
        return '¡Increíble! ¿Cuántos años tiene? Cuéntame sobre su estado.';
      default:
        return '';
    }
  }

  Widget _buildPageContent() {
    return PageView(
      controller: _pageController,
      physics: NeverScrollableScrollPhysics(),
      onPageChanged: (index) {
        setState(() {
          _currentPage = index;
          _animateMessage();
        });
      },
      children: [
        _buildPage1(),
        _buildPage2(),
        _buildPage3(),
      ],
    );
  }

  Widget _buildPage1() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: CircleAvatar(
            radius: 50,
            backgroundImage: _petImage != null ? FileImage(_petImage!) : null,
            child: _petImage == null
                ? const Icon(Icons.camera_alt, size: 50)
                : null,
          ),
        ),
        if (_photoError)
          const Text(
            'La foto de la mascota es obligatoria',
            style: TextStyle(color: Colors.red),
          ),
        const SizedBox(height: 16.0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextFormField(
            decoration: const InputDecoration(labelText: 'Nombre de mascota'),
            onSaved: (value) => petName = value,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa el nombre de tu mascota';
              } else if (value.length < 2 || value.length > 30) {
                return 'El nombre debe tener entre 2 y 30 caracteres';
              }
              return null;
            },
          ),
        )
      ],
    );
  }

  Widget _buildPage2() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<String>.empty();
              }
              return animalTypes.where((String option) {
                return option
                    .toLowerCase()
                    .contains(textEditingValue.text.toLowerCase());
              });
            },
            onSelected: (String selection) {
              setState(() {
                petType = selection;
                breedOptions = animalBreeds[selection]!;
              });
            },
            fieldViewBuilder: (BuildContext context,
                TextEditingController textEditingController,
                FocusNode focusNode,
                VoidCallback onFieldSubmitted) {
              return TextFormField(
                controller: textEditingController,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  labelText: 'Especie',
                  counterText:
                      '', // Oculta el contador de caracteres si no lo necesitas
                ),
                maxLength: 30, // Limita el campo a 30 caracteres
                onSaved: (value) => petType = value,
                validator: (value) {
                  if (value!.isEmpty) return 'Ingresa la especie de tu mascota';
                  return null;
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<String>.empty();
              }
              return breedOptions.where((String option) {
                return option
                    .toLowerCase()
                    .contains(textEditingValue.text.toLowerCase());
              });
            },
            onSelected: (String selection) {
              setState(() {
                petBreed = selection;
              });
            },
            fieldViewBuilder: (BuildContext context,
                TextEditingController textEditingController,
                FocusNode focusNode,
                VoidCallback onFieldSubmitted) {
              return TextFormField(
                controller: textEditingController,
                focusNode: focusNode,
                decoration: const InputDecoration(labelText: 'Raza'),
                onSaved: (value) => petBreed = value,
                validator: (value) {
                  if (value!.isEmpty) return 'Ingresa la raza de tu mascota';
                  return null;
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPage3() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: DropdownButtonFormField<String>(
            value: petStatus,
            decoration:
                const InputDecoration(labelText: 'Estado de la mascota'),
            items: [
              DropdownMenuItem(value: 'nada', child: const Text('Ninguno')),
              DropdownMenuItem(
                  value: 'adopcion', child: const Text('En Adopción')),
              DropdownMenuItem(value: 'perdido', child: const Text('Perdido')),
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
        ),
        if (petStatus == 'perdido' || petStatus == 'adopcion')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
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
                const SizedBox(height: 10),
                Center(
                  // Aquí se centra el botón
                  child: ElevatedButton(
                    onPressed: _selectLocationOnMap,
                    child: const Text('Seleccionar en el Mapa'),
                  ),
                ),
              ],
            ),
          ),
        if (petStatus == 'adopcion')
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: CheckboxListTile(
                  title: const Text("¿Está esterilizado?"),
                  value: _isSterilized,
                  onChanged: (bool? newValue) {
                    setState(() {
                      _isSterilized = newValue!;
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: CheckboxListTile(
                  title: const Text("¿Está vacunado?"),
                  value: _isVaccinated,
                  onChanged: (bool? newValue) {
                    setState(() {
                      _isVaccinated = newValue!;
                    });
                  },
                ),
              ),
            ],
          ),
        const SizedBox(height: 16.0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Checkbox(
                value: _knowsExactDate,
                onChanged: (bool? value) {
                  setState(() {
                    _knowsExactDate = value!;
                  });
                },
              ),
              const Text('Conozco la fecha exacta'),
            ],
          ),
        ),
        if (_knowsExactDate)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextFormField(
              decoration:
                  const InputDecoration(labelText: 'Fecha de nacimiento'),
              readOnly: true,
              onTap: () async {
                FocusScope.of(context).requestFocus(FocusNode());
                DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
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
                if (birthDate == null) return 'Ingresa su fecha de nacimiento';
                return null;
              },
              controller: TextEditingController(
                text: birthDate != null
                    ? "${birthDate!.toLocal()}".split(' ')[0]
                    : '',
              ),
            ),
          ),
        if (!_knowsExactDate)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
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
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Mascota'),
      ),
      body: Form(
        key: _formKey,
        child: Stack(
          children: [
            _buildPageContent(),
            Positioned(
              top: 16.0,
              left: 16.0,
              right: 16.0,
              child: AnimatedOpacity(
                opacity: _opacity,
                duration: Duration(milliseconds: 300),
                child: Text(
                  _getMessageForPage(_currentPage),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Positioned(
              bottom: 16.0,
              left: 16.0,
              right: 16.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    ElevatedButton(
                      onPressed: _previousPage,
                      child: const Text('Atrás'),
                    ),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _nextPage,
                    child: _currentPage < 2
                        ? const Text('Siguiente')
                        : const Text('Registrar Mascota'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
