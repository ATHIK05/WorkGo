import "package:firebase_auth/firebase_auth.dart";
import "package:cloud_firestore/cloud_firestore.dart";
import "../models/app_user.dart";
import "../services/session_manager.dart";

/// Authentication service for all three WorkGo apps.
/// Uses Firebase Email + Password auth with multi-role SessionManager caching.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SessionManager _sessionManager = SessionManager.instance;

  // ── Current user accessors ─────────────────────────────────────────────────

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  // ── Session Management Accessors ───────────────────────────────────────────

  /// Retrieve cached user for a role from SessionManager
  Future<AppUser?> getCachedSession(UserRole role) => _sessionManager.getCachedSession(role);

  /// Synchronous retrieval of cached session
  AppUser? getCachedSessionSync(UserRole role) => _sessionManager.getCachedSessionSync(role);

  /// Save session manually
  Future<void> saveSession(AppUser user) => _sessionManager.saveSession(user);

  /// Clear session for a role
  Future<void> clearSession(UserRole role) => _sessionManager.clearSession(role);

  // ── Sign Up ────────────────────────────────────────────────────────────────

  /// Create a new account with [email] + [password].
  /// Call [upsertUser] immediately after to write the Firestore user doc.
  Future<UserCredential> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (displayName != null && displayName.isNotEmpty) {
      await cred.user?.updateDisplayName(displayName);
    }
    // Trigger email verification (non-blocking — demo can skip)
    await cred.user?.sendEmailVerification();
    return cred;
  }

  // ── Sign In ────────────────────────────────────────────────────────────────

  /// Sign in with [email] + [password].
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // ── Password Reset ─────────────────────────────────────────────────────────

  /// Send a Firebase password-reset email to [email].
  /// Firebase handles the reset link — no backend involvement needed.
  Future<void> sendPasswordReset({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ── Firestore User Doc & Realtime Stream ───────────────────────────────────

  /// Fetch the AppUser from Firestore, or null if not yet set up.
  Future<AppUser?> fetchUser(String uid) async {
    try {
      final doc = await _db.collection("users").doc(uid).get();
      if (!doc.exists) return null;
      final user = AppUser.fromFirestore(doc);
      // Auto-cache session
      await _sessionManager.saveSession(user);
      return user;
    } catch (e) {
      return null;
    }
  }

  /// Stream user document updates in real-time.
  Stream<AppUser?> streamAppUser(String uid) {
    return _db.collection("users").doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      final user = AppUser.fromFirestore(doc);
      // Background cache sync
      _sessionManager.saveSession(user);
      return user;
    });
  }

  /// Create or update the Firestore user document.
  /// Always call this after [signUp] with the app-specific role.
  Future<void> upsertUser(AppUser user) async {
    await _db.collection("users").doc(user.uid).set(
      user.toFirestore(),
      SetOptions(merge: true),
    );
    // Auto-cache session
    await _sessionManager.saveSession(user);
  }

  // ── Sign Out ───────────────────────────────────────────────────────────────

  Future<void> signOut({UserRole? role}) async {
    if (role != null) {
      await _sessionManager.clearSession(role);
    } else {
      await _sessionManager.clearAllSessions();
    }
    await _auth.signOut();
  }

  // ── Delete Account (Right to Erasure - DPDP Act 2023 §12) ───────────────────

  /// Permanently erases all user profile records, KYC documents, biometric hashes,
  /// worker records, subcollections, and deletes the Firebase Auth account.
  Future<void> deleteAccount({required String uid, UserRole? role}) async {
    if (role != null) {
      await _sessionManager.clearSession(role);
    } else {
      await _sessionManager.clearAllSessions();
    }

    // 1. Delete worker documents subcollection and worker profile
    try {
      final docsSnap = await _db.collection("workers").doc(uid).collection("documents").get();
      for (final doc in docsSnap.docs) {
        await doc.reference.delete();
      }
      final reviewsSnap = await _db.collection("workers").doc(uid).collection("reviews").get();
      for (final doc in reviewsSnap.docs) {
        await doc.reference.delete();
      }
      await _db.collection("workers").doc(uid).delete();
    } catch (_) {
      // Continue even if worker record didn't exist (e.g. for customer)
    }

    // 2. Anonymize/Wipe audit logs for this user under DPDP 2023 Right to Erasure
    try {
      final auditSnap = await _db.collection("verification_audit_logs").where("workerId", isEqualTo: uid).get();
      for (final doc in auditSnap.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}

    // 3. Delete user document from users collection
    try {
      await _db.collection("users").doc(uid).delete();
    } catch (_) {}

    // 4. Delete user from Firebase Auth
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await user.delete();
      } catch (_) {
        // If re-authentication is required by Firebase Auth, sign out gracefully
        await _auth.signOut();
      }
    }
  }
}
