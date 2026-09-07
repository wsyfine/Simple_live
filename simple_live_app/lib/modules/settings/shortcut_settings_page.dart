import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';

/// 直播间快捷键设置页（Windows 桌面端）
/// 支持单键位与组合键（Ctrl/Alt/Shift/Win），配置持久化到本地
class ShortcutSettingsPage extends GetView<AppSettingsController> {
  const ShortcutSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
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
              "在直播间页面按快捷键即可触发对应操作。"
              "支持自定义组合键（如 Ctrl+F）。"
              "点击条目进行设置。",
              style: Get.textTheme.bodySmall!
                  .copyWith(color: Colors.grey),
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
                    onChanged: (keyId, modifiers) {
                      controller.setLiveRoomShortcutFullScreen(
                          keyId, modifiers);
                    },
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => _ShortcutTile(
                    title: "显示/隐藏弹幕",
                    keyId: controller.liveRoomShortcutDanmaku.value,
                    modifiers:
                        controller.liveRoomShortcutDanmakuModifiers.value,
                    onChanged: (keyId, modifiers) {
                      controller.setLiveRoomShortcutDanmaku(keyId, modifiers);
                    },
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => _ShortcutTile(
                    title: "静音/取消静音",
                    keyId: controller.liveRoomShortcutMute.value,
                    modifiers: controller.liveRoomShortcutMuteModifiers.value,
                    onChanged: (keyId, modifiers) {
                      controller.setLiveRoomShortcutMute(keyId, modifiers);
                    },
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => _ShortcutTile(
                    title: "刷新直播间",
                    keyId: controller.liveRoomShortcutRefresh.value,
                    modifiers:
                        controller.liveRoomShortcutRefreshModifiers.value,
                    onChanged: (keyId, modifiers) {
                      controller.setLiveRoomShortcutRefresh(keyId, modifiers);
                    },
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => _ShortcutTile(
                    title: "收起/展开聊天区",
                    keyId: controller.liveRoomShortcutToggleChat.value,
                    modifiers:
                        controller.liveRoomShortcutToggleChatModifiers.value,
                    onChanged: (keyId, modifiers) {
                      controller.setLiveRoomShortcutToggleChat(keyId, modifiers);
                    },
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => _ShortcutTile(
                    title: "调高音量",
                    keyId: controller.liveRoomShortcutVolumeUp.value,
                    modifiers:
                        controller.liveRoomShortcutVolumeUpModifiers.value,
                    onChanged: (keyId, modifiers) {
                      controller.setLiveRoomShortcutVolumeUp(keyId, modifiers);
                    },
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => _ShortcutTile(
                    title: "调低音量",
                    keyId: controller.liveRoomShortcutVolumeDown.value,
                    modifiers:
                        controller.liveRoomShortcutVolumeDownModifiers.value,
                    onChanged: (keyId, modifiers) {
                      controller.setLiveRoomShortcutVolumeDown(keyId, modifiers);
                    },
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => _ShortcutTile(
                    title: "调高亮度",
                    keyId: controller.liveRoomShortcutBrightnessUp.value,
                    modifiers:
                        controller.liveRoomShortcutBrightnessUpModifiers.value,
                    onChanged: (keyId, modifiers) {
                      controller.setLiveRoomShortcutBrightnessUp(
                          keyId, modifiers);
                    },
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => _ShortcutTile(
                    title: "调低亮度",
                    keyId: controller.liveRoomShortcutBrightnessDown.value,
                    modifiers: controller
                        .liveRoomShortcutBrightnessDownModifiers.value,
                    onChanged: (keyId, modifiers) {
                      controller.setLiveRoomShortcutBrightnessDown(
                          keyId, modifiers);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 单个快捷键条目：显示当前绑定，点击弹出编辑面板
class _ShortcutTile extends StatelessWidget {
  final String title;
  final int keyId;
  final int modifiers;
  final void Function(int keyId, int modifiers) onChanged;

  const _ShortcutTile({
    required this.title,
    required this.keyId,
    required this.modifiers,
    required this.onChanged,
  });

  static const _modifierBits = [
    AppSettingsController.kModifierCtrl,
    AppSettingsController.kModifierAlt,
    AppSettingsController.kModifierShift,
    AppSettingsController.kModifierWin,
  ];

  @override
  Widget build(BuildContext context) {
    final keyLabel =
        AppSettingsController.liveRoomShortcutOptions[keyId] ?? "未知";
    final modifierLabel = AppSettingsController.modifierLabel(modifiers);
    final display =
        modifierLabel.isEmpty ? keyLabel : "$modifierLabel+$keyLabel";
    return ListTile(
      visualDensity: VisualDensity.compact,
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      subtitle: keyId == AppSettingsController.kShortcutDisabled
          ? const Text(
              "已关闭",
              style: TextStyle(color: Colors.grey),
            )
          : null,
      contentPadding: AppStyle.edgeInsetsL16.copyWith(right: 8),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            display,
            style: Theme.of(context)
                .textTheme
                .bodyMedium!
                .copyWith(color: Colors.grey),
          ),
          AppStyle.hGap4,
          const Icon(
            Icons.chevron_right,
            color: Colors.grey,
          ),
        ],
      ),
      onTap: () => openEditor(context),
    );
  }

  /// 弹出编辑面板：选择键位 + 勾选修饰键
  void openEditor(BuildContext context) {
    var selectedKeyId = keyId;
    var selectedModifiers = modifiers;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setState) => SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: AppStyle.edgeInsetsA12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "设置「$title」快捷键",
                  style: Get.textTheme.titleMedium,
                ),
                AppStyle.vGap12,
                const Text(
                  "修饰键（可多选）",
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                Wrap(
                  spacing: 8,
                  children: _modifierBits.map((bit) {
                    final name = switch (bit) {
                      AppSettingsController.kModifierCtrl => "Ctrl",
                      AppSettingsController.kModifierAlt => "Alt",
                      AppSettingsController.kModifierShift => "Shift",
                      _ => "Win",
                    };
                    final checked = (selectedModifiers & bit) != 0;
                    return FilterChip(
                      label: Text(name),
                      selected: checked,
                      onSelected: (e) {
                        setState(() {
                          if (e) {
                            selectedModifiers |= bit;
                          } else {
                            selectedModifiers &= ~bit;
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                AppStyle.vGap12,
                const Text(
                  "主键位",
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children:
                      AppSettingsController.liveRoomShortcutOptions.entries.map(
                    (entry) {
                      final keyName = entry.key;
                      final label = entry.value;
                      return FilterChip(
                        label: Text(label),
                        selected: selectedKeyId == keyName,
                        onSelected: (e) {
                          setState(() {
                            selectedKeyId = keyName;
                          });
                        },
                      );
                    },
                  ).toList(),
                ),
                AppStyle.vGap24,
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: const Text("取消"),
                    ),
                    AppStyle.hGap8,
                    FilledButton(
                      onPressed: selectedKeyId ==
                              AppSettingsController.kShortcutDisabled
                          ? () {
                              Get.back();
                              onChanged(
                                  AppSettingsController.kShortcutDisabled, 0);
                            }
                          : () {
                              Get.back();
                              onChanged(selectedKeyId, selectedModifiers);
                            },
                      child: const Text("确定"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}