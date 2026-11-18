import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:get/get.dart';
import 'package:global_repository/global_repository.dart';
import 'package:settings/settings.dart';

import '../../core/config/environment_config.dart';
import '../../core/config/service_ports.dart';
import '../../core/constants/scripts.dart' as scripts;
import 'terminal_controller.dart';

class OpenQQDefaults {
  static const String storageKey = 'openqq_instance';
  static const String autoStopVncKey = 'openqq_auto_stop_vnc';

  static const String version = 'v0.3.0';
  static const String installRoot = '/root/OpenQQ';
  static const String installMarker = '/root/.openqq-android/installed.json';

  static const int display = 1;
  static const int webPort = 17860;
  static const int vncPort = 5900;
  static const int novncPort = 6080;
  static const int oneBotPort = ServicePorts.defaultOneBotWsPort;

  static const List<String> assets = [
    'openqq-install.sh',
    'openqq-start.sh',
    'openqq-stop.sh',
    'openqq-vnc-start.sh',
    'openqq-vnc-stop.sh',
    'openqq-display-start.sh',
    'openqq-node-start.sh',
  ];
}

class OpenQQInstance {
  String version = '';
  String qq = '';
  String selfId = '';
  String accessToken = '';
  String webUiUrl = '';
  String webUiToken = '';
  String lastError = '';

  bool installed = false;
  bool running = false;
  bool starting = false;
  bool stopping = false;
  bool installing = false;
  bool loggedIn = false;
  bool vncRunning = false;
  bool astrBotConnected = false;

  int webPort = OpenQQDefaults.webPort;
  int vncPort = OpenQQDefaults.vncPort;
  int novncPort = OpenQQDefaults.novncPort;
  int oneBotPort = OpenQQDefaults.oneBotPort;
  int display = OpenQQDefaults.display;

  Map<String, dynamic> toStorage() => {
        'version': version,
        'qq': qq,
        'selfId': selfId,
        'accessToken': accessToken,
        'webPort': webPort,
        'vncPort': vncPort,
        'novncPort': novncPort,
        'oneBotPort': oneBotPort,
        'display': display,
      };

  void applyStorage(Map<String, dynamic> data) {
    version = data['version']?.toString() ?? version;
    qq = data['qq']?.toString() ?? qq;
    selfId = data['selfId']?.toString() ?? selfId;
    accessToken = data['accessToken']?.toString() ?? accessToken;
    webPort = _int(data['webPort'], webPort);
    vncPort = _int(data['vncPort'], vncPort);
    novncPort = _int(data['novncPort'], novncPort);
    oneBotPort = _int(data['oneBotPort'], oneBotPort);
    display = _int(data['display'], display);
  }

  static int _int(dynamic value, int fallback) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}

class OpenQQController extends GetxController {
  final OpenQQInstance instance = OpenQQInstance();
  final RxBool autoStopVnc = true.obs;
  final RxBool busy = false.obs;

  HomeController get _home => Get.find<HomeController>();

  File get _installMarkerFile =>
      File('${scripts.ubuntuPath}${OpenQQDefaults.installMarker}');
  File get _astrBotConfigFile =>
      File('${scripts.ubuntuPath}/root/AstrBot/data/cmd_config.json');
  File get _openQQConfigFile =>
      File('${scripts.ubuntuPath}${OpenQQDefaults.installRoot}/config/openqq.json');

  String _runtimeBuffer = '';

  @override
  void onInit() {
    super.onInit();
    _load();
    unawaited(refreshInstalled());
  }

  void _load() {
    final stored = box?.get(OpenQQDefaults.storageKey);
    if (stored is Map) {
      instance.applyStorage(Map<String, dynamic>.from(stored));
    }
    final stop = box?.get(OpenQQDefaults.autoStopVncKey);
    if (stop is bool) autoStopVnc.value = stop;
  }

  void _save() {
    box?.put(OpenQQDefaults.storageKey, instance.toStorage());
  }

  void setAutoStopVnc(bool value) {
    autoStopVnc.value = value;
    box?.put(OpenQQDefaults.autoStopVncKey, value);
  }

  Future<void> refreshInstalled() async {
    try {
      if (!await _installMarkerFile.exists()) {
        instance.installed = false;
        return;
      }
      final data = await _readJsonMap(_installMarkerFile);
      final version = data?['openqq']?.toString() ?? '';
      instance.version = version;
      instance.installed = version == OpenQQDefaults.version;
      if (instance.installed) {
        final config = await _readJsonMap(_openQQConfigFile);
        instance.accessToken =
            config?['accessToken']?.toString() ?? instance.accessToken;
      }
    } catch (e) {
      Log.e('读取 OpenQQ 安装状态失败: $e', tag: 'OpenQQ');
      instance.installed = false;
    }
    update();
  }

