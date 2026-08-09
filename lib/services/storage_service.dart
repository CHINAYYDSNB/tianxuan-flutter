import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/host.dart';
import '../models/panel.dart';

class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  static const _storage = FlutterSecureStorage();

  static const _hostsKey = 'hosts';
  static const _panelsKey = 'panels';

  // ---- hosts ----
  Future<List<Host>> loadHosts() async {
    final raw = await _storage.read(key: _hostsKey);
    if (raw == null || raw.isEmpty) return [];
    return Host.decodeList(raw);
  }

  Future<void> saveHosts(List<Host> hosts) async {
    await _storage.write(key: _hostsKey, value: Host.encodeList(hosts));
  }

  Future<void> saveHostPassword(String hostId, String password) async {
    await _storage.write(key: 'host_password_$hostId', value: password);
  }

  Future<String?> loadHostPassword(String hostId) async {
    return _storage.read(key: 'host_password_$hostId');
  }

  Future<void> deleteHostPassword(String hostId) async {
    await _storage.delete(key: 'host_password_$hostId');
  }

  // ---- panels ----
  Future<List<Panel>> loadPanels() async {
    final raw = await _storage.read(key: _panelsKey);
    if (raw == null || raw.isEmpty) return [];
    return Panel.decodeList(raw);
  }

  Future<void> savePanels(List<Panel> panels) async {
    await _storage.write(key: _panelsKey, value: Panel.encodeList(panels));
  }
}
