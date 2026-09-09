import 'dart:io';

import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/services/local_storage_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// 默认物理键（PhysicalKeyboardKey.usbHidUsage）
  static int get kPhysicalKeyF => PhysicalKeyboardKey.keyF.usbHidUsage;
  static int get kPhysicalKeyD => PhysicalKeyboardKey.keyD.usbHidUsage;
  static int get kPhysicalKeyM => PhysicalKeyboardKey.keyM.usbHidUsage;
  static int get kPhysicalKeyR => PhysicalKeyboardKey.keyR.usbHidUsage;
  static int get kPhysicalKeyC => PhysicalKeyboardKey.keyC.usbHidUsage;
  static int get kPhysicalKeyUp => PhysicalKeyboardKey.arrowUp.usbHidUsage;
  static int get kPhysicalKeyDown => PhysicalKeyboardKey.arrowDown.usbHidUsage;
  static int get kPhysicalKeyEnter => PhysicalKeyboardKey.enter.usbHidUsage;
  static int get kPhysicalKeyEscape => PhysicalKeyboardKey.escape.usbHidUsage;
  static int get kPhysicalKeyLeft => PhysicalKeyboardKey.arrowLeft.usbHidUsage;
  static int get kPhysicalKeyRight => PhysicalKeyboardKey.arrowRight.usbHidUsage;

  /// 物理键 usage 显示名（USB HID usage，与大小写/布局/输入法无关，release 下
  /// Flutter 的 debugName 为空，故自定义映射表）
  static String physicalKeyLabel(int usage) {
    if (usage == kShortcutDisabled) return "未设置";
    final int u = usage & 0x0000FFFF;
    // 字母 A-Z: 0x04-0x1D
    if (u >= 0x04 && u <= 0x1D) {
      return String.fromCharCode(0x41 + u - 0x04);
    }
    // 数字 1-9: 0x1E-0x26；0: 0x27
    if (u >= 0x1E && u <= 0x26) {
      return String.fromCharCode(0x31 + u - 0x1E);
    }
    if (u == 0x27) return "0";
    // F1-F12: 0x3A-0x45；F13-F24: 0x68-0x73
    if (u >= 0x3A && u <= 0x45) return "F${u - 0x3A + 1}";
    if (u >= 0x68 && u <= 0x73) return "F${u - 0x68 + 13}";
    switch (u) {
      case 0x28:
        return "Enter";
      case 0x29:
        return "Esc";
      case 0x2A:
        return "Backspace";
      case 0x2B:
        return "Tab";
      case 0x2C:
        return "Space";
      case 0x4F:
        return "→";
      case 0x50:
        return "←";
      case 0x51:
        return "↓";
      case 0x52:
        return "↑";
      case 0x49:
        return "Insert";
      case 0x4A:
        return "Home";
      case 0x4B:
        return "PageUp";
      case 0x4C:
        return "Delete";
      case 0x4D:
        return "End";
      case 0x4E:
        return "PageDown";
      case 0x58:
        return "NumPadEnter";
      case 0x54:
        return "/";
      case 0x55:
        return "*";
      case 0x56:
        return "-";
      case 0x57:
        return "+";
      case 0x59:
        return "NumPad1";
      case 0x5A:
        return "NumPad2";
      case 0x5B:
        return "NumPad3";
      case 0x5C:
        return "NumPad4";
      case 0x5D:
        return "NumPad5";
      case 0x5E:
        return "NumPad6";
      case 0x5F:
        return "NumPad7";
      case 0x60:
        return "NumPad8";
      case 0x61:
        return "NumPad9";
      case 0x62:
        return "NumPad0";
      case 0x63:
        return "NumPad.";
      default:
        return "KEY_0x${u.toRadixString(16).toUpperCase()}";
    }
  }

  /// 是否为合法可绑定的物理键（USB HID keyboard 页，排除修饰键自身）
  static bool isValidShortcutPhysicalKey(int usage) {
    if (usage <= 0) return false;
    // 必须在 USB HID keyboard/consumer 页内（0x0007xxxx / 0x000Cxxxx）
    final int page = usage & 0xFFFF0000;
    if (page != 0x00070000 && page != 0x000C0000) return false;
    // 排除修饰键：Ctrl/Alt/Shift/Win/Super/Fn/CapsLock（usbHidUsage 值）
    const excluded = <int>{
      0x000700e0, // controlLeft
      0x000700e4, // controlRight
      0x000700e1, // shiftLeft
      0x000700e5, // shiftRight
      0x000700e2, // altLeft
      0x000700e6, // altRight
      0x000700e3, // metaLeft
      0x000700e7, // metaRight
      0x00000011, // superKey
      0x00000012, // fn
      0x00070039, // capsLock
    };
    return !excluded.contains(usage);
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
  // 每个快捷键由 physical usage（PhysicalKeyboardKey.usbHidUsage，物理键，
  // 与大小写/CapsLock/Shift/键盘布局/输入法状态无关）+ modifiers（修饰键掩码）组成
  // 键位完全可配置：任意单键与组合键，无固定键位白名单

  var liveRoomShortcutFullScreen = kPhysicalKeyF.obs;
  var liveRoomShortcutFullScreenModifiers = 0.obs;

  var liveRoomShortcutDanmaku = kPhysicalKeyD.obs;
  var liveRoomShortcutDanmakuModifiers = 0.obs;

  var liveRoomShortcutMute = kPhysicalKeyM.obs;
  var liveRoomShortcutMuteModifiers = 0.obs;

  var liveRoomShortcutRefresh = kPhysicalKeyR.obs;
  var liveRoomShortcutRefreshModifiers = 0.obs;

  var liveRoomShortcutToggleChat = kPhysicalKeyC.obs;
  var liveRoomShortcutToggleChatModifiers = 0.obs;

  var liveRoomShortcutVolumeUp = kPhysicalKeyUp.obs;
  var liveRoomShortcutVolumeUpModifiers = 0.obs;

  var liveRoomShortcutVolumeDown = kPhysicalKeyDown.obs;
  var liveRoomShortcutVolumeDownModifiers = 0.obs;

  /// 亮度+默认 Shift+↑
  var liveRoomShortcutBrightnessUp = kPhysicalKeyUp.obs;
  var liveRoomShortcutBrightnessUpModifiers = kModifierShift.obs;

  /// 亮度-默认 Shift+↓
  var liveRoomShortcutBrightnessDown = kPhysicalKeyDown.obs;
  var liveRoomShortcutBrightnessDownModifiers = kModifierShift.obs;

  /// 初始化直播间快捷键设置
  void initLiveRoomShortcutSettings() {
    liveRoomShortcutFullScreen.value = _readLiveRoomShortcutPhysical(
      LocalStorageService.kLiveRoomShortcutFullScreen,
      kPhysicalKeyF,
    );
    liveRoomShortcutFullScreenModifiers.value =
        LocalStorageService.instance.getValue(
      LocalStorageService.kLiveRoomShortcutFullScreenModifiers,
      0,
    );

    liveRoomShortcutDanmaku.value = _readLiveRoomShortcutPhysical(
      LocalStorageService.kLiveRoomShortcutDanmaku,
      kPhysicalKeyD,
    );
    liveRoomShortcutDanmakuModifiers.value =
        LocalStorageService.instance.getValue(
      LocalStorageService.kLiveRoomShortcutDanmakuModifiers,
      0,
    );

    liveRoomShortcutMute.value = _readLiveRoomShortcutPhysical(
      LocalStorageService.kLiveRoomShortcutMute,
      kPhysicalKeyM,
    );
    liveRoomShortcutMuteModifiers.value =
        LocalStorageService.instance.getValue(
      LocalStorageService.kLiveRoomShortcutMuteModifiers,
      0,
    );

    liveRoomShortcutRefresh.value = _readLiveRoomShortcutPhysical(
      LocalStorageService.kLiveRoomShortcutRefresh,
      kPhysicalKeyR,
    );
    liveRoomShortcutRefreshModifiers.value =
        LocalStorageService.instance.getValue(
      LocalStorageService.kLiveRoomShortcutRefreshModifiers,
      0,
    );

    liveRoomShortcutToggleChat.value = _readLiveRoomShortcutPhysical(
      LocalStorageService.kLiveRoomShortcutToggleChat,
      kPhysicalKeyC,
    );
    liveRoomShortcutToggleChatModifiers.value =
        LocalStorageService.instance.getValue(
      LocalStorageService.kLiveRoomShortcutToggleChatModifiers,
      0,
    );

    liveRoomShortcutVolumeUp.value = _readLiveRoomShortcutPhysical(
      LocalStorageService.kLiveRoomShortcutVolumeUp,
      kPhysicalKeyUp,
    );
    liveRoomShortcutVolumeUpModifiers.value =
        LocalStorageService.instance.getValue(
      LocalStorageService.kLiveRoomShortcutVolumeUpModifiers,
      0,
    );

    liveRoomShortcutVolumeDown.value = _readLiveRoomShortcutPhysical(
      LocalStorageService.kLiveRoomShortcutVolumeDown,
      kPhysicalKeyDown,
    );
    liveRoomShortcutVolumeDownModifiers.value =
        LocalStorageService.instance.getValue(
      LocalStorageService.kLiveRoomShortcutVolumeDownModifiers,
      0,
    );

    liveRoomShortcutBrightnessUp.value = _readLiveRoomShortcutPhysical(
      LocalStorageService.kLiveRoomShortcutBrightnessUp,
      kPhysicalKeyUp,
    );
    liveRoomShortcutBrightnessUpModifiers.value =
        LocalStorageService.instance.getValue(
      LocalStorageService.kLiveRoomShortcutBrightnessUpModifiers,
      kModifierShift,
    );

    liveRoomShortcutBrightnessDown.value = _readLiveRoomShortcutPhysical(
      LocalStorageService.kLiveRoomShortcutBrightnessDown,
      kPhysicalKeyDown,
    );
    liveRoomShortcutBrightnessDownModifiers.value =
        LocalStorageService.instance.getValue(
      LocalStorageService.kLiveRoomShortcutBrightnessDownModifiers,
      kModifierShift,
    );
  }

  /// 校验快捷键 physical usage 是否合法，不合法回退为关闭
  int _normalizeLiveRoomShortcut(int usage) {
    return isValidShortcutPhysicalKey(usage) ? usage : kShortcutDisabled;
  }

  /// 兼容读取：存储里可能是本版 physical usage、上一版 Windows VK 码、
  /// 或更早版 LogicalKeyboardKey.keyId，统一迁移为 physical usage。
  int _readLiveRoomShortcutPhysical(String storageKey, int defaultValue) {
    final stored =
        LocalStorageService.instance.getValue(storageKey, defaultValue);
    if (stored <= 0) {
      return kShortcutDisabled;
    }
    if (isValidShortcutPhysicalKey(stored)) {
      return stored;
    }
    final int? migrated = _legacyToPhysical(stored);
    if (migrated != null) {
      return migrated;
    }
    return defaultValue;
  }

  /// 旧值（VK 码 / LogicalKeyboardKey.keyId）→ PhysicalKeyboardKey.usbHidUsage
  static int? _legacyToPhysical(int legacy) {
    if (legacy <= 0) return null;
    // 已经是 physical usage（0x0007xxxx）
    if ((legacy & 0xFFFF0000) == 0x00070000) {
      return legacy;
    }
    // LogicalKeyboardKey 字母 keyId（0x61-0x7A）或 VK 字母（0x41-0x5A）
    final int letter = legacy & 0xFF;
    if (letter >= 0x41 && letter <= 0x5A) {
      return PhysicalKeyboardKey.keyA.usbHidUsage + (letter - 0x41);
    }
    if (letter >= 0x61 && letter <= 0x7A) {
      return PhysicalKeyboardKey.keyA.usbHidUsage + (letter - 0x61);
    }
    // LogicalKeyboardKey 数字 keyId / VK 数字（0x30-0x39）
    if (letter >= 0x30 && letter <= 0x39) {
      return PhysicalKeyboardKey.digit0.usbHidUsage -
          (letter == 0x30 ? 0 : (0x31 - letter)); // digit0=0x27, digit1=0x1e...
    }
    // VK F1-F24（0x70-0x87）
    if (legacy >= 0x70 && legacy <= 0x7B) {
      return PhysicalKeyboardKey.f1.usbHidUsage + (legacy - 0x70);
    }
    if (legacy >= 0x7C && legacy <= 0x87) {
      return 0x00070068 + (legacy - 0x7C);
    }
    // LogicalKeyboardKey 功能键 keyId（0x00100000801..0x818）
    if (legacy >= 0x00100000801 && legacy <= 0x00100000818) {
      return 0x0007003A + (legacy - 0x00100000801);
    }
    // 方向键/编辑键（VK 或 LogicalKeyboardKey keyId）
    switch (legacy) {
      // LogicalKeyboardKey keyId
      case 0x00100000302:
        return PhysicalKeyboardKey.arrowLeft.usbHidUsage;
      case 0x00100000304:
        return PhysicalKeyboardKey.arrowUp.usbHidUsage;
      case 0x00100000303:
        return PhysicalKeyboardKey.arrowRight.usbHidUsage;
      case 0x00100000301:
        return PhysicalKeyboardKey.arrowDown.usbHidUsage;
      case 0x0010000000d:
        return PhysicalKeyboardKey.enter.usbHidUsage;
      case 0x0010000001b:
        return PhysicalKeyboardKey.escape.usbHidUsage;
      case 0x00100000008:
        return PhysicalKeyboardKey.backspace.usbHidUsage;
      case 0x00100000308:
        return PhysicalKeyboardKey.pageUp.usbHidUsage;
      case 0x00100000307:
        return PhysicalKeyboardKey.pageDown.usbHidUsage;
      case 0x00100000306:
        return PhysicalKeyboardKey.home.usbHidUsage;
      case 0x00100000305:
        return PhysicalKeyboardKey.end.usbHidUsage;
      // VK 码
      case 0x25:
        return PhysicalKeyboardKey.arrowLeft.usbHidUsage;
      case 0x26:
        return PhysicalKeyboardKey.arrowUp.usbHidUsage;
      case 0x27:
        return PhysicalKeyboardKey.arrowRight.usbHidUsage;
      case 0x28:
        return PhysicalKeyboardKey.arrowDown.usbHidUsage;
      case 0x0D:
        return PhysicalKeyboardKey.enter.usbHidUsage;
      case 0x1B:
        return PhysicalKeyboardKey.escape.usbHidUsage;
      case 0x08:
        return PhysicalKeyboardKey.backspace.usbHidUsage;
      case 0x21:
        return PhysicalKeyboardKey.pageUp.usbHidUsage;
      case 0x22:
        return PhysicalKeyboardKey.pageDown.usbHidUsage;
      case 0x24:
        return PhysicalKeyboardKey.home.usbHidUsage;
      case 0x23:
        return PhysicalKeyboardKey.end.usbHidUsage;
      case 0x20:
        return PhysicalKeyboardKey.space.usbHidUsage;
      case 0x2D:
        return PhysicalKeyboardKey.insert.usbHidUsage;
      case 0x2E:
        return PhysicalKeyboardKey.delete.usbHidUsage;
      default:
        return null;
    }
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
