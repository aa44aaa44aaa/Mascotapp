import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';

class EditPetScreen extends StatefulWidget {
  final String petId;

  EditPetScreen({required this.petId});

  @override
  _EditPetScreenState createState() => _EditPetScreenState();
}

class _EditPetScreenState extends State<EditPetScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  String? petName, petType, petBreed;
  DateTime? birthDate;
  int? ageYears;
  int? ageMonths;
  bool _knowsExactDate = true;
  File? _petImage;
  final picker = ImagePicker();
  Map<String, dynamic>? petData;

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      if (pickedFile != null) {
        _petImage = File(pickedFile.path);
      }
    });
  }

  Future<void> _getPetData() async {
    DocumentSnapshot petDoc =
        await _firestore.collection('pets').doc(widget.petId).get();
    setState(() {
      petData = petDoc.data() as Map<String, dynamic>;
      petName = petData!['petName'];
      petType = petData!['petType'];
      petBreed = petData!['petBreed'];
      birthDate = (petData!['birthDate'] as Timestamp).toDate();
      _knowsExactDate = true; // Asume que inicialmente conoce la fecha exacta
    });
  }

  Future<void> _updatePet() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      try {
        String? imageUrl = petData!['petImageUrl'];
        if (_petImage != null) {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('pet_images')
              .child(widget.petId + '.jpg');
          final uploadTask = await storageRef.putFile(_petImage!);

          if (uploadTask.state == TaskState.success) {
            imageUrl = await storageRef.getDownloadURL();
          } else {
            throw Exception('Failed to upload pet image.');
          }
        }

        DateTime birthDateToSave;
        if (_knowsExactDate && birthDate != null) {
          birthDateToSave = birthDate!;
        } else if (ageYears != null && ageMonths != null) {
          birthDateToSave = DateTime.now().subtract(Duration(days: (ageYears! * 365) + (ageMonths! * 30)));
        } else {
          throw Exception('Debe proporcionar una fecha de nacimiento o una edad válida.');
        }

        await _firestore.collection('pets').doc(widget.petId).update({
          'petName': petName,
          'petType': petType,
          'petBreed': petBreed,
          'birthDate': birthDateToSave,
          'petImageUrl': imageUrl,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: AwesomeSnackbarContent(
                title: 'Perfecto!',
                message: 'Se actualizó correctamente la información de su mascota.',
                contentType: ContentType.success,
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
        );

        Navigator.of(context).pop();
      } catch (e) {
        print(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
          ),
        );
      }
    }
  }

  Future<void> _deletePet() async {
    try {
      await _firestore.collection('pets').doc(widget.petId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AwesomeSnackbarContent(
            title: 'Eliminado',
            message: 'Mascota eliminada correctamente',
            contentType: ContentType.failure,
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
    }
  }

  @override
  void initState() {
    super.initState();
    _getPetData();
  }

  @override
  Widget build(BuildContext context) {
    if (petData == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Editar Mascota'),
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Editar Mascota'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: <Widget>[
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: _petImage != null
                      ? FileImage(_petImage!)
                      : petData!['petImageUrl'] != null
                          ? NetworkImage(petData!['petImageUrl'])
                          : null,
                  child: _petImage == null && petData!['petImageUrl'] == null
                      ? Icon(Icons.camera_alt, size: 50)
                      : null,
                ),
              ),
              SizedBox(height: 16.0),
              TextFormField(
                initialValue: petName,
                decoration: InputDecoration(labelText: 'Nombre'),
                onSaved: (value) => petName = value,
                validator: (value) {
                  if (value!.isEmpty) return 'Ingrese el nombre de su mascota';
                  return null;
                },
              ),
              TextFormField(
                initialValue: petType,
                decoration: InputDecoration(labelText: 'Tipo'),
                onSaved: (value) => petType = value,
                validator: (value) {
                  if (value!.isEmpty) return 'Ingrese el tipo de su mascota';
                  return null;
                },
              ),
              TextFormField(
                initialValue: petBreed,
                decoration: InputDecoration(labelText: 'Raza'),
                onSaved: (value) => petBreed = value,
                validator: (value) {
                  if (value!.isEmpty) return 'Ingrese la raza de su mascota';
                  return null;
                },
              ),
              SizedBox(height: 16.0),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      title: Text('Conozco la fecha exacta'),
                      value: true,
                      groupValue: _knowsExactDate,
                      onChanged: (bool? value) {
                        setState(() {
                          _knowsExactDate = value!;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      title: Text('No sé la fecha exacta'),
                      value: false,
                      groupValue: _knowsExactDate,
                      onChanged: (bool? value) {
                        setState(() {
                          _knowsExactDate = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              if (_knowsExactDate)
                TextFormField(
                  decoration: InputDecoration(labelText: 'Fecha de nacimiento'),
                  readOnly: true,
                  onTap: () async {
                    FocusScope.of(context).requestFocus(FocusNode());
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: birthDate ?? DateTime.now(),
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
                    if (birthDate == null) return 'Ingrese la fecha de nacimiento';
                    return null;
                  },
                  controller: TextEditingController(
                    text: birthDate != null
                        ? DateFormat('yyyy-MM-dd').format(birthDate!)
                        : '',
                  ),
                ),
              if (!_knowsExactDate)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        decoration: InputDecoration(labelText: 'Años'),
                        keyboardType: TextInputType.number,
                        onSaved: (value) => ageYears = int.tryParse(value!),
                        validator: (value) {
                          if (value!.isEmpty) return 'Ingresa los años';
                          return null;
                        },
                      ),
                    ),
                    SizedBox(width: 16.0),
                    Expanded(
                      child: TextFormField(
                        decoration: InputDecoration(labelText: 'Meses'),
                        keyboardType: TextInputType.number,
                        onSaved: (value) => ageMonths = int.tryParse(value!),
                        validator: (value) {
                          if (value!.isEmpty) return 'Ingresa los meses';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _updatePet,
                child: Text('Actualizar'),
              ),
              SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _deletePet,
                child: Text('Eliminar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
