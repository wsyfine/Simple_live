#include "flutter_window.h"

#include <optional>
#include <string>
#include <utility>

#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  shortcut_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "simple_live/desktop_shortcuts",
          &flutter::StandardMethodCodec::GetInstance());
  shortcut_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "setShortcutCaptureEnabled") {
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments) {
            const auto enabled = arguments->find(
                flutter::EncodableValue("enabled"));
            if (enabled != arguments->end()) {
              if (const auto* value =
                      std::get_if<bool>(&enabled->second)) {
                shortcut_capture_enabled_ = *value;
              }
            }
          }
          result->Success();
          return;
        }
        if (call.method_name() == "setShortcutRecordingEnabled") {
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments) {
            const auto enabled = arguments->find(
                flutter::EncodableValue("enabled"));
            if (enabled != arguments->end()) {
              if (const auto* value =
                      std::get_if<bool>(&enabled->second)) {
                shortcut_recording_enabled_ = *value;
              }
            }
          }
          result->Success();
          return;
        }
        result->NotImplemented();
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  shortcut_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  switch (message) {
    case WM_KEYDOWN:
    case WM_SYSKEYDOWN:
      if (HandleShortcutKeyDown(wparam, lparam)) {
        return 0;
      }
      break;
    default:
      break;
  }

  // Give Flutter, including plugins and IMEs, an opportunity to handle window
  // messages after desktop shortcut keys have been detected by physical key.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

bool FlutterWindow::HandleShortcutKeyDown(WPARAM wparam, LPARAM lparam) {
  const UINT vk = static_cast<UINT>(wparam);
  const UINT scan_code = (lparam >> 16) & 0xff;
  const bool is_repeat = (lparam & (1 << 30)) != 0;

  // 录制模式：将按键（含修饰键状态）发送给 Dart，供快捷键设置页录制绑定。
  // 仅在非长按重复时响应，并在按下组合键的末键（非修饰键）时才上报，
  // 这样 Ctrl+F 会由 F 键触达且 modifiers 已包含 Ctrl 状态。
  if (shortcut_recording_enabled_ && !is_repeat) {
    // 修饰键本身不作为录制最末键（按下组合键的末键时才上报，
    // 这样 Ctrl+F 由 F 触达且 modifiers 已包含 Ctrl 状态）
    switch (vk) {
      case VK_SHIFT:
      case VK_CONTROL:
      case VK_MENU:
      case VK_LWIN:
      case VK_RWIN:
      case VK_APPS:
      case VK_LSHIFT:
      case VK_RSHIFT:
      case VK_LCONTROL:
      case VK_RCONTROL:
      case VK_LMENU:
      case VK_RMENU:
        return false;
      default:
        break;
    }
    SendKeyEvent("shortcutRecorded", vk, scan_code, GetModifierState(), false);
    // 录制按键不消费事件，避免设置页 UI 失去按键输入
    return false;
  }

  // 快捷键捕获模式：直播间页面且焦点不在输入框时开启。
  // 开启后所有按键均转发给 Dart 侧由配置匹配，并消费事件防止 Flutter 层重复处理。
  if (shortcut_capture_enabled_) {
    SendKeyEvent("shortcutKeyDown", vk, scan_code, GetModifierState(),
                 is_repeat);
    return true;
  }

  return false;
}

void FlutterWindow::SendKeyEvent(const std::string& method, UINT vk,
                                 UINT scan_code, int modifiers,
                                 bool is_repeat) {
  if (!shortcut_channel_) {
    return;
  }
  flutter::EncodableMap arguments = {
      {flutter::EncodableValue("keyCode"),
       flutter::EncodableValue(static_cast<int32_t>(vk))},
      {flutter::EncodableValue("scanCode"),
       flutter::EncodableValue(static_cast<int32_t>(scan_code))},
      {flutter::EncodableValue("modifiers"),
       flutter::EncodableValue(modifiers)},
      {flutter::EncodableValue("isRepeat"),
       flutter::EncodableValue(is_repeat)},
  };
  shortcut_channel_->InvokeMethod(
      method, std::make_unique<flutter::EncodableValue>(arguments));
}

int FlutterWindow::GetModifierState() {
  int modifiers = 0;
  if (GetKeyState(VK_CONTROL) & 0x8000) {
    modifiers |= 1;  // bit0 = Ctrl
  }
  if (GetKeyState(VK_MENU) & 0x8000) {
    modifiers |= 2;  // bit1 = Alt
  }
  if (GetKeyState(VK_SHIFT) & 0x8000) {
    modifiers |= 4;  // bit2 = Shift
  }
  if ((GetKeyState(VK_LWIN) & 0x8000) || (GetKeyState(VK_RWIN) & 0x8000)) {
    modifiers |= 8;  // bit3 = Win
  }
  return modifiers;
}
