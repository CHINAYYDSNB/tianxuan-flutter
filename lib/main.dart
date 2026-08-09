import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers/theme_store.dart';
import 'services/log_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LogService.instance.init();
  // Load persisted theme before runApp so there is no theme flash.
  runApp(const ProviderScopeProxy());
}

class ProviderScopeProxy extends StatelessWidget {
  const ProviderScopeProxy({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ThemeLoader();
  }
}

class _ThemeLoader extends ConsumerWidget {
  const _ThemeLoader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeStoreProvider);
    // Trigger async load once.
    Future.microtask(() => ref.read(themeStoreProvider.notifier).load());
    return const TianxuanApp();
  }
}
