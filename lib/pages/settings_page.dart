import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_store.dart';
import 'log_viewer_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeStoreProvider);
    final notifier = ref.read(themeStoreProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('外观',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('主题'),
                const SizedBox(height: 8),
                SegmentedButton<ThemeModePreference>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeModePreference.dark,
                      label: Text('深色'),
                      icon: Icon(Icons.dark_mode),
                    ),
                    ButtonSegment(
                      value: ThemeModePreference.light,
                      label: Text('浅色'),
                      icon: Icon(Icons.light_mode),
                    ),
                    ButtonSegment(
                      value: ThemeModePreference.system,
                      label: Text('跟随系统'),
                      icon: Icon(Icons.brightness_auto),
                    ),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (s) => notifier.setMode(s.first),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('诊断',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('查看日志'),
            subtitle: const Text('查看今日运行日志（./logs）'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LogViewerPage()),
              );
            },
          ),
        ),
      ],
    );
  }
}
