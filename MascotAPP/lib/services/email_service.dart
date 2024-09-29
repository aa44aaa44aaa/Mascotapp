import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  // Configuración del servidor SMTP
  static final String username = 'admin@mascotapp.cl';
  static final String password = '7]BL4@3x?^^V';

  final smtpServer = SmtpServer(
    'mascotapp.cl',
    port: 465,
    ssl: true,
    username: username,
    password: password,
  );

  Future<void> sendAdoptNotificationEmail(String petName, String userId) async {
    try {
      // Obtener los correos de destinatarios desde Firestore
      DocumentSnapshot<Map<String, dynamic>> configSnapshot =
          await FirebaseFirestore.instance
              .collection('Admin')
              .doc('configuraciones')
              .get();

      List<String> notificationEmails =
          List<String>.from(configSnapshot.data()?['notificacionemail'] ?? []);

      if (notificationEmails.isEmpty) {
        print('No se encontraron correos electrónicos de notificación.');
        return;
      }

      // Componer el mensaje de correo electrónico
      final message = Message()
        ..from = Address(username, 'MascotApp')
        ..recipients.addAll(notificationEmails) // Destinatarios
        ..subject = 'Nueva solicitud de adopción para la mascota $petName'
        ..text =
            'El usuario con ID $userId ha solicitado adoptar a la mascota $petName.';

      // Enviar el correo
      final sendReport = await send(message, smtpServer);
      print('Correo enviado: ${sendReport.toString()}');
    } catch (e) {
      print('Error enviando correo: $e');
    }
  }

  Future<void> sendApplyRefugioNotificationEmail(
      String nomRefugio,
      String dirRefugio,
      String nomRepresentante,
      String rutRepresentante,
      String telRepresentante,
      String cantAnimales,
      String fecsolicitud) async {
    try {
      // Obtener los correos de destinatarios desde Firestore
      DocumentSnapshot<Map<String, dynamic>> configSnapshot =
          await FirebaseFirestore.instance
              .collection('Admin')
              .doc('configuraciones')
              .get();

      List<String> notificationEmails =
          List<String>.from(configSnapshot.data()?['notificacionemail'] ?? []);

      if (notificationEmails.isEmpty) {
        print('No se encontraron correos electrónicos de notificación.');
        return;
      }

      // Componer el mensaje de correo electrónico
      final message = Message()
        ..from = Address(username, 'MascotApp')
        ..recipients.addAll(notificationEmails) // Destinatarios
        ..subject = 'Solicitud de refugio de $nomRefugio'
        ..text =
            'Estimado equipo de MascotApp\nHa llegado una nueva solicitud para ser refugio!\n\nNombre del refugio: $nomRefugio\nDirección del refugio: $dirRefugio\nNombre del representante: $nomRepresentante\nRut del representante: $rutRepresentante\nTeléfono del representante: $telRepresentante\nCantidad de animales: $cantAnimales\nFecha de solicitud: $fecsolicitud\nLa solicitud puede ser respondida en la aplicación.\n\nSaludos\nMensaje Automatizado de MascotApp.';

      // Enviar el correo
      final sendReport = await send(message, smtpServer);
      print('Correo enviado: ${sendReport.toString()}');
    } catch (e) {
      print('Error enviando correo: $e');
    }
  }
}
