import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/metadata/tmdb_client.dart';
import '../../data/metadata/tmdb_key.dart';
import '../../data/metadata/tmdb_settings.dart';
import '../../l10n/l10n.dart';

/// TMDB 演职员数据设置。
class TmdbSettingsPage extends ConsumerStatefulWidget {
  const TmdbSettingsPage({super.key});

  @override
  ConsumerState<TmdbSettingsPage> createState() => _TmdbSettingsPageState();
}

class _TmdbSettingsPageState extends ConsumerState<TmdbSettingsPage> {
  final TextEditingController _key = TextEditingController();
  String _language = 'zh-CN';
  bool _busy = false;

  static const List<MapEntry<String, String>> _languages =
      <MapEntry<String, String>>[
        MapEntry<String, String>('zh-CN', '简体中文'),
        MapEntry<String, String>('zh-TW', '繁體中文'),
        MapEntry<String, String>('en-US', 'English'),
        MapEntry<String, String>('ko-KR', '한국어'),
      ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final TmdbSettings settings = await TmdbSettings.load();
    if (!mounted) return;
    setState(() {
      _key.text = settings.apiKey;
      _language = settings.language;
    });
  }

  TmdbSettings get _form =>
      TmdbSettings(apiKey: _key.text, language: _language);

  Future<void> _save() async {
    await TmdbSettings.save(_form);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(L10n.of(context).ruleSaved)));
  }

  Future<void> _test() async {
    final L10n l = L10n.of(context);
    final String key = _form.apiKey.trim().isEmpty
        ? kTmdbApiKey.trim()
        : _form.apiKey.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.tmdbKeyMissing)));
      return;
    }
    setState(() => _busy = true);
    try {
      await TmdbClient(
        apiKey: key,
        language: _form.language,
        http: ref.read(httpClientProvider),
      ).testConnection();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.tmdbTestOk)));
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${l.tmdbTestFailed}: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final L10n l = L10n.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.metadataTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l.save,
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: <Widget>[
                  TextField(
                    controller: _key,
                    obscureText: true,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: l.tmdbApiKey,
                      hintText: l.tmdbKeyHint,
                    ),
                  ),
                  if (kTmdbApiKey.trim().isNotEmpty && _key.text.trim().isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          l.tmdbBuiltInKey,
                          style: TextStyle(fontSize: 12, color: scheme.outline),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _language,
                    decoration: InputDecoration(labelText: l.tmdbLanguage),
                    items: <DropdownMenuItem<String>>[
                      for (final MapEntry<String, String> entry in _languages)
                        DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                    ],
                    onChanged: (String? value) {
                      if (value != null) setState(() => _language = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _busy ? null : _test,
                      icon: _busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_tethering, size: 18),
                      label: Text(l.syncTest),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              l.tmdbNote,
              style: TextStyle(
                fontSize: 12,
                color: scheme.outline,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
