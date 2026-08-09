import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/host.dart';
import '../services/storage_service.dart';

class HostStore extends Notifier<List<Host>> {
  @override
  List<Host> build() {
    // initial empty; refresh() loads from storage asynchronously
    return [];
  }

  Future<void> refresh() async {
    state = await StorageService.instance.loadHosts();
  }

  Future<void> addHost(Host host, {String? password}) async {
    final hosts = [...state];
    hosts.insert(0, host);
    state = hosts;
    await StorageService.instance.saveHosts(hosts);
    if (password != null) {
      await StorageService.instance.saveHostPassword(host.id, password);
    }
  }

  Future<void> updateHost(Host host, {String? password}) async {
    final hosts = state.map((h) => h.id == host.id ? host : h).toList();
    state = hosts;
    await StorageService.instance.saveHosts(hosts);
    if (password != null && password.isNotEmpty) {
      await StorageService.instance.saveHostPassword(host.id, password);
    }
  }

  Future<void> deleteHost(String id) async {
    state = state.where((h) => h.id != id).toList();
    await StorageService.instance.saveHosts(state);
    await StorageService.instance.deleteHostPassword(id);
  }

  Future<String?> passwordFor(String hostId) async {
    return StorageService.instance.loadHostPassword(hostId);
  }
}

final hostStoreProvider =
    NotifierProvider<HostStore, List<Host>>(HostStore.new);

final hostPasswordProvider =
    FutureProvider.family<String?, String>((ref, hostId) async {
  return StorageService.instance.loadHostPassword(hostId);
});