  Future<void> install() async {
    if (instance.installing) return;
    instance.installing = true;
    instance.lastError = '';
    busy.value = true;
    update();
    try {
      await _home.prepareInitialUbuntuEnvironment();
      await _copyAssetsToUbuntu();
      final proxy = _shellQuote(EnvironmentConfig.githubProxy);
      final command = _ubuntuCommand(
        'export ASTRBOT_GITHUB_PROXY=$proxy; bash /root/openqq-install.sh',
      );
      await _home.terminalTabManager.addCommandTerminalTab(
        title: '安装 OpenQQ',
        command: command,
        showInTerminal: true,
        onDoneMarker: '__OPENQQ_INSTALL_DONE__',
        onOutput: (output) {
          if (output.contains('__OPENQQ_ALREADY_INSTALLED__')) {
            instance.lastError = '';
          }
        },
        onCommandDone: () {
          instance.installing = false;
          busy.value = false;
          unawaited(refreshInstalled());
        },
        onCommandExit: (code) {
          if (code != 0) {
            instance.lastError = 'OpenQQ 安装失败，退出码 $code';
          }
          instance.installing = false;
          busy.value = false;
          update();
        },
      );
    } catch (e) {
      instance.installing = false;
      busy.value = false;
      instance.lastError = e.toString();
      update();
      rethrow;
    }
  }

  Future<void> start() async {
    if (instance.running || instance.starting) return;
    await refreshInstalled();
    if (!instance.installed) {
      throw StateError('OpenQQ 尚未安装');
    }
    await _copyAssetsToUbuntu();
    if (await _home.isPortAvailable(ServicePorts.dashboardPort)) {
      throw StateError('请先启动 AstrBot');
    }
    instance.starting = true;
    instance.running = false;
    instance.loggedIn = false;
    instance.lastError = '';
    _runtimeBuffer = '';
    busy.value = true;
    update();
    try {
      await _syncOpenQQConfig(updateAstrBot: false);
      final readyFile =
          File('${scripts.ubuntuPath}/tmp/openqq-display-ready');
      try {
        if (await readyFile.exists()) await readyFile.delete();
      } catch (_) {}
      await _home.terminalTabManager.addCommandTerminalTab(
        title: 'OpenQQ',
        command: _ubuntuCommand('exec bash /root/openqq-display-start.sh'),
        showInTerminal: true,
        onOutput: (output) {
          if (output.contains('noVNC:')) {
            instance.vncRunning = true;
          }
          _parseRuntimeOutput(output);
        },
        onCommandExit: (code) {
          instance.running = false;
          instance.starting = false;
          instance.loggedIn = false;
          instance.vncRunning = false;
          if (code != 0 && instance.lastError.isEmpty) {
            instance.lastError = 'OpenQQ 已退出，退出码 $code';
          }
          busy.value = false;
          update();
        },
      );
    } catch (e) {
      instance.starting = false;
      busy.value = false;
      instance.lastError = e.toString();
      update();
      rethrow;
    }
  }

  Future<void> stop() async {
    if (instance.stopping) return;
    instance.stopping = true;
    busy.value = true;
    update();
    try {
      await _home.prepareTerminalEnvironment();
      final command = _ubuntuCommand('bash /root/openqq-stop.sh');
      await _home.terminalTabManager.addCommandTerminalTab(
        title: '停止 OpenQQ',
        command: command,
        showInTerminal: false,
        onCommandExit: (_) {
          instance.running = false;
          instance.starting = false;
          instance.loggedIn = false;
          instance.vncRunning = false;
          instance.stopping = false;
          busy.value = false;
          update();
        },
      );
    } catch (e) {
      instance.stopping = false;
      busy.value = false;
      instance.lastError = e.toString();
      update();
      rethrow;
    }
  }

  Future<void> startVnc() async {
    await _home.prepareTerminalEnvironment();
    await _home.terminalTabManager.addCommandTerminalTab(
      title: '启动 OpenQQ 登录画面',
      command: _ubuntuCommand('bash /root/openqq-vnc-start.sh'),
      showInTerminal: true,
      onOutput: (output) {
        if (output.contains('noVNC:')) {
          instance.vncRunning = true;
          update();
        }
      },
      onCommandExit: (code) {
        if (code == 0) {
          instance.vncRunning = true;
        }
        update();
      },
    );
  }

  Future<void> stopVnc() async {
    await _home.prepareTerminalEnvironment();
    await _home.terminalTabManager.addCommandTerminalTab(
      title: '停止 OpenQQ 登录画面',
      command: _ubuntuCommand('bash /root/openqq-vnc-stop.sh'),
      showInTerminal: false,
      onCommandExit: (_) {
        instance.vncRunning = false;
        update();
      },
    );
  }

  Future<void> _copyAssetsToUbuntu() async {
    final root = Directory('${scripts.ubuntuPath}/root');
    await root.create(recursive: true);
    for (final name in OpenQQDefaults.assets) {
      final target = File('${root.path}/$name');
      await AssetsUtils.copyAssetToPath(
        'assets/$name',
        target.path,
        forceCopy: true,
      );
    }
  }

  String _ubuntuCommand(String body) {
    final common = '${RuntimeEnvir.homePath}/common.sh';
    return 'source ${_shellQuote(common)}\n'
        'login_ubuntu ${_shellQuote(body)}\n';
  }

