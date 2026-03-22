import 'package:quick_actions/quick_actions.dart';
import 'package:trusttunnel/data/datasources/server_datasource.dart';

class SamsungRoutineHandler {
  static final QuickActions _quickActions = const QuickActions();

  static void init({
    required ServerDataSource serverDataSource,
    required dynamic vpnRepository, 
  }) {
    _quickActions.initialize((String shortcutType) async {
      if (shortcutType == 'connect_work_server') {
        
        // 1. Fetch all servers from the database
        final servers = await serverDataSource.getAllServers();
        
        // 2. Find the server with the exact name "server"
        final myWorkServer = servers.firstWhere(
          (s) => s.serverData.name == 'server',
          // We cast null to dynamic to avoid type errors if it doesn't exist
          orElse: () => null as dynamic, 
        );

        if (myWorkServer != null) {
          // 3. Mark it as the selected server in the app's database
          await serverDataSource.setSelectedServerId(id: myWorkServer.id);
          
          // 4. Start the VPN using the repository!
          // Note: Because I can't see VpnRepository, this assumes it has a simple `connect()` method. 
          // If it throws an error in your IDE, change it to the exact method name (e.g., start(), toggle(), etc.)
          await vpnRepository.connect();
        }
      }
    });

    // Register the shortcut with Android
    _quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(
        type: 'connect_work_server',
        localizedTitle: 'Connect to Work Server',
        icon: 'ic_launcher',
      ),
    ]);
  }
}
