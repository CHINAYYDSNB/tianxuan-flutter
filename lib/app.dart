import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pages/dashboard_page.dart';
import 'pages/panel_list_page.dart';
import 'pages/batch_page.dart';
import 'pages/settings_page.dart';
import 'providers/theme_store.dart';

ThemeData _baseTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF6366F1),
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: isDark
        ? const Color(0xFF0F1115)
        : const Color(0xFFF5F6F8),
    useMaterial3: true,
    cardTheme: CardThemeData(
      color: isDark ? const Color(0xFF16191F) : const Color(0xFFFFFFFF),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
            color: isDark ? const Color(0xFF1E222A) : const Color(0xFFE0E3E8)),
      ),
    ),
  );
}

class TianxuanApp extends ConsumerWidget {
  const TianxuanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeStoreProvider);
    return MaterialApp(
      title: 'Tianxuan',
      debugShowCheckedModeBanner: false,
      theme: _baseTheme(Brightness.light),
      darkTheme: _baseTheme(Brightness.dark),
      themeMode: themeModeFromPreference(mode),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = <Widget>[
    DashboardPage(),
    PanelListPage(),
    BatchPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? const Color(0xFF0D0F13) : const Color(0xFFFFFFFF);
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            backgroundColor: navBg,
            indicatorColor: const Color(0x336366F1),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('总览'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.language),
                label: Text('面板'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.bolt),
                label: Text('批量'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                label: Text('设置'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _pages[_index]),
        ],
      ),
    );
  }
}
