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
    try {
      final vpnController = VpnScope.vpnControllerOf(context, listen: false);
      if (vpnController.state == VpnState.disconnected) {
        _handleConnectAction();
      } else {
        _handleDisconnectAction();
      }
    } catch (e) {
      _closeApp();
    }
  }

  void _handleConnectAction() async {
    try {
      final serversController = ServersScope.controllerOf(context, listen: false);
      
      // Wait up to 3 seconds for database to load on Cold Start
      for (int i = 0; i < 6; i++) {
        if (serversController.servers.isNotEmpty) break;
        await Future.delayed(const Duration(milliseconds: 500));
      }

      final servers = serversController.servers;
      if (servers.isEmpty) {
        _closeApp();
        return;
      }

      final targetServer = servers.firstWhere(
        (s) => s.serverData.name.toLowerCase().trim() == 'server',
        orElse: () => servers.first,
      );

      serversController.pickServer(targetServer.id);

      final routingController = RoutingScope.controllerOf(context, listen: false);
      final routingList = routingController.routingList;
      if (routingList.isEmpty) {
        _closeApp();
        return;
      }

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
      // Ignore errors silently
    } 
    
    // Always execute the close function regardless of success or error
    _closeApp();
  }

  void _handleDisconnectAction() async {
    try {
      VpnScope.vpnControllerOf(context, listen: false).stop();
    } catch (e) {
      // Ignore errors silently
    }
    
    _closeApp();
  }

  // Protected Background Function
  void _closeApp() async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      final moveToBg = MoveToBg(); // FIXED: Initialized the plugin correctly
      await moveToBg.moveTaskToBack();
    } catch (e) {
      // Failsafe
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
