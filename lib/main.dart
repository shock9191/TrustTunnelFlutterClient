import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart' hide Router;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'samsung_routine_handler.dart';

import 'package:trusttunnel/di/model/initialization_helper.dart';
import 'package:trusttunnel/di/widgets/dependency_scope.dart';
import 'package:trusttunnel/feature/app/app.dart';
import 'package:trusttunnel/feature/deep_link/deep_link_scope.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_update_manager.dart';

Future<void> _initToggleChannel() async {
  const platform = MethodChannel('toggle_channel');

  platform.setMethodCallHandler((call) async {
    if (call.method == 'toggleFromPlatform') {
      // Forward tile trigger into the SamsungRoutine pipeline
      SamsungRoutineHandler.triggerToggleFromPlatform();
    }
  });
}

void main() => runZonedGuarded(
      () async {
        WidgetsFlutterBinding.ensureInitialized();

        final initializationResult = await InitializationHelperIo().init();

        // Set up quick actions / Samsung routine handler.
        SamsungRoutineHandler.init();

        // Set up platform channel used by the Quick Settings tile.
        await _initToggleChannel();

        runApp(
          DependencyScope(
            dependenciesFactory: initializationResult.dependenciesFactory,
            repositoryFactory: initializationResult.repositoryFactory,
            child: ServersScope(
              child: RoutingScope(
                child: ExcludedRoutesScope(
                  child: VpnScope(
                    vpnRepository:
                        initializationResult.repositoryFactory.vpnRepository,
                    initialState: initializationResult.initialVpnState,
                    child: const VpnUpdateManager(
                      child: DeepLinkScope(
                        child: SamsungRoutineListenerWidget(
                          child: App(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      (e, st) {
        log(
          'Error catched in main thread',
          error: e,
          stackTrace: st,
        );
      },
    );