  String _shellQuote(String value) {
    return "'${value.replaceAll("'", "'\"'\"'")}'";
  }

  void _parseRuntimeOutput(String output) {
    instance.starting = false;
    instance.running = true;
    _runtimeBuffer += output;
    if (_runtimeBuffer.length > 16384) {
      _runtimeBuffer =
          _runtimeBuffer.substring(_runtimeBuffer.length - 16384);
    }
    final text = _runtimeBuffer;

    final version = RegExp(r'OpenQQ\s+([0-9.]+)\s+QQ 版本=(\S+)')
        .firstMatch(text);
    if (version != null) {
      instance.version = 'v${version.group(1)}';
      instance.qq = version.group(2) ?? instance.qq;
    }

    final webUi = RegExp(
      r'WebUI=http://127\.0\.0\.1:(\d+)/#token=([0-9a-fA-F]+)',
    ).firstMatch(text);
    if (webUi != null) {
      instance.webPort = int.tryParse(webUi.group(1)!) ?? instance.webPort;
      instance.webUiToken = webUi.group(2)!;
      instance.webUiUrl = 'http://127.0.0.1:${instance.webPort}';
    }

    final ready = RegExp(
      r'"type"\s*:\s*"session_ready".*?"self_id"\s*:\s*"(\d+)"',
    ).firstMatch(text);
    if (ready != null && !instance.loggedIn) {
      instance.loggedIn = true;
      instance.selfId = ready.group(1)!;
      instance.qq = instance.selfId;
      instance.running = true;
      instance.starting = false;
      _save();
      update();
      if (autoStopVnc.value) {
        Future<void>.delayed(const Duration(seconds: 3), () {
          unawaited(stopVnc());
        });
      }
      return;
    }

    if (text.contains('hook_error') ||
        text.contains('"type":"offline"') ||
        text.contains('进程输出异常')) {
      instance.loggedIn = false;
      instance.lastError = 'OpenQQ 会话异常，请查看终端日志';
    }
    if (text.contains('noVNC:')) {
      instance.vncRunning = true;
    }
    _save();
    update();
  }

  Future<void> _syncOpenQQConfig({required bool updateAstrBot}) async {
    final astrBot = await _readJsonMap(_astrBotConfigFile);
    if (astrBot == null) {
      throw StateError('AstrBot 配置不存在，请先启动一次 AstrBot');
    }
    final platforms = astrBot['platform'];
    final list = platforms is List ? platforms : <dynamic>[];
    if (platforms is! List) astrBot['platform'] = list;
    Map<String, dynamic>? platform;
    for (final item in list) {
      if (item is Map && item['type']?.toString() == 'aiocqhttp') {
        platform = Map<String, dynamic>.from(item);
        break;
      }
    }
    if (platform == null) {
      if (!updateAstrBot) {
        throw StateError('AstrBot 尚未配置 aiocqhttp，请重启 AstrBot 后再试');
      }
      platform = {
        'id': 'openqq',
        'type': 'aiocqhttp',
        'enable': true,
        'ws_reverse_host': '0.0.0.0',
        'ws_reverse_port': OpenQQDefaults.oneBotPort,
        'ws_reverse_token': _newToken(),
      };
      list.add(platform);
    }
    final existingToken =
        platform['ws_reverse_token']?.toString().trim() ?? '';
    // An empty token is valid for aiocqhttp. Preserve it while AstrBot is
    // already running; generating a new one would require an AstrBot restart.
    final token = existingToken.isNotEmpty
        ? existingToken
        : (updateAstrBot ? _newToken() : '');
    platform['ws_reverse_host'] = '0.0.0.0';
    platform['ws_reverse_port'] = OpenQQDefaults.oneBotPort;
    platform['ws_reverse_token'] = token;
    if (updateAstrBot) {
      await _writeJsonMap(_astrBotConfigFile, astrBot);
    }

    final openQQ = await _readJsonMap(_openQQConfigFile) ?? <String, dynamic>{};
    openQQ['version'] = 1;
    openQQ['qqRoot'] = '/opt/QQ';
    openQQ['webPort'] = OpenQQDefaults.webPort;
    openQQ['accessToken'] =
        openQQ['accessToken']?.toString().trim().isNotEmpty == true
            ? openQQ['accessToken'].toString()
            : _newToken();
    openQQ['ws'] = {
      'enabled': false,
      'host': '127.0.0.1',
      'port': 3001,
    };
    openQQ['reverseWs'] = [
      {
        'enabled': true,
        'url': 'ws://127.0.0.1:${OpenQQDefaults.oneBotPort}/ws',
        'token': token,
      }
    ];
    await _writeJsonMap(_openQQConfigFile, openQQ);
    instance.accessToken = openQQ['accessToken'].toString();
    _save();
  }

  String _newToken() {
    final random = Random.secure();
    return List.generate(32, (_) => random.nextInt(256))
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  Future<Map<String, dynamic>?> _readJsonMap(File file) async {
    if (!await file.exists()) return null;
    var text = await file.readAsString();
    if (text.startsWith('\uFEFF')) text = text.substring(1);
    final decoded = jsonDecode(text);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  Future<void> _writeJsonMap(File file, Map<String, dynamic> data) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
  }
}
