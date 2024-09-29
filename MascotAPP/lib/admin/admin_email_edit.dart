import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminEmailScreen extends StatefulWidget {
  @override
  _AdminEmailScreenState createState() => _AdminEmailScreenState();
}

class _AdminEmailScreenState extends State<AdminEmailScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> emails = [];
  bool isAdmin = false;
  bool isLoading = true;
  TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    checkAdminRole();
  }

  Future<void> checkAdminRole() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists && userDoc['rol'] == 'admin') {
        setState(() {
          isAdmin = true;
        });
        fetchEmails();
      } else {
        setState(() {
          isAdmin = false;
        });
      }
    }
    setState(() {
      isLoading = false;
    });
  }

  Future<void> fetchEmails() async {
    DocumentSnapshot doc =
        await _firestore.collection('Admin').doc('configuraciones').get();

    if (doc.exists) {
      List<dynamic> emailList = doc['notificacionemail'];
      setState(() {
        emails = List<String>.from(emailList);
      });
    }
  }

  Future<void> addEmail(String email) async {
    if (email.isNotEmpty) {
      setState(() {
        emails.add(email);
      });
      await _firestore
          .collection('Admin')
          .doc('configuraciones')
          .update({'notificacionemail': emails});
      _emailController.clear();
    }
  }

  Future<void> removeEmail(int index) async {
    setState(() {
      emails.removeAt(index);
    });
    await _firestore
        .collection('Admin')
        .doc('configuraciones')
        .update({'notificacionemail': emails});
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: Text("Acceso Denegado"),
        ),
        body: Center(
          child: Text("No tienes permisos para acceder a esta pantalla."),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Administrar Correos'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Nuevo Correo',
                suffixIcon: IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () => addEmail(_emailController.text),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: emails.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(emails[index]),
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => removeEmail(index),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
