import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 本地媒体/录屏相关目录与命名统一管理（复用自本地存储方案）
class StoragePaths {
  StoragePaths._();

  static Directory? _root;

  static const String kScreenRecordDir = "screen_record";

  /// 根目录：<Documents>/SimpleLive/
  static Future<Directory> root() async {
    if (_root != null) {
      return _root!;
    }
    final docs = await getApplicationDocumentsDirectory();
    _root = Directory(p.join(docs.path, "SimpleLive"));
    await Directory(p.join(_root!.path, kScreenRecordDir))
        .create(recursive: true);
    return _root!;
  }

  /// 默认录屏目录：<root>/screen_record/
  static Future<Directory> screenRecordDir() async {
    final r = await root();
    final dir = Directory(p.join(r.path, kScreenRecordDir));
    await dir.create(recursive: true);
    return dir;
  }

  /// 清除文件名中的非法字符并限制长度
  static String sanitizeFileName(String title) {
    var s =
        title.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F\x7F]'), "_").trim();
    if (s.isEmpty) {
      s = "untitled";
    }
    if (s.length > 50) {
      s = s.substring(0, 50);
    }
    return s;
  }

  /// 主文件命名：{siteId}_{roomId}_{yyyyMMddHHmmss}_{title}.{ext}
  static String buildFileName({
    required String siteId,
    required String roomId,
    required String title,
    required String ext,
    DateTime? time,
  }) {
    final t = time ?? DateTime.now();
    final ts =
        "${t.year}${t.month.toString().padLeft(2, '0')}${t.day.toString().padLeft(2, '0')}"
        "${t.hour.toString().padLeft(2, '0')}${t.minute.toString().padLeft(2, '0')}"
        "${t.second.toString().padLeft(2, '0')}";
    return "${siteId}_${roomId}_${ts}_${sanitizeFileName(title)}.$ext";
  }

  /// 可用磁盘空间（字节）。仅 Windows 通过 GetDiskFreeSpaceEx 获取，失败返回 -1。
  static int freeSpaceBytes(String dirPath) {
    if (!Platform.isWindows) {
      return -1;
    }
    try {
      final kernel32 = DynamicLibrary.open('kernel32.dll');
      final getDiskFreeSpaceEx = kernel32.lookupFunction<
          Int32 Function(
              Pointer<Utf16>, Pointer<Uint64>, Pointer<Uint64>, Pointer<Uint64>),
          int Function(Pointer<Utf16>, Pointer<Uint64>, Pointer<Uint64>,
              Pointer<Uint64>)>('GetDiskFreeSpaceExW');
      final dir = dirPath.toNativeUtf16();
      final free = calloc<Uint64>();
      final total = calloc<Uint64>();
      final totalFree = calloc<Uint64>();
      try {
        final ok = getDiskFreeSpaceEx(dir, free, total, totalFree);
        return ok == 0 ? -1 : free.value;
      } finally {
        calloc.free(dir);
        calloc.free(free);
        calloc.free(total);
        calloc.free(totalFree);
      }
    } catch (_) {
      return -1;
    }
  }

  /// 格式化字节为友好文本
  static String formatBytes(int bytes) {
    if (bytes <= 0) {
      return "0 B";
    }
    const units = ["B", "KB", "MB", "GB", "TB"];
    var v = bytes.toDouble();
    var i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return "${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${units[i]}";
  }
}