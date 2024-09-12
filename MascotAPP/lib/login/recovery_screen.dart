import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/validations_service.dart';
import 'dart:async'; // Para usar el temporizador

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  _RecoveryScreenState createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final _auth = FirebaseAuth.instance;
  final TextEditingController emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isButtonDisabled = false; // Estado del botón
  int _secondsToWait = 5; // Tiempo de espera inicial
  Timer? _timer; // Temporizador
  int _currentWaitIndex = 0; // Índice del tiempo de espera actual

  // Lista de tiempos de espera en segundos (5s, 30s, 1min, 5min, 10min, etc.)
  final List<int> _waitTimes = [
    5, // 5 segundos
    30, // 30 segundos
    60, // 1 minuto
    5 * 60, // 5 minutos
    10 * 60, // 10 minutos
    15 * 60, // 15 minutos
    30 * 60, // 30 minutos
    40 * 60 // 40 minutos (+10 minutos después de los 30 min)
  ];

  Future<void> _resetPassword() async {
    if (_formKey.currentState!.validate()) {
      String email = emailController.text.trim();
      try {
        await _auth.sendPasswordResetEmail(email: email);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Se ha enviado un enlace a $email'),
          ),
        );

        // Deshabilitar el botón y activar el temporizador
        setState(() {
          _isButtonDisabled = true;
        });
        _startTimer();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Su email no está registrado'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.message}'),
            ),
          );
        }
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

  // Iniciar el temporizador para el tiempo de espera actual
  void _startTimer() {
    _secondsToWait =
        _waitTimes[_currentWaitIndex]; // Obtener el tiempo actual de la lista
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsToWait > 1) {
          _secondsToWait--;
        } else {
          _isButtonDisabled = false; // Rehabilitar el botón
          _incrementWaitTime(); // Incrementar el tiempo de espera para la próxima vez
          timer.cancel(); // Detener el temporizador
        }
      });
    });
  }

  // Incrementar el tiempo de espera para la próxima solicitud
  void _incrementWaitTime() {
    if (_currentWaitIndex < _waitTimes.length - 1) {
      _currentWaitIndex++;
    }
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancelar el temporizador cuando se cierra la pantalla
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recuperar Contraseña'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey, // Envolvemos los campos en un Form y asignamos la key
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'Restablecer contraseña',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Ingresa tu email',
                  prefixIcon: Icon(Icons.email),
                ),
                validator: (value) {
                  if (value!.isEmpty) return 'Ingresa tu email';
                  if (value.length > 255)
                    return 'El email no puede tener más de 255 caracteres';
                  if (!ValidationService.validarEmail(value)) {
                    return 'Ingresa un email válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _isButtonDisabled
                    ? null
                    : _resetPassword, // Deshabilitar el botón si es necesario
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: _isButtonDisabled
                    ? Text('Esperando $_secondsToWait segundos...')
                    : const Text('Enviar enlace'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
