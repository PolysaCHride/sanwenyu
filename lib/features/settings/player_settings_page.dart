import 'package:flutter/material.dart';

import '../../core/player/m3u8_playlist.dart';
import '../../core/player/player_config.dart';
import '../../core/player/render_policy.dart';
import '../../l10n/l10n.dart';

/// 播放器设置。
class PlayerSettingsPage extends StatefulWidget {
  const PlayerSettingsPage({super.key});

  @override
  State<PlayerSettingsPage> createState() => _PlayerSettingsPageState();
}

class _PlayerSettingsPageState extends State<PlayerSettingsPage> {
  late PlayerConfig _config = PlayerPreferences.current;

  Future<void> _apply(PlayerConfig next) async {
    setState(() => _config = next);
    await PlayerPreferences.update(next);
  }

  @override
  Widget build(BuildContext context) {
    final L10n l = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.playerSettings),
        actions: <Widget>[
          IconButton(
            tooltip: l.resetDefaults,
            onPressed: () => _apply(const PlayerConfig()),
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          _sectionTitle(context, l.renderPolicy),
          Card(
            child: RadioGroup<RenderPolicy>(
              groupValue: _config.renderPolicy,
              onChanged: (RenderPolicy? value) {
                if (value != null) _apply(_config.copyWith(renderPolicy: value));
              },
              child: Column(
                children: <Widget>[
                  RadioListTile<RenderPolicy>(
                    value: RenderPolicy.auto,
                    title: Text(l.renderPolicyAuto),
                    subtitle: Text(l.renderPolicyAutoHint),
                  ),
                  const Divider(height: 1),
                  RadioListTile<RenderPolicy>(
                    value: RenderPolicy.hardware,
                    title: Text(l.renderPolicyHardware),
                    subtitle: Text(l.renderPolicyHardwareHint),
                  ),
                  const Divider(height: 1),
                  RadioListTile<RenderPolicy>(
                    value: RenderPolicy.software,
                    title: Text(l.renderPolicySoftware),
                    subtitle: Text(l.renderPolicySoftwareHint),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle(context, l.qualityLabel),
          Card(
            child: RadioGroup<QualityPreference>(
              groupValue: _config.preferredQuality,
              onChanged: (QualityPreference? value) {
                if (value != null) _apply(_config.copyWith(preferredQuality: value));
              },
              child: Column(
                children: <Widget>[
                  for (final QualityPreference option in QualityPreference.values)
                    RadioListTile<QualityPreference>(
                      value: option,
                      title: Text(_qualityLabel(l, option)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle(context, l.playerSettings),
          Card(
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  value: _config.lowMemory,
                  onChanged: (bool value) => _apply(_config.copyWith(lowMemory: value)),
                  title: Text(l.lowMemory),
                  subtitle: Text(l.lowMemoryHint),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _config.autoPlayNext,
                  onChanged: (bool value) => _apply(_config.copyWith(autoPlayNext: value)),
                  title: Text(l.autoPlayNext),
                  subtitle: Text(l.autoPlayNextHint),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _config.gesturesEnabled,
                  onChanged: (bool value) => _apply(_config.copyWith(gesturesEnabled: value)),
                  title: Text(l.gestures),
                  subtitle: Text(l.gesturesHint),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _config.keyboardShortcuts,
                  onChanged: (bool value) =>
                      _apply(_config.copyWith(keyboardShortcuts: value)),
                  title: Text(l.keyboardShortcuts),
                  subtitle: Text(l.keyboardShortcutsHint),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _config.showDebugOverlay,
                  onChanged: (bool value) =>
                      _apply(_config.copyWith(showDebugOverlay: value)),
                  title: Text(l.debugOverlay),
                  subtitle: Text(l.debugOverlayHint),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              l.playerSettingsFootnote,
              style: TextStyle(fontSize: 12, color: scheme.outline, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _qualityLabel(L10n l, QualityPreference option) {
    return switch (option) {
      QualityPreference.auto => l.qualityAuto,
      QualityPreference.p1080 => '1080p',
      QualityPreference.p720 => '720p',
      QualityPreference.p480 => '480p',
    };
  }
}
