import 'dart:async';
import 'dart:io';
import 'package:auto_orientation_v2/auto_orientation_v2.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:floating/floating.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/custom_throttle.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';

mixin PlayerMixin {
  GlobalKey<VideoState> globalPlayerKey = GlobalKey<VideoState>();
  GlobalKey globalDanmuKey = GlobalKey();

  /// 播放器实例
  late final player = Player(
    configuration: PlayerConfiguration(
      title: "Simple Live Player",
      logLevel: AppSettingsController.instance.logEnable.value
          ? MPVLogLevel.info
          : MPVLogLevel.error,
    ),
  );

  /// 初始化播放器并设置 ao 参数
  Future<void> initializePlayer() async {
    var pp = player.platform as NativePlayer;
    // 设置浏览器 UA：libmpv 默认 UA（libmpv/xxx）会被部分 CDN 以 403 拒绝，
    // 通过 MPV 的 user-agent 属性（而非 http-header-fields）覆盖默认 UA 才能生效
    try {
      await pp.setProperty(
        'user-agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
      );
    } catch (e) {
      Log.logPrint(e);
    }
    // 设置音频输出驱动
    if (AppSettingsController.instance.customPlayerOutput.value) {
      if (player.platform is NativePlayer) {
        await (player.platform as dynamic).setProperty(
          'ao',
          AppSettingsController.instance.audioOutputDriver.value,
        );
      }
    }
    // media_kit 仓库更新导致的问题，临时解决办法
    if(Platform.isAndroid){
      await pp.setProperty('force-seekable', 'yes');
    }
  }

  /// 视频控制器
  late final videoController = VideoController(
    player,
    configuration: AppSettingsController.instance.customPlayerOutput.value
        ? VideoControllerConfiguration(
            vo: AppSettingsController.instance.videoOutputDriver.value,
            hwdec: AppSettingsController.instance.videoHardwareDecoder.value,
          )
        : AppSettingsController.instance.playerCompatMode.value
            ? const VideoControllerConfiguration(
                vo: 'mediacodec_embed',
                hwdec: 'mediacodec',
              )
            // Windows: 显式指定 vo/hwdec，避免默认 libmpv + hwdec=auto
            // 在部分显卡驱动下硬解失败且无回退，导致有声音无画面的灰屏
            // hwdec=auto-safe 会在硬解失败时自动回退到软解
            : Platform.isWindows
                ? VideoControllerConfiguration(
                    vo: 'gpu',
                    hwdec: AppSettingsController.instance.hardwareDecode.value
                        ? 'auto-safe'
                        : 'no',
                    enableHardwareAcceleration:
                        AppSettingsController.instance.hardwareDecode.value,
                    androidAttachSurfaceAfterVideoParameters: false,
                  )
                : VideoControllerConfiguration(
                    enableHardwareAcceleration:
                        AppSettingsController.instance.hardwareDecode.value,
                    androidAttachSurfaceAfterVideoParameters: false,
                  ),
  );
}

