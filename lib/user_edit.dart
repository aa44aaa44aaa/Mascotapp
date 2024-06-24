import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';

class UserEditScreen extends StatefulWidget {
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

  TextEditingController _profileNameController = TextEditingController();
  TextEditingController _bioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    String userId = _auth.currentUser!.uid;
    DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
    setState(() {
      profileImageUrl = userDoc['profileImageUrl'];
      username = userDoc['username'];
      profileName = userDoc['profileName'];
      bio = userDoc['bio'];

      _profileNameController.text = profileName ?? '';
      _bioController.text = bio ?? '';
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
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
        // Optimize image
        final bytes = await croppedFile.readAsBytes();
        img.Image? image = img.decodeImage(bytes);
        if (image != null) {
          final resizedImage = img.copyResize(image, width: 512, height: 512);
          final compressedBytes = img.encodeJpg(resizedImage, quality: 70);
          setState(() {
            _profileImage = File(croppedFile.path)
              ..writeAsBytesSync(compressedBytes);
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

    if (_profileImage != null) {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child(userId + '.jpg');
      final uploadTask = await storageRef.putFile(_profileImage!);

      if (uploadTask.state == TaskState.success) {
        imageUrl = await storageRef.getDownloadURL();
      } else {
        throw Exception('Ha ocurrido un error al intentar subir la foto');
      }
    }

    await _firestore.collection('users').doc(userId).update({
      'profileImageUrl': imageUrl,
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
        title: Text('Editar Perfil'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
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
                              : AssetImage('assets/default_profile.png') as ImageProvider,
                      child: _profileImage == null && profileImageUrl == null
                          ? Icon(Icons.camera_alt, size: 50)
                          : null,
                    ),
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _profileNameController,
                    decoration: InputDecoration(labelText: 'Nombre de perfil'),
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _bioController,
                    decoration: InputDecoration(labelText: 'Biografía'),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _saveProfile,
                    child: Text('Guardar Cambios'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
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
            leading: Icon(Icons.photo_library),
            title: Text('Seleccionar de la galería'),
            onTap: () {
              Navigator.of(context).pop();
              _pickImage(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: Icon(Icons.camera_alt),
            title: Text('Tomar una foto'),
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
