import 'package:flutter_test/flutter_test.dart';
import 'package:tianxuan_flutter/models/host.dart';
import 'package:tianxuan_flutter/models/panel.dart';

void main() {
  test('Host create + toJson/fromJson roundtrip', () {
    final h = Host.create(
      name: 'Prod',
      address: '47.100.33.169',
      port: 22,
      username: 'root',
      authType: AuthType.password,
      group: '生产',
      tags: const ['bt', 'prod'],
    );
    final back = Host.fromJson(h.toJson());
    expect(back.id, h.id);
    expect(back.name, 'Prod');
    expect(back.address, '47.100.33.169');
    expect(back.port, 22);
    expect(back.username, 'root');
    expect(back.authType, AuthType.password);
    expect(back.group, '生产');
    expect(back.tags, ['bt', 'prod']);
  });

  test('Host copyWith updates fields', () {
    final h = Host.create(
      name: 'A',
      address: '1.2.3.4',
      port: 22,
      username: 'root',
      authType: AuthType.password,
      group: 'g',
      tags: const [],
    );
    final updated = h.copyWith(name: 'B', port: 2222);
    expect(updated.id, h.id);
    expect(updated.name, 'B');
    expect(updated.port, 2222);
    expect(updated.createdAt, h.createdAt);
    expect(updated.updatedAt.isBefore(h.updatedAt), isFalse);
  });

  test('Host encode/decode list', () {
    final hosts = [
      Host.create(
        name: 'A',
        address: '1.1.1.1',
        port: 22,
        username: 'root',
        authType: AuthType.password,
        group: 'g',
        tags: const [],
      ),
      Host.create(
        name: 'B',
        address: '2.2.2.2',
        port: 22,
        username: 'admin',
        authType: AuthType.key,
        group: 'h',
        tags: const ['x'],
      ),
    ];
    final decoded = Host.decodeList(Host.encodeList(hosts));
    expect(decoded.length, 2);
    expect(decoded[1].authType, AuthType.key);
  });

  test('Panel create + update roundtrip', () {
    final p = Panel.create(name: 'BT', url: 'https://bt:8888', type: PanelType.bt);
    final decoded = Panel.fromJson(p.toJson());
    expect(decoded.name, 'BT');
    expect(decoded.type, PanelType.bt);

    final updated = p.copyWith(name: '1Panel', type: PanelType.onePanel);
    expect(updated.id, p.id);
    expect(updated.name, '1Panel');
    expect(updated.type, PanelType.onePanel);
  });

  test('Panel encode/decode list', () {
    final panels = [
      Panel.create(name: 'A', url: 'u1', type: PanelType.bt),
      Panel.create(name: 'B', url: 'u2', type: PanelType.onePanel),
    ];
    final decoded = Panel.decodeList(Panel.encodeList(panels));
    expect(decoded.length, 2);
    expect(decoded[1].type, PanelType.onePanel);
  });
}
