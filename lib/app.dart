import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'features/admin/cubit/admin_cubit.dart';
import 'features/admin/screens/admin_home_screen.dart';
import 'features/admin/screens/review_screen.dart';
import 'features/auth/cubit/auth_cubit.dart';
import 'features/auth/cubit/auth_state.dart';
import 'features/auth/models/app_user.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/teacher/cubit/vychitka_cubit.dart';
import 'features/teacher/screens/fill_vychitka_screen.dart';
import 'features/teacher/screens/teacher_home_screen.dart';
import 'injection.dart';
import 'shared/theme/app_theme.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final AuthCubit _authCubit;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authCubit = AuthCubit(getIt());

    _router = GoRouter(
      initialLocation: '/login',
      redirect: (context, state) {
        final authState = _authCubit.state;
        final isLoginRoute = state.matchedLocation == '/login';

        if (authState is! AuthAuthenticated) {
          return isLoginRoute ? null : '/login';
        }
        if (isLoginRoute) {
          return authState.user.role == UserRole.admin
              ? '/admin'
              : '/teacher';
        }
        return null;
      },
      refreshListenable: _RouterNotifier(_authCubit),
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, __) => const LoginScreen(),
        ),
        GoRoute(
          path: '/teacher',
          builder: (_, __) => const TeacherHomeScreen(),
          routes: [
            GoRoute(
              path: 'fill/:month/:year',
              builder: (_, state) => BlocProvider(
                create: (_) => VychitkaCubit(getIt()),
                child: FillVychitkaScreen(
                  month: state.pathParameters['month']!,
                  year: int.parse(state.pathParameters['year']!),
                ),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/admin',
          builder: (_, __) => BlocProvider(
            create: (_) => AdminCubit(getIt()),
            child: const AdminHomeScreen(),
          ),
          routes: [
            GoRoute(
              path: 'review/:teacher/:month/:year',
              builder: (_, state) => BlocProvider(
                create: (_) => AdminCubit(getIt()),
                child: ReviewScreen(
                  teacher: state.pathParameters['teacher']!,
                  month: state.pathParameters['month']!,
                  year: int.parse(state.pathParameters['year']!),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _authCubit,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'Вычитка',
        theme: AppTheme.light,
        routerConfig: _router,
      ),
    );
  }
}

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._cubit) {
    _cubit.stream.listen((_) => notifyListeners());
  }
  final AuthCubit _cubit;
}
