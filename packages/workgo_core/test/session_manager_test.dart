import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workgo_core/workgo_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionManager Multi-Role Persistence Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('should save and restore customer session correctly', () async {
      final sessionManager = SessionManager();
      await sessionManager.init();

      final customer = AppUser(
        uid: 'cust_101',
        email: 'customer@workgo.coop',
        displayName: 'Rathi Customer',
        role: UserRole.customer,
        region: 'Tamil Nadu',
        phoneNumber: '+919876543210',
        location: const GeoPoint(13.0827, 80.2707),
      );

      await sessionManager.saveSession(customer);

      final restored = await sessionManager.getCachedSession(UserRole.customer);
      expect(restored, isNotNull);
      expect(restored!.uid, equals('cust_101'));
      expect(restored.email, equals('customer@workgo.coop'));
      expect(restored.displayName, equals('Rathi Customer'));
      expect(restored.role, equals(UserRole.customer));
      expect(restored.location?.latitude, equals(13.0827));
      expect(restored.location?.longitude, equals(80.2707));
    });

    test('should maintain role isolation across customer, worker, and admin', () async {
      final sessionManager = SessionManager();
      await sessionManager.init();

      final customer = AppUser(
        uid: 'cust_01',
        email: 'customer@test.com',
        displayName: 'Customer User',
        role: UserRole.customer,
        region: 'Tamil Nadu',
      );

      final worker = AppUser(
        uid: 'work_02',
        email: 'artisan@test.com',
        displayName: 'Artisan User',
        role: UserRole.worker,
        region: 'Tamil Nadu',
      );

      final admin = AppUser(
        uid: 'admin_03',
        email: 'admin@workgo.coop',
        displayName: 'Admin User',
        role: UserRole.admin,
        region: 'Tamil Nadu',
      );

      // Save all 3 sessions
      await sessionManager.saveSession(customer);
      await sessionManager.saveSession(worker);
      await sessionManager.saveSession(admin);

      // Verify all 3 sessions exist simultaneously
      final rCust = await sessionManager.getCachedSession(UserRole.customer);
      final rWork = await sessionManager.getCachedSession(UserRole.worker);
      final rAdmin = await sessionManager.getCachedSession(UserRole.admin);

      expect(rCust?.uid, equals('cust_01'));
      expect(rWork?.uid, equals('work_02'));
      expect(rAdmin?.uid, equals('admin_03'));

      // Clearing customer session should NOT affect worker or admin
      await sessionManager.clearSession(UserRole.customer);

      expect(await sessionManager.getCachedSession(UserRole.customer), isNull);
      expect(await sessionManager.getCachedSession(UserRole.worker), isNotNull);
      expect(await sessionManager.getCachedSession(UserRole.admin), isNotNull);
    });

    test('should clear all sessions when requested', () async {
      final sessionManager = SessionManager();
      await sessionManager.init();

      await sessionManager.saveSession(AppUser(
        uid: 'user_1',
        email: 'u1@test.com',
        displayName: 'U1',
        role: UserRole.worker,
        region: 'Tamil Nadu',
      ));

      expect(await sessionManager.hasActiveSession(UserRole.worker), isTrue);

      await sessionManager.clearAllSessions();

      expect(await sessionManager.hasActiveSession(UserRole.worker), isFalse);
    });
  });
}
