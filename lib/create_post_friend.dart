import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';
import 'package:image/image.dart' as img;

class CreatePostFriendScreen extends StatefulWidget {
  final String petId;

  CreatePostFriendScreen({required this.petId});

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
        if (user == null) return;

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
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: <Widget>[
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
                child: _postImage != null
                    ? Image.file(_postImage!, fit: BoxFit.cover)
                    : AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          color: Colors.grey[200],
                          child: Icon(Icons.camera_alt, size: 50, color: Colors.grey[700]),
                        ),
                      ),
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
                      icon: Icon(Icons.send),
                      label: Text('Enviar para aprobación'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
