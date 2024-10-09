import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class UserEditScreen extends StatefulWidget {
  const UserEditScreen({super.key});

  @override
  _UserEditScreenState createState() => _UserEditScreenState();
}

class _UserEditScreenState extends State<UserEditScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final picker = ImagePicker();

  String? profileImageUrl, username, profileName, bio;
  File? _profileImage;
  bool isLoading = false;

  final TextEditingController _profileNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    String userId = _auth.currentUser!.uid;
    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(userId).get();
    setState(() {
      profileImageUrl = userDoc['profileImageUrl'];
      username = userDoc['username'];
      profileName = userDoc['profileName'];
      bio = userDoc['bio'];

      _usernameController.text = username ?? '';
      _profileNameController.text = profileName ?? '';
      _bioController.text = bio ?? '';
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recortar Imagen',
            toolbarColor: Colors.deepOrange,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            minimumAspectRatio: 1.0,
          ),
        ],
      );
      if (croppedFile != null) {
        // Leer los bytes del archivo recortado
        final croppedFileBytes = await croppedFile.readAsBytes();

        // Comprimir la imagen al formato WebP utilizando flutter_image_compress
        Uint8List? compressedBytes =
            await FlutterImageCompress.compressWithList(
          croppedFileBytes,
          format: CompressFormat.webp,
          quality: 80, // Ajusta la calidad según tus necesidades
        );

        if (compressedBytes != null) {
          // Crear un archivo temporal para almacenar la imagen comprimida en WebP
          final tempDir = Directory.systemTemp;
          final webpFile = File(
              '${tempDir.path}/image_${DateTime.now().millisecondsSinceEpoch}.webp');
          await webpFile.writeAsBytes(compressedBytes);

          // Actualizar el estado con la imagen comprimida
          setState(() {
            _profileImage = webpFile;
          });
        }
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      isLoading = true;
    });

    String userId = _auth.currentUser!.uid;
    String? imageUrl = profileImageUrl;
    String newUsername = _usernameController.text.trim();

    // Verificar si el nombre de usuario ya está en uso
    final QuerySnapshot result = await _firestore
        .collection('users')
        .where('username', isEqualTo: newUsername)
        .get();

    final List<DocumentSnapshot> documents = result.docs;

    // Si el nombre de usuario está en uso por otro usuario
    if (documents.isNotEmpty && documents.first.id != userId) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre de usuario ya está en uso')),
      );
      return;
    }

    if (_profileImage != null) {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$userId.webp');
      final uploadTask = await storageRef.putFile(_profileImage!);

      if (uploadTask.state == TaskState.success) {
        imageUrl = await storageRef.getDownloadURL();
      } else {
        throw Exception('Ha ocurrido un error al intentar subir la foto');
      }
    }

    await _firestore.collection('users').doc(userId).update({
      'profileImageUrl': imageUrl,
      'username': newUsername,
      'profileName': _profileNameController.text,
      'bio': _bioController.text,
    });

    setState(() {
      isLoading = false;
    });

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => _buildImageSourceSheet(),
                      );
                    },
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: _profileImage != null
                          ? FileImage(_profileImage!)
                          : profileImageUrl != null
                              ? CachedNetworkImageProvider(profileImageUrl!)
                              : const AssetImage('assets/default_profile.png')
                                  as ImageProvider,
                      child: _profileImage == null && profileImageUrl == null
                          ? const Icon(Icons.camera_alt, size: 50)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Nombre de usuario',
                      //prefixIcon: const Icon(Icons.account_circle),
                      prefix: const Padding(
                        padding: EdgeInsets.only(
                            right: 1.0), // Añadimos un pequeño espacio
                        child: Text('@'),
                      ),
                    ),
                    validator: (value) {
                      if (value!.isEmpty) return 'Ingresa tu nombre de usuario';
                      if (value.length < 2 || value.length > 20)
                        return 'El nombre de usuario debe tener entre 2 y 20 caracteres';
                      if (value.contains(' '))
                        return 'El nombre de usuario no puede contener espacios';
                      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value))
                        return 'El nombre de usuario solo puede contener letras, números y guion bajo';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
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

  Widget _buildImageSourceSheet() {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Seleccionar de la galería'),
            onTap: () {
              Navigator.of(context).pop();
              _pickImage(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Tomar una foto'),
            onTap: () {
              Navigator.of(context).pop();
              _pickImage(ImageSource.camera);
            },
          ),
        ],
      ),
    );
  }
}
