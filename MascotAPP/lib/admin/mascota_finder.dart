import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../pets/pet_profile.dart'; // Importar el perfil de mascotas
import '../utils/mascotapp_colors.dart';

class PetSearchScreen extends StatefulWidget {
  @override
  _PetSearchScreenState createState() => _PetSearchScreenState();
}

class _PetSearchScreenState extends State<PetSearchScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _allPets = [];
  List<DocumentSnapshot> _filteredPets = [];

  @override
  void initState() {
    super.initState();
    _loadAllPets();
  }

  Future<void> _loadAllPets() async {
    QuerySnapshot querySnapshot = await _firestore.collection('pets').get();
    setState(() {
      _allPets = querySnapshot.docs;
      _filteredPets = _allPets;
    });
  }

  void _filterPets(String query) {
    List<DocumentSnapshot> tempFilteredPets = [];
    if (query.isNotEmpty) {
      tempFilteredPets = _allPets.where((petDoc) {
        String petName = petDoc['petName'].toString().toLowerCase();
        String petType = petDoc['petType'].toString().toLowerCase();
        return petName.contains(query.toLowerCase()) ||
            petType.contains(query.toLowerCase());
      }).toList();
    } else {
      tempFilteredPets = _allPets;
    }
    setState(() {
      _filteredPets = tempFilteredPets;
    });
  }

  Widget _buildEstadoTag(String estado) {
    Color bgColor;
    String text;
    IconData icon;

    // Asignar el color y el ícono basados en el estado de la mascota
    switch (estado) {
      case 'adopcion':
        bgColor = MascotAppColors.refugio;
        text = 'En adopción';
        icon = Icons.volunteer_activism;
        break;
      case 'enmemoria':
        bgColor = Colors.blueAccent;
        text = 'En memoria';
        icon = Icons.book;
        break;
      case 'perdido':
        bgColor = Colors.red;
        text = 'Me perdí :(';
        icon = Icons.location_off;
        break;
      default:
        return const SizedBox
            .shrink(); // No mostrar nada si el estado es vacío o no reconocido
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar Mascotas'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Campo de búsqueda
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar mascota',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onChanged: _filterPets,
            ),
            const SizedBox(height: 16),
            // Lista de mascotas
            Expanded(
              child: _filteredPets.isNotEmpty
                  ? ListView.builder(
                      itemCount: _filteredPets.length,
                      itemBuilder: (context, index) {
                        var petDoc = _filteredPets[index];
                        String petId = petDoc.id;

                        // Casteo a Map<String, dynamic>
                        Map<String, dynamic>? petData =
                            petDoc.data() as Map<String, dynamic>?;

                        String? petName = petData?['petName'];
                        String? petType =
                            petData?['petType'] + ' ' + petData?['petBreed'];
                        String? petEstado = petData?['estado'];

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: petData != null &&
                                    petData['petImageUrl'] != null
                                ? CachedNetworkImageProvider(
                                    petData['petImageUrl'])
                                : const AssetImage('assets/default_pet.png')
                                    as ImageProvider,
                          ),
                          title: Text(petName ?? ''),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(petType ?? ''),
                              if (petEstado != null) _buildEstadoTag(petEstado),
                            ],
                          ),
                          onTap: () {
                            // Navegar al perfil de la mascota al hacer clic
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    PetProfileScreen(petId: petId),
                              ),
                            );
                          },
                        );
                      },
                    )
                  : const Center(child: Text('No se encontraron mascotas')),
            ),
          ],
        ),
      ),
    );
  }
}
