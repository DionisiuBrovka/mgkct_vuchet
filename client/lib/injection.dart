import 'package:get_it/get_it.dart';

import 'core/constants.dart';
import 'core/api_service.dart';
import 'features/auth/repository/auth_repository.dart';
import 'features/teacher/repository/teaching_report_repository.dart';

final getIt = GetIt.instance;

void setupLocator() {
  getIt.registerSingleton<ApiService>(
    ApiService(AppConstants.apiUrl),
  );
  getIt.registerSingleton<AuthRepository>(
    AuthRepository(getIt<ApiService>()),
  );
  getIt.registerSingleton<TeachingReportRepository>(
    TeachingReportRepository(getIt<ApiService>()),
  );
}
