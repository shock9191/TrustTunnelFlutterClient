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
  static final StreamController<String> _actionStream =
      StreamController<String>.broadcast();

  static Stream<String> get actionStream => _actionStream.stream;

  static void init() {
    // Quick‑actions from long‑press icon (optional)
    _quickActions.initialize((String shortcutType) async {
      await Future.delayed(const Duration(seconds: 1));
      _actionStream.add(shortcutType);
    });

    _quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(
        type: 'toggle_vpn',
        localizedTitle: 'Toggle VPN',
        icon: 'ic_launcher',
      ),
    ]);
  }

  // This is for MainActivity / tile to inject "toggle_vpn" directly.
  static void triggerToggleFromPlatform() {
    _actionStream.add('toggle_vpn');
  }
}

class SamsungRoutineListenerWidget extends StatefulWidget {
  final Widget child;

  const SamsungRoutineListenerWidget({Key? key, required this.child})
      : super(key: key);

  @override
  State<SamsungRoutineListenerWidget> createState() =>
      _SamsungRoutineListenerWidgetState();
}

class _SamsungRoutineListenerWidgetState
    extends State<SamsungRoutineListenerWidget> {
  StreamSubscription<String>? _routineSubscription;
  final _moveToBgPlugin = MoveToBg();

  @override
  void initState() {
    super.initState();
    _routineSubscription =
        SamsungRoutineHandler.actionStream.listen((action) {
      if (action == 'toggle_vpn') {
        _handleToggleAction();
      }
    });
  }

  Future<void> _handleToggleAction() async {
    try {
      final vpnController =
          VpnScope.vpnControllerOf(context, listen: false);

      if (vpnController.state == VpnState.connected ||
          vpnController.state == VpnState.connecting) {
        // DISCONNECT PATH
        vpnController.stop();
        await _moveToBgPlugin.moveTaskToBack();
        return;
      }

      // CONNECT PATH – your working logic
      final serversController =
          ServersScope.controllerOf(context, listen: false);
      final servers = serversController.servers;
      if (servers.isEmpty) {
        await _moveToBgPlugin.moveTaskToBack();
        return;
      }

      final targetServer = servers.firstWhere(
        (s) => s.serverData.name.toLowerCase().trim() == 'server',
        orElse: () => servers.first,
      );

      // 1. Mark the server as selected in the UI
      serversController.pickServer(targetServer.id);

      // 2. Fetch the required parameters from the UI scopes
      final routingList =
          RoutingScope.controllerOf(context, listen: false).routingList;
      if (routingList.isEmpty) {
        await _moveToBgPlugin.moveTaskToBack();
        return;
      }

      final routingProfile = routingList.firstWhere(
        (element) =>
            element.id == targetServer.serverData.routingProfileId,
        orElse: () => routingList.first,
      );

      final excludedRoutes =
          ExcludedRoutesScope.controllerOf(context, listen: false)
              .excludedRoutes;

      // 3. EXPLICITLY START THE VPN
      await vpnController.start(
        server: targetServer,
        routingProfile: routingProfile,
        excludedRoutes: excludedRoutes,
      );
    } catch (_) {
      // swallow error
    } finally {
      // 4. Immediately push the app back to the background
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
