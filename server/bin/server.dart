import 'dart:io';
import 'package:shelf/shelf_io.dart' as io;
import 'package:teaching_hours_server/server.dart';

Future<void> main() async {
  final env = Platform.environment;
  String required(String key) {
    final value = env[key];
    if (value == null || value.isEmpty || value.startsWith('replace-with-')) {
      throw StateError('Set $key before starting the server');
    }
    return value;
  }

  final store = PocketBaseStore(
    env['POCKETBASE_URL'] ?? 'http://127.0.0.1:8090',
    required('PB_SERVICE_EMAIL'),
    required('PB_SERVICE_PASSWORD'),
  );
  await store.health();
  // Fail early when the database has not yet been migrated.
  await store.list('teaching_reports');
  final server = await io.serve(
    createHandler(
      store,
      staticDirectory: env['STATIC_DIR'],
      allowedOrigins: (env['ALLOWED_ORIGINS'] ?? '')
          .split(',')
          .where((s) => s.isNotEmpty)
          .toSet(),
    ),
    env['HOST'] ?? '127.0.0.1',
    int.parse(env['PORT'] ?? '8080'),
  );
  stdout.writeln(
    'Teaching hours API listening on ${server.address.address}:${server.port}',
  );
  Future<void> stop(ProcessSignal _) async {
    await server.close(force: false);
    store.close();
    exit(0);
  }

  ProcessSignal.sigterm.watch().listen(stop);
  ProcessSignal.sigint.watch().listen(stop);
}
