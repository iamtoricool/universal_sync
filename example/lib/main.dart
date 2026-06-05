import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth/auth_provider.dart';
import 'auth/signin_page.dart';
import 'connectivity/connectivity_provider.dart';
import 'todos/home_page.dart';
import 'todos/providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: TodoApp()));

  // Test
}

class TodoApp extends ConsumerStatefulWidget {
  const TodoApp({super.key});
  @override
  ConsumerState<TodoApp> createState() => _TodoAppState();
}

class _TodoAppState extends ConsumerState<TodoApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authNotifierProvider.notifier).checkAuth();
    });
  }

  Future<void> _triggerSync() async {
    try {
      await ref.read(todoListProvider.notifier).triggerSync();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(connectivityProvider, (prev, next) {
      if (next.valueOrNull == true && prev?.valueOrNull == false) {
        _triggerSync();
      }
    });

    final authState = ref.watch(authNotifierProvider);

    return MaterialApp(
      title: 'universal_sync Todo',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: switch (authState.status) {
        AuthStatus.unknown => const _Splash(),
        AuthStatus.authenticated => const HomePage(),
        AuthStatus.unauthenticated => const SigninPage(),
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
