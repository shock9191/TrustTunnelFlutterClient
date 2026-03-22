import 'dart:async';
import 'dart:developer';
// 1. IMPORT OUR HANDLER
import 'samsung_routine_handler.dart'; 
import 'package:flutter/material.dart' hide Router;
import 'package:flutter/material.dart';
import 'package:trusttunnel/di/model/initialization_helper.dart';
import 'package:trusttunnel/di/widgets/dependency_scope.dart';
import 'package:trusttunnel/feature/app/app.dart';
import 'package:trusttunnel/feature/deep_link/deep_link_scope.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_update_manager.dart';

void main() => runZonedGuarded(
  () async {
    // 2. REQUIRED FOR QUICK ACTIONS
    WidgetsFlutterBinding.ensureInitialized();
    
    final initializationResult = await InitializationHelperIo().init();

    // 3. INITIALIZE THE SAMSUNG ROUTINE HANDLER
    // We pass the repositories directly from the initialization factory
    SamsungRoutineHandler.init(
      serverDataSource: initializationResult.repositoryFactory.serverDataSource,
      vpnRepository: initializationResult.repositoryFactory.vpnRepository,
    );

    runApp(
      DependencyScope(
        dependenciesFactory: initializationResult.dependenciesFactory,
        repositoryFactory: initializationResult.repositoryFactory,
        child: ServersScope(
          child: RoutingScope(
            child: ExcludedRoutesScope(
              child: VpnScope(
                vpnRepository: initializationResult.repositoryFactory.vpnRepository,
                initialState: initializationResult.initialVpnState,
                child: const VpnUpdateManager(
                  child: DeepLinkScope(
                    child: App(),
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
