import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FlappyBirdGame extends StatefulWidget {
  final String petImageUrl;
  const FlappyBirdGame({required this.petImageUrl, Key? key}) : super(key: key);

  @override
  _FlappyBirdGameState createState() => _FlappyBirdGameState();
}

class _FlappyBirdGameState extends State<FlappyBirdGame>
    with SingleTickerProviderStateMixin {
  static const double gravity = 0.5;
  static const double jump = -10.0;
  double birdY = 0;
  double birdVelocity = 0;
  double birdWidth = 50;
  double birdHeight = 50;
  bool gameStarted = false;
  late AnimationController _controller;
  Timer? _timer;
  late List<double> barrierX;
  double barrierWidth = 60;
  List<List<double>> barrierHeight = [];

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..addListener(() {
            setState(() {});
          });
    resetGame();
  }

  void startGame() {
    setState(() {
      gameStarted = true;
    });
    _timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      setState(() {
        birdVelocity += gravity;
        birdY += birdVelocity;

        if (birdY > 1) {
          timer.cancel();
          gameStarted = false;
        }

        for (int i = 0; i < barrierX.length; i++) {
          barrierX[i] -= 0.05;
          if (barrierX[i] < -1) {
            barrierX[i] += 2;
            Random random = Random();
            barrierHeight[i] = [
              random.nextDouble() * 0.5 + 0.1,
              random.nextDouble() * 0.5 + 0.1
            ];
          }

          if (birdXCollision(i) && birdYCollision(i)) {
            timer.cancel();
            gameStarted = false;
          }
        }
      });
    });
  }

  void resetGame() {
    birdY = 0;
    birdVelocity = 0;
    barrierX = [1, 1.5];
    barrierHeight = [
      [0.3, 0.3],
      [0.3, 0.3]
    ];
    _timer?.cancel();
  }

  void jumpBird() {
    setState(() {
      birdVelocity = jump;
    });
  }

  bool birdXCollision(int index) {
    return barrierX[index] < birdWidth / MediaQuery.of(context).size.width &&
        barrierX[index] + barrierWidth / MediaQuery.of(context).size.width >
            -birdWidth / MediaQuery.of(context).size.width;
  }

  bool birdYCollision(int index) {
    return birdY < -1 + barrierHeight[index][0] ||
        birdY > 1 - barrierHeight[index][1];
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (gameStarted) {
          jumpBird();
        } else {
          startGame();
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  AnimatedContainer(
                    alignment: Alignment(0, birdY),
                    duration: const Duration(milliseconds: 0),
                    child: Container(
                      height: birdHeight,
                      width: birdWidth,
                      child: Image.network(widget.petImageUrl),
                    ),
                  ),
                  if (!gameStarted)
                    Center(
                      child: const Text(
                        'TAP TO START',
                        style: TextStyle(fontSize: 24, color: Colors.white),
                      ),
                    ),
                  for (int i = 0; i < barrierX.length; i++)
                    Barrier(
                      x: barrierX[i],
                      width: barrierWidth,
                      height: barrierHeight[i],
                      index: i,
                    ),
                ],
              ),
            ),
            Container(
              height: 15,
              color: Colors.green,
            ),
            Expanded(
              child: Container(
                color: Colors.brown,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Barrier extends StatelessWidget {
  final double x;
  final double width;
  final List<double> height;
  final int index;

  const Barrier(
      {required this.x,
      required this.width,
      required this.height,
      required this.index,
      Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      alignment: Alignment(x, 1),
      duration: const Duration(milliseconds: 0),
      child: Column(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 3 / 4 * height[0],
            width: width,
            color: Colors.green,
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height * 1 / 4 * 0.2,
          ),
          Container(
            height: MediaQuery.of(context).size.height * 3 / 4 * height[1],
            width: width,
            color: Colors.green,
          ),
        ],
      ),
    );
  }
}
