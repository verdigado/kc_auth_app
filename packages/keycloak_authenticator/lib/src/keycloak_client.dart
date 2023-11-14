import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:keycloak_authenticator/src/utils/crypto_utils.dart';
import 'package:pointycastle/export.dart';

import 'enums/enums.dart';
import 'dtos/challenge.dart';

class KeycloakClient {
  final Dio _dio;
  final PrivateKey _privateKey;
  final SignatureAlgorithm _signatureAlgorithm;
  final KeyAlgorithm _keyAlgorithm;

  KeycloakClient({
    required baseUrl,
    required SignatureAlgorithm signatureAlgorithm,
    required KeyAlgorithm keyAlgorithm,
    required PrivateKey privateKey,
  })  : _signatureAlgorithm = signatureAlgorithm,
        _keyAlgorithm = keyAlgorithm,
        _privateKey = privateKey,
        _dio = Dio(BaseOptions(baseUrl: baseUrl)) {
    _dio.interceptors.add(LogInterceptor(responseBody: true, error: true));
  }

  String _sign(String value) {
    var algorithmMap = {
      SignatureAlgorithm.SHA256withRSA: 'SHA-256/RSA',
      SignatureAlgorithm.SHA512withRSA: 'SHA-512/RSA',
    };

    var algorithmName = algorithmMap[_signatureAlgorithm];
    if (algorithmName == null) {
      throw Exception('Algorithm not supported');
    }

    switch (_keyAlgorithm) {
      case KeyAlgorithm.RSA:
        return base64Encode(
          CryptoUtils.rsaSign(
            _privateKey as RSAPrivateKey,
            Uint8List.fromList(value.codeUnits),
            algorithmName: algorithmName,
          ),
        );
      case KeyAlgorithm.ECDSA:
        throw Exception('Unsupported KeyAlgorithm');
    }
  }

  String buildSignatureHeader(
    String keyId,
    Map<String, String> keyValues,
  ) {
    var buffer = StringBuffer();
    var first = true;
    keyValues.forEach((key, value) {
      if (!first) {
        buffer.write(',');
      }
      buffer.writeAll([key, ':', value]);
      first = false;
    });
    var payload = buffer.toString();
    var signature = _sign(payload);
    return 'keyId:$keyId,$payload,signature:$signature';
  }

  Future<void> register({
    required String clientId,
    required String tabId,
    required String deviceId,
    required DeviceOs deviceOs,
    String? devicePushId,
    required String key,
    required String publicKey,
    required KeyAlgorithm keyAlgorithm,
    required SignatureAlgorithm signatureAlgorithm,
  }) async {
    var queryParameters = {
      'client_id': clientId,
      'tab_id': tabId,
      'device_id': deviceId,
      'device_os': deviceOs.name.toString(),
      'device_push_id': devicePushId,
      'key_algorithm': keyAlgorithm.name.toString(),
      'signature_algorithm': signatureAlgorithm.name.toString(),
      'public_key': publicKey,
      'key': key,
    };
    try {
      await _dio.get(
        '/login-actions/action-token',
        queryParameters: queryParameters,
      );
    } on DioException catch (err) {
      rethrow;
    }
  }

  Future<List<Challenge>> getChallenges(
    String deviceId,
  ) async {
    var signatureHeader = buildSignatureHeader(
      deviceId,
      {
        'created': DateTime.now().millisecondsSinceEpoch.toString(),
        // 'request-target': 'get_/realms/$realm/challenge-resource/$deviceId',
      },
    );
    try {
      var res = await _dio.get(
        '/challenges',
        queryParameters: {
          'device_id': deviceId,
        },
        options: Options(
          headers: {
            'signature': signatureHeader,
          },
        ),
      );
      return [Challenge.fromJson(res.data)];
    } on DioException catch (err) {
      if (err.response?.statusCode == 404) {
        return [];
      }
      rethrow;
    }
  }

  completeChallenge({
    required String deviceId,
    required String clientId,
    required String tabId,
    required String key,
    required String value,
    required bool granted,
    required int timestamp,
  }) async {
    var signatureHeader = buildSignatureHeader(
      deviceId,
      {
        // 'created': DateTime.now().millisecondsSinceEpoch.toString(),
        'created': timestamp.toString(),
        'secret': value,
        'granted': granted ? 'true' : 'false',
      },
    );
    var res = await _dio.get(
      '/login-actions/action-token',
      queryParameters: {
        'client_id': clientId,
        'tab_id': tabId,
        'key': key,
        'granted': granted,
      },
      options: Options(
        headers: {
          'signature': signatureHeader,
        },
      ),
    );
  }
}
