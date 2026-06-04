import 'package:get_it/get_it.dart';

import 'core/sheets_service.dart';
import 'features/auth/repository/auth_repository.dart';
import 'features/teacher/repository/vychitka_repository.dart';

final getIt = GetIt.instance;

void setupLocator() {
  getIt.registerSingleton<SheetsService>(SheetsService());
  getIt.registerSingleton<AuthRepository>(
    AuthRepository(getIt<SheetsService>()),
  );
  getIt.registerSingleton<VychitkaRepository>(
    VychitkaRepository(getIt<SheetsService>()),
  );
}
