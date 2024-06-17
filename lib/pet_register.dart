import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:convert'; // Importar para manejar JSON
import 'package:flutter/services.dart' show rootBundle; // Importar para cargar el JSON desde assets
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart'; // Importar el paquete de AwesomeSnackBar

class PetRegisterScreen extends StatefulWidget {
  @override
  _PetRegisterScreenState createState() => _PetRegisterScreenState();
}

class _PetRegisterScreenState extends State<PetRegisterScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  String? petName, petType, petBreed;
  DateTime? birthDate;
  File? _petImage;
  bool _isLoading = false; // Controlador de estado de carga

  final picker = ImagePicker();
  List<String> animalTypes = [];
  Map<String, List<String>> animalBreeds = {};
  List<String> breedOptions = [];

  @override
  void initState() {
    super.initState();
    _loadAnimalData();
  }

  Future<void> _loadAnimalData() async {
    String data = await rootBundle.loadString('assets/animales.json');
    final jsonResult = json.decode(data);
    setState(() {
      for (var animal in jsonResult['animales']) {
        animalTypes.add(animal['nombre']);
        animalBreeds[animal['nombre']] = List<String>.from(animal['razas']);
      }
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
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
        final bytes = await croppedFile.readAsBytes();
        img.Image? image = img.decodeImage(bytes);
        if (image != null) {
          final resizedImage = img.copyResize(image, width: 512, height: 512);
          final compressedBytes = img.encodeJpg(resizedImage, quality: 70);
          setState(() {
            _petImage = File(croppedFile.path)
              ..writeAsBytesSync(compressedBytes);
          });
        }
      }
    }
  }

  Future<void> _registerPet() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isLoading = true; // Iniciar animación de carga
      });
      try {
        User? user = _auth.currentUser;

        String? imageUrl;
        if (_petImage != null) {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('pet_images')
              .child(user!.uid + '-' + petName! + '.jpg');
          final uploadTask = await storageRef.putFile(_petImage!);

          if (uploadTask.state == TaskState.success) {
            imageUrl = await storageRef.getDownloadURL();
          } else {
            throw Exception('Ha ocurrido un error al intentar subir la foto de la mascota.');
          }
        }

        await _firestore.collection('pets').add({
          'owner': user!.uid,
          'petName': petName,
          'petType': petType,
          'petBreed': petBreed,
          'birthDate': birthDate,
          'petImageUrl': imageUrl,
          'verified': false,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AwesomeSnackbarContent(
              title: 'Éxito',
              message: 'Animal registrado exitosamente.',
              contentType: ContentType.success,
            ),
            backgroundColor: Colors.transparent,
            behavior: SnackBarBehavior.floating,
            elevation: 0,
          ),
        );

        Navigator.of(context).pop();
      } catch (e) {
        print(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AwesomeSnackbarContent(
              title: 'Error',
              message: 'Error: $e',
              contentType: ContentType.failure,
            ),
            backgroundColor: Colors.transparent,
            behavior: SnackBarBehavior.floating,
            elevation: 0,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false; // Terminar animación de carga
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Registrar Mascota'),
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: Column(
                children: <Widget>[
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: _petImage != null ? FileImage(_petImage!) : null,
                      child: _petImage == null ? Icon(Icons.camera_alt, size: 50) : null,
                    ),
                  ),
                  SizedBox(height: 16.0),
                  TextFormField(
                    decoration: InputDecoration(labelText: 'Nombre de mascota'),
                    onSaved: (value) => petName = value,
                    validator: (value) {
                      if (value!.isEmpty) return 'Ingresa el nombre de tu mascota';
                      return null;
                    },
                  ),
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return animalTypes.where((String option) {
                        return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    onSelected: (String selection) {
                      setState(() {
                        petType = selection;
                        breedOptions = animalBreeds[selection]!;
                      });
                    },
                    fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: InputDecoration(labelText: 'Tipo de animal'),
                        onSaved: (value) => petType = value,
                        validator: (value) {
                          if (value!.isEmpty) return 'Ingresa el tipo de tu mascota';
                          return null;
                        },
                      );
                    },
                  ),
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return breedOptions.where((String option) {
                        return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    onSelected: (String selection) {
                      setState(() {
                        petBreed = selection;
                      });
                    },
                    fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: InputDecoration(labelText: 'Raza'),
                        onSaved: (value) => petBreed = value,
                        validator: (value) {
                          if (value!.isEmpty) return 'Ingresa la raza de tu mascota';
                          return null;
                        },
                      );
                    },
                  ),
                  TextFormField(
                    decoration: InputDecoration(labelText: 'Fecha de nacimiento'),
                    readOnly: true,
                    onTap: () async {
                      FocusScope.of(context).requestFocus(FocusNode());
                      DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now());
                      if (picked != null && picked != birthDate) {
                        setState(() {
                          birthDate = picked;
                        });
                      }
                    },
                    validator: (value) {
                      if (birthDate == null) return 'Ingresa su fecha de nacimiento';
                      return null;
                    },
                    controller: TextEditingController(
                      text: birthDate != null ? "${birthDate!.toLocal()}".split(' ')[0] : '',
                    ),
                  ),
                  SizedBox(height: 16.0),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _registerPet,
                    child: _isLoading 
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text('Registrar Mascota'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
