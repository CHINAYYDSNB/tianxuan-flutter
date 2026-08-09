import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers/theme_store.dart';
import 'services/log_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LogService.instance.init();
  runApp(const ProviderScope(child: ThemeLoader()));
}

class ThemeLoader extends ConsumerWidget {
  const ThemeLoader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeStoreProvider);
    // Trigger async load once.
    Future.microtask(() => ref.read(themeStoreProvider.notifier).load());
    return const TianxuanApp();
  }
}
