import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';

void downloadFile(String filename, Uint8List bytes, {String mimeType = 'application/octet-stream'}) {
  final XFile xFile = XFile.fromData(
    bytes,
    name: filename,
    mimeType: mimeType,
  );
  
  Share.shareXFiles(<XFile>[xFile], subject: 'Expense Report');
}
