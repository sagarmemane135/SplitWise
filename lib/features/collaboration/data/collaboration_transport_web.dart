// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:js' as js;

import 'collaboration_transport.dart';

class _PeerJsCollaborationTransport extends CollaborationTransport {
  js.JsObject? _peer;
  final Map<String, js.JsObject> _connections = <String, js.JsObject>{};
  Timer? _reconnectTimer;

  @override
  Future<String> initPeer() async {
    if (_peer != null) {
      final dynamic currentId = _peer!['id'];
      if (currentId != null && currentId.toString().isNotEmpty) {
        return currentId.toString();
      }
    }

    final dynamic peerConstructor = js.context['Peer'];
    if (peerConstructor == null) {
      throw StateError('PeerJS was not found on window. Ensure CDN script is loaded.');
    }

    final Map<String, dynamic> options = <String, dynamic>{
      'host': '0.peerjs.com',
      'port': 443,
      'path': '/',
      'secure': true,
      'debug': 1, // Reduced debug noise
      'config': <String, dynamic>{
        'iceServers': <Map<String, dynamic>>[
          <String, String>{'urls': 'stun:stun.l.google.com:19302'},
          <String, String>{'urls': 'stun:stun1.l.google.com:19302'},
          <String, String>{'urls': 'stun:stun2.l.google.com:19302'},
          <String, String>{'urls': 'stun:stun3.l.google.com:19302'},
          <String, String>{'urls': 'stun:stun4.l.google.com:19302'},
          <String, String>{'urls': 'stun:openrelay.metered.ca:80'},
          <String, dynamic>{
            'urls': <String>[
              'turn:openrelay.metered.ca:80',
              'turn:openrelay.metered.ca:443',
              'turns:openrelay.metered.ca:443',
            ],
            'username': 'openrelayproject',
            'credential': 'openrelayproject',
          },
        ],
        'sdpSemantics': 'unified-plan',
        'iceCandidatePoolSize': 10,
      },
    };

    _peer = js.JsObject(peerConstructor, <dynamic>[js.JsObject.jsify(options)]);

    _peer!.callMethod(
      'on',
      <dynamic>[
        'open',
        (dynamic id) {
          final String peerId = id.toString();
          onPeerOpen?.call(peerId);
        },
      ],
    );

    _peer!.callMethod(
      'on',
      <dynamic>[
        'connection',
        (dynamic connection) {
          if (connection is js.JsObject) {
            _attachConnection(connection);
          }
        },
      ],
    );

    _peer!.callMethod(
      'on',
      <dynamic>[
        'disconnected',
        () {
          onError?.call('Disconnected from PeerJS server. Reconnecting...');
        },
      ],
    );

    _peer!.callMethod(
      'on',
      <dynamic>[
        'error',
        (dynamic error) {
          final String errorText = error.toString();
          final String? errorType = _readJsStringProperty(error, 'type');
          if (errorType != null &&
              <String>{'server-error', 'socket-error', 'webrtc'}.contains(errorType)) {
            _schedulePeerReinitialize();
          }
          onError?.call(errorType == null ? errorText : '$errorType: $errorText');
        },
      ],
    );

    return await _waitForPeerId();
  }

