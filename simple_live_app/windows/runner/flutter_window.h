#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/encodable_value.h>

#include <memory>
#include <string>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  /// 处理 WM_KEYDOWN/WM_SYSKEYDOWN
  /// 返回 true 表示事件已被消费（不应再传递给 Flutter）
  bool HandleShortcutKeyDown(WPARAM wparam, LPARAM lparam);

  /// 向 Dart 侧发送按键事件（快捷键捕获或录制两种用途）
  void SendKeyEvent(const std::string& method, UINT vk, UINT scan_code,
                    int modifiers, bool is_repeat);

  /// 读取当前修饰键状态并编码为位掩码
  /// bit0=Ctrl bit1=Alt bit2=Shift bit3=Win
  int GetModifierState();

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      shortcut_channel_;

  /// 快捷键捕获开关（直播间页面且焦点不在输入框时为 true）
  /// 开启后所有 WM_KEYDOWN 均转发给 Dart 并消费事件
  bool shortcut_capture_enabled_ = false;

  /// 录制模式开关（快捷键设置页录制时开启）
  /// 开启后下一个非修饰键按键转发给 Dart 用于录制绑定
  bool shortcut_recording_enabled_ = false;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_