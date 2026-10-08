import 'dart:io';

import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Windows 系统托盘服务
///
/// 关闭主窗口时隐藏到系统托盘（而不是退出应用），
/// 可以通过托盘图标的右键菜单恢复窗口或真正退出。
///
/// 仅 Windows 生效。
class TrayService extends GetxService with TrayListener, WindowListener {
  static TrayService get instance => Get.find<TrayService>();

  /// 托盘图标路径
  ///
  /// 必须是 assets 相对路径：tray_manager 内部会拼接
  /// `<exe目录>/data/flutter_assets/<这里的值>`。
  /// Windows 下必须使用 .ico 文件（原生用 LoadImage + IMAGE_ICON 加载）。
  static const String _iconPath = "assets/icons/tray_icon.ico";

  bool _initialized = false;
  bool _quitting = false;

  /// 托盘子系统和窗口关闭拦截是否都已就绪。
  ///
  /// 只有它为 true 时才会把「关闭窗口」变成「隐藏到托盘」；
  /// 否则窗口会被隐藏却没有任何入口能恢复它。
  bool _trayReady = false;

  /// 托盘菜单只构建一次并复用，菜单项 id 因此保持稳定；
  /// 重新设置菜单时只同步勾选状态。
  Menu? _menu;
  MenuItem? _menuItemMinimizeToTray;

  /// 合并并发的菜单刷新请求，避免重复调用原生接口
  bool _menuUpdating = false;
  bool _menuUpdatePending = false;

  bool get _supported => Platform.isWindows;

  /// 是否正在执行「退出应用」流程。
  ///
  /// 退出时会先隐藏窗口再销毁，隐藏会触发各处的窗口事件回调；
  /// 直播间据此跳过后台挂起，避免在引擎析构前再改动播放器状态。
  bool get isQuitting => _quitting;

  Future<TrayService> init() async {
    if (!_supported || _initialized) {
      return this;
    }
    _initialized = true;

    trayManager.addListener(this);
    windowManager.addListener(this);

    // 先准备好托盘图标和菜单。只有托盘可用时才拦截窗口关闭，
    // 否则窗口会被隐藏且没有任何入口能恢复它。
    final trayReady = await _setupTray();
    if (!trayReady) {
      Log.logPrint("系统托盘初始化失败，关闭窗口时仍将直接退出");
      return this;
    }

    try {
      // 常驻开启，不随设置项动态切换：onWindowClose 中会实时读取设置
      // 决定「隐藏」还是「退出」。
      // 注意 windowManager.destroy() 走的是 PostQuitMessage(0)，不经过
      // WM_CLOSE，因此定时关闭 / 拒绝免责声明等退出路径不受这里影响。
      await windowManager.setPreventClose(true);
    } catch (e) {
      Log.logPrint("设置窗口关闭拦截失败，关闭窗口时仍将直接退出：$e");
      return this;
    }
    _trayReady = true;

    // 在设置页修改开关时，同步托盘菜单里的勾选状态
    ever(AppSettingsController.instance.minimizeToTrayEnable, (_) {
      _updateMenu();
    });

    return this;
  }

  Future<bool> _setupTray() async {
    try {
      await trayManager.setIcon(_iconPath);
      await trayManager.setToolTip("Simple Live");
      await _updateMenu();
      return true;
    } catch (e) {
      Log.logPrint("创建托盘图标失败：$e");
      return false;
    }
  }

  /// 构建托盘菜单。
  ///
  /// 只构建一次并长期复用，这样每个菜单项的 id 保持稳定。
  void _buildMenu() {
    _menuItemMinimizeToTray = MenuItem.checkbox(
      key: "minimize_to_tray",
      label: "关闭窗口时最小化到托盘",
      checked: AppSettingsController.instance.minimizeToTrayEnable.value,
      onClick: (item) {
        final next = !(item.checked ?? false);
        item.checked = next;
        AppSettingsController.instance.setMinimizeToTrayEnable(next);
      },
    );
    _menu = Menu(
      items: [
        MenuItem(
          key: "show",
          label: "显示主窗口",
          onClick: (item) {
            showWindow();
          },
        ),
        MenuItem.separator(),
        _menuItemMinimizeToTray!,
        MenuItem.separator(),
        MenuItem(
          key: "exit",
          label: "退出 Simple Live",
          onClick: (item) {
            quitApp();
          },
        ),
      ],
    );
  }

