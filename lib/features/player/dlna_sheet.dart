import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/dlna/dlna_client.dart';
import '../../data/dlna/dlna_models.dart';
import '../../data/dlna/ssdp_discovery.dart';
import '../../l10n/l10n.dart';

/// 弹出投屏设备列表；成功投屏后返回选中的设备。
Future<DlnaDevice?> showDlnaSheet(
  BuildContext context, {
  required String url,
  required String title,
  Duration? position,
}) {
  return showModalBottomSheet<DlnaDevice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => _DlnaSheet(
      url: url,
      title: title,
      position: position,
    ),
  );
}

class _DlnaSheet extends ConsumerStatefulWidget {
  const _DlnaSheet({
    required this.url,
    required this.title,
    this.position,
  });

  final String url;
  final String title;
  final Duration? position;

  @override
  ConsumerState<_DlnaSheet> createState() => _DlnaSheetState();
}

class _DlnaSheetState extends ConsumerState<_DlnaSheet> {
  bool _searching = true;
  String? _error;
  String? _connecting;
  List<DlnaDevice> _devices = const <DlnaDevice>[];

  @override
  void initState() {
    super.initState();
    _discover();
  }

  Future<void> _discover() async {
    setState(() {
      _searching = true;
      _error = null;
      _devices = const <DlnaDevice>[];
    });
    try {
      final List<String> locations =
          await const SsdpDiscovery().findLocations(timeout: const Duration(seconds: 3));
      final List<DlnaDevice> devices = <DlnaDevice>[];
      final Set<String> seen = <String>{};

      // 并行拉设备描述：串行会让「10 台设备」变成 30 秒等待。
      final List<DlnaDevice?> fetched = await Future.wait(
        locations.map((String location) async {
          try {
            final String xml = (await ref
                    .read(httpClientProvider)
                    .getText(location)
                    .timeout(const Duration(seconds: 3)))
                .data ??
                '';
            return parseDeviceDescription(xml: xml, location: location);
          } on Object {
            // 单台设备描述拉取失败不影响其它设备。
            return null;
          }
        }),
      );
      for (final DlnaDevice? device in fetched) {
        if (device == null) continue;
        if (seen.add('${device.friendlyName}|${device.controlUrl}')) {
          devices.add(device);
        }
      }
      if (!mounted) return;
      setState(() {
        _searching = false;
        _devices = devices;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _connect(DlnaDevice device) async {
    final L10n l = L10n.of(context);
    setState(() {
      _connecting = device.friendlyName;
      _error = null;
    });
    try {
      await DlnaClient(device, ref.read(httpClientProvider)).cast(
        url: widget.url,
        title: widget.title,
        position: widget.position,
      );
      if (!mounted) return;
      Navigator.of(context).pop(device);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _connecting = null;
        _error = '${l.castUnsupported}: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final L10n l = L10n.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: 360,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                child: Row(
                  children: <Widget>[
                    Text(l.cast, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    IconButton(
                      tooltip: l.retry,
                      onPressed: _searching ? null : _discover,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
              if (_searching)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(height: 12),
                        Text(l.castSearching, style: TextStyle(color: scheme.outline)),
                      ],
                    ),
                  ),
                )
              else if (_devices.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.tv_off_outlined, size: 34, color: scheme.outline),
                        const SizedBox(height: 8),
                        Text(l.castNoDevice, style: TextStyle(color: scheme.outline)),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (BuildContext context, int index) {
                      final DlnaDevice device = _devices[index];
                      final bool busy = _connecting == device.friendlyName;
                      return ListTile(
                        leading: const Icon(Icons.tv),
                        title: Text(device.friendlyName),
                        subtitle: Text(
                          device.modelName ?? device.manufacturer ?? device.controlUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cast, size: 20),
                        onTap: _connecting == null ? () => _connect(device) : null,
                      );
                    },
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: SelectableText(
                    _error!,
                    style: TextStyle(fontSize: 11, color: scheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
