import '../../domain/services/notification_planner.dart';

/// Kontrak penjadwalan notifikasi lokal pada layer Application.
abstract interface class NotificationScheduler {
  Future<void> replaceAll(List<PlannedNotification> planned);

  Future<void> cancelAll();

  Future<bool> requestPermission();

  Future<void> sendTestNotification();
}

/// Implementasi palsu deterministik untuk pengujian unit dan widget.
class FakeNotificationScheduler implements NotificationScheduler {
  FakeNotificationScheduler({this.permissionGranted = true});

  bool permissionGranted;
  int replaceAllCalls = 0;
  int cancelAllCalls = 0;
  int requestPermissionCalls = 0;
  int sendTestNotificationCalls = 0;
  List<PlannedNotification> scheduled = const [];

  @override
  Future<void> replaceAll(List<PlannedNotification> planned) async {
    replaceAllCalls++;
    scheduled = List<PlannedNotification>.unmodifiable(planned);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
    scheduled = const [];
  }

  @override
  Future<bool> requestPermission() async {
    requestPermissionCalls++;
    return permissionGranted;
  }

  @override
  Future<void> sendTestNotification() async {
    sendTestNotificationCalls++;
  }
}
