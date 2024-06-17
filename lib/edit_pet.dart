import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Importación añadida
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart'; // Importar paquete para formateo de fecha

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

        await _firestore.collection('pets').doc(widget.petId).update({
          'petName': petName,
          'petType': petType,
          'petBreed': petBreed,
          'birthDate': birthDate,
          'petImageUrl': imageUrl,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pet updated successfully.'),
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
          content: Text('Pet deleted successfully.'),
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
          title: Text('Edit Pet'),
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Pet'),
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
                decoration: InputDecoration(labelText: 'Pet Name'),
                onSaved: (value) => petName = value,
                validator: (value) {
                  if (value!.isEmpty) return 'Enter pet name';
                  return null;
                },
              ),
              TextFormField(
                initialValue: petType,
                decoration: InputDecoration(labelText: 'Pet Type'),
                onSaved: (value) => petType = value,
                validator: (value) {
                  if (value!.isEmpty) return 'Enter pet type';
                  return null;
                },
              ),
              TextFormField(
                initialValue: petBreed,
                decoration: InputDecoration(labelText: 'Pet Breed'),
                onSaved: (value) => petBreed = value,
                validator: (value) {
                  if (value!.isEmpty) return 'Enter pet breed';
                  return null;
                },
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Birth Date'),
                readOnly: true,
                onTap: () async {
                  FocusScope.of(context).requestFocus(FocusNode());
                  DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: birthDate ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now());
                  if (picked != null && picked != birthDate) {
                    setState(() {
                      birthDate = picked;
                    });
                  }
                },
                validator: (value) {
                  if (birthDate == null) return 'Select birth date';
                  return null;
                },
                controller: TextEditingController(
                  text: birthDate != null
                      ? DateFormat('yyyy-MM-dd').format(birthDate!)
                      : '',
                ),
              ),
              SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _updatePet,
                child: Text('Update Pet'),
              ),
              SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _deletePet,
                child: Text('Delete Pet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, // Botón rojo para eliminar
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
