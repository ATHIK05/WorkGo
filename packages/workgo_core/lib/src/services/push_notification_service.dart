import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../firebase_options.dart';

/// Top-level background message handler for FCM.
/// Must be a top-level function annotated with @pragma('vm:entry-point').
@pragma('vm:entry-point')
Future<void> workgoFirebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: WorkGoFirebaseOptions.currentPlatform);
    }
  } catch (_) {}
  debugPrint('[WorkGo FCM Background] Message received: ${message.messageId}, event: ${message.data['eventKey']}');
}

/// Comprehensive Push Notification Service for WorkGo (Customer & Karya)
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  bool _isInitialized = false;
  String? _currentUserType;
  String? _currentUserId;
  String? get currentUserId => _currentUserId;
  StreamSubscription<String>? _tokenRefreshSub;

  /// Signature WorkGo notification icon and accent color
  static const String notificationIconName = 'ic_stat_workgo';
  static const int notificationAccentColorValue = 0xFFE8A400; // Sunflower Gold / Amber

  /// Android Channels configured on the backend
  static const String channelBroadcast = 'workgo_broadcast_channel';
  static const String channelBooking = 'workgo_booking_channel';
  static const String channelEmergency = 'workgo_emergency_channel';
  static const String channelKyc = 'workgo_kyc_channel';

  /// Initialize permissions, presentation options, and notification listeners
  Future<void> initialize({required String userType}) async {
    if (_isInitialized) return;
    _currentUserType = userType;

    try {
      // 1. Register top-level background handler
      FirebaseMessaging.onBackgroundMessage(workgoFirebaseMessagingBackgroundHandler);

      // 2. Request user permissions (iOS & Android 13+)
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: userType == 'worker', // Allow critical alerts for emergency SOS
        provisional: false,
        sound: true,
      );

      debugPrint('[WorkGo Push] Permission status: ${settings.authorizationStatus}');

      // 3. Set foreground presentation options
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 4. Foreground message listener
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 5. Notification tap while app in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // 6. Cold-start tap check
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('[WorkGo Push] Initialization error: $e');
    }
  }

  String? _lastSyncedUserId;
  String? _lastSyncedToken;
  String? _lastSyncedLanguage;
  String? _lastSyncedUserType;

  /// Synchronize the device FCM token with Firestore users and workers collections
  Future<void> syncDeviceToken(
    String userId, {
    String? userType,
    String? preferredLanguage,
  }) async {
    if (userId.isEmpty) return;
    _currentUserId = userId;
    final effectiveUserType = userType ?? _currentUserType ?? 'customer';

    try {
      final token = await _fcm.getToken();
      if (token == null || token.isEmpty) return;

      if (userId == _lastSyncedUserId &&
          token == _lastSyncedToken &&
          preferredLanguage == _lastSyncedLanguage &&
          effectiveUserType == _lastSyncedUserType) {
        return;
      }

      debugPrint('[WorkGo Push] Device token obtained: ${token.substring(0, 12)}...');
      await _saveTokenToFirestore(userId, token, effectiveUserType, preferredLanguage);

      _lastSyncedUserId = userId;
      _lastSyncedToken = token;
      _lastSyncedLanguage = preferredLanguage;
      _lastSyncedUserType = effectiveUserType;

      // Cancel previous subscription and listen to token rotations
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _fcm.onTokenRefresh.listen((newToken) async {
        debugPrint('[WorkGo Push] Device token refreshed');
        await _saveTokenToFirestore(userId, newToken, effectiveUserType, preferredLanguage);
        _lastSyncedToken = newToken;
      });
    } catch (e) {
      debugPrint('[WorkGo Push] Token sync error: $e');
    }
  }

  Future<void> _saveTokenToFirestore(
    String userId,
    String token,
    String userType,
    String? preferredLanguage,
  ) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      // Always update users/{userId}
      final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
      batch.set(
        userRef,
        {
          'fcmToken': token,
          'fcmTokens': FieldValue.arrayUnion([token]),
          'platform': defaultTargetPlatform.name,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
          if (preferredLanguage != null) 'preferredLanguage': preferredLanguage,
        },
        SetOptions(merge: true),
      );

      // If worker, also sync to workers/{userId}
      if (userType == 'worker') {
        final workerRef = FirebaseFirestore.instance.collection('workers').doc(userId);
        batch.set(
          workerRef,
          {
            'fcmToken': token,
            'fcmTokens': FieldValue.arrayUnion([token]),
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
      debugPrint('[WorkGo Push] Token written to Firestore for $userId ($userType)');
    } catch (e) {
      debugPrint('[WorkGo Push] Failed to write token to Firestore: $e');
    }
  }

  /// Subscribe to a specific trade topic for broadcast requests (e.g. topic_trades_plumbing)
  Future<void> subscribeToTradeTopic(String tradeName) async {
    if (tradeName.isEmpty) return;
    try {
      final sanitized = tradeName.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
      await _fcm.subscribeToTopic('topic_trades_$sanitized');
      debugPrint('[WorkGo Push] Subscribed to topic_trades_$sanitized');
    } catch (e) {
      debugPrint('[WorkGo Push] Topic subscribe error: $e');
    }
  }

  /// Unsubscribe from a trade topic
  Future<void> unsubscribeFromTradeTopic(String tradeName) async {
    if (tradeName.isEmpty) return;
    try {
      final sanitized = tradeName.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
      await _fcm.unsubscribeFromTopic('topic_trades_$sanitized');
    } catch (_) {}
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[WorkGo Push] Foreground message: ${message.notification?.title}');
    final data = message.data;
    final eventKey = data['eventKey'];

    // Provide haptic feedback and alert chimes on high-priority incoming alerts
    if (eventKey == 'NEW_BROADCAST_REQUEST' || eventKey == 'EMERGENCY_SOS_REQUEST') {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    debugPrint('[WorkGo Push] Notification tapped. Data: $data');
    // Screen routing can inspect data['bookingId'], data['eventKey']
  }

  /// Dispose listeners
  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
  }
}
