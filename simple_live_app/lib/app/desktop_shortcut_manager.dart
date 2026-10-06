import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 桌面端快捷键管理器（纯 Dart 实现，基于 HardwareKeyboard 全局键盘监听）
///
/// 背景：Flutter Windows 的键盘焦点在 Flutter 子视图上，顶层窗口收不到
/// WM_KEYDOWN，因此原生层拦击 WM_KEYDOWN 的方案永远触发不了。正确做法是
/// 使用 HardwareKeyboard.instance.addHandler 在 Dart 层全局监听所有按键。
///
/// 键位标识统一使用 PhysicalKeyboardKey.usbHidUsage（物理键，USB HID usage），
/// 与大小写/CapsLock/键盘布局/输入法状态无关，支持任意单键与任意组合键。
class DesktopShortcutManager {
  DesktopShortcutManager._();

  static final DesktopShortcutManager instance = DesktopShortcutManager._();

  bool _handlerBound = false;

  /// 是否处于直播间接键捕获范围（由 LiveRoomController 生命周期驱动）
  bool _liveRoomActive = false;

  /// 是否处于录制模式（快捷键设置页按下条目后开启）
  bool _recording = false;

  /// 直播间是否处于激活状态
  bool get liveRoomActive => _liveRoomActive;

  /// 直播间按键分发回调：返回 true 表示该按键命中并消费
  /// 参数：(physicalUsage, modifiers, isRepeat)
  bool Function(int physicalUsage, int modifiers, bool isRepeat)? onShortcutKey;

  /// 录制模式按键回调：捕获到一个可绑定键时触发
  /// 参数：(physicalUsage, modifiers)
  void Function(int physicalUsage, int modifiers)? onRecordedKey;

  /// 当前焦点是否在可编辑文本（输入法组合输入状态），是则放行不拦截
  static bool get hasEditableTextFocus {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    return focusContext != null &&
        focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  /// 初始化：注册全局键盘 handler（应用启动时调用一次）
  void init() {
    if (_handlerBound) {
      return;
    }
    _handlerBound = true;
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
  }

  /// 进入直播间：激活快捷键分发范围
  void enterLiveRoomScope() {
    _liveRoomActive = true;
  }

  /// 离开直播间：退出快捷键分发范围
  void exitLiveRoomScope() {
    _liveRoomActive = false;
    _recording = false;
  }

  /// 路由变化时兜底同步（由 LiveRoomController 生命周期驱动，无需额外处理）
  void onRouteChanged() {}

  /// 开启录制模式（快捷键设置页调用）
  void startRecording(void Function(int physicalUsage, int modifiers) onRecorded) {
    onRecordedKey = onRecorded;
    _recording = true;
  }

  /// 结束录制模式
  void stopRecording() {
    onRecordedKey = null;
    _recording = false;
  }

  /// 全局键盘 handler。返回 true 表示该事件已处理并阻止继续传播。
  bool _onKeyEvent(KeyEvent event) {
    // 仅处理按下与长按重复；抬起事件放行。
    // 注意 KeyRepeatEvent 并非 KeyDownEvent 的子类（二者都直接继承 KeyEvent），
    // 必须单独放行，否则长按只会触发一次，音量/亮度无法连续调节。
    // 长按重复交由分发方按动作类型决定是否忽略。
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return false;
    }

    // 录制模式优先：捕获下一个非修饰键（长按重复不重复捕获）
    if (_recording) {
      if (event is KeyRepeatEvent) {
        return true;
      }
      return _handleRecording(event);
    }

    // 直播间范围：焦点在输入框（输入法组合）时放行，避免与中文输入法冲突
    if (!_liveRoomActive) {
      return false;
    }
    if (hasEditableTextFocus) {
      return false;
    }

    final int modifiers = _readModifiers();
    final bool isRepeat = event is KeyRepeatEvent;
    final handled = onShortcutKey?.call(event.physicalKey.usbHidUsage, modifiers,
            isRepeat) ??
        false;
    return handled;
  }

  /// 处理录制模式按键
  bool _handleRecording(KeyEvent event) {
    final key = event.physicalKey;
    // 修饰键本身不作为录制末键（按下组合键的末键时才上报，
    // 这样 Ctrl+F 由 F 键触达，modifiers 已包含 Ctrl 状态）
    if (_isModifierKey(key)) {
      return true;
    }
    final int modifiers = _readModifiers();
    final cb = onRecordedKey;
    // 录制只使用一次，捕获后立即退出录制模式，避免重复触发
    _recording = false;
    onRecordedKey = null;
    cb?.call(key.usbHidUsage, modifiers);
    // 消费该按键，避免它触发页面内其它控件
    return true;
  }

  static bool _isModifierKey(PhysicalKeyboardKey key) {
    switch (key.usbHidUsage) {
      case 0x000700e0: // controlLeft
      case 0x000700e4: // controlRight
      case 0x000700e1: // shiftLeft
      case 0x000700e5: // shiftRight
      case 0x000700e2: // altLeft
      case 0x000700e6: // altRight
      case 0x000700e3: // metaLeft
      case 0x000700e7: // metaRight
      case 0x00070039: // capsLock
        return true;
      default:
        return false;
    }
  }

  /// 读取当前修饰键状态并编码为位掩码：bit0=Ctrl bit1=Alt bit2=Shift bit3=Win
  static int _readModifiers() {
    final hw = HardwareKeyboard.instance;
    int m = 0;
    if (hw.isControlPressed) m |= 1;
    if (hw.isAltPressed) m |= 2;
    if (hw.isShiftPressed) m |= 4;
    if (hw.isMetaPressed) m |= 8;
    return m;
  }
}