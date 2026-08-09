import 'dart:convert';

import 'package:uuid/uuid.dart';

enum AuthType {
  password,
  key,
}

class Host {
  final String id;
  String name;
  String address;
  int port;
  String username;
  AuthType authType;
  String? authRef;
  String group;
  List<String> tags;
  DateTime createdAt;
  DateTime updatedAt;

  Host({
    required this.id,
    required this.name,
    required this.address,
    required this.port,
    required this.username,
    required this.authType,
    this.authRef,
    required this.group,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Host.create({
    required String name,
    required String address,
    required int port,
    required String username,
    required AuthType authType,
    String? authRef,
    required String group,
    required List<String> tags,
  }) {
    final now = DateTime.now().toUtc();
    return Host(
      id: const Uuid().v4(),
      name: name,
      address: address,
      port: port,
      username: username,
      authType: authType,
      authRef: authRef,
      group: group,
      tags: tags,
      createdAt: now,
      updatedAt: now,
    );
  }

  Host copyWith({
    String? name,
    String? address,
    int? port,
    String? username,
    AuthType? authType,
    String? authRef,
    String? group,
    List<String>? tags,
  }) {
    return Host(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      port: port ?? this.port,
      username: username ?? this.username,
      authType: authType ?? this.authType,
      authRef: authRef ?? this.authRef,
      group: group ?? this.group,
      tags: tags ?? this.tags,
      createdAt: createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'port': port,
        'username': username,
        'authType': authType.name,
        'authRef': authRef,
        'group': group,
        'tags': tags,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Host.fromJson(Map<String, dynamic> json) => Host(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String,
        port: json['port'] as int,
        username: json['username'] as String,
        authType: AuthType.values.byName(json['authType'] as String),
        authRef: json['authRef'] as String?,
        group: (json['group'] as String?) ?? '默认',
        tags: ((json['tags'] as List?) ?? []).cast<String>(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  static String encodeList(List<Host> hosts) =>
      jsonEncode(hosts.map((h) => h.toJson()).toList());

  static List<Host> decodeList(String raw) {
    final data = jsonDecode(raw) as List;
    return data.map((e) => Host.fromJson(e as Map<String, dynamic>)).toList();
  }
}
