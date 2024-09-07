import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';

class PetRegisterScreen extends StatefulWidget {
  const PetRegisterScreen({super.key});

  @override
  _PetRegisterScreenState createState() => _PetRegisterScreenState();
}

class _PetRegisterScreenState extends State<PetRegisterScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  String? petName, petType, petBreed, petStatus = 'nada';
  DateTime? birthDate;
  int? ageYears;
  int? ageMonths;
  File? _petImage;
  bool _isLoading = false;
  bool _knowsExactDate = true;
  String? userRole;

  final picker = ImagePicker();
  List<String> animalTypes = [];
  Map<String, List<String>> animalBreeds = {};
  List<String> breedOptions = [];

  @override
  void initState() {
    super.initState();
    _loadAnimalData();
    _loadUserRole();
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

  Future<void> _loadUserRole() async {
    User? user = _auth.currentUser;
    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(user!.uid).get();
    setState(() {
      userRole = userDoc['rol']; // Cargar el rol del usuario
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
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
    if (_formKey.currentState!.validate() && _petImage != null) {
      _formKey.currentState!.save();
      setState(() {
        _isLoading = true;
      });
      try {
        User? user = _auth.currentUser;

        String? imageUrl;
        if (_petImage != null) {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('pet_images')
              .child('${user!.uid}-${petName!}.jpg');
          final uploadTask = await storageRef.putFile(_petImage!);

          if (uploadTask.state == TaskState.success) {
            imageUrl = await storageRef.getDownloadURL();
          } else {
            throw Exception(
                'Ha ocurrido un error al intentar subir la foto de la mascota.');
          }
        }

        DateTime birthDateToSave;
        if (_knowsExactDate && birthDate != null) {
          birthDateToSave = birthDate!;
        } else if (ageYears != null && ageMonths != null) {
          birthDateToSave = DateTime.now()
              .subtract(Duration(days: (ageYears! * 365) + (ageMonths! * 30)));
        } else {
          throw Exception(
              'Debe proporcionar una fecha de nacimiento o una edad válida.');
        }

        await _firestore.collection('pets').add({
          'owner': user!.uid,
          'petName': petName,
          'petType': petType,
          'petBreed': petBreed,
          'birthDate': birthDateToSave,
          'petImageUrl': imageUrl,
          'petStatus': petStatus,
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
          _isLoading = false;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AwesomeSnackbarContent(
            title: 'Error',
            message: 'Debe proporcionar una imagen de la mascota.',
            contentType: ContentType.failure,
          ),
          backgroundColor: Colors.transparent,
          behavior: SnackBarBehavior.floating,
          elevation: 0,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Mascota'),
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: <Widget>[
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage:
                          _petImage != null ? FileImage(_petImage!) : null,
                      child: _petImage == null
                          ? const Icon(Icons.camera_alt, size: 50)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  TextFormField(
                    decoration:
                        const InputDecoration(labelText: 'Nombre de mascota'),
                    onSaved: (value) => petName = value,
                    validator: (value) {
                      if (value!.isEmpty)
                        return 'Ingresa el nombre de tu mascota';
                      return null;
                    },
                  ),
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return animalTypes.where((String option) {
                        return option
                            .toLowerCase()
                            .contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    onSelected: (String selection) {
                      setState(() {
                        petType = selection;
                        breedOptions = animalBreeds[selection]!;
                      });
                    },
                    fieldViewBuilder: (BuildContext context,
                        TextEditingController textEditingController,
                        FocusNode focusNode,
                        VoidCallback onFieldSubmitted) {
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration:
                            const InputDecoration(labelText: 'Tipo de animal'),
                        onSaved: (value) => petType = value,
                        validator: (value) {
                          if (value!.isEmpty)
                            return 'Ingresa el tipo de tu mascota';
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
                        return option
                            .toLowerCase()
                            .contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    onSelected: (String selection) {
                      setState(() {
                        petBreed = selection;
                      });
                    },
                    fieldViewBuilder: (BuildContext context,
                        TextEditingController textEditingController,
                        FocusNode focusNode,
                        VoidCallback onFieldSubmitted) {
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: const InputDecoration(labelText: 'Raza'),
                        onSaved: (value) => petBreed = value,
                        validator: (value) {
                          if (value!.isEmpty)
                            return 'Ingresa la raza de tu mascota';
                          return null;
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16.0),

                  // Campo de selección de estado de la mascota
                  DropdownButtonFormField<String>(
                    value: petStatus,
                    decoration: const InputDecoration(
                        labelText: 'Estado de la mascota'),
                    items: [
                      DropdownMenuItem(
                          value: 'nada', child: const Text('Ninguno')),
                      if (userRole == 'refugio')
                        DropdownMenuItem(
                            value: 'adopcion',
                            child: const Text('En Adopción')),
                      DropdownMenuItem(
                          value: 'perdido', child: const Text('Perdido')),
                      DropdownMenuItem(
                          value: 'enmemoria', child: const Text('En Memoria')),
                    ],
                    onChanged: (String? newValue) {
                      setState(() {
                        petStatus = newValue;
                      });
                    },
                    onSaved: (value) => petStatus = value,
                    validator: (value) {
                      if (value == null)
                        return 'Selecciona el estado de tu mascota';
                      return null;
                    },
                  ),

                  const SizedBox(height: 16.0),
                  Row(
                    children: [
                      Checkbox(
                        value: _knowsExactDate,
                        onChanged: (bool? value) {
                          setState(() {
                            _knowsExactDate = value!;
                          });
                        },
                      ),
                      const Text('Conozco la fecha exacta'),
                    ],
                  ),
                  if (_knowsExactDate)
                    TextFormField(
                      decoration: const InputDecoration(
                          labelText: 'Fecha de nacimiento'),
                      readOnly: true,
                      onTap: () async {
                        FocusScope.of(context).requestFocus(FocusNode());
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null && picked != birthDate) {
                          setState(() {
                            birthDate = picked;
                          });
                        }
                      },
                      validator: (value) {
                        if (birthDate == null)
                          return 'Ingresa su fecha de nacimiento';
                        return null;
                      },
                      controller: TextEditingController(
                        text: birthDate != null
                            ? "${birthDate!.toLocal()}".split(' ')[0]
                            : '',
                      ),
                    ),
                  if (!_knowsExactDate)
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration:
                                const InputDecoration(labelText: 'Años'),
                            keyboardType: TextInputType.number,
                            onSaved: (value) => ageYears = int.tryParse(value!),
                            validator: (value) {
                              if (value!.isEmpty) return 'Ingresa los años';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16.0),
                        Expanded(
                          child: TextFormField(
                            decoration:
                                const InputDecoration(labelText: 'Meses'),
                            keyboardType: TextInputType.number,
                            onSaved: (value) =>
                                ageMonths = int.tryParse(value!),
                            validator: (value) {
                              if (value!.isEmpty) return 'Ingresa los meses';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16.0),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _registerPet,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Registrar Mascota'),
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
