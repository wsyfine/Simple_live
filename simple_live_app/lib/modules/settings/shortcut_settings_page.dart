import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/desktop_shortcut_manager.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';

/// 直播间快捷键设置页（Windows 桌面端）
/// 支持任意单键与组合键（Ctrl/Alt/Shift/Win），点击条目进入录制模式，
/// 按下任意键/组合键即完成绑定；Esc 取消，配置持久化到本地。
class ShortcutSettingsPage extends StatefulWidget {
  const ShortcutSettingsPage({super.key});

  @override
  State<ShortcutSettingsPage> createState() => _ShortcutSettingsPageState();
}

class _ShortcutSettingsPageState extends State<ShortcutSettingsPage> {
  /// 当前正在录制的动作标题（null 表示未在录制）
  String? _recordingAction;

  @override
  void dispose() {
    DesktopShortcutManager.instance.stopRecording();
    super.dispose();
  }

  /// 开始录制某个动作
  Future<void> _startRecording(String actionName) async {
    await DesktopShortcutManager.instance.stopRecording();
    setState(() {
      _recordingAction = actionName;
    });
    await DesktopShortcutManager.instance.startRecording(
      (keyCode, scanCode, modifiers) {
        // 原生层已过滤修饰键本身，此处直接处理
        if (keyCode == 0x1B) {
          // Esc 取消录制
          DesktopShortcutManager.instance.stopRecording();
          if (mounted) {
            setState(() {
              _recordingAction = null;
            });
          }
          return;
        }
        if (keyCode == 0x08) {
          // Backspace 清除绑定（置为关闭）
          DesktopShortcutManager.instance.stopRecording();
          if (mounted) {
            setState(() {
              _recordingAction = null;
            });
          }
          _applyKey(actionName, 0, 0);
          return;
        }
        DesktopShortcutManager.instance.stopRecording();
        if (mounted) {
          setState(() {
            _recordingAction = null;
          });
        }
        // 单个动作只能绑定一个键；若修饰键带 Shift 且该键已占用将提示冲突
        _applyKey(actionName, keyCode, modifiers);
      },
    );
  }

