import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../pets/pet_profile.dart';
import '../user/user_profile.dart';
import '../utils/mascotapp_colors.dart';

class CombinedSearchScreen extends StatefulWidget {
  @override
  _CombinedSearchScreenState createState() => _CombinedSearchScreenState();
}

class _CombinedSearchScreenState extends State<CombinedSearchScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _allPets = [];
  List<DocumentSnapshot> _allUsers = [];
  List<dynamic> _filteredResults = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    // Cargar mascotas
    QuerySnapshot petSnapshot = await _firestore.collection('pets').get();
    // Cargar usuarios
    QuerySnapshot userSnapshot = await _firestore.collection('users').get();

    setState(() {
      _allPets = petSnapshot.docs;
      _allUsers = userSnapshot.docs;
      _filteredResults = [..._allPets, ..._allUsers];
    });
  }

  void _filterResults(String query) {
    List<dynamic> tempFilteredResults = [];

    if (query.isNotEmpty) {
      // Filtrar mascotas
      List<DocumentSnapshot> filteredPets = _allPets.where((petDoc) {
        String petName = petDoc['petName'].toString().toLowerCase();
        String petType = petDoc['petType'].toString().toLowerCase();
        return petName.contains(query.toLowerCase()) ||
            petType.contains(query.toLowerCase());
      }).toList();

      // Filtrar usuarios
      List<DocumentSnapshot> filteredUsers = _allUsers.where((userDoc) {
        String username = userDoc['username'].toString().toLowerCase();
        String profileName = userDoc['profileName'].toString().toLowerCase();
        return username.contains(query.toLowerCase()) ||
            profileName.contains(query.toLowerCase());
      }).toList();

      tempFilteredResults = [...filteredPets, ...filteredUsers];
    } else {
      tempFilteredResults = [..._allPets, ..._allUsers];
    }

    setState(() {
      _filteredResults = tempFilteredResults;
    });
  }

  Widget _buildRoleIcon(String? userRole) {
    if (userRole == null) return const SizedBox.shrink();
    switch (userRole) {
      case 'admin':
        return const Icon(Icons.verified_user,
            color: MascotAppColors.admin, size: 20);
      case 'refugio':
        return const Icon(Icons.pets, color: MascotAppColors.refugio, size: 20);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildEstadoTag(String estado) {
    Color bgColor;
    String text;
    IconData icon;

    switch (estado) {
      case 'adopcion':
        bgColor = MascotAppColors.adopcion;
        text = 'En adopción';
        icon = Icons.volunteer_activism;
        break;
      case 'enmemoria':
        bgColor = Colors.blueAccent;
        text = 'En memoria';
        icon = Icons.book;
        break;
      case 'perdido':
        bgColor = MascotAppColors.perdido;
        text = 'Me perdí :(';
        icon = Icons.location_off;
        break;
      default:
        return const SizedBox.shrink();
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

  Widget _buildListItem(dynamic item) {
    // Verificar si es un usuario o una mascota
    if (item.data().containsKey('petName')) {
      // Es una mascota
      Map<String, dynamic> petData = item.data() as Map<String, dynamic>;
      String petId = item.id;
      String? petName =
          petData.containsKey('petName') ? petData['petName'] : 'Sin nombre';
      String? petType =
          petData.containsKey('petType') && petData.containsKey('petBreed')
              ? '${petData['petType']} ${petData['petBreed']}'
              : 'Tipo desconocido';
      String? petEstado = petData['estado'];

      return ListTile(
        leading: CircleAvatar(
          backgroundImage: petData.containsKey('petImageUrl') &&
                  petData['petImageUrl'] != null
              ? CachedNetworkImageProvider(petData['petImageUrl'])
              : const AssetImage('assets/default_pet.png') as ImageProvider,
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PetProfileScreen(petId: petId),
            ),
          );
        },
      );
    } else {
      // Es un usuario
      Map<String, dynamic> userData = item.data() as Map<String, dynamic>;
      String userId = item.id;
      String? profileName = userData.containsKey('profileName')
          ? userData['profileName']
          : 'Sin nombre';
      String? username = userData.containsKey('username')
          ? userData['username']
          : 'Sin username';
      String? userRole = userData.containsKey('rol') ? userData['rol'] : null;

      return ListTile(
        leading: CircleAvatar(
          backgroundImage: userData.containsKey('profileImageUrl') &&
                  userData['profileImageUrl'] != null
              ? CachedNetworkImageProvider(userData['profileImageUrl'])
              : const AssetImage('assets/default_profile.png') as ImageProvider,
        ),
        title: Row(
          children: [
            Text(profileName ?? 'Sin nombre'),
            const SizedBox(width: 8),
            _buildRoleIcon(userRole),
          ],
        ),
        subtitle: Text('@${username ?? ''}'),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfileScreen(userId: userId),
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar mascota o usuario',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onChanged: _filterResults,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _filteredResults.isNotEmpty
                  ? ListView.builder(
                      itemCount: _filteredResults.length,
                      itemBuilder: (context, index) {
                        return _buildListItem(_filteredResults[index]);
                      },
                    )
                  : const Center(
                      child: Text('No se encontraron resultados'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
