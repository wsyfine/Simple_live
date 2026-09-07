import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/web_socket_util.dart';
import 'package:simple_live_core/src/common/http_client.dart';
import 'package:simple_live_core/src/scripts/douyin_sign.dart';

import 'proto/douyin.pb.dart';

class DouyinDanmakuArgs {
  final String webRid;
  final String roomId;
  final String userId;
  final String cookie;
  DouyinDanmakuArgs({
    required this.webRid,
    required this.roomId,
    required this.userId,
    required this.cookie,
  });
  @override
  String toString() {
    return json.encode({
      "webRid": webRid,
      "roomId": roomId,
      "userId": userId,
      "cookie": cookie,
    });
  }
}

class DouyinDanmaku implements LiveDanmaku {
  @override
  int heartbeatTime = 10 * 1000;

  @override
  Function(LiveMessage msg)? onMessage;
  @override
  Function(String msg)? onClose;
  @override
  Function()? onReady;

  /// 兼容地址（当动态IM接口受限时使用）
  static const String _compatServerUrl =
      "wss://webcast3-ws-web-lq.douyin.com/webcast/im/push/v2/";
  static const String _compatBackupUrl =
      "wss://webcast5-ws-web-lf.douyin.com/webcast/im/push/v2/";

  /// IM 上下文协商接口
  static const String _imFetchUrl =
      "https://live.douyin.com/webcast/im/fetch/";

  late DouyinDanmakuArgs danmakuArgs;
  WebScoketUtils? webScoketUtils;

  /// 是否使用协商的动态地址
  bool _useDynamicIm = true;

  /// 动态协商的 cursor
  String? _negotiatedCursor;

  /// 动态协商的 WebSocket URL
  String? _negotiatedWsUrl;

  void _logDebug(String msg) {
    CoreLog.d("[DouyinDanmaku] $msg");
  }

  void _logError(String msg) {
    CoreLog.error("[DouyinDanmaku] $msg");
  }

