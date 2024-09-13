import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:core';

class PetImageOptimizationScreen extends StatefulWidget {
  const PetImageOptimizationScreen({super.key});

  @override
  _PetImageOptimizationScreenState createState() =>
      _PetImageOptimizationScreenState();
}

class _PetImageOptimizationScreenState
    extends State<PetImageOptimizationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _currentUserRole;
  bool _isLoading = false;
  String _loadingMessage = 'Cargando...';
  double _progress = 0.0;
  List<Map<String, dynamic>> _pets = [];
  int _optimizedCount = 0;

  @override
  void initState() {
    super.initState();
    _checkAdminRole();
  }

  Future<void> _checkAdminRole() async {
    var currentUser = _auth.currentUser;
    if (currentUser != null) {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      setState(() {
        _currentUserRole = userDoc['rol'];
      });
      if (_currentUserRole == 'admin') {
        _loadPets();
      }
    }
  }

  Future<void> _loadPets() async {
    setState(() {
      _isLoading = true;
    });

    try {
      QuerySnapshot petsSnapshot = await _firestore
          .collection('pets')
          .where('petImageUrl', isGreaterThanOrEqualTo: '')
          .get();

      setState(() {
        _pets = petsSnapshot.docs
            .map((doc) =>
                {'id': doc.id, 'data': doc.data() as Map<String, dynamic>})
            .toList();
      });
    } catch (e) {
      print('Error al cargar mascotas: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getFileNameFromUrl(String imageUrl) {
    final Uri uri = Uri.parse(imageUrl);
    final String fullPath = uri.pathSegments.last;
    final String fileName = fullPath.split('%2F').last;
    return fileName;
  }

  bool _isJpgFile(String imageUrl) {
    String fileName = _getFileNameFromUrl(imageUrl);
    return fileName.toLowerCase().endsWith('.jpg');
  }

  Future<void> _optimizeImage(String petId, String imageUrl) async {
    print('Iniciando optimización para $imageUrl');
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Descargando imagen...';
      _progress = 0.2;
    });

    try {
      Uint8List? imageBytes = await _downloadImage(imageUrl);

      if (imageBytes != null) {
        int originalSize = imageBytes.length;
        setState(() {
          _loadingMessage = 'Comprimiendo imagen...';
          _progress = 0.5;
        });

        Uint8List? compressedBytes =
            await FlutterImageCompress.compressWithList(
          imageBytes,
          format: CompressFormat.webp,
          quality: 80,
        );

        if (compressedBytes != null) {
          int newSize = compressedBytes.length;
          setState(() {
            _loadingMessage = 'Subiendo imagen optimizada...';
            _progress = 0.7;
          });

          String newImageUrl =
              await _uploadOptimizedImage(petId, imageUrl, compressedBytes);

          await _firestore.collection('pets').doc(petId).update({
            'petImageUrl': newImageUrl,
          });

          setState(() {
            _loadingMessage = 'Borrando imagen original...';
            _progress = 0.9;
          });

          await _deleteOldImage(imageUrl);

          double spaceSaved = (originalSize - newSize).toDouble();
          double percentageSaved = (spaceSaved / originalSize) * 100;

          _showSuccessTicket(petId, spaceSaved, percentageSaved);
        }
      }
    } catch (e) {
      print('Error al optimizar imagen: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _progress = 0.0;
        _loadingMessage = 'Cargando...';
      });
    }
  }

  Future<Uint8List?> _downloadImage(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        return null;
      }
    } catch (e) {
      print('Error al descargar la imagen: $e');
      return null;
    }
  }

  Future<String> _uploadOptimizedImage(
      String petId, String oldImageUrl, Uint8List imageBytes) async {
    try {
      String fileName = _getFileNameFromUrl(oldImageUrl);
      String newFileName = fileName.replaceAll('.jpg', '.webp');

      String storagePath = '$newFileName';

      Reference ref = FirebaseStorage.instance.ref().child(storagePath);
      UploadTask uploadTask = ref.putData(imageBytes);
      TaskSnapshot taskSnapshot = await uploadTask;

      String newImageUrl = await taskSnapshot.ref.getDownloadURL();
      print('Nueva imagen Optimizada: $newImageUrl');

      return newImageUrl;
    } catch (e) {
      throw Exception('Error al subir la imagen optimizada: $e');
    }
  }

  Future<void> _deleteOldImage(String imageUrl) async {
    try {
      Reference oldImageRef = FirebaseStorage.instance.refFromURL(imageUrl);
      await oldImageRef.delete();
      print('Imagen antigua eliminada: $imageUrl');
    } catch (e) {
      print('Error al borrar la imagen antigua: $e');
    }
  }

  Future<void> _showSuccessTicket(
      String petId, double spaceSaved, double percentageSaved) async {
    double spaceSavedInMB = spaceSaved / (1024 * 1024);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Optimización Exitosa'),
        content: Text('La imagen ha sido optimizada con éxito.\n'
            'Espacio ahorrado: ${spaceSaved.toStringAsFixed(2)} bytes \n'
            '(${spaceSavedInMB.toStringAsFixed(2)} MB) \n'
            '(${percentageSaved.toStringAsFixed(2)}%).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    setState(() {
      _pets.removeWhere((pet) => pet['id'] == petId);
      _optimizedCount++;
    });
  }

  Future<void> _showOptimizationDialog(String petId, String imageUrl) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Optimizar Imagen'),
        content: const Text('¿Deseas optimizar esta imagen?'),
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
      ),
    );

    if (confirm == true) {
      await _optimizeImage(petId, imageUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserRole != 'admin') {
      return const Scaffold(
        body: Center(
          child: Text(
              'Acceso denegado: Solo los administradores pueden ver esta página.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Optimización de imágenes de mascotas'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                'Imágenes Optimizadas: $_optimizedCount',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(_loadingMessage),
                const SizedBox(height: 20),
                LinearProgressIndicator(value: _progress),
              ],
            )
          : ListView.builder(
              itemCount: _pets.length,
              itemBuilder: (context, index) {
                final pet = _pets[index];
                final petData = pet['data'];
                final petImageUrl = petData['petImageUrl'];

                if (!_isJpgFile(petImageUrl)) {
                  return const SizedBox(); // Solo optimizar imágenes JPG
                }

                return Card(
                  child: ListTile(
                    leading: Image.network(petImageUrl,
                        width: 50, height: 50, fit: BoxFit.cover),
                    title: Text('Mascota ID: ${pet['id']}'),
                    subtitle: Text(petImageUrl),
                    onTap: () =>
                        _showOptimizationDialog(pet['id'], petImageUrl),
                  ),
                );
              },
            ),
    );
  }
}
