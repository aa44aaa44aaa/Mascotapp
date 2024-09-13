import 'package:url_launcher/url_launcher.dart';

class FunctionsServices {
  // Función para abrir WhatsApp
  Future<void> launchWhatsApp(String phoneNumber, String message) async {
    final whatsappUrl = Uri.parse(
        'whatsapp://send?phone=$phoneNumber&text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl);
    } else {
      throw 'Could not launch $whatsappUrl';
    }
  }
}
