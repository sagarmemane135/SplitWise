import 'dart:html' as html;
import 'dart:typed_data';

void downloadFile(String filename, Uint8List bytes, {String mimeType = 'application/octet-stream'}) {
  final html.Blob blob = html.Blob(<dynamic>[bytes], mimeType);
  final String url = html.Url.createObjectUrlFromBlob(blob);
  
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
    
  html.Url.revokeObjectUrl(url);
}
