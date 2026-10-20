import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/l10n.dart';

/// 主题设置。
class ThemeSettingsPage extends ConsumerWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l = L10n.of(context);
    final ThemeMode mode = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.theme)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: RadioGroup<ThemeMode>(
              groupValue: mode,
              onChanged: (ThemeMode? value) {
                if (value != null) ref.read(themeModeProvider.notifier).set(value);
              },
              child: Column(
                children: <Widget>[
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.system,
                    title: Text(l.themeSystem),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.light,
                    title: Text(l.themeLight),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.dark,
                    title: Text(l.themeDark),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
