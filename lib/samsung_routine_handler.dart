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
    try {
      final vpnController = VpnScope.vpnControllerOf(context, listen: false);
      
      // FIXED: If it's anything other than actively 'connected', turn it ON.
      if (vpnController.state != VpnState.connected) {
        _handleConnectAction();
      } else {
        _handleDisconnectAction();
      }
    } catch (e) {
      // Ignore
    }
  }

  void _handleConnectAction() async {
    try {
      // 1. Grab everything from context immediately so it doesn't break later
      final serversController = ServersScope.controllerOf(context, listen: false);
      final routingController = RoutingScope.controllerOf(context, listen: false);
      final excludedRoutes = ExcludedRoutesScope.controllerOf(context, listen: false).excludedRoutes;
      final vpnController = VpnScope.vpnControllerOf(context, listen: false);
      
      // 2. COLD START FIX: Just wait 2 seconds if the database hasn't loaded yet.
      if (serversController.servers.isEmpty || routingController.routingList.isEmpty) {
        await Future.delayed(const Duration(seconds: 2));
      }

      // 3. Re-check the lists. If still empty, abort safely.
      final servers = serversController.servers;
      final routingList = routingController.routingList;
      if (servers.isEmpty || routingList.isEmpty) return; 
      
      // 4. Safe connection logic
      final targetServer = servers.firstWhere(
        (s) => s.serverData.name.toLowerCase().trim() == 'server',
        orElse: () => servers.first,
      );

      serversController.pickServer(targetServer.id);

      final routingProfile = routingList.firstWhere(
        (element) => element.id == targetServer.serverData.routingProfileId,
        orElse: () => routingList.first, 
      );
      
      await vpnController.start(
        server: targetServer,
        routingProfile: routingProfile,
        excludedRoutes: excludedRoutes,
      );

    } catch (e) {
      // Silently ignore to prevent app crashes
    } finally {
      // 5. FIXED: ALWAYS move to background, ensuring the app closes no matter what.
      await _moveToBgPlugin.moveTaskToBack();
    }
  }

  void _handleDisconnectAction() async {
    try {
      VpnScope.vpnControllerOf(context, listen: false).stop();
    } catch (e) {
      // Ignore
    } finally {
      await _moveToBgPlugin.moveTaskToBack();
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
