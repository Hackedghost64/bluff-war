import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/utils/net_logger.dart';

class NetworkOverlay extends StatefulWidget {
  const NetworkOverlay({super.key});

  @override
  State<NetworkOverlay> createState() => _NetworkOverlayState();
}

class _NetworkOverlayState extends State<NetworkOverlay> {
  final List<LogEntry> _logs = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    NetLogger.logStream.listen((entry) {
      if (mounted) {
        setState(() {
          _logs.add(entry);
          if (_logs.length > 200) _logs.removeAt(0);
        });
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    return Positioned(
      top: 50,
      right: 10,
      width: 250,
      height: 300,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: const Text(
                  'NETWORK LOGS',
                  style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(4),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '${log.timestamp.hour}:${log.timestamp.minute}:${log.timestamp.second} ${log.message}',
                        style: TextStyle(
                          color: _getLogColor(log.level),
                          fontSize: 9,
                          fontFamily: 'monospace',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getLogColor(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return Colors.white70;
      case LogLevel.warning:
        return Colors.orangeAccent;
      case LogLevel.error:
        return Colors.redAccent;
      case LogLevel.critical:
        return Colors.red;
      case LogLevel.transition:
        return Colors.blueAccent;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
