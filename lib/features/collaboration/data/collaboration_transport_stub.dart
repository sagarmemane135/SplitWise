import 'collaboration_transport.dart';

class _UnsupportedCollaborationTransport extends CollaborationTransport {
  @override
  Future<String> initPeer() {
    throw UnsupportedError('Peer collaboration is only supported on Flutter web in this build.');
  }

  @override
  Future<void> connect(String remotePeerId) async {
    throw UnsupportedError('Peer collaboration is only supported on Flutter web in this build.');
  }

  @override
  void sendTo(String remotePeerId, Map<String, dynamic> payload) {}

  @override
  void broadcast(Map<String, dynamic> payload) {}

  @override
  List<String> get connectedPeerIds => const <String>[];

  @override
  void dispose() {}
}

CollaborationTransport createCollaborationTransportImpl() => _UnsupportedCollaborationTransport();
