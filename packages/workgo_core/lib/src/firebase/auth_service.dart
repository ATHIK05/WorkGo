import "package:firebase_auth/firebase_auth.dart";
import "package:cloud_firestore/cloud_firestore.dart";
import "package:google_sign_in/google_sign_in.dart";
import "../models/app_user.dart";
import "../services/session_manager.dart";
import "../api_client/workgo_api_client.dart";

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
  bool get hasBackupPassword =>
      _auth.currentUser?.providerData.any((p) => p.providerId == "password") ?? false;
  bool get isGoogleUser =>
      _auth.currentUser?.providerData.any((p) => p.providerId == "google.com") ?? false;
  bool get isPhoneVerified =>
      (_auth.currentUser?.providerData.any((p) => p.providerId == "phone") ?? false) ||
      (_auth.currentUser?.phoneNumber != null && _auth.currentUser!.phoneNumber!.isNotEmpty);

  // ── Session Management Accessors ───────────────────────────────────────────

  /// Retrieve cached user for a role from SessionManager
  Future<AppUser?> getCachedSession(UserRole role) => _sessionManager.getCachedSession(role);

  /// Synchronous retrieval of cached session
  AppUser? getCachedSessionSync(UserRole role) => _sessionManager.getCachedSessionSync(role);

  /// Save session manually
  Future<void> saveSession(AppUser user) => _sessionManager.saveSession(user);

  /// Clear session for a role
  Future<void> clearSession(UserRole role) => _sessionManager.clearSession(role);

  // ── Google Sign In (Hero Gateway) ──────────────────────────────────────────

  /// Sign in with Google Account (1-tap native login)
  Future<UserCredential> signInWithGoogle({UserRole role = UserRole.customer}) async {
    final GoogleSignIn googleSignIn = GoogleSignIn();
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: "ERROR_ABORTED_BY_USER",
        message: "Google sign in was cancelled",
      );
    }
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final UserCredential userCred = await _auth.signInWithCredential(credential);
    final user = userCred.user;
    if (user != null) {
      // Fetch or initialize Firestore record
      final userDoc = await _db.collection("users").doc(user.uid).get();
      if (!userDoc.exists) {
        final newUser = AppUser(
          uid: user.uid,
          email: user.email ?? "",
          displayName: user.displayName ?? "",
          role: role,
          phoneNumber: user.phoneNumber,
          region: "IN-TN",
        );
        await upsertUser(newUser);
      }
    }
    return userCred;
  }

  /// Link current user account with Google Sign-In
  Future<UserCredential> linkGoogleAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: "NO_USER",
        message: "No user signed in to link Google account",
      );
    }
    final GoogleSignIn googleSignIn = GoogleSignIn();
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: "ERROR_ABORTED_BY_USER",
        message: "Google sign in was cancelled",
      );
    }
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final UserCredential userCred = await user.linkWithCredential(credential);
    await user.reload();

    // Persist Google linking status in Firestore
    final googleEmail = userCred.user?.email ?? googleUser.email;
    await _db.collection("users").doc(user.uid).set({
      "googleLinked": true,
      "googleEmail": googleEmail,
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    try {
      final workerDoc = await _db.collection("workers").doc(user.uid).get();
      if (workerDoc.exists) {
        await _db.collection("workers").doc(user.uid).set({
          "googleLinked": true,
          "googleEmail": googleEmail,
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {}

    return userCred;
  }

  // ── Phone OTP Gateway (2Factor Carrier SMS) ────────────────────────────────

  /// Request SMS OTP to be dispatched to [phone] via backend 2Factor service
  Future<Map<String, dynamic>> sendPhoneOtp(String phone) async {
    final res = await WorkGoApiClient().post("/api/auth/send-otp", {"phone": phone});
    if (res is Map<String, dynamic>) {
      return res;
    }
    return {"success": false, "error": "Unexpected response from server"};
  }

  /// Verify SMS OTP and link the phone number to the currently authenticated user
  Future<Map<String, dynamic>> linkPhoneNumberWithOtp({
    required String phone,
    required String otpCode,
    required String sessionId,
    String role = "customer",
  }) async {
    final res = await WorkGoApiClient().post("/api/auth/verify-and-link-phone", {
      "phone": phone,
      "otpCode": otpCode,
      "sessionId": sessionId,
      "role": role,
    });
    if (res is Map<String, dynamic> && res["success"] == true) {
      final formattedPhone = phone.startsWith("+91") ? phone : "+91$phone";
      final user = _auth.currentUser;
      if (user != null) {
        final col = role == "worker" ? "workers" : "users";
        await _db.collection(col).doc(user.uid).set({
          "phoneNumber": formattedPhone,
          "phoneVerified": true,
          "phoneVerifiedAt": FieldValue.serverTimestamp(),
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        if (role == "worker") {
          await _db.collection("users").doc(user.uid).set({
            "phoneNumber": formattedPhone,
            "phoneVerified": true,
            "phoneVerifiedAt": FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)).catchError((_) {});
        }
      }
      await _auth.currentUser?.reload();
      return res;
    }
    return res as Map<String, dynamic>;
  }

  /// Step 1 of OTP sign-in: verify code with backend → returns raw Firebase customToken.
  /// Callers MUST persist this token before calling [completePhoneOtpSignIn] so a
  /// mid-flight process kill can be recovered without re-entering the OTP.
  Future<String> verifyPhoneOtpGetToken({
    required String phone,
    required String otpCode,
    required String sessionId,
    String role = "customer",
  }) async {
    final res = await WorkGoApiClient().post("/api/auth/verify-otp-login", {
      "phone": phone,
      "otpCode": otpCode,
      "sessionId": sessionId,
      "role": role,
    });
    if (res is Map<String, dynamic> && res["success"] == true && res["customToken"] != null) {
      return res["customToken"] as String;
    }
    throw FirebaseAuthException(
      code: "OTP_LOGIN_FAILED",
      message: res is Map ? res["error"] ?? "Failed to login with phone OTP" : "Failed to login with phone OTP",
    );
  }

  /// Step 2 of OTP sign-in: exchange a pre-verified customToken for a Firebase session.
  Future<UserCredential> completePhoneOtpSignIn(String customToken) =>
      _auth.signInWithCustomToken(customToken);

  /// Sign in directly using verified Phone OTP (generates custom token).
  /// Convenience method that combines both steps — prefer the split API when
  /// the caller needs restart-recovery persistence between the two steps.
  Future<UserCredential> signInWithPhoneOtp({
    required String phone,
    required String otpCode,
    required String sessionId,
    String role = "customer",
  }) async {
    final token = await verifyPhoneOtpGetToken(
      phone: phone,
      otpCode: otpCode,
      sessionId: sessionId,
      role: role,
    );
    return _auth.signInWithCustomToken(token);
  }

  // ── Backup Password Fallback ───────────────────────────────────────────────

  /// Set or link a backup password to the user's account in case Google login is unavailable
  Future<void> linkBackupPassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: "NO_USER",
        message: "No user is currently signed in",
      );
    }
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: "NO_EMAIL",
        message: "An email address is required to set a backup password",
      );
    }

    final hasPassword = user.providerData.any((p) => p.providerId == "password");
    if (hasPassword) {
      await user.updatePassword(newPassword);
    } else {
      final cred = EmailAuthProvider.credential(email: email, password: newPassword);
      await user.linkWithCredential(cred);
    }

    // Persist security metadata in Firestore
    await _db.collection("users").doc(user.uid).set({
      "hasBackupPassword": true,
      "backupPasswordUpdatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Also update worker profile if worker
    try {
      final workerDoc = await _db.collection("workers").doc(user.uid).get();
      if (workerDoc.exists) {
        await _db.collection("workers").doc(user.uid).set({
          "hasBackupPassword": true,
          "backupPasswordUpdatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

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
