import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class MemoryGameScreen extends StatefulWidget {
  const MemoryGameScreen({super.key});

  @override
  _MemoryGameScreenState createState() => _MemoryGameScreenState();
}

class _MemoryGameScreenState extends State<MemoryGameScreen>
    with SingleTickerProviderStateMixin {
  List<String> _images = [];
  List<bool> _revealed = [];
  List<bool> _matched = [];
  List<GlobalKey<FlipCardState>> _cardKeys = [];
  int _selectedIndex = -1;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _level = 1;
  bool _showCards = false;
  bool _gameStarted = false;
  bool _gameFinished = false;
  bool _waiting = false;
  bool _showLevelCompletedAnimation = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _loadImages();
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
  }

  Future<void> _loadImages() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        print('Usuario no autenticado');
        return;
      }

      print('Obteniendo imágenes de mascotas...');

      int numPairs = _level + 2;

      var userPetsSnapshot = await _firestore
          .collection('pets')
          .where('owner', isEqualTo: user.uid)
          .limit(numPairs)
          .get();

      var otherPetsSnapshot = await _firestore
          .collection('pets')
          .where('owner', isNotEqualTo: user.uid)
          .limit(numPairs)
          .get();

      List<String> petImages = [];

      print('Cargando imágenes de las mascotas del usuario...');
      for (var doc in userPetsSnapshot.docs) {
        var pet = doc.data();
        if (pet['petImageUrl'] != null) {
          petImages.add(pet['petImageUrl']);
        }
      }

      print('Cargando imágenes de otras mascotas...');
      for (var doc in otherPetsSnapshot.docs) {
        var pet = doc.data();
        if (pet['petImageUrl'] != null) {
          petImages.add(pet['petImageUrl']);
        }
      }

      if (petImages.isEmpty) {
        print('No se encontraron imágenes de mascotas');
        return;
      }

      petImages.shuffle();
      print('Imágenes de mascotas mezcladas: $petImages');

      List<String> selectedImages = petImages.take(numPairs).toList();
      selectedImages.addAll(
          List.from(selectedImages)); // Duplicar imágenes para los pares
      selectedImages.shuffle();

      print('Imágenes seleccionadas y duplicadas: $selectedImages');

      setState(() {
        _images = selectedImages;
        _revealed = List<bool>.filled(_images.length, false);
        _matched = List<bool>.filled(_images.length, false);
        _cardKeys = List.generate(
            _images.length, (index) => GlobalKey<FlipCardState>());
        _gameStarted = false;
        _gameFinished = false;
        _selectedIndex = -1;
      });

      print('Estado actualizado con nuevas imágenes: $_images');
      _showCardsBriefly();
    } catch (e) {
      print('Error cargando imágenes: $e');
    }
  }

  void _showCardsBriefly() {
    setState(() {
      _showCards = true;
    });
    Future.delayed(const Duration(seconds: 3), () {
      setState(() {
        _showCards = false;
        _startGame();
      });
    });
  }

  void _startGame() {
    setState(() {
      _gameStarted = true;
      print('Juego iniciado');
    });
  }

  void _onCardTapped(int index) {
    if (_waiting ||
        _revealed[index] ||
        _cardKeys[index].currentState?.isFront == false) return;

    print('Carta tocada en el índice: $index');
    setState(() {
      _cardKeys[index].currentState?.toggleCard();
      _revealed[index] = true;
    });

    if (_selectedIndex == -1) {
      _selectedIndex = index;
      print('Índice seleccionado: $_selectedIndex');
    } else {
      if (_selectedIndex == index) {
        print('La misma carta fue seleccionada dos veces');
        return;
      }

      if (_images[_selectedIndex] == _images[index]) {
        setState(() {
          _matched[_selectedIndex] = true;
          _matched[index] = true;
          print('Cartas reveladas en los índices: $_selectedIndex, $index');
          _selectedIndex = -1;
          _checkGameFinished();
        });
      } else {
        _waiting = true;
        int prevIndex = _selectedIndex;
        _selectedIndex = -1;
        Future.delayed(const Duration(seconds: 1), () {
          setState(() {
            _revealed[prevIndex] = false;
            _revealed[index] = false;
            _cardKeys[prevIndex].currentState?.toggleCard();
            _cardKeys[index].currentState?.toggleCard();
            _waiting = false;
          });
        });
      }
    }
  }

  void _checkGameFinished() {
    if (_matched.every((matched) => matched)) {
      setState(() {
        _gameFinished = true;
        _showLevelCompletedAnimation = true;
        _animationController.forward();
        Future.delayed(const Duration(seconds: 2), () {
          setState(() {
            _showLevelCompletedAnimation = false;
          });
        });
        print('Juego terminado');
      });
    }
  }

  void _nextLevel() {
    if (_level < 10) {
      setState(() {
        _level++;
        print('Siguiente nivel: $_level');
        _showLevelCompletedAnimation = false;
        _animationController.reset();
        _loadImages();
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int totalCards = (_level + 2) * 2; // Número total de cartas
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    // Calculamos el número de columnas y filas óptimo
    int columns = (totalCards ~/ 3).ceil();
    int rows = (totalCards / columns).ceil();

    // Ajustamos si hay demasiadas filas
    while (rows > 6) {
      columns++;
      rows = (totalCards / columns).ceil();
    }

    // Calculamos el tamaño de cada carta
    double cardWidth = (screenWidth - 32) / columns; // 32 es el padding total
    double cardHeight = (screenHeight - AppBar().preferredSize.height - 100) /
        rows; // 100 es espacio adicional para otros widgets

    // Aseguramos que las cartas no sean demasiado pequeñas
    final minSize = 60.0;
    if (cardWidth < minSize || cardHeight < minSize) {
      final scale =
          (cardWidth < cardHeight) ? minSize / cardWidth : minSize / cardHeight;
      cardWidth *= scale;
      cardHeight *= scale;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Juego de Memoria - Nivel: $_level'),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (!_gameStarted && !_gameFinished)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    '¡Memoriza las cartas!',
                    style: TextStyle(fontSize: 24),
                  ),
                ),
              if (!_gameStarted && !_gameFinished)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              if (_gameStarted && !_gameFinished)
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 4,
                        runSpacing: 4,
                        children: List.generate(_images.length, (index) {
                          return SizedBox(
                            width: cardWidth,
                            height: cardHeight,
                            child: FlipCard(
                              key: _cardKeys[index],
                              flipOnTouch: !_revealed[index] && !_showCards,
                              direction: FlipDirection.HORIZONTAL,
                              front: GestureDetector(
                                onTap: () => _onCardTapped(index),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  child:
                                      const Icon(Icons.help_outline, size: 30),
                                ),
                              ),
                              back: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: CachedNetworkImage(
                                      imageUrl: _images[index],
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  if (_matched[index])
                                    const Center(
                                      child: Icon(
                                        Icons.star,
                                        color: Colors.yellow,
                                        size: 30,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              if (_gameFinished && !_showLevelCompletedAnimation)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        '¡Felicidades! Has completado este nivel.',
                        style: TextStyle(fontSize: 24),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _nextLevel,
                        child: const Text('Siguiente Nivel'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (_showLevelCompletedAnimation)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: AnimationLimiter(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: AnimationConfiguration.toStaggeredList(
                        duration: const Duration(milliseconds: 500),
                        childAnimationBuilder: (widget) => SlideAnimation(
                          horizontalOffset: 50.0,
                          child: FadeInAnimation(child: widget),
                        ),
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.yellow,
                            size: 100,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '¡Superaste el nivel!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _showLevelCompletedAnimation = false;
                                _nextLevel();
                              });
                            },
                            child: const Text('Siguiente Nivel'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_showLevelCompletedAnimation)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: AnimationLimiter(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: AnimationConfiguration.toStaggeredList(
                        duration: const Duration(milliseconds: 500),
                        childAnimationBuilder: (widget) => SlideAnimation(
                          horizontalOffset: 50.0,
                          child: FadeInAnimation(child: widget),
                        ),
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.yellow,
                            size: 100,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '¡Superaste el nivel!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _showLevelCompletedAnimation = false;
                                _nextLevel();
                              });
                            },
                            child: const Text('Siguiente Nivel'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
