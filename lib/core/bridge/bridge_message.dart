import 'dart:convert';

/// Web 与 App 之间统一消息协议（JSON over JavaScriptChannel）。
///
/// 请求：{"id":"1","action":"saveOffline","payload":{...}}
/// 响应：{"id":"1","ok":true,"data":{...}} 或 {"id":"1","ok":false,"error":"..."}
class BridgeMessage {
  const BridgeMessage({
    required this.id,
    required this.action,
    this.payload = const {},
  });

  final String id;
  final String action;
  final Map<String, dynamic> payload;

  factory BridgeMessage.fromJson(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return BridgeMessage(
      id: (map['id'] ?? '') as String,
      action: (map['action'] ?? '') as String,
      payload: (map['payload'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'action': action,
        'payload': payload,
      };
}

/// App 向 Web 回传的响应消息。
class BridgeResponse {
  const BridgeResponse({required this.id, required this.ok, this.data, this.error});

  final String id;
  final bool ok;
  final dynamic data;
  final String? error;

  Map<String, dynamic> toJson() => {
        'id': id,
        'ok': ok,
        if (data != null) 'data': data,
        if (error != null) 'error': error,
      };

  String encode() => jsonEncode(toJson());
}
