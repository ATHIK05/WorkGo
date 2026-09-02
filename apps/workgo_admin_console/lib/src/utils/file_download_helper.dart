import 'dart:typed_data';
import 'file_download_helper_stub.dart'
    if (dart.library.html) 'file_download_helper_web.dart' as impl;

class FileDownloadHelper {
  FileDownloadHelper._();

  /// Triggers a native browser file download of raw bytes using HTML5 Blob / Anchor Element.
  static void downloadInBrowser(Uint8List bytes, String fileName, {String mimeType = 'application/zip'}) {
    impl.triggerBrowserDownload(bytes, fileName, mimeType: mimeType);
  }
}
