import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    _quickActions.initialize((String shortcutType) {
      // Send the action to the stream instantly, no delays blocking the intent.
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
      // Fire and forget so we don't block the UI thread
      _processAction(action);
    });
  }

  Future<void> _processAction(String action) async {
    // 1. Give the Scopes time to build natively without blocking the listener
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    try {
      if (action == 'disconnect_vpn') {
        VpnScope.vpnControllerOf(context, listen: false).stop();
      } else if (action == 'connect_work_server') {
        await _executeConnect();
      } else if (action == 'toggle_vpn') {
        final vpnState = VpnScope.vpnControllerOf(context, listen: false).state;
        
        // If it is anything other than actively connected/connecting, force it ON.
        if (vpnState == VpnState.connected || vpnState == VpnState.connecting) {
          VpnScope.vpnControllerOf(context, listen: false).stop();
        } else {
          await _executeConnect();
        }
      }
    } catch (e) {
      // Ignore connection errors
    }

    // 2. Force the app out of the foreground
    _forceBackground();
  }

  Future<void> _executeConnect() async {
    final serversController = ServersScope.controllerOf(context, listen: false);
    
    // Safety loop: wait up to 2 seconds for DB if it's slow
    for (int i = 0; i < 4; i++) {
      if (serversController.servers.isNotEmpty) break;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    final servers = serversController.servers;
    if (servers.isEmpty) return;

    final targetServer = servers.firstWhere(
      (s) => s.serverData.name.toLowerCase().trim() == 'server',
      orElse: () => servers.first,
    );

    serversController.pickServer(targetServer.id);

    final routingController = RoutingScope.controllerOf(context, listen: false);
    final routingList = routingController.routingList;
    if (routingList.isEmpty) return;

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
  }

  void _forceBackground() async {
    // Wait slightly to let the VPN command reach the engine
    await Future.delayed(const Duration(milliseconds: 800));
    
    try {
      final moveToBg = MoveToBg();
      await moveToBg.moveTaskToBack();
    } catch (e) {
      try {
        // Fallback: If moveTaskToBack fails, pop the app context natively
        SystemNavigator.pop();
      } catch (e2) {
        // Ignore
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
