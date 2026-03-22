import 'dart:async';
import 'package:flutter/material.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:move_to_bg/move_to_bg.dart';

import 'package:trusttunnel/data/model/vpn_state.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope.dart';

class SamsungRoutineHandler {
  static final QuickActions _quickActions = const QuickActions();
  static final StreamController<String> _actionStream = StreamController<String>.broadcast();
  static Stream<String> get actionStream => _actionStream.stream;

  static void init() {
    _quickActions.initialize((String shortcutType) async {
      await Future.delayed(const Duration(milliseconds: 500));
      _actionStream.add(shortcutType);
    });

    _quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(type: 'connect_work_server', localizedTitle: 'Connect', icon: 'ic_launcher'),
      const ShortcutItem(type: 'disconnect_vpn', localizedTitle: 'Disconnect', icon: 'ic_launcher'),
      const ShortcutItem(type: 'toggle_vpn', localizedTitle: 'Toggle VPN', icon: 'ic_launcher'),
    ]);
  }
}

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
      _executeAction(action);
    });
  }

  // The Master Wrapper: This guarantees the app goes to the background no matter what happens.
  void _executeAction(String action) async {
    try {
      if (action == 'connect_work_server') {
        await _handleConnectAction();
      } else if (action == 'disconnect_vpn') {
        await _handleDisconnectAction();
      } else if (action == 'toggle_vpn') {
        await _handleToggleAction();
      }
    } finally {
      // Small wait to ensure VPN commands fired, then force background
      await Future.delayed(const Duration(milliseconds: 500));
      final moveToBgPlugin = MoveToBg();
      await moveToBgPlugin.moveTaskToBack();
    }
  }

  // Safe Waiting Room for Cold Starts
  Future<bool> _waitForAppToInitialize() async {
    for (int i = 0; i < 10; i++) {
      try {
        if (!mounted) return false;
        
        final servers = ServersScope.controllerOf(context, listen: false).servers;
        final routingList = RoutingScope.controllerOf(context, listen: false).routingList;
        VpnScope.vpnControllerOf(context, listen: false); // Touch to ensure it exists
        
        if (servers.isNotEmpty && routingList.isNotEmpty) {
          return true; // Everything loaded perfectly
        }
      } catch (e) {
        // App still booting, Scopes not found yet. Keep looping.
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return false;
  }

  Future<void> _handleToggleAction() async {
    bool isReady = await _waitForAppToInitialize();
    if (!isReady) return;

    final vpnController = VpnScope.vpnControllerOf(context, listen: false);
    if (vpnController.state == VpnState.disconnected) {
      await _handleConnectAction(skipInitCheck: true);
    } else {
      await _handleDisconnectAction();
    }
  }

  Future<void> _handleConnectAction({bool skipInitCheck = false}) async {
    if (!skipInitCheck) {
      bool isReady = await _waitForAppToInitialize();
      if (!isReady) return;
    }

    try {
      final serversController = ServersScope.controllerOf(context, listen: false);
      final servers = serversController.servers;
      
      final targetServer = servers.firstWhere(
        (s) => s.serverData.name.toLowerCase().trim() == 'server',
        orElse: () => servers.first,
      );

      serversController.pickServer(targetServer.id);

      final routingList = RoutingScope.controllerOf(context, listen: false).routingList;
      final routingProfile = routingList.firstWhere(
        (element) => element.id == targetServer.serverData.routingProfileId,
        orElse: () => routingList.first, 
      );

      final excludedRoutes = ExcludedRoutesScope.controllerOf(context, listen: false).excludedRoutes;
      final vpnController = VpnScope.vpnControllerOf(context, listen: false);
      
      await vpnController.start(
        server: targetServer,
        routingProfile: routingProfile,
        excludedRoutes: excludedRoutes,
      );
    } catch (e) {
      // Let the finally block handle it
    }
  }

  Future<void> _handleDisconnectAction() async {
    try {
      VpnScope.vpnControllerOf(context, listen: false).stop();
    } catch (e) {
      // Let the finally block handle it
    }
  }

  @override
  void dispose() {
    _routineSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
