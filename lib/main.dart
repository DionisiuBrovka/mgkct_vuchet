import 'package:flutter/material.dart';

import 'app.dart';
import 'core/sheets_service.dart';
import 'injection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupLocator();
  await getIt<SheetsService>().init();
  runApp(const App());
}