  Future<String> _waitForPeerId() async {
    for (int i = 0; i < 40; i++) {
      final dynamic id = _peer!['id'];
      if (id != null && id.toString().isNotEmpty) {
        return id.toString();
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw StateError('Peer initialization timed out.');
  }

  @override
  Future<void> connect(String remotePeerId) async {
    int attempts = 0;
    const int maxAttempts = 3;
    StateError? lastError;

    while (attempts < maxAttempts) {
      try {
        attempts++;
        if (attempts > 1) {
          onError?.call('Retrying connection (Attempt $attempts of $maxAttempts)...');
          await Future<void>.delayed(const Duration(seconds: 2));
        }
        await _attemptConnect(remotePeerId);
        return; // Success
      } on StateError catch (e) {
        lastError = e;
        // Don't retry if peer is clearly unavailable
        if (e.message.contains('peer-unavailable')) break;
      } catch (e) {
        lastError = StateError(e.toString());
      }
    }
    throw lastError ?? StateError('Connection failed after $maxAttempts attempts.');
  }

  Future<void> _attemptConnect(String remotePeerId) async {
    if (_peer == null) {
      await initPeer();
    }

    final dynamic connection = _peer!.callMethod(
      'connect',
      <dynamic>[
        remotePeerId,
        js.JsObject.jsify(<String, dynamic>{'reliable': true, 'serialization': 'json'}),
      ],
    );

    if (connection is! js.JsObject) {
      throw StateError('PeerJS did not return a valid connection object.');
    }

    final Completer<void> completer = Completer<void>();
    late final Timer timeout;
    bool settled = false;

    void finishSuccess() {
      if (!settled) {
        settled = true;
        timeout.cancel();
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    }

    void finishError(String message) {
      if (!settled) {
        settled = true;
        timeout.cancel();
        if (!completer.isCompleted) {
          completer.completeError(StateError(message));
        }
      }
    }

    // Increased timeout for mobile/cellular networks
    timeout = Timer(const Duration(seconds: 30), () {
      finishError('Connection timeout. Ensure host is online and try again.');
      try {
        connection.callMethod('close', <dynamic>[]);
      } catch (_) {}
    });

    connection.callMethod(
      'on',
      <dynamic>[
        'open',
        () {
          finishSuccess();
        },
      ],
    );

    connection.callMethod(
      'on',
      <dynamic>[
        'error',
        (dynamic err) {
          final String? type = _readJsStringProperty(err, 'type');
          finishError(type == 'peer-unavailable'
              ? 'Host peer is unavailable. Check invite link and host status.'
              : 'Connection failed ($type). Check both devices network and retry.');
        },
      ],
    );

    _attachConnection(connection);
    return completer.future;
  }

  void _attachConnection(js.JsObject connection) {
    final String remotePeerId = connection['peer'].toString();
    _connections[remotePeerId] = connection;

    connection.callMethod(
      'on',
      <dynamic>[
        'open',
        () {
          onConnectionOpen?.call(remotePeerId);
        },
      ],
    );

    connection.callMethod(
      'on',
      <dynamic>[
        'close',
        () {
          _connections.remove(remotePeerId);
          onConnectionClosed?.call(remotePeerId);
        },
      ],
    );

    connection.callMethod(
      'on',
      <dynamic>[
        'error',
        (dynamic error) {
          onError?.call(error.toString());
        },
      ],
    );

    connection.callMethod(
      'on',
      <dynamic>[
        'data',
        (dynamic raw) {
          final Map<String, dynamic>? payload = _parsePayload(raw);
          if (payload != null) {
            onMessage?.call(CollaborationMessage(fromPeerId: remotePeerId, payload: payload));
          }
        },
      ],
    );
  }

  Map<String, dynamic>? _parsePayload(dynamic raw) {
    try {
      if (raw is String) {
        return jsonDecode(raw) as Map<String, dynamic>;
      }
      if (raw is js.JsObject) {
        final String json = js.context['JSON'].callMethod('stringify', <dynamic>[raw]) as String;
        return jsonDecode(json) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  void sendTo(String remotePeerId, Map<String, dynamic> payload) {
    final js.JsObject? connection = _connections[remotePeerId];
    if (connection == null) {
      return;
    }
    connection.callMethod('send', <dynamic>[jsonEncode(payload)]);
  }

  @override
  void broadcast(Map<String, dynamic> payload) {
    for (final String peerId in _connections.keys.toList()) {
      sendTo(peerId, payload);
    }
  }

  @override
  List<String> get connectedPeerIds => _connections.keys.toList(growable: false);

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    for (final js.JsObject connection in _connections.values) {
      try {
        connection.callMethod('close', <dynamic>[]);
      } catch (_) {}
    }
    _connections.clear();

    if (_peer != null) {
      try {
        _peer!.callMethod('destroy', <dynamic>[]);
      } catch (_) {}
      _peer = null;
    }
  }

  void _schedulePeerReinitialize() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () async {
      try {
        final String? existingId = _peer == null ? null : _peer!['id']?.toString();
        if (_peer != null) {
          _peer!.callMethod('destroy', <dynamic>[]);
          _peer = null;
        }
        await initPeer();
        if (existingId != null && existingId.isNotEmpty && _peer != null) {
          onError?.call('PeerJS reinitialized (previous id: $existingId).');
        }
      } catch (e) {
        onError?.call('PeerJS reinitialize failed: $e');
      }
    });
  }

  String? _readJsStringProperty(dynamic obj, String key) {
    try {
      if (obj is js.JsObject) {
        final dynamic value = obj[key];
        if (value != null) {
          return value.toString();
        }
      }
    } catch (_) {}
    return null;
  }
}

CollaborationTransport createCollaborationTransportImpl() => _PeerJsCollaborationTransport();
