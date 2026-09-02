import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';

/// Centralized session persistence manager for WorkGo multi-role applications.
/// 
/// Provides persistent role-isolated storage across:
/// 1. Customer (`UserRole.customer`)
/// 2. Worker / Karya Artisan (`UserRole.worker`)
/// 3. Cooperative Administrator (`UserRole.admin`)
/// 
/// Keeps each role's session separate so switching or reloading apps never
/// kicks users out or forces repeated logins.
class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  static SessionManager get instance => _instance;
  SessionManager._internal();

  static const String _keyPrefix = "workgo_session_";
  static const String _lastActiveRoleKey = "workgo_last_active_role";
  static const String _rememberMeKey = "workgo_remember_me";

  final Map<UserRole, AppUser?> _memoryCache = {};
  bool _isInitialized = false;

  /// Prefix key for each role's session
  String _sessionKey(UserRole role) => "$_keyPrefix${role.name}";

  /// Pre-warm session cache from disk on app startup
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final role in UserRole.values) {
        final jsonStr = prefs.getString(_sessionKey(role));
        if (jsonStr != null && jsonStr.isNotEmpty) {
          try {
            final Map<String, dynamic> map = jsonDecode(jsonStr);
            _memoryCache[role] = AppUser.fromMap(map);
          } catch (e) {
            debugPrint("[SessionManager] Error parsing cached session for ${role.name}: $e");
          }
        }
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint("[SessionManager] Failed to initialize SharedPreferences: $e");
    }
  }

  /// Save active user session for a specific role
  Future<void> saveSession(AppUser user, {bool setAsLastActive = true}) async {
    _memoryCache[user.role] = user;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(user.toMap());
      await prefs.setString(_sessionKey(user.role), jsonStr);
      if (setAsLastActive) {
        await prefs.setString(_lastActiveRoleKey, user.role.name);
      }
      await prefs.setBool(_rememberMeKey, true);
    } catch (e) {
      debugPrint("[SessionManager] Failed to save session for ${user.role.name}: $e");
    }
  }

  /// Retrieve cached user session for a role (checks memory cache first, then disk)
  Future<AppUser?> getCachedSession(UserRole role) async {
    if (_memoryCache.containsKey(role) && _memoryCache[role] != null) {
      return _memoryCache[role];
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_sessionKey(role));
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> map = jsonDecode(jsonStr);
        final user = AppUser.fromMap(map);
        _memoryCache[role] = user;
        return user;
      }
    } catch (e) {
      debugPrint("[SessionManager] Failed to read session for ${role.name}: $e");
    }
    return null;
  }

  /// Synchronous retrieval (available if `init()` or `getCachedSession()` was called earlier)
  AppUser? getCachedSessionSync(UserRole role) {
    return _memoryCache[role];
  }

  /// Check if a valid session exists for a role
  Future<bool> hasActiveSession(UserRole role) async {
    final user = await getCachedSession(role);
    return user != null && user.uid.isNotEmpty;
  }

  /// Clear session for a specific role (called upon explicit logout)
  Future<void> clearSession(UserRole role) async {
    _memoryCache.remove(role);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey(role));
      final lastRole = prefs.getString(_lastActiveRoleKey);
      if (lastRole == role.name) {
        await prefs.remove(_lastActiveRoleKey);
      }
    } catch (e) {
      debugPrint("[SessionManager] Failed to clear session for ${role.name}: $e");
    }
  }

  /// Clear all stored user sessions across all roles
  Future<void> clearAllSessions() async {
    _memoryCache.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final role in UserRole.values) {
        await prefs.remove(_sessionKey(role));
      }
      await prefs.remove(_lastActiveRoleKey);
      await prefs.remove(_rememberMeKey);
    } catch (e) {
      debugPrint("[SessionManager] Failed to clear all sessions: $e");
    }
  }

  /// Get the last active role saved on this device
  Future<UserRole?> getLastActiveRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final roleStr = prefs.getString(_lastActiveRoleKey);
      if (roleStr != null) {
        return UserRole.values.firstWhere(
          (r) => r.name == roleStr,
          orElse: () => UserRole.customer,
        );
      }
    } catch (_) {}
    return null;
  }
}
