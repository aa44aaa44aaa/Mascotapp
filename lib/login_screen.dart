import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'register_screen.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();

  String? email, password;

  @override
  void initState() {
    super.initState();
    //_checkAuthState();
  }

  void _checkAuthState() {
    _auth.authStateChanges().listen((User? user) {
      if (user != null && user.emailVerified) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
      }
    });
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      try {
        UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: email!,
          password: password!,
        );

        if (!userCredential.user!.emailVerified) {
          ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color.fromARGB(0, 0, 0, 0),
            behavior: SnackBarBehavior.floating,
            elevation: 1,
            content: AwesomeSnackbarContent(
              title: 'Verificación',
              message: 'Necesitamos verificarte, revisa tu correo porfavor',
              contentType: ContentType.warning,
            ),
          ),
          );
          return;
        }

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SvgPicture.asset(
                'assets/good_dog.svg', // Assumed your SVG image path
                height: 200,
              ),
              SizedBox(height: 16.0),
              Text(
                'Bienvenido de vuelta!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16.0),
              TextFormField(
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.email),
                  labelText: 'Email',
                ),
                onSaved: (value) => email = value,
                validator: (value) {
                  if (value!.isEmpty) return 'Ingresa tu email';
                  return null;
                },
              ),
              SizedBox(height: 16.0),
              TextFormField(
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.lock),
                  labelText: 'Contraseña',
                ),
                obscureText: true,
                onSaved: (value) => password = value,
                validator: (value) {
                  if (value!.isEmpty) return 'Ingresa tu contraseña';
                  return null;
                },
              ),
              SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text('Ingresar'),
              ),
              SizedBox(height: 16.0),
              TextButton(
                onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => RegisterScreen()),
                      );
                    },
                child: Text("Aún no tienes cuenta? Registrate!"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}