import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PetAdminEditScreen extends StatefulWidget {
  final String petId;
  final String userId; // ID del administrador que está editando

  const PetAdminEditScreen(
      {super.key, required this.petId, required this.userId});

  @override
  _PetAdminEditScreenState createState() => _PetAdminEditScreenState();
}

class _PetAdminEditScreenState extends State<PetAdminEditScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();

  String? petName, petType, petBreed, petStatus, location, adminRole;
  DateTime? birthDate;
  int? ageYears;
  int? ageMonths;
  bool _knowsExactDate = true;
  File? _petImage;
  bool _isSterilized = false;
  bool _isVaccinated = false;
  bool isAdmin = false; // Indica si el usuario es admin
  final picker = ImagePicker();
  Map<String, dynamic>? petData;

  @override
  void initState() {
    super.initState();
    _getAdminRole();
    _getPetData();
  }

  Future<void> _getAdminRole() async {
    DocumentSnapshot adminDoc =
        await _firestore.collection('users').doc(widget.userId).get();
    setState(() {
      adminRole = adminDoc.get('rol') ?? 'user';
      isAdmin = adminRole == 'admin'; // Verifica si el usuario es admin
    });
  }

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
      petStatus = petData!['estado'];
      birthDate = (petData!['birthDate'] as Timestamp).toDate();
      _knowsExactDate = true;
      location = petData!['location'] ?? '';
      _isSterilized = petData!['esterilizado'] ?? false;
      _isVaccinated = petData!['vacunado'] ?? false;
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
              .child('${widget.petId}.webp');
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
          birthDateToSave = DateTime.now()
              .subtract(Duration(days: (ageYears! * 365) + (ageMonths! * 30)));
        } else {
          throw Exception(
              'Debe proporcionar una fecha de nacimiento o una edad válida.');
        }

        await _firestore.collection('pets').doc(widget.petId).update({
          'petName': petName,
          'petType': petType,
          'petBreed': petBreed,
          'birthDate': birthDateToSave,
          'petImageUrl': imageUrl,
          'estado': petStatus,
          if (petStatus == 'perdido' || petStatus == 'adopcion')
            'location': location,
          if (petStatus == 'adopcion') 'esterilizado': _isSterilized,
          if (petStatus == 'adopcion') 'vacunado': _isVaccinated,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AwesomeSnackbarContent(
              title: 'Perfecto!',
              message:
                  'Se actualizó correctamente la información de su mascota.',
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
            content: AwesomeSnackbarContent(
              title: 'Error!',
              message: '$e',
              contentType: ContentType.failure,
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeletePet() async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('¿Estás seguro?'),
          content: const Text('¿Desea eliminar esta mascota?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sí'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      _deletePet();
    }
  }

  Future<void> _deletePet() async {
    try {
      // Iniciar una referencia a la colección de 'posts' de la mascota
      final QuerySnapshot petPostsSnapshot = await _firestore
          .collection('posts')
          .where('petId', isEqualTo: widget.petId)
          .get();

      WriteBatch batch = _firestore.batch(); // Batch de Firestore

      // Iterar sobre cada post relacionado con la mascota
      for (DocumentSnapshot doc in petPostsSnapshot.docs) {
        final postData = doc.data() as Map<String, dynamic>;

        // Verificar si el post tiene una imagen y eliminarla de Firebase Storage
        if (postData['postImageUrl'] != null &&
            postData['postImageUrl'].isNotEmpty) {
          final String imageUrl = postData['postImageUrl'];
          final Reference imageRef =
              FirebaseStorage.instance.refFromURL(imageUrl);

          await imageRef.delete(); // Eliminar la imagen de Firebase Storage
        }

        // Eliminar el post del batch
        batch.delete(doc.reference);
      }

      // Eliminar la mascota
      batch.delete(_firestore.collection('pets').doc(widget.petId));

      // Commit del batch (eliminar mascota y posts)
      await batch.commit();

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AwesomeSnackbarContent(
            title: 'Eliminado',
            message:
                'Mascota, sus posts y sus imágenes eliminados correctamente',
            contentType: ContentType.failure,
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      );

      // Volver a la pantalla anterior
      Navigator.of(context).pop();
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AwesomeSnackbarContent(
            title: 'Error!',
            message: '$e',
            contentType: ContentType.failure,
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (petData == null || adminRole == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Editar Mascota'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Mascota (Admin)'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
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
                      ? const Icon(Icons.camera_alt, size: 50)
                      : null,
                ),
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                initialValue: petName,
                decoration: const InputDecoration(labelText: 'Nombre'),
                onSaved: (value) => petName = value,
                validator: (value) {
                  if (value!.isEmpty) return 'Ingrese el nombre de su mascota';
                  return null;
                },
              ),
              TextFormField(
                initialValue: petType,
                decoration: const InputDecoration(labelText: 'Tipo'),
                onSaved: (value) => petType = value,
                validator: (value) {
                  if (value!.isEmpty) return 'Ingrese el tipo de su mascota';
                  return null;
                },
              ),
              TextFormField(
                initialValue: petBreed,
                decoration: const InputDecoration(labelText: 'Raza'),
                onSaved: (value) => petBreed = value,
                validator: (value) {
                  if (value!.isEmpty) return 'Ingrese la raza de su mascota';
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              DropdownButtonFormField<String>(
                value: petStatus,
                decoration:
                    const InputDecoration(labelText: 'Estado de la mascota'),
                items: [
                  DropdownMenuItem(value: 'nada', child: const Text('Ninguno')),
                  DropdownMenuItem(
                      value: 'adopcion', child: const Text('En Adopción')),
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
              ),
              const SizedBox(height: 16.0),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('Conozco la fecha exacta'),
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
                      title: const Text('No sé la fecha exacta'),
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
                  decoration:
                      const InputDecoration(labelText: 'Fecha de nacimiento'),
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
                    if (birthDate == null)
                      return 'Ingrese la fecha de nacimiento';
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
                        decoration: const InputDecoration(labelText: 'Años'),
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
                        decoration: const InputDecoration(labelText: 'Meses'),
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
              const SizedBox(height: 16.0),
              if (petStatus == 'perdido' || petStatus == 'adopcion')
                TextFormField(
                  initialValue: location,
                  decoration: const InputDecoration(
                      labelText: 'Ubicación (Comuna, Ciudad)'),
                  onSaved: (value) => location = value,
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'Por favor ingresa la ubicación';
                    }
                    return null;
                  },
                ),
              if (petStatus == 'adopcion')
                Column(
                  children: [
                    CheckboxListTile(
                      title: const Text('¿Está esterilizado?'),
                      value: _isSterilized,
                      onChanged: (bool? value) {
                        setState(() {
                          _isSterilized = value!;
                        });
                      },
                    ),
                    CheckboxListTile(
                      title: const Text('¿Está vacunado?'),
                      value: _isVaccinated,
                      onChanged: (bool? value) {
                        setState(() {
                          _isVaccinated = value!;
                        });
                      },
                    ),
                  ],
                ),
              const SizedBox(height: 16.0),
              if (isAdmin)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _updatePet,
                        child: const Text('Actualizar'),
                      ),
                    ),
                    const SizedBox(width: 16.0),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _confirmDeletePet,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Eliminar'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
