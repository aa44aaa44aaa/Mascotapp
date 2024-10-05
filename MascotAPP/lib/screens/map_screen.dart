import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../pets/pet_profile.dart';
import 'package:firebase_auth/firebase_auth.dart';

const MAPBOX_ACCESS_TOKEN =
    'pk.eyJ1IjoiYWE0NGFhYTQ0YWFhIiwiYSI6ImNtMXNsa2NvNDA0dzQyb3E0am4zdTc5ZmcifQ.DkLqjouazVETO5EfYKTmhw';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController controller = MapController();
  List<Map<String, dynamic>> pets = [];
  LatLng? userLocation; // Para almacenar la ubicación del usuario
  String? userProfilePicUrl =
      'assets/default_profile.png'; // Ruta de la foto de perfil (ajustar según tu lógica)
  String? userRole; // Para almacenar el rol del usuario
  bool showUserTooltip = false; // Estado para controlar el tooltip

  String calculateAge(Timestamp birthDate) {
    DateTime birth = birthDate.toDate();
    DateTime now = DateTime.now();
    int years = now.year - birth.year;
    int months = now.month - birth.month;

    // Ajuste si el día actual es menor que el día de nacimiento
    if (now.day < birth.day) {
      months--;
    }

    // Ajuste si los meses son negativos
    if (months < 0) {
      years--;
      months += 12;
    }

    // Retorna el resultado como un string
    return years > 0 ? '$years años, $months meses' : '$months meses';
  }

  @override
  void initState() {
    super.initState();
    loadPets();
    _getUserLocation(); // Obtener la ubicación del usuario
    _loadUserProfile();
  }

  // Método para cargar la foto de perfil y el rol del usuario
  Future<void> _loadUserProfile() async {
    User? user =
        FirebaseAuth.instance.currentUser; // Obtenemos el usuario autenticado
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (mounted) {
        setState(() {
          userProfilePicUrl = userDoc['profileImageUrl'] ??
              'assets/default_profile.png'; // Asignamos la imagen o una por defecto
          userRole = userDoc['rol']; // Obtenemos el rol del usuario
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> getPetsList() async {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('pets')
        .where('estado', whereIn: ['adopcion']).get();

    return querySnapshot.docs.map((doc) {
      final petData = doc.data() as Map<String, dynamic>;
      petData['petId'] = doc.id;
      return petData;
    }).toList();
  }

  Future<void> loadPets() async {
    pets = await getPetsList();
    setState(() {});
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Comprobar si los servicios de ubicación están habilitados
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Si los servicios no están habilitados, no seguimos
      print("servicios no están habilitados, no seguimos");
      return;
    }

    // Comprobar permisos
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Si el usuario deniega los permisos, no continuamos
        print("El usuario deniega los permisos, no continuamos");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Los permisos están denegados para siempre
      print("Los permisos están denegados para siempre");
      return;
    }

    // Obtener la ubicación actual del usuario
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    setState(() {
      // Establecemos la ubicación del usuario en el mapa
      userLocation = LatLng(position.latitude, position.longitude);
      print("User location: $userLocation");
      controller.move(
          userLocation!, 13.0); // Centrar el mapa en la ubicación del usuario
      showUserTooltip = true; // Mostrar el tooltip
    });

    // Ocultar el tooltip después de 3 segundos
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          showUserTooltip = false;
        });
      }
    });
  }

  Map<String, dynamic> getPetStatusProperties(String? estado) {
    Color borderColor = Colors.grey;
    IconData icon = Icons.help;
    String message = '';

    if (estado != null) {
      switch (estado) {
        case 'perdido':
          borderColor = Colors.red;
          icon = Icons.location_off;
          message = 'Me perdí! :(';
          break;
        case 'adopcion':
          borderColor = Colors.brown;
          icon = Icons.volunteer_activism;
          message = 'Estoy en adopción!';
          break;
      }
    }

    return {
      'borderColor': borderColor,
      'icon': icon,
      'message': message,
    };
  }

  Widget petMarker(
      Map<String, dynamic> pet, Color borderColor, IconData statusIcon) {
    return Stack(
      alignment:
          Alignment.bottomRight, // Ícono pequeño en la esquina inferior derecha
      children: [
        CircleAvatar(
          radius: 35, // Tamaño del avatar
          backgroundImage: pet['petImageUrl'] != null
              ? CachedNetworkImageProvider(pet['petImageUrl'])
              : const AssetImage('assets/default_pet.png') as ImageProvider,
          child: Container(
            decoration: BoxDecoration(
              border:
                  Border.all(color: borderColor, width: 4), // Borde de color
              borderRadius: BorderRadius.circular(50),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white, // Fondo blanco para el ícono
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(4), // Espaciado dentro del ícono
            child: Icon(
              statusIcon,
              color: borderColor,
              size: 16, // Tamaño del ícono pequeño
            ),
          ),
        ),
      ],
    );
  }

  Widget userMarker() {
    return Tooltip(
      message: showUserTooltip ? '¡Estás aquí!' : '', // Mensaje del tooltip
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Mapa de Flutter
          FlutterMap(
            mapController: controller,
            options: MapOptions(
              initialCenter: userLocation ??
                  LatLng(-33.375,
                      -70.640), // Posición inicial o ubicación del usuario
              initialZoom: 13,
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
              if (pets.isNotEmpty)
                MarkerLayer(
                  markers: pets.map((pet) {
                    final petStatus = getPetStatusProperties(pet['estado']);
                    final borderColor = petStatus['borderColor'];
                    final LatLng position = LatLng(pet['lat'], pet['long']);
                    final statusIcon = petStatus['icon'];
                    final String petId = pet['petId'];

                    return Marker(
                      point: position,
                      width: 60,
                      height: 60,
                      alignment: Alignment.topCenter,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PetProfileScreen(petId: petId),
                            ),
                          );
                        },
                        child: petMarker(pet, borderColor, statusIcon),
                      ),
                    );
                  }).toList(),
                ),
              if (userLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                        point: userLocation!,
                        width: 50,
                        height: 50,
                        child: userMarker()),
                  ],
                ),
            ],
          ),
          // Lista de mascotas en adopción deslizable
          DraggableScrollableSheet(
            initialChildSize: 0.2, // Tamaño inicial
            minChildSize: 0.2, // Tamaño mínimo al arrastrar
            maxChildSize: 0.6, // Tamaño máximo al arrastrar
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10.0,
                    ),
                  ],
                ),
                child: FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('pets')
                      .where('estado', isEqualTo: 'adopcion')
                      .get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    var petsList = snapshot.data!.docs;

                    if (petsList.isEmpty) {
                      return const Center(
                          child: Text('No hay mascotas en adopción.'));
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: petsList.length,
                      itemBuilder: (context, index) {
                        var pet =
                            petsList[index].data() as Map<String, dynamic>;
                        var petAge = calculateAge(pet['birthDate']);
                        var ownerId = pet['owner'];
                        var location = pet['location'];

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(ownerId)
                              .get(),
                          builder: (context, ownerSnapshot) {
                            if (!ownerSnapshot.hasData) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            var owner = ownerSnapshot.data!.data()
                                as Map<String, dynamic>;
                            var ownerName = owner['username'];

                            return Card(
                              margin: const EdgeInsets.all(8.0),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: pet['petImageUrl'] != null
                                      ? CachedNetworkImageProvider(
                                          pet['petImageUrl'])
                                      : const AssetImage(
                                              'assets/default_pet.png')
                                          as ImageProvider,
                                ),
                                title: Text(pet['petName']),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        '${pet['petType']} - $petAge\nPor: @$ownerName'),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_pin,
                                            color: Colors.red, size: 16),
                                        Text(location),
                                      ],
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PetProfileScreen(
                                          petId: petsList[index].id),
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
            },
          ),
        ],
      ),
    );
  }
}
