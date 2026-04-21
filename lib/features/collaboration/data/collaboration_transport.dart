import 'collaboration_transport_stub.dart'
    if (dart.library.html) 'collaboration_transport_web.dart' as impl;

class CollaborationMessage {
  const CollaborationMessage({required this.fromPeerId, required this.payload});

  final String fromPeerId;
  final Map<String, dynamic> payload;
}

abstract class CollaborationTransport {
  void Function(String peerId)? onPeerOpen;
  void Function(String peerId)? onConnectionOpen;
  void Function(String peerId)? onConnectionClosed;
  void Function(String error)? onError;
  void Function(CollaborationMessage message)? onMessage;

  Future<String> initPeer();
  Future<void> connect(String remotePeerId);
  void sendTo(String remotePeerId, Map<String, dynamic> payload);
  void broadcast(Map<String, dynamic> payload);
  List<String> get connectedPeerIds;
  void dispose();
}

CollaborationTransport createCollaborationTransport() => impl.createCollaborationTransportImpl();
