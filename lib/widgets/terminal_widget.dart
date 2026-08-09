import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import '../services/ssh_service.dart';

const TerminalTheme _darkTheme = TerminalTheme(
  cursor: Color(0xFF58A6FF),
  selection: Color(0x3358A6FF),
  foreground: Color(0xFFE6EDF3),
  background: Color(0xFF0D1117),
  black: Color(0xFF484F58),
  white: Color(0xFFE6EDF3),
  red: Color(0xFFFF7B72),
  green: Color(0xFF3FB950),
  yellow: Color(0xFFD29922),
  blue: Color(0xFF58A6FF),
  magenta: Color(0xFFBC8CFF),
  cyan: Color(0xFF39C5CF),
  brightBlack: Color(0xFF6E7681),
  brightRed: Color(0xFFFFA198),
  brightGreen: Color(0xFF56D364),
  brightYellow: Color(0xFFE3B341),
  brightBlue: Color(0xFF79C0FF),
  brightMagenta: Color(0xFFD2A8FF),
  brightCyan: Color(0xFF56D4DD),
  brightWhite: Color(0xFFFFF7ED),
  searchHitBackground: Color(0xFFFFD33D),
  searchHitBackgroundCurrent: Color(0xFFFF7B72),
  searchHitForeground: Color(0xFF0D1117),
);

class TerminalWidget extends StatefulWidget {
  final SshService ssh;

  const TerminalWidget({super.key, required this.ssh});

  @override
  State<TerminalWidget> createState() => _TerminalWidgetState();
}

class _TerminalWidgetState extends State<TerminalWidget> {
  late final Terminal _terminal;
  String? _error;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(
      maxLines: 10000,
      onOutput: (data) {
        widget.ssh.write(data);
      },
      onResize: (w, h, pw, ph) {
        widget.ssh.resize(w, h);
      },
    );
    widget.ssh.onOutput = (bytes) {
      _terminal.write(String.fromCharCodes(bytes));
    };
    widget.ssh.onStateChange = (connected) {
      if (mounted && connected) {
        _terminal.write('\x1b[32m[已连接]\x1b[0m\r\n');
      }
    };
    widget.ssh.onError = (e) {
      if (mounted) setState(() => _error = e);
    };
  }

  @override
  void dispose() {
    widget.ssh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_error != null)
          Container(
            width: double.infinity,
            color: Colors.red.shade900.withValues(alpha: 0.3),
            padding: const EdgeInsets.all(6),
            child: Text(_error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ),
        Expanded(
          child: TerminalView(
            _terminal,
            theme: _darkTheme,
            backgroundOpacity: 1,
          ),
        ),
      ],
    );
  }
}
