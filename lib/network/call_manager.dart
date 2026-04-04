import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:marbylink/models/call.dart';
import 'package:marbylink/models/device.dart';
class CallManager {
  static const int PORT = 8880;
  final String _deviceId;
  final Map<String, Call> _calls = {};
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final StreamController<Call> _callController = StreamController<Call>.broadcast();
  late RawDatagramSocket _socket;
  Stream<Call> get onCallUpdate => _callController.stream;
  CallManager(this._deviceId) {
    _init();
  }
  Future<void> _init() async {
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, PORT, reuseAddress: true, reusePort: true);
      _socket.broadcastEnabled = true;
      _socket.listen(_handleDatagram);
    } catch (e) {
      print('Error initializing call manager: $e');
    }
  }
  Future<Call> makeCall(String receiverId, String receiverIp, CallType type) async {
    final callId = 'call_${Random().nextInt(1000000)}';
    final call = Call(
      id: callId,
      callerId: _deviceId,
      receiverId: receiverId,
      type: type,
      status: CallStatus.pending,
    );
    _calls[callId] = call;
    _callController.add(call);
    // 创建 WebRTC 对等连接
    final peerConnection = await _createPeerConnection(callId);
    _peerConnections[callId] = peerConnection;
    // 生成 SDP offer
    final offer = await peerConnection.createOffer();
    await peerConnection.setLocalDescription(offer);
    // 发送呼叫请求
    _sendCallRequest(callId, receiverIp, offer.toMap());
    return call;
  }
  void answerCall(String callId) async {
    final call = _calls[callId];
    if (call != null) {
      call.start();
      _callController.add(call);
      final peerConnection = _peerConnections[callId];
      if (peerConnection != null) {
        // 生成 SDP answer
        final answer = await peerConnection.createAnswer();
        await peerConnection.setLocalDescription(answer);
        // 发送呼叫响应
        _sendCallResponse(callId, answer.toMap());
      }
    }
  }
  void endCall(String callId) async {
    final call = _calls[callId];
    if (call != null) {
      call.end();
      _callController.add(call);
      final peerConnection = _peerConnections[callId];
      if (peerConnection != null) {
        await peerConnection.close();
        _peerConnections.remove(callId);
      }
      _calls.remove(callId);
    }
  }
  void rejectCall(String callId) {
    final call = _calls[callId];
    if (call != null) {
      call.reject();
      _callController.add(call);
      _calls.remove(callId);
    }
  }
  Future<RTCPeerConnection> _createPeerConnection(String callId) async {
    final configuration = {
      'iceServers': [], // 局域网内不需要 STUN/TURN 服务器
    };
    final peerConnection = await createPeerConnection(configuration);
    // 添加本地流
    final mediaConstraints = {
      'audio': true,
      'video': true,
    };
    final mediaStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    for (final track in mediaStream.getTracks()) {
      peerConnection.addTrack(track, mediaStream);
    }
    // 处理远程流
    peerConnection.onTrack = (RTCTrackEvent event) {
      // 处理远程媒体流
    };
    // 处理 ICE 候选
    peerConnection.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate != null) {
        // 发送 ICE 候选
        _sendIceCandidate(callId, candidate.toMap());
      }
    };
    return peerConnection;
  }
  void _sendCallRequest(String callId, String receiverIp, Map<String, dynamic> offer) {
    final message = json.encode({
      'type': 'call_request',
      'callId': callId,
      'callerId': _deviceId,
      'receiverId': _calls[callId]?.receiverId,
      'callType': _calls[callId]?.type.toString().split('.').last,
      'offer': offer,
    });
    final data = utf8.encode(message);
    _socket.send(data, InternetAddress(receiverIp), PORT);
  }
  void _sendCallResponse(String callId, Map<String, dynamic> answer) {
    final call = _calls[callId];
    if (call != null) {
      final message = json.encode({
        'type': 'call_response',
        'callId': callId,
        'receiverId': _deviceId,
        'callerId': call.callerId,
        'answer': answer,
      });
      final data = utf8.encode(message);
      // 这里需要知道 caller 的 IP 地址
      // 暂时使用广播
      _socket.send(data, InternetAddress('255.255.255.255'), PORT);
    }
  }
  void _sendIceCandidate(String callId, Map<String, dynamic> candidate) {
    final call = _calls[callId];
    if (call != null) {
      final message = json.encode({
        'type': 'ice_candidate',
        'callId': callId,
        'candidate': candidate,
        'senderId': _deviceId,
        'receiverId': call.callerId == _deviceId ? call.receiverId : call.callerId,
      });
      final data = utf8.encode(message);
      // 暂时使用广播发送 ICE 候选
      _socket.send(data, InternetAddress('255.255.255.255'), PORT);
    }
  }
  void _handleDatagram(RawSocketEvent event) {
    if (event == RawSocketEvent.read) {
      final datagram = _socket.receive();
      if (datagram != null) {
        try {
          final message = utf8.decode(datagram.data);
          final data = json.decode(message);
          switch (data['type']) {
            case 'call_request':
              _handleCallRequest(data, datagram.address.address);
              break;
            case 'call_response':
              _handleCallResponse(data);
              break;
            case 'ice_candidate':
              _handleIceCandidate(data);
              break;
          }
        } catch (e) {
          print('Error handling call datagram: $e');
        }
      }
    }
  }
  void _handleCallRequest(Map<String, dynamic> data, String callerIp) {
    final callId = data['callId'];
    final callerId = data['callerId'];
    final receiverId = data['receiverId'];
    final callType = data['callType'] == 'video' ? CallType.video : CallType.voice;
    if (receiverId == _deviceId) {
      final call = Call(
        id: callId,
        callerId: callerId,
        receiverId: receiverId,
        type: callType,
        status: CallStatus.ringing,
      );
      _calls[callId] = call;
      _callController.add(call);
      // 创建 WebRTC 对等连接
      _createPeerConnection(callId).then((peerConnection) {
        _peerConnections[callId] = peerConnection;
        // 设置远程描述
        final offer = RTCSessionDescription(data['offer']['sdp'], data['offer']['type']);
        peerConnection.setRemoteDescription(offer);
      });
    }
  }
  void _handleCallResponse(Map<String, dynamic> data) {
    final callId = data['callId'];
    final callerId = data['callerId'];
    if (callerId == _deviceId) {
      final call = _calls[callId];
      if (call != null) {
        call.start();
        _callController.add(call);
        final peerConnection = _peerConnections[callId];
        if (peerConnection != null) {
          // 设置远程描述
          final answer = RTCSessionDescription(data['answer']['sdp'], data['answer']['type']);
          peerConnection.setRemoteDescription(answer);
        }
      }
    }
  }
  void _handleIceCandidate(Map<String, dynamic> data) {
    final callId = data['callId'];
    final candidate = RTCIceCandidate(
      data['candidate']['candidate'],
      data['candidate']['sdpMid'],
      data['candidate']['sdpMLineIndex'],
    );
    final peerConnection = _peerConnections[callId];
    if (peerConnection != null) {
      peerConnection.addCandidate(candidate);
    }
  }
  void dispose() {
    for (final peerConnection in _peerConnections.values) {
      peerConnection.close();
    }
    _peerConnections.clear();
    _calls.clear();
    _callController.close();
    _socket.close();
  }
}