import 'dart:convert';

import 'package:uuid/uuid.dart';

enum PanelType {
  bt,
  onePanel,
}

class Panel {
  final String id;
  String name;
  String url;
  PanelType type;
  DateTime createdAt;
  DateTime updatedAt;

  Panel({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Panel.create({
    required String name,
    required String url,
    required PanelType type,
  }) {
    final now = DateTime.now().toUtc();
    return Panel(
      id: const Uuid().v4(),
      name: name,
      url: url,
      type: type,
      createdAt: now,
      updatedAt: now,
    );
  }

  Panel copyWith({
    String? name,
    String? url,
    PanelType? type,
  }) {
    return Panel(
      id: id,
      name: name ?? this.name,
      url: url ?? this.url,
      type: type ?? this.type,
      createdAt: createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'type': type.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Panel.fromJson(Map<String, dynamic> json) => Panel(
        id: json['id'] as String,
        name: json['name'] as String,
        url: json['url'] as String,
        type: PanelType.values.byName(json['type'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  static String encodeList(List<Panel> panels) =>
      jsonEncode(panels.map((p) => p.toJson()).toList());

  static List<Panel> decodeList(String raw) {
    final data = jsonDecode(raw) as List;
    return data.map((e) => Panel.fromJson(e as Map<String, dynamic>)).toList();
  }
}