  Future<void> _updateMenu() async {
    if (_quitting) {
      return;
    }
    // 同时只跑一次，期间到来的请求合并为一次补充刷新
    if (_menuUpdating) {
      _menuUpdatePending = true;
      return;
    }
    _menuUpdating = true;
    try {
      do {
        _menuUpdatePending = false;
        final firstBuild = _menu == null;
        if (firstBuild) {
          _buildMenu();
        }
        final item = _menuItemMinimizeToTray!;
        final want =
            AppSettingsController.instance.minimizeToTrayEnable.value;
        if (firstBuild) {
          await trayManager.setContextMenu(_menu!);
        } else if (item.checked != want) {
          // 只在勾选状态真的变了才下发。
          // 菜单项自身的点击已经改过 checked，此时两边一致，
          // 直接跳过，避免与 tray_manager 内部的勾选同步重复调用原生接口。
          item.checked = want;
          await trayManager.setContextMenu(_menu!);
        }
      } while (_menuUpdatePending && !_quitting);
    } catch (e) {
      Log.logPrint("更新托盘菜单失败：$e");
    } finally {
      _menuUpdating = false;
    }
  }

  /// 显示并激活主窗口
  Future<void> showWindow() async {
    try {
      if (!await windowManager.isVisible()) {
        await windowManager.show();
      }
      if (await windowManager.isMinimized()) {
        await windowManager.restore();
      }
      await windowManager.focus();
    } catch (e) {
      Log.logPrint("显示主窗口失败：$e");
    }
  }

  /// 隐藏到系统托盘
  Future<void> hideToTray() async {
    // 提示信息渲染在应用窗口内，窗口隐藏后就看不到了，
    // 所以首次隐藏时先提示、稍等再隐藏。
    // 这里独立 try/catch：提示失败不能影响真正的隐藏。
    try {
      final tipShown = LocalStorageService.instance.getValue(
        LocalStorageService.kTrayTipShown,
        false,
      );
      if (!tipShown) {
        await LocalStorageService.instance.setValue(
          LocalStorageService.kTrayTipShown,
          true,
        );
        SmartDialog.showToast("已最小化到托盘，单击托盘图标可恢复窗口");
        await Future.delayed(const Duration(milliseconds: 1200));
      }
    } catch (e) {
      Log.logPrint("显示托盘提示失败：$e");
    }

    try {
      await windowManager.hide();
    } catch (e) {
      Log.logPrint("最小化到托盘失败：$e");
    }
  }

  /// 真正退出应用。
  ///
  /// 顺序很重要：先移除托盘图标、再隐藏窗口，最后才销毁窗口。
  /// 销毁窗口只是投递一条退出消息，真正耗时的是此后的引擎与播放器
  /// 析构；把窗口提前隐藏，这段耗时就发生在用户看不到的地方。
  Future<void> quitApp() async {
    if (_quitting) {
      return;
    }
    _quitting = true;
    try {
      // 先移除托盘图标，避免退出后在托盘留下幽灵图标
      await trayManager.destroy();
    } catch (e) {
      Log.logPrint(e);
    }
    try {
      // 先把窗口藏起来再销毁。
      // windowManager.destroy() 只投递 WM_QUIT，窗口要等消息循环退出、
      // FlutterViewController 析构完成后才被真正销毁；播放直播时
      // libmpv 的析构要一两秒，窗口若留在屏幕上，Windows 会把它判定为
      // 无响应并叠加等待光标（转圈）。先隐藏，用户看到的就是"点了就关"。
      await windowManager.hide();
    } catch (e) {
      Log.logPrint(e);
    }
    try {
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
      return;
    } catch (e) {
      Log.logPrint(e);
    }
    exit(0);
  }

  /// 用户点击窗口关闭按钮
  @override
  void onWindowClose() {
    if (_quitting || !_trayReady) {
      return;
    }
    if (AppSettingsController.instance.minimizeToTrayEnable.value) {
      hideToTray();
    } else {
      quitApp();
    }
  }

  /// 左键单击托盘图标（Windows 原生把 WM_LBUTTONUP 映射到这里）
  @override
  void onTrayIconMouseDown() {
    showWindow();
  }

  /// 右键单击托盘图标：原生不会自动弹出菜单，需要手动调用
  @override
  void onTrayIconRightMouseDown() async {
    try {
      // ignore: deprecated_member_use
      await trayManager.popUpContextMenu(bringAppToFront: true);
    } catch (e) {
      Log.logPrint("弹出托盘菜单失败：$e");
    }
  }

  @override
  void onClose() {
    try {
      trayManager.removeListener(this);
      windowManager.removeListener(this);
    } catch (e) {
      Log.logPrint(e);
    }
    super.onClose();
  }
}
