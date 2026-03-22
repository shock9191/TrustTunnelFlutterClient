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
  final _moveToBgPlugin = MoveToBg(); // Reverted to your exact working setup

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

  // THE WAITING ROOM: Safely waits for Flutter to finish booting without crashing
  Future<bool> _waitForAppToInitialize() async {
    for (int i = 0; i < 10; i++) { // Wait up to 5 seconds max
      try {
        if (!mounted) return false;
        
        // If these scopes aren't ready, they throw an exception which we safely catch.
        final servers = ServersScope.controllerOf(context, listen: false).servers;
        final routingList = RoutingScope.controllerOf(context, listen: false).routingList;
        
        // Just touching VpnScope to ensure it is ready
        VpnScope.vpnControllerOf(context, listen: false);
        
        // Check if database has actually finished loading
        if (servers.isNotEmpty && routingList.isNotEmpty) {
          return true; // App is 100% ready to execute commands!
        }
      } catch (e) {
        // App is still drawing the widget tree, ignore and wait
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return false; // Timed out
  }

  void _handleToggleAction() async {
    bool isReady = await _waitForAppToInitialize();
    if (!isReady) {
      await _moveToBgPlugin.moveTaskToBack();
      return;
    }

    try {
      final vpnController = VpnScope.vpnControllerOf(context, listen: false);
      if (vpnController.state == VpnState.disconnected) {
        _handleConnectAction(skipInitCheck: true);
      } else {
        _handleDisconnectAction();
      }
    } catch (e) {
      await _moveToBgPlugin.moveTaskToBack();
    }
  }

  void _handleConnectAction({bool skipInitCheck = false}) async {
    try {
      if (!skipInitCheck) {
        bool isReady = await _waitForAppToInitialize();
        if (!isReady) {
          await _moveToBgPlugin.moveTaskToBack();
          return;
        }
      }

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
      
      // Tiny delay to let the VPN tunnel fully establish before minimizing
      await Future.delayed(const Duration(milliseconds: 500));
      
    } catch (e) {
      // Safely ignore connection errors
    } finally {
      await _moveToBgPlugin.moveTaskToBack();
    }
  }

  void _handleDisconnectAction() async {
    try {
      VpnScope.vpnControllerOf(context, listen: false).stop();
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      // Safely ignore
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
