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
      await Future.delayed(const Duration(seconds: 1));
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
  final _moveToBgPlugin = MoveToBg();

  @override
  void initState() {
    super.initState();
    _routineSubscription = SamsungRoutineHandler.actionStream.listen((action) {
      if (action == 'connect_work_server') {
        _handleConnectAction();
      } else if (action == 'disconnect_vpn') {
        _handleDisconnectAction();
      } else if (action == 'toggle_vpn') {
        _handleToggleAction();
      }
    });
  }

  void _handleToggleAction() {
    final vpnController = VpnScope.vpnControllerOf(context, listen: false);
    if (vpnController.state == VpnState.disconnected) {
      _handleConnectAction();
    } else {
      _handleDisconnectAction();
    }
  }

  void _handleConnectAction() async {
    try {
      final serversController = ServersScope.controllerOf(context, listen: false);
      final routingController = RoutingScope.controllerOf(context, listen: false);
      
      // FIX: Wait for BOTH servers and routing profiles to load from the database
      int retries = 0;
      while ((serversController.servers.isEmpty || routingController.routingList.isEmpty) && retries < 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        retries++;
      }

      // If context was lost during the wait, abort safely
      if (!mounted) return;

      final servers = serversController.servers;
      final routingList = routingController.routingList;

      // If either list is STILL empty after waiting, abort to prevent a crash
      if (servers.isEmpty || routingList.isEmpty) return;
      
      final targetServer = servers.firstWhere(
        (s) => s.serverData.name.toLowerCase().trim() == 'server',
        orElse: () => servers.first,
      );

      serversController.pickServer(targetServer.id);

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

      await _moveToBgPlugin.moveTaskToBack();

    } catch (e) {
      // Ignore errors silently to prevent app crashes in the background
    }
  }

  void _handleDisconnectAction() async {
    try {
      VpnScope.vpnControllerOf(context, listen: false).stop();
      await _moveToBgPlugin.moveTaskToBack();
    } catch (e) {
      // Ignore errors silently
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
