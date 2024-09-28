import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart'; // Para formatear fechas
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';

class UserAdminEditScreen extends StatefulWidget {
  final String userId; // ID del usuario que será editado

  const UserAdminEditScreen({super.key, required this.userId});

  @override
  _UserAdminEditScreenState createState() => _UserAdminEditScreenState();
}

class _UserAdminEditScreenState extends State<UserAdminEditScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? profileImageUrl, username, profileName, bio, email, uid;
  String? selectedRole = 'user'; // Rol predeterminado
  bool isVerified = false; // Valor inicial como false
  bool isLoading = false;
  DateTime? birthDate, accountCreation, lastSignIn;

  final TextEditingController _profileNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      isLoading = true;
    });

    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(widget.userId).get();

      if (userDoc.exists) {
        Map<String, dynamic>? userData =
            userDoc.data() as Map<String, dynamic>?;

        setState(() {
          // Datos del usuario de Firestore
          profileImageUrl = userData?['profileImageUrl'] ?? '';
          username = userData?['username'] ?? '';
          profileName = userData?['profileName'] ?? '';
          bio = userData?['bio'] ?? '';
          email = userData?['email'];
          uid = widget.userId;
          birthDate = (userData?['birthDate'] != null)
              ? (userData?['birthDate'] as Timestamp).toDate()
              : null;

          // Rol y verificación
          if (userData?.containsKey('rol') ?? false) {
            selectedRole = userData?['rol'];
          } else {
            selectedRole = 'user';
            _firestore
                .collection('users')
                .doc(widget.userId)
                .update({'rol': 'user'});
          }

          if (userData?.containsKey('verified') ?? false) {
            isVerified = userData?['verified'];
          } else {
            isVerified = false;
            _firestore
                .collection('users')
                .doc(widget.userId)
                .update({'verified': false});
          }

          _profileNameController.text = profileName ?? '';
          _bioController.text = bio ?? '';
        });
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AwesomeSnackbarContent(
            title: 'Error al cargar datos de usuario',
            message: '$e',
            contentType: ContentType.failure,
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      );
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      isLoading = true;
    });

    try {
      await _firestore.collection('users').doc(widget.userId).update({
        'profileName': _profileNameController.text,
        'bio': _bioController.text,
        'rol': selectedRole ?? 'user',
        'verified': isVerified,
      });

      setState(() {
        isLoading = false;
      });

      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AwesomeSnackbarContent(
            title: 'Error al guardar cambios',
            message: '$e',
            contentType: ContentType.failure,
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil como Admin'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Encabezado con la imagen de perfil y la información del usuario
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: profileImageUrl != null &&
                                profileImageUrl!.isNotEmpty
                            ? CachedNetworkImageProvider(profileImageUrl!)
                            : const AssetImage('assets/default_profile.png')
                                as ImageProvider,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Mostrar información básica
                            Row(
                              children: [
                                Icon(Icons.email),
                                Text(
                                  '$email',
                                ),
                              ],
                            ),
                            if (birthDate != null)
                              Row(
                                children: [
                                  Icon(Icons.cake),
                                  Text(
                                      '${DateFormat('dd/MM/yyyy').format(birthDate!)}'),
                                ],
                              ),
                            Row(
                              children: [
                                Icon(Icons.verified_user),
                                Text('$uid'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Mostrar información de autenticación
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Formulario de edición de perfil
                  TextFormField(
                    controller: _profileNameController,
                    decoration:
                        const InputDecoration(labelText: 'Nombre de perfil'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bioController,
                    decoration: const InputDecoration(labelText: 'Biografía'),
                  ),
                  const SizedBox(height: 16),
                  // Dropdown para seleccionar el rol
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    onChanged: (value) {
                      setState(() {
                        selectedRole = value;
                      });
                    },
                    items: ['user', 'refugio', 'admin']
                        .map((role) => DropdownMenuItem(
                              value: role,
                              child: Text(role),
                            ))
                        .toList(),
                    decoration: const InputDecoration(
                      labelText: 'Rol de Usuario',
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Checkbox para verificar al usuario
                  CheckboxListTile(
                    title: const Text('Verificado'),
                    value: isVerified,
                    onChanged: (value) {
                      setState(() {
                        isVerified = value ?? false;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text('Guardar Cambios'),
                  ),
                ],
              ),
            ),
    );
  }
}
