import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/database_helper.dart';

class SyncService {
  static Future<bool> isConnected() async {
    final results = await Connectivity().checkConnectivity();
    return results
        .any((r) => r == ConnectivityResult.wifi || r == ConnectivityResult.mobile);
  }

  /// Simulates a cloud sync. Returns true on success.
  static Future<bool> syncToCloud() async {
    if (!await isConnected()) return false;
    // Simulate network latency
    await Future.delayed(const Duration(milliseconds: 1500));
    await DatabaseHelper.instance.markAllSynced();
    return true;
  }

  static Future<int> getUnsyncedCount() async {
    return DatabaseHelper.instance.getUnsyncedCount();
  }

  static Stream<List<ConnectivityResult>> get connectivityStream =>
      Connectivity().onConnectivityChanged;
}
