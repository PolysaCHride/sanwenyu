import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

/// 关于。
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final L10n l = L10n.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.about)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l.version, style: TextStyle(fontSize: 12, color: scheme.outline)),
                  const SizedBox(height: 4),
                  const Text('0.2.0'),
                  const SizedBox(height: 16),
                  Text(l.noticeTitle, style: TextStyle(fontSize: 12, color: scheme.outline)),
                  const SizedBox(height: 4),
                  Text(l.noticeText, style: const TextStyle(fontSize: 13, height: 1.6)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
