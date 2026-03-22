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

  void _handleToggleAction() async {
    // Retry loop to ensure VPN controller is ready on cold start
    for (int i = 0; i < 6; i++) {
      try {
        if (!mounted) return;
        final vpnController = VpnScope.vpnControllerOf(context, listen: false);
        
        if (vpnController.state == VpnState.disconnected) {
          _handleConnectAction();
        } else {
          _handleDisconnectAction();
        }
        return; // Success, exit loop
      } catch (e) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  void _handleConnectAction() async {
    // Try to connect up to 6 times (giving the app 3 seconds to fully boot)
    for (int i = 0; i < 6; i++) {
      try {
        if (!mounted) return;

        final serversController = ServersScope.controllerOf(context, listen: false);
        final servers = serversController.servers;
        
        // If servers aren't loaded yet, throw an error to trigger the catch block and retry
        if (servers.isEmpty) throw Exception("Servers not ready");

        final targetServer = servers.firstWhere(
          (s) => s.serverData.name.toLowerCase().trim() == 'server',
          orElse: () => servers.first,
        );

        serversController.pickServer(targetServer.id);

        final routingController = RoutingScope.controllerOf(context, listen: false);
        final routingList = routingController.routingList;
        
        if (routingList.isEmpty) throw Exception("Routing not ready");

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

        // Success! Move to background and exit the retry loop.
        await _moveToBgPlugin.moveTaskToBack();
        return; 

      } catch (e) {
        // App is still booting (Scopes not found or lists empty). Wait 500ms and try again.
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  void _handleDisconnectAction() async {
    for (int i = 0; i < 6; i++) {
      try {
        if (!mounted) return;
        VpnScope.vpnControllerOf(context, listen: false).stop();
        await _moveToBgPlugin.moveTaskToBack();
        return; // Success, exit loop
      } catch (e) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
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
