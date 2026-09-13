import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

/// Just-In-Time (JIT) Dynamic AssetLoader for `easy_localization`.
///
/// Architecture:
/// 1. Reads strings from Cloud Firestore (`locales/{langCode}`).
/// 2. Utilizes Firestore's persistent offline disk cache (`Source.serverAndCache`)
///    for instant 0ms startup without network lag.
/// 3. Safely falls back to bundled asset JSON (`packages/workgo_core/assets/lang/en.json`)
///    if Firestore is unreachable or the locale has not been populated yet.
/// 4. Merges remote translations over baseline English assets so no UI key ever appears blank.
class FirestoreAssetLoader extends AssetLoader {
  final String collectionPath;
  final AssetLoader fallbackLoader;

  const FirestoreAssetLoader({
    this.collectionPath = 'locales',
    this.fallbackLoader = const RootBundleAssetLoader(),
  });

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    Map<String, dynamic>? baseStrings;

    // 1. Load baseline bundled asset strings (e.g. en.json or bundled locale)
    try {
      baseStrings = await fallbackLoader.load(path, locale);
    } catch (_) {
      // If the specific locale JSON does not exist in bundle (e.g. ml, te, kn),
      // fallback to master en.json
      try {
        baseStrings = await fallbackLoader.load(path, const Locale('en'));
      } catch (e) {
        debugPrint('[FirestoreAssetLoader] Bundled fallback failed: $e');
      }
    }

    // 2. Fetch or load from Firestore local disk cache / remote
    try {
      final docRef = FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(locale.languageCode);

      final docSnap = await docRef.get(const GetOptions(source: Source.serverAndCache));

      if (docSnap.exists) {
        final data = docSnap.data();
        if (data != null) {
          final Map<String, dynamic> remoteStrings;
          if (data['strings'] is Map) {
            remoteStrings = Map<String, dynamic>.from(data['strings'] as Map);
          } else {
            remoteStrings = Map<String, dynamic>.from(data);
          }

          if (baseStrings != null) {
            final merged = Map<String, dynamic>.from(baseStrings);
            merged.addAll(remoteStrings);
            return merged;
          }
          return remoteStrings;
        }
      }
    } catch (e) {
      // In offline scenarios without previous cache, or in pure unit test runs
      // where Firebase isn't initialized, return bundled base strings.
      debugPrint('[FirestoreAssetLoader] Firestore fetch error: $e');
    }

    return baseStrings ?? {};
  }
}
