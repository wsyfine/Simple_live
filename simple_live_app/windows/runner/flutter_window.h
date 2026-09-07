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
  bool HandleShortcutKeyDown(WPARAM wparam, LPARAM lparam);
  std::string ShortcutKeyForWindowsKey(WPARAM wparam, LPARAM lparam);
  bool SendShortcutEvent(const std::string& key, int modifiers, bool isRepeat);

  /// 读取当前修饰键状态并编码为位掩码
  /// bit0=Ctrl bit1=Alt bit2=Shift bit3=Win
  int GetModifierState();

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      shortcut_channel_;

  /// 是否启用快捷键捕获（由 Dart 侧根据页面与焦点状态控制）
  bool shortcut_capture_enabled_ = false;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_