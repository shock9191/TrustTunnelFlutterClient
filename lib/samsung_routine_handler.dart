import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quick_actions/quick_actions.dart';

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
    _quickActions.initialize((String shortcutType) {
      // Instantly capture the intent so Android doesn't drop it.
      _actionStream.add(shortcutType);
    });

    _quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(
          type: 'connect_work_server',
          localizedTitle: 'Connect',
          icon: 'ic_launcher'),
      const ShortcutItem(
          type: 'disconnect_vpn',
          localizedTitle: 'Disconnect',
          icon: 'ic_launcher'),
      const ShortcutItem(
          type: 'toggle_vpn',
          localizedTitle: 'Toggle VPN',
          icon: 'ic_launcher'),
    ]);
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
  StreamSubscription? _routineSubscription;
  String? _pendingAction; // Stores the action if the app is still booting
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _routineSubscription =
        SamsungRoutineHandler.actionStream.listen((action) {
      _pendingAction = action;
      // We don't execute immediately. We tell Flutter to execute ONLY after the UI is built.
      if (!_isProcessing) {
        _safeExecute();
      }
    });
  }

  void _safeExecute() {
    // This tells Flutter: "Wait until the context is fully mounted and drawn, then run this."
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_pendingAction == null || !mounted || _isProcessing) return;

      _isProcessing = true;
      final action = _pendingAction;
      _pendingAction = null; // Clear the queue

      try {
        if (action == 'disconnect_vpn') {
          VpnScope.vpnControllerOf(context, listen: false).stop();
        } else if (action == 'connect_work_server') {
          await _executeConnect();
        } else if (action == 'toggle_vpn') {
          final vpnState =
              VpnScope.vpnControllerOf(context, listen: false).state;
          if (vpnState == VpnState.connected ||
              vpnState == VpnState.connecting) {
            VpnScope.vpnControllerOf(context, listen: false).stop();
          } else {
            await _executeConnect();
          }
        }
      } catch (e) {
        // Safe catch
      }

      // Force backgrounding after execution
      _forceBackground();
      _isProcessing = false;
    });
  }

  Future<void> _executeConnect() async {
    final serversController = ServersScope.controllerOf(
      context,
      listen: false,
    );

    // Give the database a moment to load if it is a fresh cold start
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

    final routingController =
        RoutingScope.controllerOf(context, listen: false);
    final routingList = routingController.routingList;
    if (routingList.isEmpty) return;

    final routingProfile = routingList.firstWhere(
      (element) => element.id == targetServer.serverData.routingProfileId,
      orElse: () => routingList.first,
    );

    final excludedRoutes =
        ExcludedRoutesScope.controllerOf(context, listen: false)
            .excludedRoutes;
    final vpnController =
        VpnScope.vpnControllerOf(context, listen: false);

    await vpnController.start(
      server: targetServer,
      routingProfile: routingProfile,
      excludedRoutes: excludedRoutes,
    );
  }

  void _forceBackground() async {
    await Future.delayed(const Duration(milliseconds: 500));
    // Since MoveToBg keeps failing randomly due to Android 12 restrictions,
    // we use the native Android intent to go home. It is 100% reliable.
    try {
      const platform = MethodChannel('app_channel');
      await platform.invokeMethod('goHome');
    } catch (e) {
      // If method channel isn't set up, fallback to standard system pop
      SystemNavigator.pop();
    }
  }

  @override
  void dispose() {
    _routineSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If a pending action arrives while building, process it right after build completes
    if (_pendingAction != null && !_isProcessing) {
      _safeExecute();
    }
    return widget.child;
  }
}
