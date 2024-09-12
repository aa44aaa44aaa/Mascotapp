// Validaciones para formularios
class ValidationService {
  // Validar que el nombre completo contenga al menos dos palabras
  static bool validarNombreCompleto(String nombre) {
    List<String> palabras = nombre.trim().split(' ');
    return palabras.length >= 2;
  }

  // Validar formato de RUT
  static String formatRut(String text) {
    text = text.replaceAll('.', '').replaceAll('-', '');
    if (text.length > 1) {
      String rutBody = text.substring(0, text.length - 1);
      String dv = text.substring(text.length - 1);
      rutBody = rutBody.replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]}.');
      return '$rutBody-$dv';
    }
    return text;
  }

  // Validar RUT chileno
  static bool validarRut(String rut) {
    rut = rut.toUpperCase().replaceAll('.', '').replaceAll('-', '');
    if (rut.length < 9) return false;

    String aux = rut.substring(0, rut.length - 1);
    String dv = rut.substring(rut.length - 1);

    List<int> reversedRut = aux.split('').reversed.map(int.parse).toList();
    List<int> factors = [2, 3, 4, 5, 6, 7];

    int sum = 0;
    for (int i = 0; i < reversedRut.length; i++) {
      sum += reversedRut[i] * factors[i % factors.length];
    }

    int res = 11 - (sum % 11);

    if (res == 11) return dv == '0';
    if (res == 10) return dv == 'K';
    return res.toString() == dv;
  }

  // Validar número de teléfono chileno
  static bool validarNumeroChileno(String numero) {
    final regex = RegExp(r'^\+569\d{8}$'); // Formato "+569XXXXXXXX"
    return regex.hasMatch(numero);
  }

  // Validar formato de email
  static bool validarEmail(String email) {
    final regex = RegExp(
      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
    );
    return regex.hasMatch(email);
  }
}
