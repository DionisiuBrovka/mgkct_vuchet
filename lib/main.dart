import 'package:flutter/material.dart';

import 'app.dart';
import 'core/pocket_base_service.dart';
import 'injection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupLocator();
  await getIt<PocketBaseService>().init();
  runApp(const App());
}
