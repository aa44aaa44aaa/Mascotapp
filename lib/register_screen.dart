import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter_svg/flutter_svg.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();

  String? email, password, confirmPassword, username, profileName, bio;
  DateTime? birthDate;
  File? _profileImage;

  final picker = ImagePicker();
  bool isLoading = false;
  bool isEmailAvailable = true;
  bool isUsernameAvailable = true;
  Timer? _debounce;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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

  Future<void> _register() async {
    setState(() {
      isLoading = true;
    });

    if (_formKey.currentState!.validate() && _profileImage != null) {
      _formKey.currentState!.save();
      try {
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: email!,
          password: password!,
        );

        await userCredential.user!.sendEmailVerification();

        String? imageUrl;
        if (_profileImage != null) {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('profile_images')
              .child(userCredential.user!.uid + '.jpg');
          final uploadTask = await storageRef.putFile(_profileImage!);

          if (uploadTask.state == TaskState.success) {
            imageUrl = await storageRef.getDownloadURL();
          } else {
            throw Exception('Ha ocurrido un error al intentar subir la foto');
          }
        }

        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'username': username,
          'profileName': profileName,
          'bio': bio,
          'birthDate': birthDate,
          'email': email,
          'profileImageUrl': imageUrl,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.transparent,
            behavior: SnackBarBehavior.floating,
            elevation: 1,
            content: AwesomeSnackbarContent(
              title: 'Verificación',
              message: 'Necesitamos verificarte, revisa tu correo',
              contentType: ContentType.success,
            ),
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
          ),
        );
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    } else {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.transparent,
          behavior: SnackBarBehavior.floating,
          elevation: 0,
          content: AwesomeSnackbarContent(
            title: 'Información faltante',
            message: 'Por favor, sube una foto de perfil',
            contentType: ContentType.failure,
          ),
        ),
      );
    }
  }

  Future<void> _checkEmailAvailability(String email) async {
    final result = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .get();
    setState(() {
      isEmailAvailable = result.docs.isEmpty;
    });
  }

  Future<void> _checkUsernameAvailability(String username) async {
    final result = await _firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .get();
    setState(() {
      isUsernameAvailable = result.docs.isEmpty;
    });
  }

  void _debounceCheck(Function(String) callback, String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(Duration(milliseconds: 500), () => callback(value));
  }

  void _nextPage() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      if (_pageController.page == 0 && !isEmailAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AwesomeSnackbarContent(
              title: 'Error',
              message: 'Este correo ya está en uso',
              contentType: ContentType.failure,
            ),
          ),
        );
      } else if (_pageController.page == 1 && !isUsernameAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AwesomeSnackbarContent(
              title: 'Error',
              message: 'Este nombre de usuario ya está en uso',
              contentType: ContentType.failure,
            ),
          ),
        );
      } else {
        _pageController.nextPage(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeIn,
        );
      }
    }
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeIn,
    );
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingresa tu contraseña';
    }
    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != password) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Registro'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: PageView(
                controller: _pageController,
                physics: NeverScrollableScrollPhysics(),
                children: [
                  _buildPage1(),
                  _buildPage2(),
                  _buildPage3(),
                ],
              ),
            ),
    );
  }

  Widget _buildPage1() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SvgPicture.asset(
                'assets/cat.svg', // Assumed your SVG image path
                height: 200,
              ),
            Text('Primero, ingresa tus credenciales.'),
            SizedBox(height: 16.0),
            TextFormField(
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.email),
                labelText: 'Email',
                suffixIcon: isEmailAvailable
                    ? Icon(Icons.check, color: Colors.green)
                    : Icon(Icons.close, color: Colors.red),
              ),
              onChanged: (value) {
                email = value;
                _debounceCheck(_checkEmailAvailability, value);
              },
              onSaved: (value) => email = value,
              validator: (value) {
                if (value!.isEmpty) return 'Ingresa tu email';
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value))
                  return 'Formato de email incorrecto';
                if (!isEmailAvailable) return 'Este correo ya está en uso';
                return null;
              },
            ),
            SizedBox(height: 16.0),
            TextFormField(
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.password),
                labelText: 'Contraseña',
              ),
              obscureText: true,
              onChanged: (value) {
                password = value;
              },
              onSaved: (value) => password = value,
              validator: _validatePassword,
            ),
            SizedBox(height: 16.0),
            TextFormField(
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.password),
                labelText: 'Confirmar contraseña',
              ),
              obscureText: true,
              onChanged: (value) {
                confirmPassword = value;
              },
              onSaved: (value) => confirmPassword = value,
              validator: _validateConfirmPassword,
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _nextPage,
              child: Text('Siguiente'),
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

  Widget _buildPage2() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Ahora, creemos tu perfil!'),
            SizedBox(height: 16.0),
            TextFormField(
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.account_circle),
                labelText: 'Nombre de usuario (@)',
                suffixIcon: isUsernameAvailable
                    ? Icon(Icons.check, color: Colors.green)
                    : Icon(Icons.close, color: Colors.red),
              ),
              onChanged: (value) {
                username = value;
                _debounceCheck(_checkUsernameAvailability, value);
              },
              onSaved: (value) => username = value,
              validator: (value) {
                if (value!.isEmpty) return 'Ingresa tu nombre de usuario';
                if (value.length < 3) return 'El nombre de usuario debe tener al menos 3 caracteres';
                if (!isUsernameAvailable) return 'Este nombre de usuario ya está en uso';
                return null;
              },
            ),
            SizedBox(height: 16.0),
            TextFormField(
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.account_circle_outlined),
                labelText: 'Nombre de perfil',
              ),
              onSaved: (value) => profileName = value,
              validator: (value) {
                if (value!.isEmpty) return 'Ingresa tu nombre';
                return null;
              },
            ),
            SizedBox(height: 16.0),
            TextFormField(
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.article),
                labelText: 'Biografía',
              ),
              onSaved: (value) => bio = value,
            ),
            SizedBox(height: 16.0),
            TextFormField(
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.calendar_today),
                labelText: 'Fecha de nacimiento',
              ),
              readOnly: true,
              onTap: () async {
                FocusScope.of(context).requestFocus(new FocusNode());
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
                if (birthDate == null) return 'Ingresa tu fecha de nacimiento';
                return null;
              },
              controller: TextEditingController(
                text: birthDate != null ? DateFormat('dd-MM-yyyy').format(birthDate!) : '',
              ),
            ),
            SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _previousPage,
                  child: Text('Anterior'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(150, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _nextPage,
                  child: Text('Siguiente'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(150, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage3() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Por último, tu foto de perfil!'),
            SizedBox(height: 16.0),
            GestureDetector(
              onTap: () {
                _animationController.forward();
                showModalBottomSheet(
                  context: context,
                  builder: (context) => _buildImageSourceSheet(),
                ).whenComplete(() => _animationController.reverse());
              },
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                child: _profileImage == null ? Icon(Icons.camera_alt, size: 50) : null,
              ),
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _register,
              child: Text('Registrar'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _previousPage,
              child: Text('Anterior'),
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