  /// 应用绑定结果
  void _applyKey(String actionName, int vk, int modifiers) {
    final controller = Get.find<AppSettingsController>();
    switch (actionName) {
      case "切换全屏":
        controller.setLiveRoomShortcutFullScreen(vk, modifiers);
        break;
      case "显示/隐藏弹幕":
        controller.setLiveRoomShortcutDanmaku(vk, modifiers);
        break;
      case "静音/取消静音":
        controller.setLiveRoomShortcutMute(vk, modifiers);
        break;
      case "刷新直播间":
        controller.setLiveRoomShortcutRefresh(vk, modifiers);
        break;
      case "收起/展开聊天区":
        controller.setLiveRoomShortcutToggleChat(vk, modifiers);
        break;
      case "调高音量":
        controller.setLiveRoomShortcutVolumeUp(vk, modifiers);
        break;
      case "调低音量":
        controller.setLiveRoomShortcutVolumeDown(vk, modifiers);
        break;
      case "调高亮度":
        controller.setLiveRoomShortcutBrightnessUp(vk, modifiers);
        break;
      case "调低亮度":
        controller.setLiveRoomShortcutBrightnessDown(vk, modifiers);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppSettingsController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text("直播间快捷键"),
      ),
      body: ListView(
        padding: AppStyle.edgeInsetsA12,
        children: [
          Padding(
            padding: AppStyle.edgeInsetsA12.copyWith(top: 0),
            child: Text(
              "点击条目后按下任意键或组合键即可绑定（如 Ctrl+F、F1、PageUp）。\n"
              "Esc 取消录制，Backspace 清除绑定，支持任意键位不限定预设。",
              style: Get.textTheme.bodySmall!.copyWith(color: Colors.grey),
            ),
          ),
          SettingsCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(
                  () => _ShortcutTile(
                    title: "切换全屏",
                    keyCode: controller.liveRoomShortcutFullScreen.value,
                    modifiers:
                        controller.liveRoomShortcutFullScreenModifiers.value,
                    recording:
                        _recordingAction == "切换全屏",
                    onTap: () => _startRecording("切换全屏"),
                    onClear: () =>
                        _applyKey("切换全屏", 0, 0),
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => _ShortcutTile(
                    title: "显示/隐藏弹幕",
                    keyCode: controller.liveRoomShortcutDanmaku.value,
                    modifiers:
                        controller.liveRoomShortcutDanmakuModifiers.value,
                    recording: _recordingAction == "显示/隐藏弹幕",
                    onTap: () => _startRecording("显示/隐藏弹幕"),
                    onClear: () => _applyKey("显示/隐藏弹幕", 0, 0),
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => _ShortcutTile(
                    title: "静音/取消静音",
                    keyCode: controller.liveRoomShortcutMute.value,
                    modifiers: controller.liveRoomShortcutMuteModifiers.value,
                    recording: _recordingAction == "静音/取消静音",
                    onTap: () => _startRecording("静音/取消静音"),
                    onClear: () => _applyKey("静音/取消静音", 0, 0),
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => _ShortcutTile(
                    title: "刷新直播间",
                    keyCode: controller.liveRoomShortcutRefresh.value,
                    modifiers:
                        controller.liveRoomShortcutRefreshModifiers.value,
                    recording: _recordingAction == "刷新直播间",
                    onTap: () => _startRecording("刷新直播间"),
                    onClear: () => _applyKey("刷新直播间", 0, 0),
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => _ShortcutTile(
                    title: "收起/展开聊天区",
                    keyCode: controller.liveRoomShortcutToggleChat.value,
                    modifiers:
                        controller.liveRoomShortcutToggleChatModifiers.value,
                    recording: _recordingAction == "收起/展开聊天区",
                    onTap: () => _startRecording("收起/展开聊天区"),
                    onClear: () => _applyKey("收起/展开聊天区", 0, 0),
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => _ShortcutTile(
                    title: "调高音量",
                    keyCode: controller.liveRoomShortcutVolumeUp.value,
                    modifiers:
                        controller.liveRoomShortcutVolumeUpModifiers.value,
                    recording: _recordingAction == "调高音量",
                    onTap: () => _startRecording("调高音量"),
                    onClear: () => _applyKey("调高音量", 0, 0),
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => _ShortcutTile(
                    title: "调低音量",
                    keyCode: controller.liveRoomShortcutVolumeDown.value,
                    modifiers:
                        controller.liveRoomShortcutVolumeDownModifiers.value,
                    recording: _recordingAction == "调低音量",
                    onTap: () => _startRecording("调低音量"),
                    onClear: () => _applyKey("调低音量", 0, 0),
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => _ShortcutTile(
                    title: "调高亮度",
                    keyCode: controller.liveRoomShortcutBrightnessUp.value,
                    modifiers:
                        controller.liveRoomShortcutBrightnessUpModifiers.value,
                    recording: _recordingAction == "调高亮度",
                    onTap: () => _startRecording("调高亮度"),
                    onClear: () => _applyKey("调高亮度", 0, 0),
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => _ShortcutTile(
                    title: "调低亮度",
                    keyCode: controller.liveRoomShortcutBrightnessDown.value,
                    modifiers: controller
                        .liveRoomShortcutBrightnessDownModifiers.value,
                    recording: _recordingAction == "调低亮度",
                    onTap: () => _startRecording("调低亮度"),
                    onClear: () => _applyKey("调低亮度", 0, 0),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: AppStyle.edgeInsetsA12,
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  _resetAll();
                },
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text("恢复默认快捷键"),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 恢复全部默认快捷键
  void _resetAll() {
    DesktopShortcutManager.instance.stopRecording();
    Get.find<AppSettingsController>().initLiveRoomShortcutSettings();
    // 将内存值写回存储
    final c = Get.find<AppSettingsController>();
    c.setLiveRoomShortcutFullScreen(
        AppSettingsController.kVkF, 0);
    c.setLiveRoomShortcutDanmaku(
        AppSettingsController.kVkD, 0);
    c.setLiveRoomShortcutMute(AppSettingsController.kVkM, 0);
    c.setLiveRoomShortcutRefresh(AppSettingsController.kVkR, 0);
    c.setLiveRoomShortcutToggleChat(AppSettingsController.kVkC, 0);
    c.setLiveRoomShortcutVolumeUp(AppSettingsController.kVkUp, 0);
    c.setLiveRoomShortcutVolumeDown(AppSettingsController.kVkDown, 0);
    c.setLiveRoomShortcutBrightnessUp(
        AppSettingsController.kVkUp, AppSettingsController.kModifierShift);
    c.setLiveRoomShortcutBrightnessDown(
        AppSettingsController.kVkDown, AppSettingsController.kModifierShift);
  }
}

/// 单个快捷键条目：显示当前绑定，点击进入录制
class _ShortcutTile extends StatelessWidget {
  final String title;
  final int keyCode;
  final int modifiers;
  final bool recording;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _ShortcutTile({
    required this.title,
    required this.keyCode,
    required this.modifiers,
    required this.recording,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final keyLabel = keyCode == AppSettingsController.kShortcutDisabled
        ? "未设置"
        : AppSettingsController.windowsVkLabel(keyCode);
    final modifierLabel = AppSettingsController.modifierLabel(modifiers);
    final display =
        modifierLabel.isEmpty ? keyLabel : "$modifierLabel+$keyLabel";
    return ListTile(
      visualDensity: VisualDensity.compact,
      title: Text(
        recording ? "请按下新快捷键…（Esc取消）" : title,
        style: recording
            ? const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w600,
              )
            : Theme.of(context).textTheme.bodyLarge,
      ),
      contentPadding: AppStyle.edgeInsetsL16.copyWith(right: 8),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (keyCode != AppSettingsController.kShortcutDisabled)
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              tooltip: "清除绑定",
              onPressed: onClear,
              icon: const Icon(Icons.clear, color: Colors.grey),
            ),
          Text(
            display,
            style: Theme.of(context)
                .textTheme
                .bodyMedium!
                .copyWith(color: Colors.grey),
          ),
          AppStyle.hGap4,
          const Icon(
            Icons.keyboard,
            color: Colors.grey,
            size: 20,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}