import 'package:get_it/get_it.dart';

import 'core/constants.dart';
import 'core/api_service.dart';
import 'core/report_repository.dart';
import 'features/auth/repository/auth_repository.dart';

final getIt = GetIt.instance;

void setupLocator() {
  getIt.registerSingleton<ApiService>(
    ApiService(AppConstants.apiUrl),
  );
  getIt.registerSingleton<AuthRepository>(
    AuthRepository(getIt<ApiService>()),
  );
  getIt.registerSingleton<ReportRepository>(
      ReportRepository(getIt<ApiService>()));
}
