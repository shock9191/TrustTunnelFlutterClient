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

      if (shortcutType == 'connect_work_server') {
        try {
          final servers = await serverRepository.getAllServers(); 
          if (servers.isEmpty) return; // Exit if no servers exist at all
          
          // Try to find "server", ignoring case and spaces
          var myWorkServer = servers.firstWhere(
            (s) => s.serverData.name.toLowerCase().trim() == 'server',
            orElse: () => null as dynamic, 
          );

          // FALLBACK: If "server" wasn't found, just use the first server in the list
          // This ensures the button does *something* instead of silently failing
          myWorkServer ??= servers.first;

          if (myWorkServer != null) {
            await serverRepository.setSelectedServerId(id: myWorkServer.id);

            // Fetch the routing profile
            var routingProfile = await routingRepository.getProfileById(
              id: myWorkServer.serverData.routingProfileId,
            );

            // FALLBACK: If the profile is null, grab the first available profile
            if (routingProfile == null) {
              final allProfiles = await routingRepository.getAllProfiles();
              if (allProfiles.isNotEmpty) {
                routingProfile = allProfiles.first;
              }
            }

            final excludedRoutes = await settingsRepository.getExcludedRoutes();

            // Finally, start the VPN!
            if (routingProfile != null) {
               await vpnRepository.startListenToStates(
                 server: myWorkServer,
                 routingProfile: routingProfile,
                 excludedRoutes: excludedRoutes ?? [],
               );
            }
          }
        } catch (e) {
          // Ignore errors so the app doesn't crash
        }
      } 
      
      else if (shortcutType == 'disconnect_vpn') {
        await vpnRepository.stop();
      }
      
    });

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