mixin PlayerStateMixin on PlayerMixin {
  ///音量控制条计时器
  Timer? hidevolumeTimer;

  /// 是否进入桌面端小窗
  RxBool smallWindowState = false.obs;

  /// 是否显示弹幕
  RxBool showDanmakuState = false.obs;

  /// 是否显示控制器
  RxBool showControlsState = false.obs;

  /// 是否显示设置窗口
  RxBool showSettingState = false.obs;

  /// 是否显示弹幕设置窗口
  RxBool showDanmakuSettingState = false.obs;

  /// 是否处于锁定控制器状态
  RxBool lockControlsState = false.obs;

  /// 是否处于全屏状态
  RxBool fullScreenState = false.obs;

  /// 显示手势Tip
  RxBool showGestureTip = false.obs;

  /// 手势Tip文本
  RxString gestureTipText = "".obs;

  /// 显示提示底部Tip
  RxBool showBottomTip = false.obs;

  /// 提示底部Tip文本
  RxString bottomTipText = "".obs;

  /// 自动隐藏控制器计时器
  Timer? hideControlsTimer;

  /// 自动隐藏提示计时器
  Timer? hideSeekTipTimer;

  /// 是否为竖屏直播间
  var isVertical = false.obs;

  Widget? danmakuView;

  var showQualites = false.obs;
  var showLines = false.obs;

  /// 隐藏控制器
  void hideControls() {
    showControlsState.value = false;
    hideControlsTimer?.cancel();
  }

  void setLockState() {
    lockControlsState.value = !lockControlsState.value;
    if (lockControlsState.value) {
      showControlsState.value = false;
    } else {
      showControlsState.value = true;
    }
  }

  /// 显示控制器
  void showControls() {
    showControlsState.value = true;
    resetHideControlsTimer();
  }

  /// 开始隐藏控制器计时
  /// - 当点击控制器上时功能时需要重新计时
  void resetHideControlsTimer() {
    hideControlsTimer?.cancel();

    hideControlsTimer = Timer(
      const Duration(
        seconds: 5,
      ),
      hideControls,
    );
  }

  void updateScaleMode() {
    var boxFit = BoxFit.contain;
    double? aspectRatio;
    if (player.state.width != null && player.state.height != null) {
      aspectRatio = player.state.width! / player.state.height!;
    }

    if (AppSettingsController.instance.scaleMode.value == 0) {
      boxFit = BoxFit.contain;
    } else if (AppSettingsController.instance.scaleMode.value == 1) {
      boxFit = BoxFit.fill;
    } else if (AppSettingsController.instance.scaleMode.value == 2) {
      boxFit = BoxFit.cover;
    } else if (AppSettingsController.instance.scaleMode.value == 3) {
      boxFit = BoxFit.contain;
      aspectRatio = 16 / 9;
    } else if (AppSettingsController.instance.scaleMode.value == 4) {
      boxFit = BoxFit.contain;
      aspectRatio = 4 / 3;
    }
    globalPlayerKey.currentState?.update(
      aspectRatio: aspectRatio,
      fit: boxFit,
    );
  }
}
mixin PlayerDanmakuMixin on PlayerStateMixin {
  /// 弹幕控制器
  DanmakuController? danmakuController;

  void initDanmakuController(DanmakuController e) {
    danmakuController = e;
    // danmakuController?.updateOption(
    //   DanmakuOption(
    //     fontSize: AppSettingsController.instance.danmuSize.value,
    //     area: AppSettingsController.instance.danmuArea.value,
    //     duration: AppSettingsController.instance.danmuSpeed.value,
    //     opacity: AppSettingsController.instance.danmuOpacity.value,
    //     strokeWidth: AppSettingsController.instance.danmuStrokeWidth.value,
    //     fontWeight: FontWeight
    //         .values[AppSettingsController.instance.danmuFontWeight.value],
    //   ),
    // );
  }

  void updateDanmuOption(DanmakuOption? option) {
    if (danmakuController == null || option == null) return;
    danmakuController!.updateOption(option);
  }

  void disposeDanmakuController() {
    danmakuController?.clear();
  }

  void addDanmaku(List<DanmakuContentItem> items) {
    if (!showDanmakuState.value) {
      return;
    }
    for (var item in items) {
      danmakuController?.addDanmaku(item);
    }
  }
}
mixin PlayerSystemMixin on PlayerMixin, PlayerStateMixin, PlayerDanmakuMixin {
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  final pip = Floating();
  StreamSubscription<PiPStatus>? _pipSubscription;

  //final VolumeController volumeController = VolumeController();

  /// 初始化一些系统状态
  void initSystem() async {
    if (Platform.isAndroid || Platform.isIOS) {
      VolumeController.instance.showSystemUI = false;
    }

    // 屏幕常亮
    //WakelockPlus.enable();

    // 开始隐藏计时
    resetHideControlsTimer();

    // 进入全屏模式
    if (AppSettingsController.instance.autoFullScreen.value) {
      enterFullScreen();
    }
  }

  /// 释放一些系统状态
  Future resetSystem() async {
    _pipSubscription?.cancel();
    //pip.dispose();
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );

    await setPortraitOrientation();
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      // 亮度重置,桌面平台可能会报错,暂时不处理桌面平台的亮度
      try {
        await ScreenBrightness.instance.resetApplicationScreenBrightness();
      } catch (e) {
        Log.logPrint(e);
      }
    }

    await WakelockPlus.disable();
  }

  /// 进入全屏
  Future<void> enterFullScreen() async {
    fullScreenState.value = true;
    if (Platform.isAndroid || Platform.isIOS) {
      //全屏
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
      if (!isVertical.value) {
        //横屏
        setLandscapeOrientation();
      }
    } else {
      // 保存当前窗口尺寸与位置，便于退出全屏后精确恢复
      try {
        _lastWindowSize = await windowManager.getSize();
        _lastWindowPosition = await windowManager.getPosition();
      } catch (e) {
        Log.logPrint(e);
      }
      await windowManager.setFullScreen(true);
    }
    //danmakuController?.clear();
  }

  /// 退出全屏
  Future<void> exitFull() async {
    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge,
          overlays: SystemUiOverlay.values);
      setPortraitOrientation();
    } else {
      await windowManager.setFullScreen(false);
      // 等窗口恢复非全屏后，显式恢复上次的尺寸与位置，
      // 修复 Windows 上偶尔出现的退出全屏后窗口无法恢复的问题
      try {
        if (_lastWindowSize != null) {
          await windowManager.setSize(_lastWindowSize!);
        }
        if (_lastWindowPosition != null) {
          await windowManager.setPosition(_lastWindowPosition!);
        }
      } catch (e) {
        Log.logPrint(e);
      }
    }
    fullScreenState.value = false;

    //danmakuController?.clear();
  }

  Size? _lastWindowSize;
  Offset? _lastWindowPosition;

  ///小窗模式()
  void enterSmallWindow() async {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      fullScreenState.value = true;
      smallWindowState.value = true;

      // 读取窗口大小
      _lastWindowSize = await windowManager.getSize();
      _lastWindowPosition = await windowManager.getPosition();

      windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      // 获取视频窗口大小
      var width = player.state.width ?? 16;
      var height = player.state.height ?? 9;

      // 横屏还是竖屏
      if (height > width) {
        var aspectRatio = width / height;
        windowManager.setSize(Size(400, 400 / aspectRatio));
      } else {
        var aspectRatio = height / width;
        windowManager.setSize(Size(280 / aspectRatio, 280));
      }

      windowManager.setAlwaysOnTop(true);
    }
  }

  ///退出小窗模式()
  void exitSmallWindow() {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      fullScreenState.value = false;
      smallWindowState.value = false;
      windowManager.setTitleBarStyle(TitleBarStyle.normal);
      // 未记录过窗口大小时跳过恢复，避免空指针/恢复异常
      if (_lastWindowSize != null) {
        windowManager.setSize(_lastWindowSize!);
      }
      if (_lastWindowPosition != null) {
        windowManager.setPosition(_lastWindowPosition!);
      }
      windowManager.setAlwaysOnTop(false);
      //windowManager.setAlignment(Alignment.center);
    }
  }

  /// 设置横屏
  Future setLandscapeOrientation() async {
    if (await beforeIOS16()) {
      AutoOrientation.landscapeAutoMode();
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  /// 设置竖屏
  Future setPortraitOrientation() async {
    if (await beforeIOS16()) {
      AutoOrientation.portraitAutoMode();
    } else {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
  }

  /// 是否是IOS16以下
  Future<bool> beforeIOS16() async {
    if (Platform.isIOS) {
      var info = await deviceInfo.iosInfo;
      var version = info.systemVersion;
      var versionInt = int.tryParse(version.split('.').first) ?? 0;
      return versionInt < 16;
    } else {
      return false;
    }
  }

  /// 是否正在录屏
  final RxBool isRecording = false.obs;

  /// 开启小窗播放前弹幕状态
  bool danmakuStateBeforePIP = false;

  Future enablePIP() async {
    if (!Platform.isAndroid) {
      return;
    }
    if (await pip.isPipAvailable == false) {
      SmartDialog.showToast("设备不支持小窗播放");
      return;
    }
    danmakuStateBeforePIP = showDanmakuState.value;
    //关闭并清除弹幕
    if (AppSettingsController.instance.pipHideDanmu.value &&
        danmakuStateBeforePIP) {
      showDanmakuState.value = false;
    }
    danmakuController?.clear();
    //关闭控制器
    showControlsState.value = false;

    //监听事件
    var width = player.state.width ?? 0;
    var height = player.state.height ?? 0;
    Rational ratio = const Rational.landscape();
    if (height > width) {
      ratio = const Rational.vertical();
    } else {
      ratio = const Rational.landscape();
    }
    await pip.enable(
      ImmediatePiP(
        aspectRatio: ratio,
      ),
    );

    _pipSubscription ??= pip.pipStatusStream.listen((event) {
      if (event == PiPStatus.disabled) {
        danmakuController?.clear();
        showDanmakuState.value = danmakuStateBeforePIP;
      }
      Log.w(event.toString());
    });
  }
}
mixin PlayerGestureControlMixin
    on PlayerStateMixin, PlayerMixin, PlayerSystemMixin {
  /// 单击显示/隐藏控制器
  void onTap() {
    if (showControlsState.value) {
      hideControls();
    } else {
      showControls();
    }
  }

  //桌面端操控
  void onEnter(PointerEnterEvent event) {
    if (!showControlsState.value) {
      showControls();
    }
  }

  void onExit(PointerExitEvent event) {
    if (showControlsState.value) {
      hideControls();
    }
  }

  /// 桌面端鼠标在播放区内移动时显示控制器并重新计时
  /// - 控制器已显示时仅重新计时，移动到控制条以外的区域也能保持常亮
  void onHover(PointerHoverEvent event, BuildContext context) {
    showControls();
  }

  /// 双击全屏/退出全屏
  void onDoubleTap(TapDownDetails details) {
    if (lockControlsState.value) {
      return;
    }
    if (fullScreenState.value) {
      exitFull();
    } else {
      enterFullScreen();
    }
  }

  bool verticalDragging = false;
  bool leftVerticalDrag = false;
  var _currentVolume = 0.0;
  var _currentBrightness = 1.0;
  var verStartPosition = 0.0;

  DelayedThrottle? throttle;

  /// 竖向手势开始
  void onVerticalDragStart(DragStartDetails details) async {
    if (lockControlsState.value && fullScreenState.value) {
      return;
    }

    final dy = details.globalPosition.dy;
    // 开始位置必须是中间2/4的位置
    if (dy < Get.height * 0.25 || dy > Get.height * 0.75) {
      return;
    }

    verStartPosition = dy;
    leftVerticalDrag = details.globalPosition.dx < Get.width / 2;

    throttle = DelayedThrottle(200);

    verticalDragging = true;
    // 所有平台都显示调节数值浮层（含Windows/macOS桌面端）
    showGestureTip.value = true;
    // 重置跨手势去重状态，避免新手势首次拖动被旧值跳过
    lastVolume = -1;
    _lastAppliedVolume = -1;
    if (Platform.isAndroid || Platform.isIOS) {
      _currentVolume = await VolumeController.instance.getVolume();
    } else {
      // 桌面端：优先读取系统当前音量作为基线（与手势写入的系统音量同通道，
      // 避免基线偏差导致音量跳变/衰减异常）；失败时回退应用设置值
      try {
        _currentVolume = await VolumeController.instance.getVolume();
        if (_currentVolume < 0 || _currentVolume > 1) {
          throw StateError("invalid volume");
        }
      } catch (e) {
        _currentVolume =
            AppSettingsController.instance.playerVolume.value / 100;
      }
    }
    try {
      _currentBrightness = await ScreenBrightness.instance.application;
    } catch (e) {
      // 部分桌面平台可能不支持读取亮度，默认按 1.0 处理
      _currentBrightness = 1.0;
    }
  }

  /// 竖向手势更新
  void onVerticalDragUpdate(DragUpdateDetails e) async {
    if (lockControlsState.value && fullScreenState.value) {
      return;
    }
    if (verticalDragging == false) return;

    //String text = "";
    //double value = 0.0;

    if (leftVerticalDrag) {
      setGestureBrightness(e.globalPosition.dy);
    } else {
      setGestureVolume(e.globalPosition.dy);
    }
  }

  int lastVolume = -1; // it's ok to be -1

  void setGestureVolume(double dy) {
    double value = 0.0;
    double seek;
    if (dy > verStartPosition) {
      value = ((dy - verStartPosition) / (Get.height * 0.5));

      seek = _currentVolume - value;
      if (seek < 0) {
        seek = 0;
      }
    } else {
      value = ((dy - verStartPosition) / (Get.height * 0.5));
      seek = value.abs() + _currentVolume;
      if (seek > 1) {
        seek = 1;
      }
    }
    int volume = _convertVolume((seek * 100).round());
    if (volume == lastVolume) {
      return;
    }
    lastVolume = volume;
    // update UI outside throttle to make it more fluent
    gestureTipText.value = "音量 $volume%";
    throttle?.invoke(() async => await _realSetVolume(volume));
  }

  // 0 to 100, 5 step each
  int _convertVolume(int volume) {
    return (volume / 5).round() * 5;
  }

  Future _realSetVolume(int volume) async {
    if (volume == _lastAppliedVolume) {
      return;
    }
    _lastAppliedVolume = volume;
    try {
      await VolumeController.instance.setVolume(volume / 100);
    } catch (e) {
      Log.logPrint(e);
    }
    // 同步应用设置与持久化，保证下次手势/设置页/快捷键基线一致，
    // 避免手势改的是系统音量而基线仍是旧设置导致的音量衰减/弹回
    AppSettingsController.instance.setPlayerVolume(volume.toDouble());
  }

  // 上一次已应用的音量（用于去重）
  int _lastAppliedVolume = -1;

  // 亮度节流：限制高频平台调用，避免卡顿掉帧
  DateTime? _lastBrightnessApplyAt;
  double _lastAppliedBrightness = -1;
  static const _brightnessApplyMinInterval = Duration(milliseconds: 50);

  void setGestureBrightness(double dy) {
    double value = 0.0;
    double seek;
    if (dy > verStartPosition) {
      value = ((dy - verStartPosition) / (Get.height * 0.5));
      seek = _currentBrightness - value;
      if (seek < 0) {
        seek = 0;
      }
    } else {
      value = ((dy - verStartPosition) / (Get.height * 0.5));
      seek = value.abs() + _currentBrightness;
      if (seek > 1) {
        seek = 1;
      }
    }
    // UI 数值实时更新，不经过节流
    gestureTipText.value = "亮度 ${(seek * 100).toInt()}%";
    _applyBrightnessThrottled(seek);
  }

  /// 节流应用亮度（Windows 上 WMI/平台通道调用较慢，过高频率会阻塞主线程导致掉帧）
  void _applyBrightnessThrottled(double seek) {
    final now = DateTime.now();
    if (_lastBrightnessApplyAt != null &&
        now.difference(_lastBrightnessApplyAt!) < _brightnessApplyMinInterval) {
      return;
    }
    _lastBrightnessApplyAt = now;
    // 值去重：几乎相同的亮度不重复设置
    if ((seek - _lastAppliedBrightness).abs() < 0.005) {
      return;
    }
    _lastAppliedBrightness = seek;
    try {
      ScreenBrightness.instance.setApplicationScreenBrightness(seek);
    } catch (e) {
      Log.logPrint(e);
    }
  }

  /// 竖向手势完成
  void onVerticalDragEnd(DragEndDetails details) async {
    if (lockControlsState.value && fullScreenState.value) {
      return;
    }
    throttle = null;
    verticalDragging = false;
    leftVerticalDrag = false;
    showGestureTip.value = false;
  }
}

class PlayerController extends BaseController
    with
        PlayerMixin,
        PlayerStateMixin,
        PlayerDanmakuMixin,
        PlayerSystemMixin,
        PlayerGestureControlMixin {
  @override
  void onInit() {
    initSystem();
    initStream();
    //设置音量
    player.setVolume(AppSettingsController.instance.playerVolume.value);
    // 启动播放停滞 watchdog
    _startPlaybackStallWatchdog();
    super.onInit();
  }

  // --- 播放停滞 watchdog 相关变量 ---
  Timer? _playbackStallWatchdogTimer;
  Timer? _playbackStallStableTimer;
  Duration? _stallLastPosition;
  DateTime? _stallLastProgressAt;
  DateTime? _lastPlaybackStallRecoveryAt;
  int _stallLoadGeneration = 0;
  String? _stallMediaUri;
  int _playbackStallRecoveryAttempts = 0;
  bool _playbackStallRecoveryInFlight = false;

  static const _playbackStallSampleInterval = Duration(seconds: 3);
  static const _playbackStallTimeout = Duration(seconds: 15);
  static const _playbackBufferingStallTimeout = Duration(seconds: 30);
  static const _playbackStallCooldown = Duration(seconds: 5);
  static const _maxPlaybackStallRecoveryAttempts = 3;

  StreamSubscription<String>? _errorSubscription;
  StreamSubscription? _completedSubscription;
  StreamSubscription? _widthSubscription;
  StreamSubscription? _heightSubscription;
  StreamSubscription? _logSubscription;
  StreamSubscription? _playingSubscription;

  void initStream() {
    _errorSubscription = player.stream.error.listen((event) {
      Log.d("播放器错误：$event");
      // 跳过无音频输出的错误
      // Could not open/initialize audio device -> no sound.
      if (event.contains('no sound.')) {
        return;
      }
      //SmartDialog.showToast(event);
      mediaError(event);
    });

    _playingSubscription = player.stream.playing.listen((event) {
      if (event) {
        WakelockPlus.enable();
        Log.d("Playing");
      }
    });

    _completedSubscription = player.stream.completed.listen((event) {
      if (event) {
        mediaEnd();
      }
    });
    _logSubscription = player.stream.log.listen((event) {
      Log.d("播放器日志：$event");
    });
    _widthSubscription = player.stream.width.listen((event) {
      Log.d(
          'width:$event  W:${(player.state.width)}  H:${(player.state.height)}');
      isVertical.value =
          (player.state.height ?? 9) > (player.state.width ?? 16);
    });
    _heightSubscription = player.stream.height.listen((event) {
      Log.d(
          'height:$event  W:${(player.state.width)}  H:${(player.state.height)}');
      isVertical.value =
          (player.state.height ?? 9) > (player.state.width ?? 16);
    });
  }

  void disposeStream() {
    _errorSubscription?.cancel();
    _completedSubscription?.cancel();
    _widthSubscription?.cancel();
    _heightSubscription?.cancel();
    _logSubscription?.cancel();
    _pipSubscription?.cancel();
    _playingSubscription?.cancel();
  }

  void mediaEnd() {
    WakelockPlus.disable();
  }

  void mediaError(String error) {
    WakelockPlus.disable();
  }

  void showDebugInfo() {
    Utils.showBottomSheet(
      title: "播放信息",
      child: ListView(
        children: [
          ListTile(
            title: const Text("Resolution"),
            subtitle: Text('${player.state.width}x${player.state.height}'),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text:
                      "Resolution\n${player.state.width}x${player.state.height}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("VideoParams"),
            subtitle: Text(player.state.videoParams.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: "VideoParams\n${player.state.videoParams}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("AudioParams"),
            subtitle: Text(player.state.audioParams.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: "AudioParams\n${player.state.audioParams}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("Media"),
            subtitle: Text(player.state.playlist.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: "Media\n${player.state.playlist}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("AudioTrack"),
            subtitle: Text(player.state.track.audio.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: "AudioTrack\n${player.state.track.audio}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("VideoTrack"),
            subtitle: Text(player.state.track.video.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: "VideoTrack\n${player.state.track.audio}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("AudioBitrate"),
            subtitle: Text(player.state.audioBitrate.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: "AudioBitrate\n${player.state.audioBitrate}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("Volume"),
            subtitle: Text(player.state.volume.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: "Volume\n${player.state.volume}",
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void onClose() async {
    Log.w("播放器关闭");
    if (smallWindowState.value) {
      exitSmallWindow();
    }
    disposeStream();
    disposeDanmakuController();
    await resetSystem();
    await player.dispose();
    // 停止播放停滞 watchdog
    _playbackStallWatchdogTimer?.cancel();
    _playbackStallStableTimer?.cancel();
    super.onClose();
  }

  /// 启动播放停滞 watchdog
  void _startPlaybackStallWatchdog() {
    _playbackStallWatchdogTimer?.cancel();
    _playbackStallWatchdogTimer = Timer.periodic(
      _playbackStallSampleInterval,
      (_) => _checkPlaybackStall(),
    );
  }

  /// 检查播放是否停滞
  void _checkPlaybackStall() {
    final now = DateTime.now();
    // 使用 playlist.medias[index] 获取当前媒体 URI
    final playlistIndex = player.state.playlist.index;
    final playlistMedias = player.state.playlist.medias;
    String? mediaUri;
    if (playlistIndex >= 0 && playlistIndex < playlistMedias.length) {
      mediaUri = playlistMedias[playlistIndex].uri;
    }
    final position = player.state.position;
    final buffering = player.state.buffering;

    // 如果加载代次或媒体 URI 发生变化，重置计数器
    if (_stallMediaUri != mediaUri) {
      _stallLoadGeneration = player.state.playlist.index;
      _stallMediaUri = mediaUri;
      _stallLastPosition = position;
      _stallLastProgressAt = now;
      _playbackStallRecoveryAttempts = 0;
      _playbackStallStableTimer?.cancel();
      _playbackStallStableTimer = null;
      return;
    }

    // 检查位置是否发生了变化
    if (_stallLastPosition == null || position != _stallLastPosition) {
      _stallLastPosition = position;
      _stallLastProgressAt = now;
      
      // 如果刚刚从恢复中恢复正常播放，重置稳定计时器
      if (_playbackStallRecoveryAttempts > 0 && _playbackStallStableTimer == null) {
        _playbackStallStableTimer = Timer(const Duration(seconds: 30), () {
          _playbackStallStableTimer = null;
          _playbackStallRecoveryAttempts = 0;
        });
      }
      return;
    }

    // 检查是否已经超过停滞超时时间
    final lastProgressAt = _stallLastProgressAt;
    if (lastProgressAt != null &&
        now.difference(lastProgressAt) >
            (buffering ? _playbackBufferingStallTimeout : _playbackStallTimeout)) {
      // 检查是否满足恢复条件
      if (_playbackStallRecoveryInFlight ||
          _playbackStallRecoveryAttempts >= _maxPlaybackStallRecoveryAttempts ||
          (_lastPlaybackStallRecoveryAt != null &&
              now.difference(_lastPlaybackStallRecoveryAt!) < _playbackStallCooldown)) {
        return;
      }

      // 触发恢复操作
      _recoverPlaybackStall();
    }
  }

  /// 恢复播放停滞
  Future<void> _recoverPlaybackStall() async {
    if (_playbackStallRecoveryInFlight) {
      return;
    }

    _playbackStallRecoveryInFlight = true;
    _playbackStallRecoveryAttempts += 1;
    _lastPlaybackStallRecoveryAt = DateTime.now();
    _stallLastProgressAt = DateTime.now();

    SmartDialog.showToast(
      "播放停滞，正在尝试恢复 (${_playbackStallRecoveryAttempts}/$_maxPlaybackStallRecoveryAttempts)",
    );

    try {
      // 尝试换线
      final switched = await Get.find<LiveRoomController>().trySwitchLine();
      if (switched && Get.find<LiveRoomController>().currentLineIndex >= 0) {
        SmartDialog.showToast("已切换到备用线路");
      } else {
        // 如果没有备用线路，则刷新
        Get.find<LiveRoomController>().refreshRoom();
        SmartDialog.showToast("已刷新直播间");
      }
    } catch (e, stackTrace) {
      Log.e("播放停滞恢复失败：$e", stackTrace);
      SmartDialog.showToast("恢复失败，将继续重试");
    } finally {
      _playbackStallRecoveryInFlight = false;
    }
  }

  /// 重置播放停滞样本
  void _resetPlaybackStallSample() {
    _stallLastPosition = null;
    _stallLastProgressAt = null;
    _playbackStallStableTimer?.cancel();
    _playbackStallStableTimer = null;
  }
}
