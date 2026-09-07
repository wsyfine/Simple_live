import 'dart:io';

import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/services/local_storage_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class AppSettingsController extends GetxController {
  static AppSettingsController get instance =>
      Get.find<AppSettingsController>();

  /// 快捷键禁用值
  static const int kShortcutDisabled = 0;

  /// 修饰键掩码：bit0=Ctrl bit1=Alt bit2=Shift bit3=Win
  static const int kModifierCtrl = 1;
  static const int kModifierAlt = 2;
  static const int kModifierShift = 4;
  static const int kModifierWin = 8;

  /// Windows 虚拟键码（VK）名称表（设置界面显示用）
  static String windowsVkLabel(int vk) {
    if (vk >= 0x41 && vk <= 0x5A) return String.fromCharCode(vk);
    if (vk >= 0x30 && vk <= 0x39) return String.fromCharCode(vk);
    if (vk >= 0x70 && vk <= 0x7A) return "F${vk - 0x70 + 1}";
    if (vk >= 0x7B && vk <= 0x87) return "F${vk - 0x70 + 1}";
    switch (vk) {
      case 0x08:
        return "Backspace";
      case 0x09:
        return "Tab";
      case 0x0D:
        return "Enter";
      case 0x1B:
        return "Esc";
      case 0x20:
        return "Space";
      case 0x21:
        return "PageUp";
      case 0x22:
        return "PageDown";
      case 0x23:
        return "End";
      case 0x24:
        return "Home";
      case 0x25:
        return "←";
      case 0x26:
        return "↑";
      case 0x27:
        return "→";
      case 0x28:
        return "↓";
      case 0x2D:
        return "Insert";
      case 0x2E:
        return "Delete";
      case 0x60:
        return "NumPad0";
      case 0x61:
        return "NumPad1";
      case 0x62:
        return "NumPad2";
      case 0x63:
        return "NumPad3";
      case 0x64:
        return "NumPad4";
      case 0x65:
        return "NumPad5";
      case 0x66:
        return "NumPad6";
      case 0x67:
        return "NumPad7";
      case 0x68:
        return "NumPad8";
      case 0x69:
        return "NumPad9";
      case 0x6A:
        return "NumPad*";
      case 0x6B:
        return "NumPad+";
      case 0x6D:
        return "NumPad-";
      case 0x6E:
        return "NumPad.";
      case 0x6F:
        return "NumPad/";
      case 0x90:
        return "NumLock";
      case 0x91:
        return "ScrollLock";
      case 0x14:
        return "CapsLock";
      case 0xBA:
        return ";";
      case 0xBB:
        return "=";
      case 0xBC:
        return ",";
      case 0xBD:
        return "-";
      case 0xBE:
        return ".";
      case 0xBF:
        return "/";
      case 0xC0:
        return "`";
      case 0xDB:
        return "[";
      case 0xDC:
        return "\\";
      case 0xDD:
        return "]";
      case 0xDE:
        return "'";
      default:
        return "VK_${vk.toRadixString(16).toUpperCase()}";
    }
  }

  /// 是否为合法可绑定的 Windows 虚拟键码（排除修饰键自身）
  static bool isValidShortcutVk(int vk) {
    if (vk < 0x08 || vk > 0xFF) return false;
    // 排除修饰键：Ctrl/Alt/Shift/Win 及其左右键
    const excluded = {
      0x10, 0x11, 0x12, 0x14, // Shift/Ctrl/Alt/CapsLock
      0x5B, 0x5C, 0x5D, // 左Win/右Win/菜单键
      0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, // 左右 Shift/Ctrl/Alt
    };
    return !excluded.contains(vk);
  }

  /// 修饰键显示名
  static String modifierLabel(int modifiers) {
    if (modifiers == 0) {
      return "";
    }
    final parts = <String>[];
    if (modifiers & kModifierCtrl != 0) parts.add("Ctrl");
    if (modifiers & kModifierAlt != 0) parts.add("Alt");
    if (modifiers & kModifierShift != 0) parts.add("Shift");
    if (modifiers & kModifierWin != 0) parts.add("Win");
    return parts.join("+");
  }

  /// 缩放模式
  var scaleMode = 0.obs;

  var themeMode = 0.obs;

  var firstRun = false;

  @override
  void onInit() {
    themeMode.value = LocalStorageService.instance
        .getValue(LocalStorageService.kThemeMode, 0);
    firstRun = LocalStorageService.instance
        .getValue(LocalStorageService.kFirstRun, true);
    danmuSize.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuSize, 16.0);
    danmuOpacity.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuOpacity, 1.0);
    danmuArea.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuArea, 0.8);
    danmuSpeed.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuSpeed, 10.0);
    danmuEnable.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuEnable, true);
    danmuStrokeWidth.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuStrokeWidth, 2.0);
    danmuTopMargin.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuTopMargin, 0.0);
    danmuBottomMargin.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuBottomMargin, 0.0);
    danmuFontWeight.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuFontWeight, 4);

    hardwareDecode.value = LocalStorageService.instance
        .getValue(LocalStorageService.kHardwareDecode, true);
    chatTextSize.value = LocalStorageService.instance
        .getValue(LocalStorageService.kChatTextSize, 14.0);

    chatTextGap.value = LocalStorageService.instance
        .getValue(LocalStorageService.kChatTextGap, 4.0);

    chatBubbleStyle.value = LocalStorageService.instance.getValue(
      LocalStorageService.kChatBubbleStyle,
      false,
    );

    qualityLevel.value = LocalStorageService.instance
        .getValue(LocalStorageService.kQualityLevel, 1);
    qualityLevelCellular.value = LocalStorageService.instance
        .getValue(LocalStorageService.kQualityLevelCellular, 1);

    autoExitEnable.value = LocalStorageService.instance
        .getValue(LocalStorageService.kAutoExitEnable, false);

    autoExitDuration.value = LocalStorageService.instance
        .getValue(LocalStorageService.kAutoExitDuration, 60);

    roomAutoExitDuration.value = LocalStorageService.instance
        .getValue(LocalStorageService.kRoomAutoExitDuration, 60);

    playerCompatMode.value = LocalStorageService.instance
        .getValue(LocalStorageService.kPlayerCompatMode, false);

    playerAutoPause.value = LocalStorageService.instance
        .getValue(LocalStorageService.kPlayerAutoPause, false);

    playerForceHttps.value = LocalStorageService.instance
        .getValue(LocalStorageService.kPlayerForceHttps, false);

    autoFullScreen.value = LocalStorageService.instance
        .getValue(LocalStorageService.kAutoFullScreen, false);

    // ignore: invalid_use_of_protected_member
    shieldList.value = LocalStorageService.instance.shieldBox.values.toSet();

    scaleMode.value = LocalStorageService.instance.getValue(
      LocalStorageService.kPlayerScaleMode,
      0,
    );

    playerVolume.value = LocalStorageService.instance.getValue(
      LocalStorageService.kPlayerVolume,
      100.0,
    );
    pipHideDanmu.value = LocalStorageService.instance
        .getValue(LocalStorageService.kPIPHideDanmu, true);

    styleColor.value = LocalStorageService.instance
        .getValue(LocalStorageService.kStyleColor, 0xff3498db);

    isDynamic.value = LocalStorageService.instance
        .getValue(LocalStorageService.kIsDynamic, false);

    bilibiliLoginTip.value = LocalStorageService.instance
        .getValue(LocalStorageService.kBilibiliLoginTip, true);

    playerBufferSize.value = LocalStorageService.instance
        .getValue(LocalStorageService.kPlayerBufferSize, 32);

    logEnable.value = LocalStorageService.instance
        .getValue(LocalStorageService.kLogEnable, false);
    if (logEnable.value) {
      Log.initWriter();
    }

    customPlayerOutput.value = LocalStorageService.instance
        .getValue(LocalStorageService.kCustomPlayerOutput, false);

    videoOutputDriver.value = LocalStorageService.instance.getValue(
      LocalStorageService.kVideoOutputDriver,
      Platform.isAndroid ? "gpu" : "libmpv",
    );

    audioOutputDriver.value = LocalStorageService.instance.getValue(
      LocalStorageService.kAudioOutputDriver,
      Platform.isAndroid
          ? "audiotrack"
          : Platform.isLinux
              ? "pulse"
              : Platform.isWindows
                  ? "wasapi"
                  : Platform.isIOS
                      ? "audiounit"
                      : Platform.isMacOS
                          ? "coreaudio"
                          : "sdl",
    );

    videoHardwareDecoder.value = LocalStorageService.instance.getValue(
      LocalStorageService.kVideoHardwareDecoder,
      Platform.isAndroid ? "auto-safe" : "auto",
    );

    autoUpdateFollowEnable.value = LocalStorageService.instance
        .getValue(LocalStorageService.kAutoUpdateFollowEnable, true);

    autoUpdateFollowDuration.value = LocalStorageService.instance
        .getValue(LocalStorageService.kUpdateFollowDuration, 10);

    updateFollowThreadCount.value = LocalStorageService.instance
        .getValue(LocalStorageService.kUpdateFollowThreadCount, 0);  // 默认 0 = 自动

    initSiteSort();
    initHomeSort();
    initLiveRoomShortcutSettings();

    super.onInit();
  }

  void initSiteSort() {
    var sort = LocalStorageService.instance
        .getValue(
          LocalStorageService.kSiteSort,
          Sites.allSites.keys.join(","),
        )
        .split(",");
    //如果数量与allSites的数量不一致，将缺失的添加上
    if (sort.length != Sites.allSites.length) {
      var keys = Sites.allSites.keys.toList();
      for (var i = 0; i < keys.length; i++) {
        if (!sort.contains(keys[i])) {
          sort.add(keys[i]);
        }
      }
    }

    siteSort.value = sort;
  }

  void initHomeSort() {
    var sort = LocalStorageService.instance
        .getValue(
          LocalStorageService.kHomeSort,
          Constant.allHomePages.keys.join(","),
        )
        .split(",");
    //如果数量与allSites的数量不一致，将缺失的添加上
    if (sort.length != Constant.allHomePages.length) {
      var keys = Constant.allHomePages.keys.toList();
      for (var i = 0; i < keys.length; i++) {
        if (!sort.contains(keys[i])) {
          sort.add(keys[i]);
        }
      }
    }

    homeSort.value = sort;
  }

  void setNoFirstRun() {
    LocalStorageService.instance.setValue(LocalStorageService.kFirstRun, false);
  }

  void changeTheme() {
    Get.dialog(
      RadioGroup(
        groupValue: themeMode.value,
        onChanged: (e) {
          Get.back();
          setTheme(e ?? 0);
        },
        child: const SimpleDialog(
          title: Text("设置主题"),
          children: [
            RadioListTile<int>(
              title: Text("跟随系统"),
              value: 0,
            ),
            RadioListTile<int>(
              title: Text("浅色模式"),
              value: 1,
            ),
            RadioListTile<int>(
              title: Text("深色模式"),
              value: 2,
            ),
          ],
        ),
      ),
    );
  }

  void setTheme(int i) {
    themeMode.value = i;
    var mode = ThemeMode.values[i];

    LocalStorageService.instance.setValue(LocalStorageService.kThemeMode, i);
    Get.changeThemeMode(mode);
  }

  var hardwareDecode = true.obs;
  void setHardwareDecode(bool e) {
    hardwareDecode.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kHardwareDecode, e);
  }

  var chatTextSize = 14.0.obs;
  void setChatTextSize(double e) {
    chatTextSize.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kChatTextSize, e);
  }

  var chatTextGap = 4.0.obs;
  void setChatTextGap(double e) {
    chatTextGap.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kChatTextGap, e);
  }

  var chatBubbleStyle = false.obs;
  void setChatBubbleStyle(bool e) {
    chatBubbleStyle.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kChatBubbleStyle, e);
  }

  var danmuSize = 16.0.obs;
  void setDanmuSize(double e) {
    danmuSize.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kDanmuSize, e);
  }

  var danmuSpeed = 10.0.obs;
  void setDanmuSpeed(double e) {
    danmuSpeed.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kDanmuSpeed, e);
  }

  var danmuArea = 0.8.obs;
  void setDanmuArea(double e) {
    danmuArea.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kDanmuArea, e);
  }

  var danmuOpacity = 1.0.obs;
  void setDanmuOpacity(double e) {
    danmuOpacity.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kDanmuOpacity, e);
  }

  var danmuEnable = true.obs;
  void setDanmuEnable(bool e) {
    danmuEnable.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kDanmuEnable, e);
  }

  var danmuStrokeWidth = 2.0.obs;
  void setDanmuStrokeWidth(double e) {
    danmuStrokeWidth.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kDanmuStrokeWidth, e);
  }

  var danmuFontWeight = 4.obs;
  void setDanmuFontWeight(int e) {
    danmuFontWeight.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kDanmuFontWeight, e);
  }

  var qualityLevel = 1.obs;
  void setQualityLevel(int level) {
    qualityLevel.value = level;
    LocalStorageService.instance
        .setValue(LocalStorageService.kQualityLevel, level);
  }

  var qualityLevelCellular = 1.obs;
  void setQualityLevelCellular(int level) {
    qualityLevelCellular.value = level;
    LocalStorageService.instance
        .setValue(LocalStorageService.kQualityLevelCellular, level);
  }

  var autoExitEnable = false.obs;
  void setAutoExitEnable(bool e) {
    autoExitEnable.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kAutoExitEnable, e);
  }

  var autoExitDuration = 60.obs;
  void setAutoExitDuration(int e) {
    autoExitDuration.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kAutoExitDuration, e);
  }

  var roomAutoExitDuration = 60.obs;
  void setRoomAutoExitDuration(int e) {
    roomAutoExitDuration.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kRoomAutoExitDuration, e);
  }

  var playerCompatMode = false.obs;
  void setPlayerCompatMode(bool e) {
    playerCompatMode.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kPlayerCompatMode, e);
  }

  var playerBufferSize = 32.obs;
  void setPlayerBufferSize(int e) {
    playerBufferSize.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kPlayerBufferSize, e);
  }

  var playerAutoPause = false.obs;
  void setPlayerAutoPause(bool e) {
    playerAutoPause.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kPlayerAutoPause, e);
  }

  var autoFullScreen = false.obs;
  void setAutoFullScreen(bool e) {
    autoFullScreen.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kAutoFullScreen, e);
  }

  var playershowSuperChat = true.obs;
  void setPlayerShowSuperChat(bool e) {
    playershowSuperChat.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kPlayerShowSuperChat, e);
  }

  RxSet<String> shieldList = <String>{}.obs;
  void addShieldList(String e) {
    shieldList.add(e);
    LocalStorageService.instance.shieldBox.put(e, e);
  }

  void removeShieldList(String e) {
    shieldList.remove(e);
    LocalStorageService.instance.shieldBox.delete(e);
  }

  Future clearShieldList() async {
    shieldList.clear();
    await LocalStorageService.instance.shieldBox.clear();
  }

  void setScaleMode(int value) {
    scaleMode.value = value;
    LocalStorageService.instance.setValue(
      LocalStorageService.kPlayerScaleMode,
      value,
    );
  }

  RxList<String> siteSort = RxList<String>();
  void setSiteSort(List<String> e) {
    siteSort.value = e;
    LocalStorageService.instance.setValue(
      LocalStorageService.kSiteSort,
      siteSort.join(","),
    );
  }

  RxList<String> homeSort = RxList<String>();
  void setHomeSort(List<String> e) {
    homeSort.value = e;
    LocalStorageService.instance.setValue(
      LocalStorageService.kHomeSort,
      homeSort.join(","),
    );
  }

  Rx<double> playerVolume = 100.0.obs;
  void setPlayerVolume(double value) {
    playerVolume.value = value;
    LocalStorageService.instance.setValue(
      LocalStorageService.kPlayerVolume,
      value,
    );
  }

  var pipHideDanmu = true.obs;
  void setPIPHideDanmu(bool e) {
    pipHideDanmu.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kPIPHideDanmu, e);
  }

  var styleColor = 0xff3498db.obs;
  void setStyleColor(int e) {
    styleColor.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kStyleColor, e);
  }

  var isDynamic = false.obs;
  void setIsDynamic(bool e) {
    isDynamic.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kIsDynamic, e);
  }

  var danmuTopMargin = 0.0.obs;
  void setDanmuTopMargin(double e) {
    danmuTopMargin.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kDanmuTopMargin, e);
  }

  var danmuBottomMargin = 0.0.obs;
  void setDanmuBottomMargin(double e) {
    danmuBottomMargin.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kDanmuBottomMargin, e);
  }

  var bilibiliLoginTip = true.obs;
  void setBiliBiliLoginTip(bool e) {
    bilibiliLoginTip.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kBilibiliLoginTip, e);
  }

  var logEnable = false.obs;
  void setLogEnable(bool e) {
    logEnable.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kLogEnable, e);
  }

  var customPlayerOutput = false.obs;
  void setCustomPlayerOutput(bool e) {
    customPlayerOutput.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kCustomPlayerOutput, e);
  }

  var videoOutputDriver = "".obs;
  void setVideoOutputDriver(String e) {
    videoOutputDriver.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kVideoOutputDriver, e);
  }

  var audioOutputDriver = "".obs;
  void setAudioOutputDriver(String e) {
    audioOutputDriver.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kAudioOutputDriver, e);
  }

  var videoHardwareDecoder = "".obs;
  void setVideoHardwareDecoder(String e) {
    videoHardwareDecoder.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kVideoHardwareDecoder, e);
  }

  var autoUpdateFollowEnable = false.obs;
  void setAutoUpdateFollowEnable(bool e) {
    autoUpdateFollowEnable.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kAutoUpdateFollowEnable, e);
  }

  var autoUpdateFollowDuration = 10.obs;
  void setAutoUpdateFollowDuration(int e) {
    autoUpdateFollowDuration.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kUpdateFollowDuration, e);
  }

  var updateFollowThreadCount = 4.obs;
  void setUpdateFollowThreadCount(int e) {
    updateFollowThreadCount.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kUpdateFollowThreadCount, e);
  }

  var playerForceHttps = false.obs;
  void setPlayerForceHttps(bool e) {
    playerForceHttps.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kPlayerForceHttps, e);
  }

  // ---------- 直播间快捷键配置 ----------
  // 每个快捷键由 vk（Windows 虚拟键码，0=关闭）+ modifiers（修饰键掩码）组成
  // 支持任意单键与组合键，键位完全可配置

  /// Windows VK 常量
  static const int kVkF = 0x46;
  static const int kVkD = 0x44;
  static const int kVkM = 0x4D;
  static const int kVkR = 0x52;
  static const int kVkC = 0x43;
  static const int kVkUp = 0x26;
  static const int kVkDown = 0x28;

  var liveRoomShortcutFullScreen = kVkF.obs;
  var liveRoomShortcutFullScreenModifiers = 0.obs;

  var liveRoomShortcutDanmaku = kVkD.obs;
  var liveRoomShortcutDanmakuModifiers = 0.obs;

  var liveRoomShortcutMute = kVkM.obs;
  var liveRoomShortcutMuteModifiers = 0.obs;

  var liveRoomShortcutRefresh = kVkR.obs;
  var liveRoomShortcutRefreshModifiers = 0.obs;

  var liveRoomShortcutToggleChat = kVkC.obs;
  var liveRoomShortcutToggleChatModifiers = 0.obs;

  var liveRoomShortcutVolumeUp = kVkUp.obs;
  var liveRoomShortcutVolumeUpModifiers = 0.obs;

  var liveRoomShortcutVolumeDown = kVkDown.obs;
  var liveRoomShortcutVolumeDownModifiers = 0.obs;

  /// 亮度+默认 Shift+↑
  var liveRoomShortcutBrightnessUp = kVkUp.obs;
  var liveRoomShortcutBrightnessUpModifiers = kModifierShift.obs;

  /// 亮度-默认 Shift+↓
  var liveRoomShortcutBrightnessDown = kVkDown.obs;
  var liveRoomShortcutBrightnessDownModifiers = kModifierShift.obs;

  /// 初始化直播间快捷键设置
  void initLiveRoomShortcutSettings() {
    liveRoomShortcutFullScreen.value = _readLiveRoomShortcutVk(
      LocalStorageService.kLiveRoomShortcutFullScreen,
      kVkF,
    );
    liveRoomShortcutFullScreenModifiers.value =
        LocalStorageService.instance.getValue(
      LocalStorageService.kLiveRoomShortcutFullScreenModifiers,
      0,
    );

    liveRoomShortcutDanmaku.value = _readLiveRoomShortcutVk(
      LocalStorageService.kLiveRoomShortcutDanmaku,
      kVkD,
    );
    liveRoomShortcutDanmakuModifiers.value =
        LocalStorageService.instance.getValue(
      LocalStorageService.kLiveRoomShortcutDanmakuModifiers,
      0,
    );

    liveRoomShortcutMute.value = _readLiveRoomShortcutVk(
      LocalStorageService.kLiveRoomShortcutMute,
      kVkM,
    );
    liveRoomShortcutMuteModifiers.value =
        LocalStorageService.instance.getValue(
      LocalStorageService.kLiveRoomShortcutMuteModifiers,
      0,
    );

    liveRoomShortcutRefresh.value = _readLiveRoomShortcutVk(
      LocalStorageService.kLiveRoomShortcutRefresh,
      kVkR,
    );
    liveRoomShortcutRefreshModifiers.value =
        LocalStorageService.instance.getValue(
      LocalStorageService.kLiveRoomShortcutRefreshModifiers,
      0,
    );

    liveRoomShortcutToggleChat.value = _readLiveRoomShortcutVk(
      LocalStorageService.kLiveRoomShortcutToggleChat,
      kVkC,
    );
    liveRoomShortcutToggleChatModifiers.value =
        LocalStorageService.instance.getValue(
      LocalStorageService.kLiveRoomShortcutToggleChatModifiers,
      0,
    );

    liveRoomShortcutVolumeUp.value = _readLiveRoomShortcutVk(
      LocalStorageService.kLiveRoomShortcutVolumeUp,
      kVkUp,
    );
    liveRoomShortcutVolumeUpModifiers.value =
        LocalStorageService.instance.getValue(
      LocalStorageService.kLiveRoomShortcutVolumeUpModifiers,
      0,
    );

    liveRoomShortcutVolumeDown.value = _readLiveRoomShortcutVk(
      LocalStorageService.kLiveRoomShortcutVolumeDown,
      kVkDown,
    );
    liveRoomShortcutVolumeDownModifiers.value =
        LocalStorageService.instance.getValue(
      LocalStorageService.kLiveRoomShortcutVolumeDownModifiers,
      0,
    );

    liveRoomShortcutBrightnessUp.value = _readLiveRoomShortcutVk(
      LocalStorageService.kLiveRoomShortcutBrightnessUp,
      kVkUp,
    );
    liveRoomShortcutBrightnessUpModifiers.value =
        LocalStorageService.instance.getValue(
      LocalStorageService.kLiveRoomShortcutBrightnessUpModifiers,
      kModifierShift,
    );

    liveRoomShortcutBrightnessDown.value = _readLiveRoomShortcutVk(
      LocalStorageService.kLiveRoomShortcutBrightnessDown,
      kVkDown,
    );
    liveRoomShortcutBrightnessDownModifiers.value =
        LocalStorageService.instance.getValue(
      LocalStorageService.kLiveRoomShortcutBrightnessDownModifiers,
      kModifierShift,
    );
  }

  /// 校验快捷键 VK 是否合法，不合法回退为关闭
  int _normalizeLiveRoomShortcut(int vk) {
    return isValidShortcutVk(vk) ? vk : kShortcutDisabled;
  }

  /// 兼容读取：旧版存储格式为 LogicalKeyboardKey.keyId（>0xFF 的大整数），
  /// 其低 8 位即 Windows VK 码；新版直接存 VK 码。
  int _readLiveRoomShortcutVk(String storageKey, int defaultValue) {
    final stored =
        LocalStorageService.instance.getValue(storageKey, defaultValue);
    if (stored > 0xFF) {
      return _normalizeLiveRoomShortcut(stored & 0xFF);
    }
    return _normalizeLiveRoomShortcut(stored);
  }

  /// 所有快捷键动作名称（用于冲突提示）
  Map<String, int> get _liveRoomShortcutKeyLabels => {
        "切换全屏": liveRoomShortcutFullScreen.value,
        "显示/隐藏弹幕": liveRoomShortcutDanmaku.value,
        "静音/取消静音": liveRoomShortcutMute.value,
        "刷新直播间": liveRoomShortcutRefresh.value,
        "收起/展开聊天区": liveRoomShortcutToggleChat.value,
        "调高音量": liveRoomShortcutVolumeUp.value,
        "调低音量": liveRoomShortcutVolumeDown.value,
        "调高亮度": liveRoomShortcutBrightnessUp.value,
        "调低亮度": liveRoomShortcutBrightnessDown.value,
      };

  Map<String, int> get _liveRoomShortcutModifierLabels => {
        "切换全屏": liveRoomShortcutFullScreenModifiers.value,
        "显示/隐藏弹幕": liveRoomShortcutDanmakuModifiers.value,
        "静音/取消静音": liveRoomShortcutMuteModifiers.value,
        "刷新直播间": liveRoomShortcutRefreshModifiers.value,
        "收起/展开聊天区": liveRoomShortcutToggleChatModifiers.value,
        "调高音量": liveRoomShortcutVolumeUpModifiers.value,
        "调低音量": liveRoomShortcutVolumeDownModifiers.value,
        "调高亮度": liveRoomShortcutBrightnessUpModifiers.value,
        "调低亮度": liveRoomShortcutBrightnessDownModifiers.value,
      };

  /// 设置快捷键（含冲突检测）
  void _setLiveRoomShortcut({
    required int keyId,
    required int modifiers,
    required RxInt keyTarget,
    required RxInt modifierTarget,
    required String actionName,
    required String storageKey,
    required String modifiersStorageKey,
  }) {
    final normalized = _normalizeLiveRoomShortcut(keyId);
    // 如果设置为关闭，跳过冲突检测
    if (normalized != kShortcutDisabled) {
      for (final entry in _liveRoomShortcutKeyLabels.entries) {
        if (entry.key == actionName) {
          continue;
        }
        if (entry.value == normalized &&
            _liveRoomShortcutModifierLabels[entry.key] == modifiers) {
          SmartDialog.showToast("该按键已用于${entry.key}");
          return;
        }
      }
    }
    keyTarget.value = normalized;
    modifierTarget.value = modifiers;
    LocalStorageService.instance.setValue(storageKey, normalized);
    LocalStorageService.instance
        .setValue(modifiersStorageKey, modifiers);
  }

  void setLiveRoomShortcutFullScreen(int keyId, int modifiers) {
    _setLiveRoomShortcut(
      keyId: keyId,
      modifiers: modifiers,
      keyTarget: liveRoomShortcutFullScreen,
      modifierTarget: liveRoomShortcutFullScreenModifiers,
      actionName: "切换全屏",
      storageKey: LocalStorageService.kLiveRoomShortcutFullScreen,
      modifiersStorageKey:
          LocalStorageService.kLiveRoomShortcutFullScreenModifiers,
    );
  }

  void setLiveRoomShortcutDanmaku(int keyId, int modifiers) {
    _setLiveRoomShortcut(
      keyId: keyId,
      modifiers: modifiers,
      keyTarget: liveRoomShortcutDanmaku,
      modifierTarget: liveRoomShortcutDanmakuModifiers,
      actionName: "显示/隐藏弹幕",
      storageKey: LocalStorageService.kLiveRoomShortcutDanmaku,
      modifiersStorageKey:
          LocalStorageService.kLiveRoomShortcutDanmakuModifiers,
    );
  }

  void setLiveRoomShortcutMute(int keyId, int modifiers) {
    _setLiveRoomShortcut(
      keyId: keyId,
      modifiers: modifiers,
      keyTarget: liveRoomShortcutMute,
      modifierTarget: liveRoomShortcutMuteModifiers,
      actionName: "静音/取消静音",
      storageKey: LocalStorageService.kLiveRoomShortcutMute,
      modifiersStorageKey: LocalStorageService.kLiveRoomShortcutMuteModifiers,
    );
  }

  void setLiveRoomShortcutRefresh(int keyId, int modifiers) {
    _setLiveRoomShortcut(
      keyId: keyId,
      modifiers: modifiers,
      keyTarget: liveRoomShortcutRefresh,
      modifierTarget: liveRoomShortcutRefreshModifiers,
      actionName: "刷新直播间",
      storageKey: LocalStorageService.kLiveRoomShortcutRefresh,
      modifiersStorageKey:
          LocalStorageService.kLiveRoomShortcutRefreshModifiers,
    );
  }

  void setLiveRoomShortcutToggleChat(int keyId, int modifiers) {
    _setLiveRoomShortcut(
      keyId: keyId,
      modifiers: modifiers,
      keyTarget: liveRoomShortcutToggleChat,
      modifierTarget: liveRoomShortcutToggleChatModifiers,
      actionName: "收起/展开聊天区",
      storageKey: LocalStorageService.kLiveRoomShortcutToggleChat,
      modifiersStorageKey:
          LocalStorageService.kLiveRoomShortcutToggleChatModifiers,
    );
  }

  void setLiveRoomShortcutVolumeUp(int keyId, int modifiers) {
    _setLiveRoomShortcut(
      keyId: keyId,
      modifiers: modifiers,
      keyTarget: liveRoomShortcutVolumeUp,
      modifierTarget: liveRoomShortcutVolumeUpModifiers,
      actionName: "调高音量",
      storageKey: LocalStorageService.kLiveRoomShortcutVolumeUp,
      modifiersStorageKey:
          LocalStorageService.kLiveRoomShortcutVolumeUpModifiers,
    );
  }

  void setLiveRoomShortcutVolumeDown(int keyId, int modifiers) {
    _setLiveRoomShortcut(
      keyId: keyId,
      modifiers: modifiers,
      keyTarget: liveRoomShortcutVolumeDown,
      modifierTarget: liveRoomShortcutVolumeDownModifiers,
      actionName: "调低音量",
      storageKey: LocalStorageService.kLiveRoomShortcutVolumeDown,
      modifiersStorageKey:
          LocalStorageService.kLiveRoomShortcutVolumeDownModifiers,
    );
  }

  void setLiveRoomShortcutBrightnessUp(int keyId, int modifiers) {
    _setLiveRoomShortcut(
      keyId: keyId,
      modifiers: modifiers,
      keyTarget: liveRoomShortcutBrightnessUp,
      modifierTarget: liveRoomShortcutBrightnessUpModifiers,
      actionName: "调高亮度",
      storageKey: LocalStorageService.kLiveRoomShortcutBrightnessUp,
      modifiersStorageKey:
          LocalStorageService.kLiveRoomShortcutBrightnessUpModifiers,
    );
  }

  void setLiveRoomShortcutBrightnessDown(int keyId, int modifiers) {
    _setLiveRoomShortcut(
      keyId: keyId,
      modifiers: modifiers,
      keyTarget: liveRoomShortcutBrightnessDown,
      modifierTarget: liveRoomShortcutBrightnessDownModifiers,
      actionName: "调低亮度",
      storageKey: LocalStorageService.kLiveRoomShortcutBrightnessDown,
      modifiersStorageKey:
          LocalStorageService.kLiveRoomShortcutBrightnessDownModifiers,
    );
  }
}
