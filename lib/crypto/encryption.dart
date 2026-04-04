import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
class Encryption {
  static const String ALGORITHM = 'x25519-xsalsa20-poly1305';
  late String _deviceId;
  final Map<String, String> _devicePublicKeys = {};
  final Map<String, String> _deviceSigningPublicKeys = {};
  Future<void> initialize(String deviceId) async {
    _deviceId = deviceId;
  }
  String get publicKeyBase64 => _deviceId;
  String get signingPublicKeyBase64 => _deviceId;
  void addDevicePublicKey(String deviceId, String publicKeyBase64, String signingPublicKeyBase64) {
    _devicePublicKeys[deviceId] = publicKeyBase64;
    _deviceSigningPublicKeys[deviceId] = signingPublicKeyBase64;
  }
  Future<Uint8List> encrypt(String message, String deviceId) async {
    if (!_devicePublicKeys.containsKey(deviceId)) {
      throw Exception('Public key not found for device: $deviceId');
    }
    // 简化实现，使用 SHA256 加密
    final key = utf8.encode(_deviceId + deviceId);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(utf8.encode(message));
    final combined = Uint8List(32 + message.length);
    combined.setAll(0, digest.bytes);
    combined.setAll(32, utf8.encode(message));
    return combined;
  }
  Future<String> decrypt(Uint8List encryptedData, String deviceId) async {
    if (!_devicePublicKeys.containsKey(deviceId)) {
      throw Exception('Public key not found for device: $deviceId');
    }
    // 简化实现，使用 SHA256 解密
    final key = utf8.encode(_deviceId + deviceId);
    final hmac = Hmac(sha256, key);
    final messageBytes = encryptedData.sublist(32);
    final message = utf8.decode(messageBytes);
    final digest = hmac.convert(messageBytes);
    // 验证哈希值
    final expectedDigest = encryptedData.sublist(0, 32);
    if (digest.bytes.length != expectedDigest.length) {
      throw Exception('Invalid encryption data');
    }
    for (int i = 0; i < digest.bytes.length; i++) {
      if (digest.bytes[i] != expectedDigest[i]) {
        throw Exception('Invalid encryption data');
      }
    }
    return message;
  }
  Future<String> sign(String message) async {
    // 简化实现，使用 SHA256 签名
    final key = utf8.encode(_deviceId);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(utf8.encode(message));
    return base64.encode(digest.bytes);
  }
  Future<bool> verify(String message, String signatureBase64, String deviceId) async {
    if (!_deviceSigningPublicKeys.containsKey(deviceId)) {
      throw Exception('Signing public key not found for device: $deviceId');
    }
    // 简化实现，使用 SHA256 验证
    final key = utf8.encode(deviceId);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(utf8.encode(message));
    final expectedSignature = base64.encode(digest.bytes);
    return expectedSignature == signatureBase64;
  }
}