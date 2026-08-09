import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import '../services/log_service.dart';
import '../services/recording_service.dart';
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
  final RecordingService? recorder;

  const TerminalWidget({super.key, required this.ssh, this.recorder});

  @override
  State<TerminalWidget> createState() => _TerminalWidgetState();
}

class _TerminalWidgetState extends State<TerminalWidget> {
  late final Terminal _terminal;
  final TextEditingController _imeCtrl = TextEditingController();
  final FocusNode _imeFocus = FocusNode();
  String _pendingIme = '';
  bool _wasComposing = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    // Terminal output only (render server->client stream). Input is handled
    // by the transparent TextField below, NOT by xterm's keyboard handler,
    // to support both hardware keys and Chinese IME reliably on Windows.
    _terminal = Terminal(
      maxLines: 10000,
      onResize: (w, h, pw, ph) {
        widget.ssh.resize(w, h);
      },
    );
    widget.ssh.onOutput = (bytes) {
      widget.recorder?.record(bytes);
      // Decode bytes as UTF-8 so CJK output renders correctly.
      _terminal.write(utf8.decode(bytes, allowMalformed: true));
    };
    widget.ssh.onStateChange = (connected) {
      if (mounted && connected) {
        _terminal.write('\x1b[32m[已连接]\x1b[0m\r\n');
      }
    };
    widget.ssh.onError = (e) {
      if (mounted) setState(() => _error = e);
    };

    // Watch TextField value: send committed text (non-composing) to terminal,
    // then reset. During IME composition (composing active) we do nothing so
    // the input method is not interrupted.
    _imeCtrl.addListener(_onImeChanged);
  }

  @override
  void dispose() {
    _imeCtrl.removeListener(_onImeChanged);
    _imeCtrl.dispose();
    _imeFocus.dispose();
    widget.ssh.dispose();
    super.dispose();
  }

  /// Hardware keyboard (non-IME) key events.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final logical = event.logicalKey;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final alt = HardwareKeyboard.instance.isAltPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;

    // Ctrl+C / Ctrl+D / Ctrl+Z style control keys
    if (ctrl && logical.keyLabel.length == 1) {
      final letter = logical.keyLabel.toLowerCase();
      if (letter == 'c') {
        widget.ssh.write('\x03');
        return KeyEventResult.handled;
      }
      if (letter == 'd') {
        widget.ssh.write('\x04');
        return KeyEventResult.handled;
      }
      if (letter == 'z') {
        widget.ssh.write('\x1a');
        return KeyEventResult.handled;
      }
      if (letter == 'l') {
        widget.ssh.write('\x0c');
        return KeyEventResult.handled;
      }
    }

    // Map a LogicalKeyboardKey to a terminal key sequence.
    String? seq = _keySequence(logical, ctrl: ctrl, alt: alt, shift: shift);
    if (seq != null) {
      widget.ssh.write(seq);
      return KeyEventResult.handled;
    }

    // Printable characters are NOT handled here: let them flow into the
    // TextField so that both English (typed directly) and Chinese IME
    // composition are captured through onChanged. Handling them here would
    // send IME pinyin keystrokes to the terminal as garbage.
    return KeyEventResult.ignored;
  }

  /// Map special keys to terminal escape sequences.
  String? _keySequence(LogicalKeyboardKey key,
      {required bool ctrl, required bool alt, required bool shift}) {
    if (key == LogicalKeyboardKey.arrowUp) return '\x1b[A';
    if (key == LogicalKeyboardKey.arrowDown) return '\x1b[B';
    if (key == LogicalKeyboardKey.arrowRight) return '\x1b[C';
    if (key == LogicalKeyboardKey.arrowLeft) return '\x1b[D';
    if (key == LogicalKeyboardKey.home) return '\x1b[H';
    if (key == LogicalKeyboardKey.end) return '\x1b[F';
    if (key == LogicalKeyboardKey.pageUp) return '\x1b[5~';
    if (key == LogicalKeyboardKey.pageDown) return '\x1b[6~';
    if (key == LogicalKeyboardKey.delete) return '\x1b[3~';
    if (key == LogicalKeyboardKey.backspace) return '\x7f';
    if (key == LogicalKeyboardKey.tab) return '\t';
    return null;
  }

  /// TextField value changed. Send committed text to the terminal.
  ///
  /// Distinguishes two cases:
  ///  1. IME composition just finished (was composing -> now collapsed):
  ///     send the whole committed text (covers Chinese and IME-typed ASCII).
  ///  2. Direct English typing (collapsed the whole time): send only the
  ///     newly-appended increment so characters are not duplicated.
  void _onImeChanged() {
    final value = _imeCtrl.value;
    LogService.instance.info('ime',
        'changed text=[${value.text}] composing=${value.composing} wasComposing=$_wasComposing');
    final composing = !value.composing.isCollapsed;
    final text = value.text;

    if (composing) {
      // IME composition in progress: remember text, do not send yet.
      _pendingIme = text;
      _wasComposing = true;
      return;
    }

    // Committed text (no active composition now).
    final justFinishedIme = _wasComposing;
    _wasComposing = false;

    if (text.isEmpty) {
      _pendingIme = '';
      return;
    }

    if (justFinishedIme) {
      // An IME composition just completed: send the whole result.
      widget.ssh.write(text);
      _resetIme();
      return;
    }

    // Direct English typing: send only the newly-appended increment.
    final pending = _pendingIme;
    String delta;
    if (text.startsWith(pending)) {
      delta = text.substring(pending.length);
    } else {
      delta = text;
    }
    _pendingIme = '';
    if (delta.isNotEmpty) {
      widget.ssh.write(delta);
    }
    _resetIme();
  }

  void _resetIme() {
    _pendingIme = '';
    _imeCtrl.value = const TextEditingValue(
      text: '',
      selection: TextSelection.collapsed(offset: 0),
    );
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
          child: Stack(
            children: [
              Positioned.fill(
                child: TerminalView(
                  _terminal,
                  theme: _darkTheme,
                  backgroundOpacity: 1,
                  readOnly: true,
                ),
              ),
              // Transparent full-screen TextField: holds focus, catches both
              // hardware keys (Focus.onKeyEvent) and IME composition (onChanged).
              Positioned.fill(
                child: Focus(
                  focusNode: _imeFocus,
                  autofocus: true,
                  onKeyEvent: _onKeyEvent,
                  child: TextField(
                    controller: _imeCtrl,
                    style:
                        const TextStyle(fontSize: 1, color: Colors.transparent),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                    cursorColor: Colors.transparent,
                    showCursor: false,
                    enableSuggestions: false,
                    autocorrect: false,
                    maxLines: null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
