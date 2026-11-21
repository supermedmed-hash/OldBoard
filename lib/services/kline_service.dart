import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Pont vers le code natif Android (cable KKL USB, protocole KWP1281, lecture seule).
class KLineService {
  static const _m = MethodChannel('oldboard/kline');
  static const _e = EventChannel('oldboard/kline/events');

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Stream<Map<dynamic, dynamic>>? _events;
  Stream<Map<dynamic, dynamic>> get events {
    if (!supported) return const Stream.empty();
    return _events ??= _e.receiveBroadcastStream().map((e) => e as Map<dynamic, dynamic>);
  }

  Future<List<Map<dynamic, dynamic>>> listDevices() async {
    if (!supported) return [];
    final r = await _m.invokeMethod<List<dynamic>>('listDevices');
    return (r ?? []).cast<Map<dynamic, dynamic>>();
  }

  Future<bool> connect(int address, List<int> groups) async {
    if (!supported) return false;
    return await _m.invokeMethod<bool>('connect', {'address': address, 'groups': groups}) ?? false;
  }

  Future<void> setGroups(List<int> groups) async {
    if (!supported) return;
    await _m.invokeMethod('setGroups', {'groups': groups});
  }

  Future<void> switchAddress(int address, List<int> groups) async {
    if (!supported) return;
    await _m.invokeMethod('switchAddress', {'address': address, 'groups': groups});
  }

  Future<void> readFaults() async {
    if (!supported) return;
    await _m.invokeMethod('readFaults');
  }

  Future<void> clearFaults() async {
    if (!supported) return;
    await _m.invokeMethod('clearFaults');
  }

  Future<void> throttleAlign({int group = 98}) async {
    if (!supported) return;
    await _m.invokeMethod('throttleAlign', {'group': group});
  }

  Future<void> resetAdaptations() async {
    if (!supported) return;
    await _m.invokeMethod('resetAdaptations');
  }

  Future<void> disconnect() async {
    if (!supported) return;
    await _m.invokeMethod('disconnect');
  }
}
