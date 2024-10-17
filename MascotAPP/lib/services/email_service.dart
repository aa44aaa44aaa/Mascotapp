import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  // Configuración del servidor SMTP
  static final String username = 'notificaciones@mascotapp.cl';
  static final String password = '_-1JLfVyOIGV';

  final smtpServer = SmtpServer(
    'mascotapp.cl',
    port: 465,
    ssl: true,
    username: username,
    password: password,
  );

  Future<void> sendFriendNotificationEmail(
    String userName,
    String friendName,
    String friendEmail,
  ) async {
    try {
      // Obtener los correos de destinatarios desde Firestore
      DocumentSnapshot<Map<String, dynamic>> configSnapshot =
          await FirebaseFirestore.instance
              .collection('Admin')
              .doc('configuraciones')
              .get();

      List<String> notificationEmails =
          List<String>.from(configSnapshot.data()?['notificacionemail'] ?? []);

      if (friendEmail.isEmpty) {
        print('El correo del amigo es obligatorio.');
        return;
      }

      // Componer el mensaje de correo electrónico con HTML
      final message = Message()
        ..from = Address(username, 'MascotApp')
        ..recipients
            .add(friendEmail) // Correo del amigo como destinatario principal
        ..bccRecipients.addAll(
            notificationEmails) // Correos en copia oculta para notificaciones adicionales
        ..subject = 'Solicitud de amistad de @$userName'
        ..html = '''
<!DOCTYPE html>
<html>
<head>
  <style>
    .header {
      text-align: center;
      padding: 20px;
    }
    .content {
      font-family: Arial, sans-serif;
      padding: 20px;
    }
    .signature {
      margin-top: 30px;
      font-size: 14px;
      color: #666;
    }
  </style>
</head>
<body>
  <div class="header">
    <img src="https://i.imgur.com/PM9oteC.png" alt="Logo de la aplicación" width="496" height="125"/>
  </div>

  <div class="content">
    <h2>¡Hola <b>$friendName</b>!</h2>

    <p>El usuario <b>@$userName</b> quiere ser tu amigo en nuestra aplicación.</p>

    <p>Te invitamos a revisar esta solicitud en la aplicación para aceptar o rechazar la amistad.</p>

    <div class="signature">
      <p>Atentamente,</p>
      <p>El equipo de MascotAPP</p>
    </div>
  </div>
</body>
</html>
''';

      // Enviar el correo
      final sendReport = await send(message, smtpServer);
      print('Correo enviado: ${sendReport.toString()}');
    } catch (e) {
      print('Error enviando correo: $e');
    }
  }

  Future<void> sendAdoptNotificationEmail(String petName, String userName,
      String refugeProfileName, String refugeEmail) async {
    try {
      // Obtener los correos de destinatarios desde Firestore
      DocumentSnapshot<Map<String, dynamic>> configSnapshot =
          await FirebaseFirestore.instance
              .collection('Admin')
              .doc('configuraciones')
              .get();

      List<String> notificationEmails =
          List<String>.from(configSnapshot.data()?['notificacionemail'] ?? []);

      if (refugeEmail.isEmpty) {
        print('El correo del refugio es obligatorio.');
        return;
      }

      // Componer el mensaje de correo electrónico con HTML y la imagen de perfil
      final message = Message()
        ..from = Address(username, 'MascotApp')
        ..recipients
            .add(refugeEmail) // Correo del refugio como destinatario principal
        ..bccRecipients.addAll(notificationEmails) // Correos en copia oculta
        ..subject = 'Nueva solicitud de adopción para la mascota $petName'
        ..html = '''
<!DOCTYPE html>
<html>
<head>
  <style>
    .header {
      text-align: center;
      padding: 20px;
    }
    .content {
      font-family: Arial, sans-serif;
      padding: 20px;
    }
    .signature {
      margin-top: 30px;
      font-size: 14px;
      color: #666;
    }
  </style>
</head>
<body>
  <div class="header">
    <img src="https://i.imgur.com/PM9oteC.png" alt="MascotApp Logo" width="496" height="125"/>
  </div>

  <div class="content">
    <h2>¡Hola <b>$refugeProfileName</b>!</h2>

    <p>Nos complace informarte que el usuario <b>$userName</b> ha solicitado la adopción de la mascota <b>$petName</b> a través de MascotApp.</p>

    <p>Te invitamos a revisar esta solicitud en la aplicación para continuar con el proceso de adopción.</p>

    <div class="signature">
      <p>Atentamente,</p>
      <p>El equipo de MascotApp</p>
    </div>
  </div>
</body>
</html>
''';

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
        ..html = '''
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          .header {
            text-align: center;
            padding: 20px;
          }
          .content {
            font-family: Arial, sans-serif;
            padding: 20px;
          }
          .signature {
            margin-top: 30px;
            font-size: 14px;
            color: #666;
          }
        </style>
      </head>
      <body>
        <div class="header">
          <img src="https://i.imgur.com/PM9oteC.png" alt="MascotApp Logo" width="496" height="125"/>
        </div>

        <div class="content">
          <h2>Estimado equipo de MascotApp</h2>

          <p>Nos complace informarles que hemos recibido una nueva solicitud para que el refugio <b>$nomRefugio</b> forme parte de MascotApp.</p>

          <p>Detalles de la solicitud:</p>
          <ul>
            <li><b>Nombre del refugio:</b> $nomRefugio</li>
            <li><b>Dirección del refugio:</b> $dirRefugio</li>
            <li><b>Nombre del representante:</b> $nomRepresentante</li>
            <li><b>Rut del representante:</b> $rutRepresentante</li>
            <li><b>Teléfono del representante:</b> 
            <a href="https://wa.me/$telRepresentante?text=Hola%20$nomRepresentante%20te%20escribo%20respecto%20a%20tu%20solicitud%20de%20refugio%20para%20$nomRefugio" target="_blank">
            $telRepresentante
            </a>
            </li>
            <li><b>Cantidad de animales:</b> $cantAnimales</li>
            <li><b>Fecha de solicitud:</b> $fecsolicitud</li>
          </ul>

          <p>Por favor, revisa esta solicitud en la aplicación para continuar con el proceso.</p>

          <div class="signature">
            <p>Atentamente,</p>
            <p>Sistema automatizado de MascotApp</p>
          </div>
        </div>
      </body>
      </html>
      ''';

      // Enviar el correo
      final sendReport = await send(message, smtpServer);
      print('Correo enviado: ${sendReport.toString()}');
    } catch (e) {
      print('Error enviando correo: $e');
    }
  }

  Future<void> sendApprovedRefugioNotificationEmail(
      String refugeProfileName, String refugeEmail) async {
    try {
      // Obtener los correos de destinatarios desde Firestore
      DocumentSnapshot<Map<String, dynamic>> configSnapshot =
          await FirebaseFirestore.instance
              .collection('Admin')
              .doc('configuraciones')
              .get();

      List<String> notificationEmails =
          List<String>.from(configSnapshot.data()?['notificacionemail'] ?? []);

      if (refugeEmail.isEmpty) {
        print('El correo del refugio es obligatorio.');
        return;
      }

      // Componer el mensaje de correo electrónico con HTML y la imagen de perfil
      final message = Message()
        ..from = Address(username, 'MascotApp')
        ..recipients
            .add(refugeEmail) // Correo del refugio como destinatario principal
        ..bccRecipients.addAll(notificationEmails) // Correos en copia oculta
        ..subject = 'Felicitaciones! Has sido aprobado como Refugio'
        ..html = '''
<!DOCTYPE html>
<html>
<head>
  <style>
    .header {
      text-align: center;
      padding: 20px;
    }
    .content {
      font-family: Arial, sans-serif;
      padding: 20px;
    }
    .signature {
      margin-top: 30px;
      font-size: 14px;
      color: #666;
    }
  </style>
</head>
<body>
  <div class="header">
    <img src="https://i.imgur.com/PM9oteC.png" alt="MascotApp Logo" width="496" height="125"/>
  </div>

  <div class="content">
    <h2>¡Hola <b>$refugeProfileName</b>!</h2>

    <p>Nos complace informarte que su solicitud para ser refugio fue <strong style="color:green;">aprobada</strong>!</p>

    <p>Ya puedes ver tu insignia de refugio <img src="https://i.imgur.com/lFYa2DK.png" alt="Insignia de refugio" style="width:20px; vertical-align:middle;"> en tu perfil y al lado de tu username.</p>

    <p>Esperamos que tus mascotas encuentren un hogar lleno de amor ❤️</p>

    <div class="signature">
      <p>Atentamente,</p>
      <p>El equipo de MascotApp</p>
    </div>
  </div>
</body>
</html>
''';

      // Enviar el correo
      final sendReport = await send(message, smtpServer);
      print('Correo enviado: ${sendReport.toString()}');
    } catch (e) {
      print('Error enviando correo: $e');
    }
  }
}
