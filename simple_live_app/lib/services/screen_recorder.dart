import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/services/hls_parser.dart';

/// 断流续接参数
typedef RecordNext = ({String url, Map<String, String> headers});

/// 直播流录制引擎：直接从流地址拉流写文件，不依赖播放器 muxer。
/// - FLV 直播：流式 dump 原始字节到 .flv，断流后回调续接
/// - HLS 直播：循环拉取 live playlist，下载 .ts 分片，停止后合并为 .ts
class ScreenRecorder {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  CancelToken? _cancelToken;
  Future<void>? _loop;
  String? _destPath;
  Directory? _segDir;
  bool _stopped = false;

  DateTime? _startTime;
  int _bytes = 0;

  /// 进度回调（已录字节、录制时长）
  void Function(int bytes, Duration duration)? onProgress;

  /// 断流续接回调：返回新 URL/headers，null 表示放弃续接结束录制
  Future<RecordNext?> Function()? onInterrupted;

  bool get recording => _loop != null && !_stopped;
  int get recordedBytes => _bytes;
  Duration get recordedDuration =>
      _startTime == null ? Duration.zero : DateTime.now().difference(_startTime!);

  /// 启动录制（不阻塞）
  void start({
    required String url,
    required Map<String, String>? headers,
    required String destPath,
    required bool isHls,
  }) {
    _destPath = destPath;
    _cancelToken = CancelToken();
    _stopped = false;
    _startTime = DateTime.now();
    _bytes = 0;
    final h = Map<String, String>.from(headers ?? {});
    h.putIfAbsent(
      "user-agent",
      () => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
          "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
    );
    _loop = isHls ? _recordHls(url, h, destPath) : _recordFlv(url, h, destPath);
  }

  /// 停止录制，等待数据落盘，返回最终文件路径（可能为 null 表示无数据）
  Future<String?> stop() async {
    if (_loop == null) {
      return null;
    }
    _stopped = true;
    _cancelToken?.cancel();
    try {
      await _loop;
    } catch (e) {
      // 预期：cancel 触发的 DioException
      if (e is! DioException || e.type != DioExceptionType.cancel) {
        Log.w("录屏循环结束异常: $e");
      }
    }
    _loop = null;
    _cancelToken = null;
    _startTime = null;
    final dest = _destPath;
    // HLS：合并分片
    if (_segDir != null && dest != null) {
      try {
        await _mergeSegments(dest, _segDir!);
      } catch (e) {
        Log.w("录屏分片合并失败: $e");
      }
      try {
        await _segDir!.delete(recursive: true);
      } catch (_) {}
      _segDir = null;
    }
    return dest;
  }

  /// 取消录制（退出直播间时调用，丢弃未完成的 HLS 分片）
  Future<void> cancel() async {
    _stopped = true;
    _cancelToken?.cancel();
    try {
      await _loop;
    } catch (_) {}
    _loop = null;
    _cancelToken = null;
    _startTime = null;
    if (_segDir != null) {
      try {
        await _segDir!.delete(recursive: true);
      } catch (_) {}
      _segDir = null;
    }
  }

  /// FLV：流式 dump，断流后通过 onInterrupted 续接
  Future<void> _recordFlv(
      String url, Map<String, String> headers, String dest) async {
    var currentUrl = url;
    var currentHeaders = headers;
    final file = await File(dest).open(mode: FileMode.write);
    try {
      while (!_stopped) {
        final interrupted = await _dumpFlv(currentUrl, currentHeaders, file);
        if (_stopped) break;
        if (!interrupted) break; // 正常结束（理论直播不会）
        // 断流：请求新 URL 续接
        final next = await onInterrupted?.call();
        if (next == null) break;
        currentUrl = next.url;
        currentHeaders = next.headers;
        Log.i("录屏续接新流");
      }
    } finally {
      await file.close();
    }
  }

  /// 打开一次 FLV 流并 dump，返回是否中断（true = 需续接）
  Future<bool> _dumpFlv(
      String url, Map<String, String> headers, RandomAccessFile file) async {
    try {
      final resp = await _dio.get<ResponseBody>(
        url,
        options: Options(
          responseType: ResponseType.stream,
          headers: headers,
          followRedirects: true,
        ),
        cancelToken: _cancelToken,
      );
      await for (final chunk in resp.data!.stream) {
        if (_stopped) break;
        file.writeFromSync(chunk);
        _bytes += chunk.length;
        onProgress?.call(_bytes, recordedDuration);
      }
      return true; // 流正常结束（直播服务器断开），视为中断尝试续接
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      Log.w("FLV 录流中断: ${e.message}");
      return true;
    }
  }

  /// HLS：循环拉 live playlist，下载新分片
  Future<void> _recordHls(
      String url, Map<String, String> headers, String dest) async {
    _segDir = await Directory(
      p.join(p.dirname(dest), ".seg_${p.basename(dest)}"),
    ).create(recursive: true);
    var playlistUrl = url;
    final done = <String>{};

    while (!_stopped) {
      final contentResp = await _dio.get<String>(
        playlistUrl,
        options: Options(headers: headers),
        cancelToken: _cancelToken,
      );
      var pl = HlsParser.parse(contentResp.data ?? "", playlistUrl);

      if (pl.isMaster) {
        pl.variants.sort((a, b) => b.bandwidth.compareTo(a.bandwidth));
        playlistUrl = pl.variants.first.url;
        final subResp = await _dio.get<String>(
          playlistUrl,
          options: Options(headers: headers),
          cancelToken: _cancelToken,
        );
        pl = HlsParser.parse(subResp.data ?? "", playlistUrl);
      }

      if (pl.encrypted) {
        throw Exception("暂不支持加密 HLS（${pl.keyMethod}）");
      }

      for (final seg in pl.segments) {
        if (_stopped) break;
        if (done.contains(seg.seq)) continue;
        await _dio.download(
          seg.url,
          p.join(_segDir!.path, "seg_${seg.seq}.ts"),
          options: Options(headers: headers),
          cancelToken: _cancelToken,
          deleteOnError: true,
        );
        done.add(seg.seq);
        try {
          _bytes +=
              await File(p.join(_segDir!.path, "seg_${seg.seq}.ts")).length();
        } catch (_) {}
        onProgress?.call(_bytes, recordedDuration);
      }

      if (pl.endList) break;
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  /// 按序号升序合并 .ts 分片
  Future<void> _mergeSegments(String dest, Directory segDir) async {
    final files = segDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith(".ts"))
        .toList()
      ..sort((a, b) {
        int seqOf(File f) => int.tryParse(
                p.basename(f.path).replaceAll(RegExp(r'\D'), "")) ??
            0;
        return seqOf(a).compareTo(seqOf(b));
      });

    if (files.isEmpty) {
      return;
    }
    final raf = await File(dest).open(mode: FileMode.write);
    try {
      for (final f in files) {
        raf.writeFromSync(await f.readAsBytes());
      }
      await raf.flush();
    } finally {
      await raf.close();
    }
  }
}