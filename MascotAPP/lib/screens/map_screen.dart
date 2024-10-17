import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../pets/pet_profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../user/user_profile.dart';
import '../utils/mascotapp_colors.dart';

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
  List<Map<String, dynamic>> shelters = []; // Lista para almacenar refugios
  LatLng? userLocation; // Para almacenar la ubicación del usuario
  String? userProfilePicUrl =
      'assets/default_profile.png'; // Ruta de la foto de perfil (ajustar según tu lógica)
  String? userRole; // Para almacenar el rol del usuario
  bool showUserTooltip = false; // Estado para controlar el tooltip
  Timer? locationUpdateTimer; // Para manejar el temporizador

  // Variables para los filtros
  bool showAdoption = true;
  bool showLost = true;
  bool showShelters = true; // Filtro para mostrar refugios

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
    loadShelters(); // Cargar refugios
    _getUserLocation(); // Obtener la ubicación del usuario
    loadPets();
    _loadUserProfile();
    _startLocationUpdates(); // Iniciar actualización periódica de la ubicación
  }

  @override
  void dispose() {
    locationUpdateTimer
        ?.cancel(); // Cancelar el temporizador cuando se destruya la pantalla
    super.dispose();
  }

  // Función que filtra las mascotas según el filtro activo
  List<Map<String, dynamic>> getFilteredPets() {
    return pets.where((pet) {
      if (pet['estado'] == 'adopcion' && showAdoption) {
        return true;
      } else if (pet['estado'] == 'perdido' && showLost) {
        return true;
      }
      return false;
    }).toList();
  }

  // Función para cargar los refugios desde Firestore
  Future<void> loadShelters() async {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('rol', isEqualTo: 'refugio')
        .get();

    // Procesar los documentos obtenidos
    shelters = querySnapshot.docs.map((doc) {
      final shelterData = doc.data() as Map<String, dynamic>;
      shelterData['shelterId'] = doc.id;
      return shelterData;
    }).toList();

    print("Shelters: $shelters");
    setState(() {});
  }

  // Método para iniciar la actualización periódica de la ubicación
  void _startLocationUpdates() {
    locationUpdateTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      _updateUserLocation(); // Obtener la ubicación cada 60 segundos
    });
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
        .where('estado', whereIn: ['adopcion', 'perdido']).get();

    return querySnapshot.docs.map((doc) {
      final petData = doc.data() as Map<String, dynamic>;
      petData['petId'] = doc.id;
      return petData;
    }).toList();
  }

  Future<void> loadPets() async {
    pets = await getPetsList();
    print(pets);
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
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted) {
        setState(() {
          showUserTooltip = false;
        });
      }
    });
  }

  Future<void> _updateUserLocation() async {
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
      // Establecemos la nueva ubicación del usuario
      userLocation = LatLng(position.latitude, position.longitude);
      print("User location: $userLocation");

      // Mostrar el tooltip del usuario sin centrar el mapa
      showUserTooltip = true;
    });
  }

  // Método para calcular la distancia entre la ubicación del usuario y una mascota

  double calculateDistance(LatLng userLocation, double petLat, double petLong) {
    return Geolocator.distanceBetween(
      userLocation.latitude,
      userLocation.longitude,
      petLat,
      petLong,
    );
  }

  Map<String, dynamic> getPetStatusProperties(String? estado) {
    Color borderColor = Colors.grey;
    IconData icon = Icons.help;
    String message = '';

    if (estado != null) {
      switch (estado) {
        case 'perdido':
          borderColor = MascotAppColors.perdido;
          icon = Icons.location_off;
          message = 'Me perdí! :(';
          break;
        case 'adopcion':
          borderColor = MascotAppColors.adopcion;
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

  Widget shelterMarker(Map<String, dynamic> shelter, IconData shelterIcon) {
    return Stack(
      alignment:
          Alignment.bottomRight, // Ícono pequeño en la esquina inferior derecha
      children: [
        CircleAvatar(
          radius: 35, // Tamaño del avatar
          backgroundImage: shelter['profileImageUrl'] != null
              ? CachedNetworkImageProvider(shelter['profileImageUrl'])
              : const AssetImage('assets/default_shelter.png') as ImageProvider,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                  color: MascotAppColors.refugio, width: 4), // Borde verde
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
              shelterIcon,
              color: MascotAppColors.refugio,
              size: 16, // Tamaño del ícono pequeño
            ),
          ),
        ),
      ],
    );
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

  @override
  Widget build(BuildContext context) {
    final filteredPets = getFilteredPets();

    // Mezclar mascotas y refugios en la lista
    final combinedList = [...filteredPets];
    if (showShelters) {
      combinedList.addAll(shelters);
    }

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
              if (filteredPets.isNotEmpty)
                MarkerLayer(
                  markers: filteredPets
                      .where((pet) => pet['lat'] != null && pet['long'] != null)
                      .map((pet) {
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
              if (showShelters && shelters.isNotEmpty)
                MarkerLayer(
                  markers: shelters
                      .where((shelter) =>
                          shelter['lat'] != null && shelter['long'] != null)
                      .map((shelter) {
                    final LatLng position =
                        LatLng(shelter['lat'], shelter['long']);
                    final String shelterId = shelter['shelterId'];
                    final String? shelterImageUrl = shelter['profileImageUrl'];

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
                                  UserProfileScreen(userId: shelterId),
                            ),
                          );
                        },
                        child: shelterMarker(
                          shelter,
                          Icons
                              .pets, // Icono de refugio (o puedes elegir otro icono)
                        ),
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
                      child: userMarker(),
                    ),
                  ],
                ),
            ],
          ),

          // Botones de filtro en la parte superior derecha
          Positioned(
            top: 20,
            right: 20,
            child: Column(
              children: [
                FilterButton(
                  isActive: showAdoption,
                  icon: Icons.volunteer_activism,
                  label: "Adopción",
                  color: MascotAppColors.adopcion,
                  onPressed: () {
                    setState(() {
                      showAdoption = !showAdoption; // Toggle Adopción
                    });
                  },
                ),
                const SizedBox(height: 10),
                FilterButton(
                  isActive: showLost,
                  icon: Icons.location_off,
                  label: "Perdido",
                  color: MascotAppColors.perdido,
                  onPressed: () {
                    setState(() {
                      showLost = !showLost; // Toggle Perdido
                    });
                  },
                ),
                const SizedBox(height: 10),
                FilterButton(
                  isActive: showShelters,
                  icon: Icons.pets,
                  label: "Refugios",
                  color: MascotAppColors.refugio,
                  onPressed: () {
                    setState(() {
                      showShelters = !showShelters; // Toggle Refugios
                    });
                  },
                ),
              ],
            ),
          ),

          // Lista de mascotas en adopción deslizable
          DraggableScrollableSheet(
            initialChildSize: 0.2,
            minChildSize: 0.2,
            maxChildSize: 0.4,
            builder: (BuildContext context, ScrollController scrollController) {
              if (combinedList.isEmpty) {
                return const Center(
                  child: Text(':)'),
                );
              }

              // Calcular distancia para mascotas y refugios si se tiene la ubicación del usuario
              if (userLocation != null) {
                combinedList.forEach((item) {
                  if (item['lat'] != null && item['long'] != null) {
                    // Asegúrate de que 'lat' y 'long' no sean null
                    double? lat = item['lat'] as double?;
                    double? long = item['long'] as double?;

                    if (lat != null && long != null) {
                      double distance = calculateDistance(
                        userLocation!,
                        lat,
                        long,
                      );
                      item['distance'] = distance;
                    } else {
                      item['distance'] =
                          null; // O establece un valor por defecto
                    }
                  }
                });

                // Ordenar la lista por distancia, solo si 'distance' no es null
                combinedList.sort((a, b) {
                  double? distanceA = a['distance'] as double?;
                  double? distanceB = b['distance'] as double?;

                  if (distanceA == null)
                    return 1; // Si 'distance' es null, mueve al final
                  if (distanceB == null) return -1;

                  return distanceA.compareTo(distanceB);
                });
              }

              return ListView.builder(
                controller: scrollController,
                itemCount: combinedList.length,
                itemBuilder: (context, index) {
                  var item = combinedList[index];

                  // Verificar si es una mascota o refugio
                  bool isPet = item
                      .containsKey('estado'); // Las mascotas tienen 'estado'

                  if (isPet) {
                    // Tarjeta de mascota
                    var pet = item;
                    var petAge = calculateAge(pet['birthDate']);
                    var ownerId = pet['owner'];
                    var location = pet['location'];
                    var distance = pet['distance'] != null
                        ? (pet['distance'] / 1000).toStringAsFixed(2)
                        : 'N/A';

                    final petStatus = getPetStatusProperties(pet['estado']);
                    final statusColor = petStatus['borderColor'];
                    final statusMessage = petStatus['message'];
                    final statusIcon = petStatus['icon'];

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

                        var owner =
                            ownerSnapshot.data!.data() as Map<String, dynamic>;
                        var ownerName = owner['username'];
                        var ownerRole = owner['rol'];

                        return Card(
                          margin: const EdgeInsets.all(8.0),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: pet['petImageUrl'] != null
                                  ? CachedNetworkImageProvider(
                                      pet['petImageUrl'])
                                  : const AssetImage('assets/default_pet.png')
                                      as ImageProvider,
                            ),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    pet['petName'],
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 4, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        statusIcon,
                                        color: statusColor,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        statusMessage,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('${pet['petType']} - $petAge'),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text('Por: @$ownerName'),
                                    const SizedBox(width: 4),
                                    if (ownerRole == 'refugio')
                                      const Icon(Icons.pets,
                                          color: MascotAppColors.refugio,
                                          size: 16),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.location_pin,
                                        color: Colors.red, size: 16),
                                    Text(location),
                                    Text(' ($distance km)'),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      PetProfileScreen(petId: pet['petId']),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  } else {
                    // Tarjeta de refugio
                    var shelter = item;
                    var shelterName = shelter['profileName'];
                    var location = shelter['location'];
                    var distance = shelter['distance'] != null
                        ? (shelter['distance'] / 1000).toStringAsFixed(2)
                        : 'N/A';

                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: shelter['profileImageUrl'] != null
                              ? CachedNetworkImageProvider(
                                  shelter['profileImageUrl'])
                              : const AssetImage('assets/default_shelter.png')
                                  as ImageProvider,
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                shelterName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 8),
                              decoration: BoxDecoration(
                                color: MascotAppColors.refugio.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.pets,
                                    color: MascotAppColors.refugio,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Refugio',
                                    style: TextStyle(
                                      color: MascotAppColors.refugio,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.location_pin,
                                    color: Colors.red, size: 16),
                                Text(location),
                                Text(' ($distance km)'),
                              ],
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserProfileScreen(
                                  userId: shelter['shelterId']),
                            ),
                          );
                        },
                      ),
                    );
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// Botón de filtro personalizado
class FilterButton extends StatelessWidget {
  final bool isActive;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const FilterButton({
    Key? key,
    required this.isActive,
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.2) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? color : Colors.grey,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isActive ? color : Colors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? color : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
