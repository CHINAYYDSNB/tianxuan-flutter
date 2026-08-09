import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import '../services/recording_service.dart';

const TerminalTheme _replayTheme = TerminalTheme(
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

class ReplayPage extends StatefulWidget {
  final RecordingSession session;

  const ReplayPage({super.key, required this.session});

  @override
  State<ReplayPage> createState() => _ReplayPageState();
}

class _ReplayPageState extends State<ReplayPage> {
  late final Terminal _terminal;
  Timer? _timer;
  int _nextEvent = 0;
  bool _playing = false;
  double _speed = 1.0;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(
      maxLines: 10000,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _play() {
    if (_playing) return;
    if (_nextEvent >= widget.session.events.length) {
      _reset();
    }
    setState(() => _playing = true);
    _tick();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) => _tick());
  }

  void _tick() {
    final events = widget.session.events;
    if (_nextEvent >= events.length) {
      _timer?.cancel();
      setState(() {
        _playing = false;
        _progress = 1.0;
      });
      return;
    }
    final nowMs = _nextEvent == 0
        ? 0
        : events[_nextEvent - 1].timeMs;
    // advance all events up to current wall-clock position
    final wallMs = (nowMs + 50 * _speed);
    while (_nextEvent < events.length &&
        events[_nextEvent].timeMs <= wallMs) {
      _terminal.write(utf8.decode(events[_nextEvent].data, allowMalformed: true));
      _nextEvent++;
    }
    setState(() {
      _progress = events.isEmpty
          ? 1.0
          : (_nextEvent / events.length).clamp(0.0, 1.0);
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _playing = false);
  }

  void _reset() {
    _timer?.cancel();
    _terminal = Terminal(maxLines: 10000);
    setState(() {
      _nextEvent = 0;
      _playing = false;
      _progress = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return Scaffold(
      appBar: AppBar(
        title: Text('录像回放 · ${s.hostName}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DropdownButton<double>(
              value: _speed,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 1.0, child: Text('1x')),
                DropdownMenuItem(value: 2.0, child: Text('2x')),
                DropdownMenuItem(value: 4.0, child: Text('4x')),
              ],
              onChanged: (v) => setState(() => _speed = v ?? 1.0),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: const Color(0xFF0D1117),
              padding: const EdgeInsets.all(8),
              child: TerminalView(_terminal, theme: _replayTheme),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 6,
                      backgroundColor: const Color(0xFF1E222A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: '重新播放',
                        icon: const Icon(Icons.replay),
                        onPressed: _reset,
                      ),
                      IconButton(
                        tooltip: _playing ? '暂停' : '播放',
                        icon: Icon(_playing
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill),
                        iconSize: 40,
                        color: const Color(0xFF6366F1),
                        onPressed: _playing ? _pause : _play,
                      ),
                      Text(
                        '${s.startedAt.toLocal()} · ${s.durationMs ~/ 1000}s',
                        style: const TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
