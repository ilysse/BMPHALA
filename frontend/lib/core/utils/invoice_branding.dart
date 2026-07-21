import 'dart:convert';

import 'package:flutter/services.dart';

Future<String> loadDefaultInvoiceLogoDataUri() async {
  final data = await rootBundle.load('assets/branding/app_logo.jpg');
  return 'data:image/jpeg;base64,${base64Encode(data.buffer.asUint8List())}';
}
