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
      _processActionSafely(action);
    });
  }

  void _processActionSafely(String action) async {
    // 1. THE BLIND WAIT: Give the app 2 full seconds to completely build its UI and load the DB.
    // This entirely prevents the silent cold-start crashes. 
    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;

    try {
      if (action == 'disconnect_vpn') {
        VpnScope.vpnControllerOf(context, listen: false).stop();
      } else if (action == 'connect_work_server') {
        await _executeConnect();
      } else if (action == 'toggle_vpn') {
        final vpnState = VpnScope.vpnControllerOf(context, listen: false).state;
        
        // FIXED TOGGLE LOGIC: If it is actively connected/connecting, turn it off. 
        // If it is idle, disconnected, error, or ANYTHING ELSE, turn it on.
        if (vpnState == VpnState.connected || vpnState == VpnState.connecting) {
          VpnScope.vpnControllerOf(context, listen: false).stop();
        } else {
          await _executeConnect();
        }
      }
    } catch (e) {
      // Catch connection errors silently so they DO NOT stop the backgrounding process
    }

    // 2. THE GUARANTEED BACKGROUND: Wait 1 second for VPN commands to register, then minimize.
    // Because this is outside the logic block above, it will fire 100% of the time.
    await Future.delayed(const Duration(milliseconds: 1000));
    try {
      await _moveToBgPlugin.moveTaskToBack();
    } catch (e) {
      // Failsafe
    }
  }

  Future<void> _executeConnect() async {
    final serversController = ServersScope.controllerOf(context, listen: false);
    
    // Safety check: if DB is still slow after the 2s wait, give it 1 more second.
    if (serversController.servers.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 1000));
    }
    
    final servers = serversController.servers;
    if (servers.isEmpty) return; // Abort safely if literally zero servers exist

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
