import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/locale.dart';
import '../../app/providers.dart';
import '../../l10n/l10n.dart';

/// 语言设置。
class LanguageSettingsPage extends ConsumerWidget {
  const LanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l = L10n.of(context);
    final AppLocaleMode mode = ref.watch(localeModeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.language)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: RadioGroup<AppLocaleMode>(
              groupValue: mode,
              onChanged: (AppLocaleMode? value) {
                if (value != null) {
                  ref.read(localeModeProvider.notifier).set(value);
                }
              },
              child: Column(
                children: <Widget>[
                  RadioListTile<AppLocaleMode>(
                    value: AppLocaleMode.system,
                    title: Text(l.languageSystem),
                  ),
                  const Divider(height: 1),
                  RadioListTile<AppLocaleMode>(
                    value: AppLocaleMode.zh,
                    title: Text(l.languageZh),
                  ),
                  const Divider(height: 1),
                  RadioListTile<AppLocaleMode>(
                    value: AppLocaleMode.en,
                    title: Text(l.languageEn),
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
