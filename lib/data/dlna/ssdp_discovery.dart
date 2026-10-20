import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'dlna_models.dart';

/// SSDP 设备发现。
///
/// 只负责收集 `LOCATION`，设备描述与 SOAP 控制交给上层。
class SsdpDiscovery {
  const SsdpDiscovery();

  static final InternetAddress _multicast = InternetAddress('239.255.255.250');

  Future<List<String>> findLocations({
    Duration timeout = const Duration(seconds: 3),
    String searchTarget = mediaRenderer,
  }) async {
    RawDatagramSocket? socket;
    StreamSubscription<RawSocketEvent>? subscription;

    final Map<String, String> locations = <String, String>{};
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      subscription = socket.listen((RawSocketEvent event) {
        if (event != RawSocketEvent.read) return;
        final Datagram? datagram = socket?.receive();
        if (datagram == null) return;
        final String text = utf8.decode(datagram.data, allowMalformed: true);
        final String? location = SsdpResponse.parse(text).location;
        if (location == null || location.isEmpty) return;
        locations[location] = location;
      });

      final List<int> payload = utf8.encode(buildMSearchRequest(searchTarget: searchTarget));
      // UDP 会丢包，发两次。
      socket.send(payload, _multicast, 1900);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      socket.send(payload, _multicast, 1900);
      await Future<void>.delayed(timeout);
      return locations.values.toList();
    } on SocketException {
      return const <String>[];
    } finally {
      await subscription?.cancel();
      socket?.close();
    }
  }
}
