import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/desktop_shortcut_manager.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';

/// 直播间快捷键设置页（Windows 桌面端）
/// 支持任意单键与组合键（Ctrl/Alt/Shift/Win），点击条目进入录制模式，
/// 按下任意键/组合键即完成绑定；Esc 取消，Backspace 清除，配置持久化到本地。
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
  void _startRecording(String actionName) {
    DesktopShortcutManager.instance.stopRecording();
    setState(() {
      _recordingAction = actionName;
    });
    DesktopShortcutManager.instance.startRecording((physicalUsage, modifiers) {
      // Esc 取消录制（录制回调期间 _recording 已被 manager 置回 false）
      if (physicalUsage == PhysicalKeyboardKey.escape.usbHidUsage) {
        if (mounted) {
          setState(() {
            _recordingAction = null;
          });
        }
        return;
      }
      // Backspace 清除绑定（置为关闭）
      if (physicalUsage == PhysicalKeyboardKey.backspace.usbHidUsage) {
        if (mounted) {
          setState(() {
            _recordingAction = null;
          });
        }
        _applyKey(actionName, 0, 0);
        return;
      }
      if (mounted) {
        setState(() {
          _recordingAction = null;
        });
      }
      _applyKey(actionName, physicalUsage, modifiers);
    });
  }

  /// 应用绑定结果
  void _applyKey(String actionName, int keyId, int modifiers) {
    final controller = Get.find<AppSettingsController>();
    switch (actionName) {
      case "切换全屏":
        controller.setLiveRoomShortcutFullScreen(keyId, modifiers);
        break;
      case "显示/隐藏弹幕":
        controller.setLiveRoomShortcutDanmaku(keyId, modifiers);
        break;
      case "静音/取消静音":
        controller.setLiveRoomShortcutMute(keyId, modifiers);
        break;
      case "刷新直播间":
        controller.setLiveRoomShortcutRefresh(keyId, modifiers);
        break;
      case "收起/展开聊天区":
        controller.setLiveRoomShortcutToggleChat(keyId, modifiers);
        break;
      case "调高音量":
        controller.setLiveRoomShortcutVolumeUp(keyId, modifiers);
        break;
      case "调低音量":
        controller.setLiveRoomShortcutVolumeDown(keyId, modifiers);
        break;
      case "调高亮度":
        controller.setLiveRoomShortcutBrightnessUp(keyId, modifiers);
        break;
      case "调低亮度":
        controller.setLiveRoomShortcutBrightnessDown(keyId, modifiers);
        break;
      case "关闭直播间":
        controller.setLiveRoomShortcutCloseRoom(keyId, modifiers);
        break;
      case "录屏/停止录屏":
        controller.setLiveRoomShortcutRecord(keyId, modifiers);
        break;
    }
  }

  /// 恢复全部默认快捷键
  void _resetAll() {
    DesktopShortcutManager.instance.stopRecording();
    final c = Get.find<AppSettingsController>();
    c.setLiveRoomShortcutFullScreen(AppSettingsController.kPhysicalKeyF, 0);
    c.setLiveRoomShortcutDanmaku(AppSettingsController.kPhysicalKeyD, 0);
    c.setLiveRoomShortcutMute(AppSettingsController.kPhysicalKeyM, 0);
    c.setLiveRoomShortcutRefresh(AppSettingsController.kPhysicalKeyR, 0);
    c.setLiveRoomShortcutToggleChat(AppSettingsController.kPhysicalKeyC, 0);
    c.setLiveRoomShortcutVolumeUp(AppSettingsController.kPhysicalKeyUp, 0);
    c.setLiveRoomShortcutVolumeDown(AppSettingsController.kPhysicalKeyDown, 0);
    c.setLiveRoomShortcutBrightnessUp(
        AppSettingsController.kPhysicalKeyUp, AppSettingsController.kModifierShift);
    c.setLiveRoomShortcutBrightnessDown(
        AppSettingsController.kPhysicalKeyDown, AppSettingsController.kModifierShift);
    c.setLiveRoomShortcutCloseRoom(
        AppSettingsController.kPhysicalKeyBackspace, 0);
    c.setLiveRoomShortcutRecord(AppSettingsController.kPhysicalKeyS, 0);
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
                    keyId: controller.liveRoomShortcutFullScreen.value,
                    modifiers:
                        controller.liveRoomShortcutFullScreenModifiers.value,
                    recording: _recordingAction == "切换全屏",
                    onTap: () => _startRecording("切换全屏"),
                    onClear: () => _applyKey("切换全屏", 0, 0),
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => _ShortcutTile(
                    title: "显示/隐藏弹幕",
                    keyId: controller.liveRoomShortcutDanmaku.value,
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
                    keyId: controller.liveRoomShortcutMute.value,
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
                    keyId: controller.liveRoomShortcutRefresh.value,
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
                    keyId: controller.liveRoomShortcutToggleChat.value,
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
                    keyId: controller.liveRoomShortcutVolumeUp.value,
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
                    keyId: controller.liveRoomShortcutVolumeDown.value,
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
                    keyId: controller.liveRoomShortcutBrightnessUp.value,
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
                    keyId: controller.liveRoomShortcutBrightnessDown.value,
                    modifiers: controller
                        .liveRoomShortcutBrightnessDownModifiers.value,
                    recording: _recordingAction == "调低亮度",
                    onTap: () => _startRecording("调低亮度"),
                    onClear: () => _applyKey("调低亮度", 0, 0),
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => _ShortcutTile(
                    title: "关闭直播间",
                    keyId: controller.liveRoomShortcutCloseRoom.value,
                    modifiers:
                        controller.liveRoomShortcutCloseRoomModifiers.value,
                    recording: _recordingAction == "关闭直播间",
                    onTap: () => _startRecording("关闭直播间"),
                    onClear: () => _applyKey("关闭直播间", 0, 0),
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => _ShortcutTile(
                    title: "录屏/停止录屏",
                    keyId: controller.liveRoomShortcutRecord.value,
                    modifiers:
                        controller.liveRoomShortcutRecordModifiers.value,
                    recording: _recordingAction == "录屏/停止录屏",
                    onTap: () => _startRecording("录屏/停止录屏"),
                    onClear: () => _applyKey("录屏/停止录屏", 0, 0),
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
}

/// 单个快捷键条目：显示当前绑定，点击进入录制
class _ShortcutTile extends StatelessWidget {
  final String title;
  final int keyId;
  final int modifiers;
  final bool recording;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _ShortcutTile({
    required this.title,
    required this.keyId,
    required this.modifiers,
    required this.recording,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final keyLabel = AppSettingsController.physicalKeyLabel(keyId);
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
          if (keyId != AppSettingsController.kShortcutDisabled)
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