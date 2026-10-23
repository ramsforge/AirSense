import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/packet.dart';

class DiscoveredHost {
  final String ip;
  final int port;
  final String name;

  DiscoveredHost({required this.ip, required this.port, required this.name});
}

class DiscoveryService {
  static Future<List<DiscoveredHost>> findHosts({
    int port = 9050,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final List<DiscoveredHost> hosts = [];
    RawDatagramSocket? socket;

    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final ping = Uint8List(5);
      ping[0] = 0x41; // A
      ping[1] = 0x49; // I
      ping[2] = 0x52; // R
      ping[3] = 0x53; // S
      ping[4] = PacketType.discoveryPing.value;

      final completer = Completer<List<DiscoveredHost>>();

      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket?.receive();
          if (datagram == null) return;

          final data = datagram.data;
          if (data.length >= 6 &&
              data[0] == 0x41 &&
              data[1] == 0x49 &&
              data[2] == 0x52 &&
              data[3] == 0x53 &&
              data[4] == PacketType.discoveryPong.value) {
            final nameLen = data[5];
            String name = "AirSense PC";
            if (data.length >= 6 + nameLen) {
              name = utf8.decode(data.sublist(6, 6 + nameLen));
            }

            final host = DiscoveredHost(
              ip: datagram.address.address,
              port: port,
              name: name,
            );

            if (!hosts.any((h) => h.ip == host.ip)) {
              hosts.add(host);
            }
          }
        }
      });

      // Send broadcast
      socket.send(ping, InternetAddress('255.255.255.255'), port);

      Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.complete(hosts);
        }
      });

      return await completer.future;
    } catch (e) {
      debugPrint('[AirSense Discovery] Error: $e');
      return hosts;
    } finally {
      socket?.close();
    }
  }
}
