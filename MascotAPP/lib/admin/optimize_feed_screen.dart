import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:core';

class ImageFeedOptimizationScreen extends StatefulWidget {
  const ImageFeedOptimizationScreen({super.key});

  @override
  _ImageFeedOptimizationScreenState createState() =>
      _ImageFeedOptimizationScreenState();
}

class _ImageFeedOptimizationScreenState
    extends State<ImageFeedOptimizationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _currentUserRole;
  bool _isLoading = false;
  String _loadingMessage = 'Cargando...'; // Mensaje del proceso
  double _progress = 0.0; // Barra de progreso
  List<Map<String, dynamic>> _posts = [];
  int _optimizedCount = 0; // Contador de imágenes optimizadas

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
        _loadPosts();
      }
    }
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      QuerySnapshot postsSnapshot = await _firestore
          .collection('posts')
          .where('postImageUrl', isGreaterThanOrEqualTo: '')
          .get();

      setState(() {
        _posts = postsSnapshot.docs
            .map((doc) =>
                {'id': doc.id, 'data': doc.data() as Map<String, dynamic>})
            .toList();
      });
    } catch (e) {
      print('Error al cargar posts: $e');
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

  Future<void> _optimizeImage(String postId, String imageUrl) async {
    print('Iniciando optimización para $imageUrl');
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Descargando imagen...';
      _progress = 0.2; // Progreso inicial
    });

    try {
      Uint8List? imageBytes = await _downloadImage(imageUrl);

      if (imageBytes != null) {
        int originalSize = imageBytes.length; // Tamaño original de la imagen
        setState(() {
          _loadingMessage = 'Comprimiendo imagen...';
          _progress = 0.5;
        });

        Uint8List? compressedBytes =
            await FlutterImageCompress.compressWithList(
          imageBytes,
          format: CompressFormat.webp,
          quality: 80, // Calidad ajustada
        );

        if (imageBytes != null) {
          int newSize =
              compressedBytes.length; // Tamaño de la imagen optimizada
          setState(() {
            _loadingMessage = 'Subiendo imagen optimizada...';
            _progress = 0.7;
          });

          String newImageUrl =
              await _uploadOptimizedImage(postId, imageUrl, compressedBytes);

          await _firestore.collection('posts').doc(postId).update({
            'postImageUrl': newImageUrl,
          });

          setState(() {
            _loadingMessage = 'Borrando imagen original...';
            _progress = 0.9;
          });

          await _deleteOldImage(imageUrl);

          double spaceSaved =
              (originalSize - newSize).toDouble(); // Cast to double
          double percentageSaved =
              (spaceSaved / originalSize) * 100; // Porcentaje ahorrado

          // Mostrar el ticket de éxito, eliminar la tarjeta y mostrar el ahorro
          _showSuccessTicket(postId, spaceSaved, percentageSaved);
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
      String postId, String oldImageUrl, Uint8List imageBytes) async {
    try {
      String fileName = _getFileNameFromUrl(oldImageUrl);
      String newFileName = fileName.replaceAll('.jpg', '.webp');

      // Removed unused folderPath variable
      String storagePath = '$newFileName';

      Reference ref = FirebaseStorage.instance.ref().child(storagePath);
      UploadTask uploadTask = ref.putData(imageBytes);
      TaskSnapshot taskSnapshot = await uploadTask;

      String newImageUrl = await taskSnapshot.ref.getDownloadURL();

      // Print the new image URL in the console
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
      String postId, double spaceSaved, double percentageSaved) async {
    // Convert bytes to MB
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

    // Eliminar la tarjeta del post correspondiente
    setState(() {
      _posts.removeWhere((post) => post['id'] == postId);
      _optimizedCount++; // Incrementar el contador de imágenes optimizadas
    });
  }

  Future<void> _showOptimizationDialog(String postId, String imageUrl) async {
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
      await _optimizeImage(postId, imageUrl);
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
        title: const Text('Optimización de imágenes'),
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
              itemCount: _posts.length,
              itemBuilder: (context, index) {
                final post = _posts[index];
                final postData = post['data'];
                final postImageUrl = postData['postImageUrl'];

                if (!_isJpgFile(postImageUrl)) {
                  return const SizedBox(); // Solo mostramos las imágenes JPG
                }

                return Card(
                  child: ListTile(
                    leading: Image.network(postImageUrl,
                        width: 50, height: 50, fit: BoxFit.cover),
                    title: Text('Post ID: ${post['id']}'),
                    subtitle: Text(postImageUrl),
                    onTap: () =>
                        _showOptimizationDialog(post['id'], postImageUrl),
                  ),
                );
              },
            ),
    );
  }
}
