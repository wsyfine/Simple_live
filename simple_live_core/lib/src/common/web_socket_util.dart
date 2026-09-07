import 'dart:async';

import 'package:web_socket_channel/io.dart';

enum SocketStatus {
  connected,
  failed,
  closed,
}

class WebScoketUtils {
  SocketStatus status = SocketStatus.closed;

  /// 链接
  final String url;

  /// 备用链接（单个，向下兼容）
  final String? backupUrl;

  /// 备用链接列表（用于端口轮询等场景）
  final List<String>? backupUrls;

  /// 心跳时间
  final int heartBeatTime;

  /// 接收到信息
  final Function(dynamic)? onMessage;

  /// 连接关闭
  final Function(String msg)? onClose;

  /// 尝试重连
  final Function()? onReconnect;

  /// 准备就绪
  final Function()? onReady;

  /// 心跳
  final Function()? onHeartBeat;

  /// 请求头
  Map<String, dynamic>? headers;

  /// 当前尝试的备用链接索引
  int _currentBackupIndex = 0;

  /// 是否正在使用备用链接
  bool _usingBackup = false;

  WebScoketUtils({
    required this.url,
    required this.heartBeatTime,
    this.onMessage,
    this.onClose,
    this.onReconnect,
    this.onReady,
    this.onHeartBeat,
    this.headers,
    this.backupUrl,
    this.backupUrls,
  });
  IOWebSocketChannel? webSocket;
  Timer? heartBeatTimer;

  /// 重连次数
  int reconnectTime = 0;
  Timer? reconnectTimer;

  /// 最大重连次数
  int maxReconnectTime = 5;

  StreamSubscription<dynamic>? streamSubscription;

  void connect({bool retry = false}) async {
    close();
    try {
      var wsurl = _selectUrl(retry);
      webSocket = IOWebSocketChannel.connect(
        wsurl,
        connectTimeout: Duration(seconds: 10),
        headers: headers,
      );

      await webSocket?.ready;
      // 连接成功，重置备用索引
      _currentBackupIndex = 0;
      _usingBackup = false;
      ready();
    } catch (e) {
      var nextAvailable = _advanceBackupIndex();
      if (nextAvailable) {
        // 有下一个备用地址，继续尝试
        connect(retry: true);
        return;
      }
      if (!retry && backupUrl != null) {
        // 尝试单个备用地址
        connect(retry: true);
        return;
      }
      onError(e, e);
    }
  }

  /// 选择当前要连接的 URL
  String _selectUrl(bool retry) {
    if (_usingBackup && backupUrls != null && _currentBackupIndex < backupUrls!.length) {
      return backupUrls![_currentBackupIndex];
    }
    if (retry && backupUrl != null) {
      _usingBackup = true;
      return backupUrl!;
    }
    return url;
  }

  /// 前进到下一个备用链接索引
  /// 返回 true 表示还有更多备用地址可用
  bool _advanceBackupIndex() {
    if (backupUrls != null && _currentBackupIndex + 1 < backupUrls!.length) {
      _currentBackupIndex++;
      _usingBackup = true;
      return true;
    }
    return false;
  }

  /// 连接完成
  void ready() {
    status = SocketStatus.connected;

    streamSubscription = webSocket?.stream.listen(
      (data) => receiveMessage(data),
      onError: (e, s) => onError(e, s),
      onDone: onDone,
    );

    onReady?.call();
    initHeartBeat();
  }

  void initHeartBeat() {
    heartBeatTimer = Timer.periodic(
      Duration(milliseconds: heartBeatTime),
      (timer) {
        onHeartBeat?.call();
      },
    );
  }

  void receiveMessage(dynamic data) {
    //接受到一条信息才算重连成功
    reconnectTime = 0;
    onMessage?.call(data);
  }

  void onError(e, s) {
    status = SocketStatus.failed;
    onClose?.call(e.toString());
  }

  void onDone() {
    if (status == SocketStatus.closed) {
      return;
    }
    onReconnect?.call();
    reconnect();
  }

  void sendMessage(dynamic message) {
    if (status == SocketStatus.connected) {
      webSocket?.sink.add(message);
    }
  }

  void close() {
    status = SocketStatus.closed;

    streamSubscription?.cancel();

    reconnectTimer?.cancel();
    reconnectTimer = null;

    webSocket?.sink.close();

    heartBeatTimer?.cancel();
    heartBeatTimer = null;
  }

  void reconnect() {
    status = SocketStatus.closed;
    if (reconnectTime < maxReconnectTime) {
      reconnectTime++;
      reconnectTimer = Timer.periodic(Duration(seconds: 5), (timer) {
        connect();
      });
    } else {
      onClose?.call("重连超过最大次数，与服务器断开连接");
      reconnectTimer?.cancel();
      reconnectTimer = null;
      close();
      return;
    }
  }
}