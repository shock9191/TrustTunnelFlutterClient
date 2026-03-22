import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quick_actions/quick_actions.dart';

import 'package:trusttunnel/data/model/vpn_state.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope.dart';

/// Handles Samsung routines, launcher shortcuts and static shortcuts.
class SamsungRoutineHandler {
  static final QuickActions _quickActions = const QuickActions();

  static final StreamController<String> _actionStream =
      StreamController<String>.broadcast();

  // Exposed so bootstrap can push initial shortcut types.
  static StreamController<String> get actionStreamController =>
      _actionStream;

  static Stream<String> get actionStream => _actionStream.stream;

  static void init() {
    // Dynamic shortcuts (quick_actions plugin, works with many launchers).
    _quickActions.initialize((String shortcutType) {
      _actionStream.add(shortcutType);
    });

    _quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(
        type: 'connect_work_server',
        localizedTitle: 'Connect',
        icon: 'ic_launcher',
      ),
      const ShortcutItem(
        type: 'disconnect_vpn',
        localizedTitle: 'Disconnect',
        icon: 'ic_launcher',
      ),
      const ShortcutItem(
        type: 'toggle_vpn',
        localizedTitle: 'Toggle VPN',
        icon: 'ic_launcher',
      ),
    ]);
  }
}

/// Reads the initial static shortcut "type" from Android (via MainActivity)
/// and feeds it into SamsungRoutineHandler so the same logic runs.
///
/// Call `AndroidShortcutBootstrap.init()` in `main()` AFTER
/// `SamsungRoutineHandler.init()` and BEFORE `runApp(...)`.
class AndroidShortcutBootstrap {
  static const MethodChannel _launchChannel =
      MethodChannel('launch_channel');

  static Future<void> init() async {
    try {
      final String? type =
          await _launchChannel.invokeMethod<String>('getInitialShortcutType');
      if (type != null && type.isNotEmpty) {
        SamsungRoutineHandler.actionStreamController.add(type);
      }
    } catch (_) {
      // Ignore if channel not available.
    }
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
  String? _pendingAction; // Stores the action if the app is still booting
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _routineSubscription =
        SamsungRoutineHandler.actionStream.listen((action) {
      _pendingAction = action;
      if (!_isProcessing) {
        _safeExecute();
      }
    });
  }

  void _safeExecute() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_pendingAction == null || !mounted || _isProcessing) return;

      _isProcessing = true;
      final action = _pendingAction;
      _pendingAction = null;

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
      } catch (_) {
        // ignore
      }

      _forceBackground();
      _isProcessing = false;
    });
  }

  Future<void> _executeConnect() async {
    final serversController =
        ServersScope.controllerOf(context, listen: false);

    // Give the database a moment to load if it is a fresh cold start.
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

    try {
      await vpnController.start(
        server: targetServer,
        routingProfile: routingProfile,
        excludedRoutes: excludedRoutes,
      );
    } catch (_) {
      // ignore
    }
  }

  void _forceBackground() async {
    await Future.delayed(const Duration(milliseconds: 500));
    try {
      const platform = MethodChannel('app_channel');
      await platform.invokeMethod('goHome');
    } catch (_) {
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
    if (_pendingAction != null && !_isProcessing) {
      _safeExecute();
    }
    return widget.child;
  }
}
