  import 'package:flutter/material.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:firebase_storage/firebase_storage.dart';
  import 'package:image_picker/image_picker.dart';
  import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
  import 'package:image_cropper/image_cropper.dart';
  import 'dart:io';
  import 'package:image/image.dart' as img; // Asegúrate de agregar image package en pubspec.yaml
  import 'home_screen.dart';
  import 'pets_screen.dart';

  class CreatePostScreen extends StatefulWidget {
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
              toolbarColor: Color.fromRGBO(130, 34, 255, 1),
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
              aspectRatioPresets: [
                //CropAspectRatioPreset.ratio4x5,
                //CropAspectRatioPreset.ratio5x4,
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
          // Optimize image
          final bytes = await croppedFile.readAsBytes();
          img.Image? image = img.decodeImage(bytes);
          if (image != null) {
            final compressedBytes = img.encodeJpg(image, quality: 70);
            setState(() {
              _postImage = File(croppedFile.path)
                ..writeAsBytesSync(compressedBytes);
            });
          }
        }
      }
    }

    Future<void> _createPost() async {
      if (_formKey.currentState!.validate()) {
        _formKey.currentState!.save();
        try {
          setState(() {
            _isLoading = true;
          });
          User? user = _auth.currentUser;
          if (user == null || petId == null) return;

          DocumentSnapshot petDoc = await _firestore.collection('pets').doc(petId).get();
          if (!petDoc.exists) return;

          DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();

          String? imageUrl;
          if (_postImage != null) {
            final storageRef = FirebaseStorage.instance
                .ref()
                .child('post_images')
                .child(user.uid + '-' + DateTime.now().toString() + '.jpg');
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
            MaterialPageRoute(builder: (context) => HomeScreen()),
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
      }
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16.0),
            child: Column(
              children: <Widget>[
                StreamBuilder<User?>(
                  stream: _auth.authStateChanges(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }
                    User? user = snapshot.data;
                    return StreamBuilder<QuerySnapshot>(
                      stream: _firestore.collection('pets').where('owner', isEqualTo: user?.uid).snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return CircularProgressIndicator();
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
                                        leading: Icon(Icons.photo_library),
                                        title: Text('Elegir de la galería'),
                                        onTap: () {
                                          Navigator.of(context).pop();
                                          _pickImage(ImageSource.gallery);
                                        },
                                      ),
                                      ListTile(
                                        leading: Icon(Icons.photo_camera),
                                        title: Text('Tomar una foto'),
                                        onTap: () {
                                          Navigator.of(context).pop();
                                          _pickImage(ImageSource.camera);
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: 
                                _postImage != null
                                    ? Image.file(_postImage!, fit: BoxFit.cover)
                                    : AspectRatio(
                                      aspectRatio: 16 / 9,
                                      child:
                                        Container(
                                        color: Colors.grey[200],
                                        child: Icon(Icons.camera_alt, size: 50, color: Colors.grey[700]),
                                        ) 
                                      )

                            ),
                            SizedBox(height: 16.0),
                            DropdownButtonFormField<String>(
                              decoration: InputDecoration(labelText: 'Seleccionar Mascota'),
                              items: pets.map((DocumentSnapshot document) {
                                return DropdownMenuItem<String>(
                                  value: document.id,
                                  child: Text(document['petName']),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  petId = value;
                                });
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'Porfavor seleccione una mascota';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 16.0),
                            TextFormField(
                              decoration: InputDecoration(labelText: 'Texto de la publicación'),
                              onSaved: (value) => text = value,
                              validator: (value) {
                                if (value!.isEmpty) return 'Ingrese un texto para la publicación';
                                return null;
                              },
                            ),
                            SizedBox(height: 16.0),
                            _isLoading
                                ? CircularProgressIndicator()
                                : ElevatedButton.icon(
                                    onPressed: _createPost,
                                    icon: Icon(Icons.upload),
                                    label: Text('Publicar'),
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
