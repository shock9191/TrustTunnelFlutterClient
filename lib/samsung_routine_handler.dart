import 'dart:async';
import 'package:flutter/material.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope.dart';

class SamsungRoutineHandler {
  static final QuickActions _quickActions = const QuickActions();
  static final StreamController<String> _actionStream = StreamController<String>.broadcast();
  static Stream<String> get actionStream => _actionStream.stream;

  static void init() {
    _quickActions.initialize((String shortcutType) async {
      // Delay to ensure the UI tree is fully built before sending the signal
      await Future.delayed(const Duration(seconds: 1));
      _actionStream.add(shortcutType);
    });

    _quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(
        type: 'connect_work_server',
        localizedTitle: 'Connect to Work Server',
        icon: 'ic_launcher',
      ),
      const ShortcutItem(
        type: 'disconnect_vpn',
        localizedTitle: 'Disconnect VPN',
        icon: 'ic_launcher',
      ),
    ]);
  }
}

/// An invisible widget that wraps the main App() to catch shortcut intents.
/// This prevents us from having to modify trusttunnel's core UI files.
class SamsungRoutineListenerWidget extends StatefulWidget {
  final Widget child;

  const SamsungRoutineListenerWidget({Key? key, required this.child}) : super(key: key);

  @override
  State<SamsungRoutineListenerWidget> createState() => _SamsungRoutineListenerWidgetState();
}

class _SamsungRoutineListenerWidgetState extends State<SamsungRoutineListenerWidget> {
  StreamSubscription? _routineSubscription;

  @override
  void initState() {
    super.initState();
    _routineSubscription = SamsungRoutineHandler.actionStream.listen((action) {
      if (action == 'connect_work_server') {
        _handleConnectAction();
      } else if (action == 'disconnect_vpn') {
        _handleDisconnectAction();
      }
    });
  }

  void _handleConnectAction() {
    // 1. Get the official UI state controller
    final serversController = ServersScope.controllerOf(context, listen: false);
    
    // 2. Find the target server
    final servers = serversController.state.servers;
    if (servers.isEmpty) return;
    
    final targetServer = servers.firstWhere(
      (s) => s.serverData.name.toLowerCase().trim() == 'server',
      orElse: () => servers.first,
    );

    // 3. Emulate a physical tap on the "TURN ON" UI button
    // This perfectly triggers the VpnUpdateManager!
    serversController.selectServer(targetServer.id);
  }

  void _handleDisconnectAction() {
    // Calling stop() on the main VpnScope exactly like the UI does
    VpnScope.vpnControllerOf(context, listen: false).stop();
  }

  @override
  void dispose() {
    _routineSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This widget renders absolutely nothing of its own; it just passes the app through.
    return widget.child;
  }
}