  /// 构建 IM 协商请求的公共查询参数
  Map<String, String> _buildImQueryParams() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return {
      "app_name": "douyin_web",
      "version_code": "180800",
      "webcast_sdk_version": "1.3.0",
      "update_version_code": "1.3.0",
      "compress": "gzip",
      "cursor": "h-1_t-${ts}_r-1_d-1_u-1",
      "host": "https://live.douyin.com",
      "aid": "6383",
      "live_id": "1",
      "did_rule": "3",
      "debug": "false",
      "maxCacheMessageNumber": "20",
      "endpoint": "live_pc",
      "support_wrds": "1",
      "im_path": "/webcast/im/fetch/",
      "user_unique_id": danmakuArgs.userId,
      "device_platform": "web",
      "cookie_enabled": "true",
      "screen_width": "1920",
      "screen_height": "1080",
      "browser_language": "zh-CN",
      "browser_platform": "Win32",
      "browser_name": "Mozilla",
      "browser_version": DouyinSite.kDefaultUserAgent.replaceAll(
        "Mozilla/",
        "",
      ),
      "browser_online": "true",
      "tz_name": "Asia/Shanghai",
      "identity": "audience",
      "room_id": danmakuArgs.roomId,
      "heartbeatDuration": "0",
    };
  }

  /// 构建 WebSocket 连接 URL（兼容方式）
  String _buildCompatWsUrl() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final uri = Uri.parse(_compatServerUrl).replace(
      scheme: "wss",
      queryParameters: {
        ..._buildImQueryParams(),
        // 兼容方式使用静态 cursor
        "cursor": "h-1_t-${ts}_r-1_d-1_u-1",
      },
    );

    final sign = DouyinSign.getSignature(danmakuArgs.roomId, danmakuArgs.userId);
    return "$uri&signature=$sign";
  }

  /// 构建 IM 协商请求的完整 URL
  String _buildImFetchUrl() {
    final uri = Uri.parse(_imFetchUrl).replace(
      scheme: "https",
      queryParameters: _buildImQueryParams(),
    );
    return DouyinSign.getAbogusUrl(uri.toString(), DouyinSite.kDefaultUserAgent);
  }

  /// 协商 IM 上下文，获取动态 cursor 和 WebSocket URL
  /// 返回 true 表示协商成功，false 表示失败（将使用兼容地址）
  Future<bool> _negotiateImContext() async {
    try {
      _logDebug("正在协商 IM 上下文...");
      final requestUrl = _buildImFetchUrl();
      final headers = <String, String>{
        "User-Agent": DouyinSite.kDefaultUserAgent,
        "Cookie": danmakuArgs.cookie,
        "Origin": "https://live.douyin.com",
        "Referer": "https://live.douyin.com/${danmakuArgs.webRid}",
      };

      final response = await HttpClient.instance.getJson(
        requestUrl,
        header: headers,
      );

      // 检查风控响应
      if (response == null) {
        _logError("IM 协商返回空响应，将使用兼容地址");
        _useDynamicIm = false;
        return false;
      }

      if (response is String && (response == "blocked" || response.isEmpty)) {
        _logError("IM 协商被风控拦截 (response=$response)，将使用兼容地址");
        _useDynamicIm = false;
        return false;
      }

      if (response is! Map) {
        _logError("IM 协商返回格式异常: $response，将使用兼容地址");
        _useDynamicIm = false;
        return false;
      }

      // 提取 cursor 和 WebSocket URL
      final data = response["data"];
      if (data == null) {
        _logError("IM 协商响应缺少 data 字段，将使用兼容地址");
        _useDynamicIm = false;
        return false;
      }

      if (data is Map) {
        _negotiatedCursor = data["cursor"]?.toString();
        // 从 fetch 内部数据中提取 WebSocket URL
        final messages = data["messages"];
        if (messages is List && messages.isNotEmpty) {
          for (final msg in messages) {
            if (msg is Map && msg["method"] == "WebcastControlMessage") {
              // 某些响应中包含控制消息，忽略
              continue;
            }
          }
        }

        if (_negotiatedCursor != null && _negotiatedCursor!.isNotEmpty) {
          _logDebug("IM 上下文协商成功，cursor=${_negotiatedCursor}");
          _useDynamicIm = true;
          return true;
        }
      }

      _logError("IM 协商未能提取有效 cursor，将使用兼容地址");
      _useDynamicIm = false;
      return false;
    } catch (e) {
      _logError("IM 上下文协商异常: $e，将使用兼容地址");
      _useDynamicIm = false;
      return false;
    }
  }

  /// 构建动态 WebSocket URL（使用协商后的 cursor）
  String _buildDynamicWsUrl() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final cursor = _negotiatedCursor ?? "h-1_t-${ts}_r-1_d-1_u-1";

    final uri = Uri.parse(_compatServerUrl).replace(
      scheme: "wss",
      queryParameters: {
        ..._buildImQueryParams(),
        "cursor": cursor,
      },
    );

    final sign = DouyinSign.getSignature(danmakuArgs.roomId, danmakuArgs.userId);
    return "$uri&signature=$sign";
  }

  @override
  Future start(dynamic args) async {
    danmakuArgs = args as DouyinDanmakuArgs;

    // 第一步：尝试协商动态 IM 上下文
    _useDynamicIm = true;
    _negotiatedCursor = null;
    _negotiatedWsUrl = null;
    await _negotiateImContext();

    // 第二步：构建 WebSocket URL
    String wsUrl;
    String backupUrl;

    if (_useDynamicIm && _negotiatedCursor != null) {
      wsUrl = _buildDynamicWsUrl();
      backupUrl = wsUrl.replaceAll("webcast3-ws-web-lq", "webcast5-ws-web-lf");
      _logDebug("使用动态 IM 地址连接: $wsUrl");
    } else {
      wsUrl = _buildCompatWsUrl();
      backupUrl = wsUrl.replaceAll("webcast3-ws-web-lq", "webcast5-ws-web-lf");
      _logDebug("使用兼容地址连接: $wsUrl");
    }

    // 第三步：建立 WebSocket 连接
    webScoketUtils = WebScoketUtils(
      url: wsUrl,
      backupUrl: backupUrl,
      headers: {
        "User-Agent": DouyinSite.kDefaultUserAgent,
        "Cookie": danmakuArgs.cookie,
        "Origin": "https://live.douyin.com",
      },
      heartBeatTime: heartbeatTime,
      onMessage: (e) {
        decodeMessage(e);
      },
      onReady: () {
        _logDebug("WebSocket 连接就绪");
        onReady?.call();
        joinRoom(args);
      },
      onHeartBeat: () {
        heartbeat();
      },
      onReconnect: () {
        onClose?.call("与服务器断开连接，正在尝试重连");
      },
      onClose: (e) {
        _logError("服务器连接失败: $e");
        onClose?.call("服务器连接失败$e");
      },
    );
    webScoketUtils?.connect();
  }

  @override
  void heartbeat() {
    var obj = PushFrame();
    obj.payloadType = 'hb';
    webScoketUtils?.sendMessage(obj.writeToBuffer());
  }

  void decodeMessage(args) {
    // CoreLog.i(args.toString());

    try {
      var wssPackage = PushFrame.fromBuffer(args);

      var logId = wssPackage.logId;
      var decompressed = gzip.decode(wssPackage.payload);
      var payloadPackage = Response.fromBuffer(decompressed);
      if (payloadPackage.needAck) {
        sendAck(logId, payloadPackage.internalExt);
        //return;
      }
      for (var msg in payloadPackage.messagesList) {
        if (msg.method == 'WebcastChatMessage') {
          unPackWebcastChatMessage(msg.payload);
        } else if (msg.method == 'WebcastRoomUserSeqMessage') {
          unPackWebcastRoomUserSeqMessage(msg.payload);
        }
      }
    } catch (e) {
      _logError("消息解码失败: $e");
    }
  }

  void unPackWebcastChatMessage(List<int> payload) {
    var chatMessage = ChatMessage.fromBuffer(payload);
    onMessage?.call(
      LiveMessage(
        type: LiveMessageType.chat,
        color: LiveMessageColor.white,
        //暂不知道具体怎么转换颜色
        // color: chatMessage.common.fullScreenTextColor.
        //     ? LiveMessageColor.white
        //     : LiveMessageColor.numberToColor(color),
        message: chatMessage.content,
        userName: chatMessage.user.nickName,
      ),
    );
  }

  void unPackWebcastRoomUserSeqMessage(List<int> payload) {
    var roomUserSeqMessage = RoomUserSeqMessage.fromBuffer(payload);

    onMessage?.call(
      LiveMessage(
        type: LiveMessageType.online,
        data: roomUserSeqMessage.totalUser.toInt(),
        color: LiveMessageColor.white,
        message: "",
        userName: "",
      ),
    );
  }

  void sendAck(var logId, String internalExt) {
    var obj = PushFrame();
    obj.payloadType = 'ack';
    obj.logId = logId;
    obj.payloadType = internalExt;
    webScoketUtils?.sendMessage(obj.writeToBuffer());
  }

  void joinRoom(args) {
    var obj = PushFrame();
    obj.payloadType = 'hb';
    webScoketUtils?.sendMessage(obj.writeToBuffer());
  }

  @override
  Future stop() async {
    onMessage = null;
    onClose = null;
    webScoketUtils?.close();
  }
}