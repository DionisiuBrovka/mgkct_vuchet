import 'package:get_it/get_it.dart';

import 'core/constants.dart';
import 'core/pocket_base_service.dart';
import 'features/auth/repository/auth_repository.dart';
import 'features/teacher/repository/vychitka_repository.dart';

final getIt = GetIt.instance;

void setupLocator() {
  getIt.registerSingleton<PocketBaseService>(
    PocketBaseService(AppConstants.pocketBaseUrl),
  );
  getIt.registerSingleton<AuthRepository>(
    AuthRepository(getIt<PocketBaseService>()),
  );
  getIt.registerSingleton<VychitkaRepository>(
    VychitkaRepository(getIt<PocketBaseService>()),
  );
}
