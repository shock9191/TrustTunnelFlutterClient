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
      
      // Delay to ensure the Flutter engine and VPN services are fully awake
      await Future.delayed(const Duration(seconds: 1));

      // --- ACTION 1: CONNECT TO WORK SERVER ---
      if (shortcutType == 'connect_work_server') {
        final servers = await serverRepository.getAllServers(); 
        
        final myWorkServer = servers.firstWhere(
          (s) => s.serverData.name == 'server',
          orElse: () => null as dynamic, 
        );

        if (myWorkServer != null) {
          await serverRepository.setSelectedServerId(id: myWorkServer.id);

          final routingProfile = await routingRepository.getProfileById(
            id: myWorkServer.serverData.routingProfileId,
          );
          final excludedRoutes = await settingsRepository.getExcludedRoutes();

          if (routingProfile != null) {
             await vpnRepository.startListenToStates(
               server: myWorkServer,
               routingProfile: routingProfile,
               excludedRoutes: excludedRoutes,
             );
          }
        }
      } 
      
      // --- ACTION 2: DISCONNECT VPN ---
      else if (shortcutType == 'disconnect_vpn') {
        // Calling stop() directly on the repository terminates the active connection
        await vpnRepository.stop();
      }
      
    });

    // Register BOTH shortcuts with the Android OS
    _quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(
        type: 'connect_work_server',
        localizedTitle: 'Connect to Work Server',
        icon: 'ic_launcher',
      ),
      const ShortcutItem(
        type: 'disconnect_vpn',
        localizedTitle: 'Disconnect VPN',
        icon: 'ic_launcher', 
      ),
    ]);
  }
}
