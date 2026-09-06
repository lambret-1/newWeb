import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// 腾讯云机器翻译（TMT）TC3-HMAC-SHA256 签名请求。
/// 接口：TextTranslate（tmt.tencentcloudapi.com）
class TencentTranslateClient {
  TencentTranslateClient({required this.secretId, required this.secretKey});

  final String secretId;
  final String secretKey;

  static const String _host = 'tmt.tencentcloudapi.com';
  static const String _service = 'tmt';
  static const String _action = 'TextTranslate';
  static const String _version = '2018-03-21';
  static const String _region = 'ap-guangzhou';

  Future<String?> translate(
    String text, {
    String source = 'auto',
    String target = 'zh',
  }) async {
    try {
      final body = jsonEncode({
        'SourceText': text,
        'Source': source,
        'Target': target,
        'ProjectId': 0,
      });
      final payload = utf8.encode(body);

      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000)
          .toUtc()
          .toIso8601String()
          .substring(0, 10);

      // 1. CanonicalRequest
      final canonicalHeaders = 'content-type:application/json; charset=utf-8\n'
          'host:$_host\n'
          'x-tc-action:${_action.toLowerCase()}\n';
      final signedHeaders = 'content-type;host;x-tc-action';
      final canonicalRequest = 'POST\n/\n\n$canonicalHeaders\n'
          '$signedHeaders\n${sha256.convert(payload)}';

      // 2. StringToSign
      final stringToSign = 'TC3-HMAC-SHA256\n$timestamp\n'
          '$date/$_service/tc3_request\n'
          '${sha256.convert(utf8.encode(canonicalRequest))}';

      // 3. 派生密钥并签名
      final secretDate = Hmac(sha256, utf8.encode('TC3$secretKey'))
          .convert(utf8.encode(date))
          .bytes;
      final secretService =
          Hmac(sha256, secretDate).convert(utf8.encode(_service)).bytes;
      final secretSigning =
          Hmac(sha256, secretService).convert(utf8.encode('tc3_request')).bytes;
      final signature = Hmac(sha256, secretSigning)
          .convert(utf8.encode(stringToSign))
          .toString();

      final authorization =
          'TC3-HMAC-SHA256 Credential=$secretId/$date/$_service/tc3_request, '
          'SignedHeaders=$signedHeaders, Signature=$signature';

      final res = await http.post(
        Uri.parse('https://$_host/'),
        headers: {
          'Authorization': authorization,
          'Content-Type': 'application/json; charset=utf-8',
          'Host': _host,
          'X-TC-Action': _action,
          'X-TC-Version': _version,
          'X-TC-Timestamp': '$timestamp',
          'X-TC-Region': _region,
        },
        body: body,
      );
      if (res.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final response = data['Response'] as Map<String, dynamic>?;
      if (response == null || response['Error'] != null) return null;
      final targetText = response['TargetText'] as String?;
      return (targetText == null || targetText.isEmpty) ? null : targetText;
    } catch (_) {
      return null;
    }
  }
}
