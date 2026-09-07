import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_live_app/app/log.dart';

/// 桌面端快捷键管理器（Windows 原生层 simple_live/desktop_shortcuts）
///
/// 职责：
/// 1. 维护与原生层的 MethodChannel（捕获开关、录制开关、按键事件回传）
/// 2. 同步捕获状态：LiveRoomController 生命周期驱动 + 焦点监听（输入法兼容）
/// 3. 将原生按键事件通过回调分发给注册方（直播间分发/设置页录制）
///
/// 键位完全可配置：原生层上送 Windows 虚拟键码（VK）+ 扫描码 + 修饰键掩码，
/// 不限制固定键位，任意单键/组合键均可绑定。
class DesktopShortcutManager {
  DesktopShortcutManager._();

  static final DesktopShortcutManager instance = DesktopShortcutManager._();

  /// 原生层快捷键通道
  static const MethodChannel _channel =
      MethodChannel("simple_live/desktop_shortcuts");

  bool _handlerBound = false;
  bool? _captureEnabled;
  bool _liveRoomActive = false;

  /// 直播间是否处于激活状态（由 LiveRoomController 生命周期驱动）
  bool get liveRoomActive => _liveRoomActive;

  /// 当前焦点是否在可编辑文本（输入法组合输入状态）
  static bool get hasEditableTextFocus {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    return focusContext != null &&
        focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  /// 直播间注册的按键分发回调（vk, scanCode, modifiers, isRepeat）
  void Function(int keyCode, int scanCode, int modifiers, bool isRepeat)?
      onShortcutKey;

  /// 录制模式注册的按键回调（vk, scanCode, modifiers）
  void Function(int keyCode, int scanCode, int modifiers)? onRecordedKey;

  /// 初始化：绑定通道 handler 与焦点监听（应用启动时调用一次）
  void init() {
    if (_handlerBound) {
      return;
    }
    _handlerBound = true;
    _channel.setMethodCallHandler(_handleMethodCall);
    FocusManager.instance.addListener(_syncCaptureState);
  }

  /// 进入直播间：开启快捷键捕获
  void enterLiveRoomScope() {
    if (_liveRoomActive) {
      return;
    }
    _liveRoomActive = true;
    unawaited(_syncCaptureState());
  }

  /// 离开直播间：关闭快捷键捕获
  void exitLiveRoomScope() {
    if (!_liveRoomActive) {
      return;
    }
    _liveRoomActive = false;
    unawaited(_syncCaptureState());
  }

  /// 路由变化时同步（兜底）
  void onRouteChanged() {
    unawaited(_syncCaptureState());
  }

  /// 同步捕获状态：直播间激活 且 焦点不在输入框
  Future<void> _syncCaptureState() async {
    final enabled = _liveRoomActive && !hasEditableTextFocus;
    if (_captureEnabled == enabled) {
      return;
    }
    _captureEnabled = enabled;
    try {
      await _channel.invokeMethod(
        "setShortcutCaptureEnabled",
        {"enabled": enabled},
      );
    } catch (e) {
      Log.d("桌面快捷键捕获状态同步失败: $e");
    }
  }

  /// 开启录制模式（快捷键设置页调用，任意按键回传 onRecordedKey）
  Future<void> startRecording(
      void Function(int keyCode, int scanCode, int modifiers) onRecorded) async {
    onRecordedKey = onRecorded;
    try {
      await _channel.invokeMethod(
        "setShortcutRecordingEnabled",
        {"enabled": true},
      );
    } catch (e) {
      Log.d("开启快捷键录制失败: $e");
    }
  }

  /// 结束录制模式
  Future<void> stopRecording() async {
    onRecordedKey = null;
    try {
      await _channel.invokeMethod(
        "setShortcutRecordingEnabled",
        {"enabled": false},
      );
    } catch (e) {
      Log.d("关闭快捷键录制失败: $e");
    }
  }

  /// 原生通道回调
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == "shortcutKeyDown") {
      final args = call.arguments;
      if (args is! Map) {
        return null;
      }
      final keyCode = (args["keyCode"] as int?) ?? 0;
      final scanCode = (args["scanCode"] as int?) ?? 0;
      final modifiers = (args["modifiers"] as int?) ?? 0;
      final isRepeat = (args["isRepeat"] as bool?) ?? false;
      if (keyCode <= 0) {
        return null;
      }
      onShortcutKey?.call(keyCode, scanCode, modifiers, isRepeat);
      return null;
    }
    if (call.method == "shortcutRecorded") {
      final args = call.arguments;
      if (args is! Map) {
        return null;
      }
      final keyCode = (args["keyCode"] as int?) ?? 0;
      final scanCode = (args["scanCode"] as int?) ?? 0;
      final modifiers = (args["modifiers"] as int?) ?? 0;
      if (keyCode <= 0) {
        return null;
      }
      onRecordedKey?.call(keyCode, scanCode, modifiers);
      return null;
    }
    return null;
  }
}