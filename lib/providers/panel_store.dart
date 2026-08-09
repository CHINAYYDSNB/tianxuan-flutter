import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/panel.dart';
import '../services/storage_service.dart';

class PanelStore extends Notifier<List<Panel>> {
  @override
  List<Panel> build() {
    return [];
  }

  Future<void> refresh() async {
    state = await StorageService.instance.loadPanels();
  }

  Future<void> addPanel(Panel panel) async {
    final panels = [...state];
    panels.insert(0, panel);
    state = panels;
    await StorageService.instance.savePanels(panels);
  }

  Future<void> updatePanel(Panel panel) async {
    final panels = state.map((p) => p.id == panel.id ? panel : p).toList();
    state = panels;
    await StorageService.instance.savePanels(panels);
  }

  Future<void> deletePanel(String id) async {
    state = state.where((p) => p.id != id).toList();
    await StorageService.instance.savePanels(state);
  }
}

final panelStoreProvider =
    NotifierProvider<PanelStore, List<Panel>>(PanelStore.new);
