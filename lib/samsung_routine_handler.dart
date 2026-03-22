import 'package:quick_actions/quick_actions.dart';

class SamsungRoutineHandler {
  static final QuickActions _quickActions = const QuickActions();

  static void init({
    required dynamic serverRepository,
    required dynamic vpnRepository,
    required dynamic routingRepository,
    required dynamic settingsRepository,
  }) {
    _quickActions.initialize((String shortcutType) async {
      if (shortcutType == 'connect_work_server') {
        await Future.delayed(const Duration(seconds: 1));
        // 1. Fetch all servers
        final servers = await serverRepository.getAllServers(); 
        
        // 2. Find the server named "server"
        final myWorkServer = servers.firstWhere(
          (s) => s.serverData.name == 'server',
          orElse: () => null as dynamic, 
        );

        if (myWorkServer != null) {
          // 3. Mark the server as selected in the UI
          await serverRepository.setSelectedServerId(id: myWorkServer.id);

          // 4. Fetch the routing profile associated with this server
          final routingProfile = await routingRepository.getProfileById(
            id: myWorkServer.serverData.routingProfileId,
          );

          // 5. Fetch the global excluded routes (e.g., bypass LAN)
          final excludedRoutes = await settingsRepository.getExcludedRoutes();

          // 6. Start the VPN! 
          // (TrustTunnel calls this startListenToStates, which boots the VPN engine)
          if (routingProfile != null) {
             await vpnRepository.startListenToStates(
               server: myWorkServer,
               routingProfile: routingProfile,
               excludedRoutes: excludedRoutes,
             );
          }
        }
      }
    });

    // Register the shortcut with Android OS
    _quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(
        type: 'connect_work_server',
        localizedTitle: 'Connect to Work Server',
        icon: 'ic_launcher',
      ),
    ]);
  }
}
