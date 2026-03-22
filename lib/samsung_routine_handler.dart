import 'dart:async';
import 'package:flutter/material.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:move_to_bg/move_to_bg.dart';

// We import the direct dependencies instead of the UI Scopes
import 'package:trusttunnel/core/di/di.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';
import 'package:trusttunnel/domain/repository/vpn_repository.dart';
import 'package:trusttunnel/domain/repository/servers_repository.dart';
import 'package:trusttunnel/domain/repository/routing_repository.dart';
import 'package:trusttunnel/domain/repository/settings_repository.dart';

class SamsungRoutineHandler {
  static final QuickActions _quickActions = const QuickActions();
  static final StreamController<String> _actionStream = StreamController<String>.broadcast();
  static Stream<String> get actionStream => _actionStream.stream;

  static void init() {
    _quickActions.initialize((String shortcutType) async {
      // Small delay to ensure DI is ready
      await Future.delayed(const Duration(milliseconds: 500));
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
      _executeAction(action);
    });
  }

  // Master execution function that guarantees backgrounding
  void _executeAction(String action) async {
    try {
      if (action == 'connect_work_server') {
        await _handleConnectAction();
      } else if (action == 'disconnect_vpn') {
        await _handleDisconnectAction();
      } else if (action == 'toggle_vpn') {
        await _handleToggleAction();
      }
    } finally {
      // Guaranteed to fire, no matter what happens in the logic above
      await Future.delayed(const Duration(milliseconds: 500));
      await _moveToBgPlugin.moveTaskToBack();
    }
  }

  Future<void> _handleToggleAction() async {
    try {
      // Get the VPN Repository directly from Dependency Injection (no context needed!)
      final vpnRepo = getIt<VpnRepository>();
      final state = vpnRepo.state.value;
      
      if (state == VpnState.disconnected) {
        await _handleConnectAction();
      } else {
        await _handleDisconnectAction();
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _handleConnectAction() async {
    try {
      // Fetch core dependencies via getIt instead of Provider Scopes
      final serversRepo = getIt<ServersRepository>();
      final routingRepo = getIt<RoutingRepository>();
      final settingsRepo = getIt<SettingsRepository>();
      final vpnRepo = getIt<VpnRepository>();

      // Wait a moment for the database stream to emit its first list if starting cold
      int retries = 0;
      while (serversRepo.servers.value.isEmpty && retries < 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        retries++;
      }

      final servers = serversRepo.servers.value;
      if (servers.isEmpty) return; // DB empty, abort.

      final targetServer = servers.firstWhere(
        (s) => s.serverData.name.toLowerCase().trim() == 'server',
        orElse: () => servers.first,
      );

      // Force save the active server directly to the database
      await serversRepo.saveActiveServerId(targetServer.id);

      final routingList = routingRepo.routingProfiles.value;
      final routingProfile = routingList.firstWhere(
        (element) => element.id == targetServer.serverData.routingProfileId,
        orElse: () => routingList.isNotEmpty ? routingList.first : throw Exception("No routing"),
      );

      final excludedRoutes = settingsRepo.excludedRoutes.value;

      // Start the VPN
      await vpnRepo.start(
        server: targetServer,
        routingProfile: routingProfile,
        excludedRoutes: excludedRoutes,
      );

    } catch (e) {
      // If it fails, the finally block in _executeAction still pushes to background.
    }
  }

  Future<void> _handleDisconnectAction() async {
    try {
      final vpnRepo = getIt<VpnRepository>();
      await vpnRepo.stop();
    } catch (e) {
      // Ignore
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
