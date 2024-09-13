import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class CreatePostFriendScreen extends StatefulWidget {
  final String petId;

  const CreatePostFriendScreen({super.key, required this.petId});

  @override
  _CreatePostFriendScreenState createState() => _CreatePostFriendScreenState();
}

class _CreatePostFriendScreenState extends State<CreatePostFriendScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  final picker = ImagePicker();

  String? text;
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
              //CropAspectRatioPreset.ratio4x5,
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
            _postImage = webpFile;
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
        if (user == null) return;

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

        await _firestore.collection('pending_posts').add({
          'postedby': user.uid,
          'petId': widget.petId,
          'postImageUrl': imageUrl,
          'text': text,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending',
        });

        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AwesomeSnackbarContent(
              title: 'Perfecto!',
              message: 'El post ha sido enviado para aprobación.',
              contentType: ContentType.success,
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        );

        Navigator.pop(context);
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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: <Widget>[
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
              TextFormField(
                decoration:
                    const InputDecoration(labelText: 'Texto de la publicación'),
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
                      icon: const Icon(Icons.send),
                      label: const Text('Enviar para aprobación'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
