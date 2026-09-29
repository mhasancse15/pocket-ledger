import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  void Function(String payload)? _onNotificationTap;
  String? _pendingPayload;

  static const AndroidNotificationChannel budgetChannel =
      AndroidNotificationChannel(
        'budget_alerts',
        'Budget alerts',
        description: 'Notifications about budgets and monthly spending targets',
        importance: Importance.high,
      );
  static const AndroidNotificationChannel recurringChannel =
      AndroidNotificationChannel(
        'recurring_reminders',
        'Recurring expense reminders',
        description: 'Reminders for upcoming recurring expenses',
        importance: Importance.high,
      );

  Future<void> initialize() async {
    timezone_data.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    timezone.setLocalLocation(timezone.getLocation(localTimezone));

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) _dispatchNotificationTap(payload);
      },
    );
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(budgetChannel);
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(recurringChannel);

    final launchDetails = await plugin.getNotificationAppLaunchDetails();
    final payload = launchDetails?.notificationResponse?.payload;
    if (launchDetails?.didNotificationLaunchApp == true && payload != null) {
      _dispatchNotificationTap(payload);
    }
  }

  void setNotificationTapHandler(void Function(String payload) handler) {
    _onNotificationTap = handler;
    final pendingPayload = _pendingPayload;
    if (pendingPayload != null) {
      _pendingPayload = null;
      handler(pendingPayload);
    }
  }

  void _dispatchNotificationTap(String payload) {
    final handler = _onNotificationTap;
    if (handler == null) {
      _pendingPayload = payload;
    } else {
      handler(payload);
    }
  }

  Future<bool> requestPermission() async {
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }

    final ios = plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return true;
  }

  Future<void> showBudgetNotification({
    required String sourceId,
    required int year,
    required int month,
    required String title,
    required String message,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'budget_alerts',
        'Budget alerts',
        channelDescription: 'Notifications about budgets and monthly targets',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await plugin.show(
      id: _notificationId(sourceId, year, month),
      title: title,
      body: message,
      notificationDetails: details,
      payload: sourceId,
    );
  }

  Future<void> scheduleRecurringReminder({
    required String ruleId,
    required int notificationId,
    required String title,
    required String amount,
    required DateTime scheduledDate,
    required int reminderDays,
  }) async {
    final reminderDate = scheduledDate.subtract(Duration(days: reminderDays));
    final localReminder = DateTime(
      reminderDate.year,
      reminderDate.month,
      reminderDate.day,
      9,
    );
    final notificationTitle = reminderDays == 0
        ? '$title is due today'
        : '$title is due in $reminderDays ${reminderDays == 1 ? 'day' : 'days'}';
    final message = '$amount • ${_calendarDate(scheduledDate)}';
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'recurring_reminders',
        'Recurring expense reminders',
        channelDescription: 'Reminders for upcoming recurring expenses',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    final payload = 'recurring:$ruleId';

    if (!localReminder.isAfter(DateTime.now())) {
      await plugin.show(
        id: notificationId,
        title: notificationTitle,
        body: message,
        notificationDetails: details,
        payload: payload,
      );
      return;
    }

    await plugin.zonedSchedule(
      id: notificationId,
      title: notificationTitle,
      body: message,
      scheduledDate: timezone.TZDateTime.from(localReminder, timezone.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  Future<void> cancelRecurringReminder(String ruleId, {int? notificationId}) =>
      plugin.cancel(id: notificationId ?? recurringNotificationId(ruleId));

  int recurringNotificationId(String ruleId) =>
      _notificationId('recurring:$ruleId', 0, 0);

  String _calendarDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';

  int _notificationId(String sourceId, int year, int month) {
    var hash = 0;
    for (final unit in '$sourceId:$year:$month'.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}
