import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'dart:typed_data';
//import 'package:image/image.dart' as img;
import '../screens/home_screen.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  _CreatePostScreenState createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  final picker = ImagePicker();

  String? petId, text;
  File? _postImage;
  bool _isLoading = false;

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        compressQuality: 80,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recortar Imagen',
            toolbarColor: const Color.fromRGBO(130, 34, 255, 1),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.ratio5x4,
            lockAspectRatio: true,
            aspectRatioPresets: [
              CropAspectRatioPreset.ratio5x4,
              CropAspectRatioPreset.ratio16x9,
              CropAspectRatioPreset.square,
            ],
          ),
          IOSUiSettings(
            minimumAspectRatio: 1.0,
          ),
        ],
      );
      if (croppedFile != null) {
        final croppedFileBytes = await croppedFile.readAsBytes();

        // Comprimir la imagen al formato WebP utilizando flutter_image_compress
        Uint8List? compressedBytes =
            await FlutterImageCompress.compressWithList(
          croppedFileBytes,
          format: CompressFormat.webp,
          quality: 80, // Puedes ajustar la calidad aquí
        );

        if (compressedBytes != null) {
          // Crear un archivo temporal para almacenar la imagen comprimida en WebP
          final tempDir = Directory.systemTemp;
          final webpFile = File(
              '${tempDir.path}/image_${DateTime.now().millisecondsSinceEpoch}.webp');
          await webpFile.writeAsBytes(compressedBytes);

          setState(() {
            _postImage = webpFile;
          });
        }
      }
    }
  }

  Future<void> _createPost() async {
    if (_formKey.currentState!.validate() && _postImage != null) {
      _formKey.currentState!.save();
      try {
        setState(() {
          _isLoading = true;
        });
        User? user = _auth.currentUser;
        if (user == null || petId == null) return;

        DocumentSnapshot petDoc =
            await _firestore.collection('pets').doc(petId).get();
        if (!petDoc.exists) return;

        String? imageUrl;
        if (_postImage != null) {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('post_images')
              .child('${user.uid}-${DateTime.now()}.webp');
          final uploadTask = await storageRef.putFile(_postImage!);

          if (uploadTask.state == TaskState.success) {
            imageUrl = await storageRef.getDownloadURL();
          } else {
            throw Exception('Failed to upload post image.');
          }
        }

        await _firestore.collection('posts').add({
          'postedby': user.uid,
          'petId': petId,
          'postImageUrl': imageUrl,
          'text': text,
          'timestamp': FieldValue.serverTimestamp(),
          'likes': [],
        });

        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AwesomeSnackbarContent(
              title: 'Perfecto!',
              message: 'El post ha sido publicado exitosamente.',
              contentType: ContentType.success,
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        print(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona una imagen.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: <Widget>[
              StreamBuilder<User?>(
                stream: _auth.authStateChanges(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  User? user = snapshot.data;
                  return StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('pets')
                        .where('owner', isEqualTo: user?.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const CircularProgressIndicator();
                      }
                      var pets = snapshot.data!.docs;
                      if (pets.isEmpty) {
                        return const Center(
                          child: Text(
                            'Aún no agregas una mascota!, debes añadir una para poder publicar una foto',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }
                      return Column(
                        children: [
                          GestureDetector(
                            onTap: () async {
                              showModalBottomSheet(
                                context: context,
                                builder: (context) => Wrap(
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.photo_library),
                                      title: const Text('Elegir de la galería'),
                                      onTap: () {
                                        Navigator.of(context).pop();
                                        _pickImage(ImageSource.gallery);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.photo_camera),
                                      title: const Text('Tomar una foto'),
                                      onTap: () {
                                        Navigator.of(context).pop();
                                        _pickImage(ImageSource.camera);
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: _postImage != null
                                ? Image.file(_postImage!, fit: BoxFit.cover)
                                : AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: Container(
                                      color: Colors.grey[200],
                                      child: Icon(Icons.camera_alt,
                                          size: 50, color: Colors.grey[700]),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 16.0),
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                                labelText: 'Seleccionar Mascota'),
                            items: pets.map((DocumentSnapshot document) {
                              Map<String, dynamic> petData =
                                  document.data()! as Map<String, dynamic>;
                              String? estado = petData.containsKey('estado')
                                  ? petData['estado']
                                  : null;
                              bool isVerified = petData.containsKey('verified')
                                  ? (petData['verified'] ?? false)
                                  : false;
                              IconData? icon;
                              Color? iconColor;

                              if (estado != null) {
                                switch (estado) {
                                  case 'perdido':
                                    iconColor = Colors.red;
                                    icon = Icons.location_off;
                                    break;
                                  case 'enmemoria':
                                    iconColor = Colors.blueAccent;
                                    icon = Icons.book;
                                    break;
                                  case 'adopcion':
                                    iconColor = Colors.brown;
                                    icon = Icons.pets;
                                    break;
                                }
                              }

                              return DropdownMenuItem<String>(
                                value: document.id,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundImage:
                                          CachedNetworkImageProvider(
                                              petData['petImageUrl']),
                                      radius: 20,
                                    ),
                                    const SizedBox(width: 8.0),
                                    Text(petData['petName']),
                                    if (isVerified) ...[
                                      const SizedBox(width: 5),
                                      const Icon(Icons.verified,
                                          color: Colors.blue, size: 20),
                                    ],
                                    if (icon != null) ...[
                                      const SizedBox(width: 5),
                                      Icon(icon, color: iconColor, size: 24),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                petId = value;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Por favor seleccione una mascota';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16.0),
                          TextFormField(
                            decoration: const InputDecoration(
                                labelText: 'Texto de la publicación'),
                            onSaved: (value) => text = value,
                            validator: (value) {
                              if (value!.isEmpty)
                                return 'Ingrese un texto para la publicación';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16.0),
                          _isLoading
                              ? const CircularProgressIndicator()
                              : ElevatedButton.icon(
                                  onPressed: _createPost,
                                  icon: const Icon(Icons.upload),
                                  label: const Text('Publicar'),
                                ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
