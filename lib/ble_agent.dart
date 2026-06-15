library main;

import 'dart:async';
import 'package:flutter/services.dart';

/// BLE设备信息
class BleDevice {
  final String deviceId;
  final String deviceName;
  final String mac;
  final int rssi;

  BleDevice({
    required this.deviceId,
    required this.deviceName,
    required this.mac,
    required this.rssi,
  });

  factory BleDevice.fromMap(Map<dynamic, dynamic> map) {
    return BleDevice(
      deviceId: map['deviceId'] as String,
      deviceName: map['deviceName'] as String,
      mac: map['mac'] as String,
      rssi: map['rssi'] as int,
    );
  }
}

/// 语言信息
class Language {
  final String key;
  final String value;

  Language({
    required this.key,
    required this.value,
  });

  factory Language.fromMap(Map<dynamic, dynamic> map) {
    return Language(
      key: map['key'] as String,
      value: map['value'] as String,
    );
  }
}

/// 工作模式
enum WorkMode {
  telephoneSubtitle,
  callTranslation,
  bidirectionalTranslation,
}

/// 步骤模式
enum StepMode {
  asr,
  translation,
  tts,
}

/// BLE设备监听器
abstract class BleDeviceListener {
  void onDeviceFound(BleDevice device);
  void onConnected(BleDevice device);
  void onDisconnected(BleDevice device);
  void onError(String error);
  void onAudioModeUpdated(int errorCode, String errorMessage);
  void onAudioStreamData(List<int> audioData);
}

/// 翻译监听器
abstract class TranslationListener {
  void onRecognitionResult(String id, String text, bool isFinal, bool isLeft);
  void onTranslation(String id, String sourceText, String translatedText, bool isLeft);
  void onError(int errorCode, String error);
  void onTtsFile(String id, String filePath, bool isLeft);
  void onConsumeTokens(String tokenType, int tokens);
}

/// BleAgent Flutter SDK
class BleAgentFlutter {
  static const MethodChannel _channel = MethodChannel('ble_agent');
  static const EventChannel _deviceEventChannel = EventChannel('ble_agent/device_events');
  static const EventChannel _translationEventChannel = EventChannel('ble_agent/translation_events');

  final List<BleDeviceListener> _deviceListeners = [];
  final List<TranslationListener> _translationListeners = [];

  StreamSubscription? _deviceEventSubscription;
  StreamSubscription? _translationEventSubscription;

  /// 初始化SDK
  Future<String> initialize({
    required String userId,
    required String organizationId,
    required String secret,
    required String appPackageName,
    required String country,
  }) async {
    try {
      final result = await _channel.invokeMethod<String>('initialize', {
        'userId': userId,
        'organizationId': organizationId,
        'secret': secret,
        'appPackageName': appPackageName,
        'country': country,
      });

      // 初始化成功后，设置事件监听
      _setupEventListeners();

      return result ?? '初始化成功';
    } on PlatformException catch (e) {
      throw Exception('初始化失败: ${e.message}');
    }
  }

  /// 设置事件监听器
  void _setupEventListeners() {
    // 设备事件监听
    _deviceEventSubscription = _deviceEventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        final Map<dynamic, dynamic> map = event as Map<dynamic, dynamic>;
        final String eventType = map['eventType'] as String;

        switch (eventType) {
          case 'onDeviceFound':
            final device = BleDevice.fromMap(map['device'] as Map<dynamic, dynamic>);
            for (var listener in _deviceListeners) {
              listener.onDeviceFound(device);
            }
            break;
          case 'onConnected':
            final device = BleDevice.fromMap(map['device'] as Map<dynamic, dynamic>);
            for (var listener in _deviceListeners) {
              listener.onConnected(device);
            }
            break;
          case 'onDisconnected':
            final device = BleDevice.fromMap(map['device'] as Map<dynamic, dynamic>);
            for (var listener in _deviceListeners) {
              listener.onDisconnected(device);
            }
            break;
          case 'onError':
            final error = map['error'] as String;
            for (var listener in _deviceListeners) {
              listener.onError(error);
            }
            break;
          case 'onAudioModeUpdated':
            final errorCode = map['errorCode'] as int;
            final errorMessage = map['errorMessage'] as String;
            for (var listener in _deviceListeners) {
              listener.onAudioModeUpdated(errorCode, errorMessage);
            }
            break;
          case 'onAudioStreamData':
            final audioData = List<int>.from(map['audioData'] as List);
            for (var listener in _deviceListeners) {
              listener.onAudioStreamData(audioData);
            }
            break;
        }
      },
      onError: (dynamic error) {
        for (var listener in _deviceListeners) {
          listener.onError(error.toString());
        }
      },
    );

    // 翻译事件监听
    _translationEventSubscription = _translationEventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        final Map<dynamic, dynamic> map = event as Map<dynamic, dynamic>;
        final String eventType = map['eventType'] as String;

        switch (eventType) {
          case 'onRecognitionResult':
            final id = map['id'] as String;
            final text = map['text'] as String;
            final isFinal = map['isFinal'] as bool;
            final isLeft = map['isLeft'] as bool;
            for (var listener in _translationListeners) {
              listener.onRecognitionResult(id, text, isFinal, isLeft);
            }
            break;
          case 'onTranslation':
            final id = map['id'] as String;
            final sourceText = map['sourceText'] as String;
            final translatedText = map['translatedText'] as String;
            final isLeft = map['isLeft'] as bool;
            for (var listener in _translationListeners) {
              listener.onTranslation(id, sourceText, translatedText, isLeft);
            }
            break;
          case 'onError':
            final errorCode = map['errorCode'] as int;
            final error = map['error'] as String;
            for (var listener in _translationListeners) {
              listener.onError(errorCode, error);
            }
            break;
          case 'onTtsFile':
            final id = map['id'] as String;
            final filePath = map['filePath'] as String;
            final isLeft = map['isLeft'] as bool;
            for (var listener in _translationListeners) {
              listener.onTtsFile(id, filePath, isLeft);
            }
            break;
          case 'onConsumeTokens':
            final tokenType = map['tokenType'] as String;
            final tokens = map['tokens'] as int;
            for (var listener in _translationListeners) {
              listener.onConsumeTokens(tokenType, tokens);
            }
            break;
        }
      },
      onError: (dynamic error) {
        for (var listener in _translationListeners) {
          listener.onError(-1, error.toString());
        }
      },
    );
  }

  /// 扫描设备
  Future<void> scanDevices() async {
    try {
      await _channel.invokeMethod('scanDevices');
    } on PlatformException catch (e) {
      throw Exception('扫描设备失败: ${e.message}');
    }
  }

  /// 停止扫描设备
  Future<void> stopScan() async {
    try {
      await _channel.invokeMethod('stopScan');
    } on PlatformException catch (e) {
      throw Exception('停止扫描失败: ${e.message}');
    }
  }

  /// 连接设备
  Future<void> connectDevice(String deviceId) async {
    try {
      await _channel.invokeMethod('connectDevice', {'deviceId': deviceId});
    } on PlatformException catch (e) {
      throw Exception('连接设备失败: ${e.message}');
    }
  }

  /// 断开设备连接
  Future<void> disconnectDevice() async {
    try {
      await _channel.invokeMethod('disconnectDevice');
    } on PlatformException catch (e) {
      throw Exception('断开连接失败: ${e.message}');
    }
  }

  /// 检查SDK是否已初始化
  Future<bool> isInitialized() async {
    try {
      final result = await _channel.invokeMethod<bool>('isInitialized');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// 检查设备是否已连接
  Future<bool> isDeviceConnected() async {
    try {
      final result = await _channel.invokeMethod<bool>('isDeviceConnected');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// 获取支持的语言列表
  Future<List<Language>> fetchLanguages() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('fetchLanguages');
      return result?.map((e) => Language.fromMap(e as Map<dynamic, dynamic>)).toList() ?? [];
    } on PlatformException catch (e) {
      throw Exception('获取语言列表失败: ${e.message}');
    }
  }

  /// 开始翻译
  Future<void> startTranslation({
    required WorkMode workMode,
    required String sourceLang,
    required String targetLang,
    required StepMode stepMode,
  }) async {
    try {
      await _channel.invokeMethod('startTranslation', {
        'workMode': workMode.index,
        'sourceLang': sourceLang,
        'targetLang': targetLang,
        'stepMode': stepMode.index,
      });
    } on PlatformException catch (e) {
      throw Exception('开始翻译失败: ${e.message}');
    }
  }

  /// 停止录音或翻译
  Future<void> stopRecordingAndTranslation() async {
    try {
      await _channel.invokeMethod('stopRecordingAndTranslation');
    } on PlatformException catch (e) {
      throw Exception('停止失败: ${e.message}');
    }
  }

  /// 开始通话录音
  Future<void> startCallRecording() async {
    try {
      await _channel.invokeMethod('startCallRecording');
    } on PlatformException catch (e) {
      throw Exception('开始录音失败: ${e.message}');
    }
  }

  /// 设置TTS缓存启用状态
  Future<void> setTtsCacheEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setTtsCacheEnabled', {'enabled': enabled});
    } on PlatformException catch (e) {
      throw Exception('设置TTS缓存失败: ${e.message}');
    }
  }

  /// 检查TTS缓存是否启用
  Future<bool> isTtsCacheEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isTtsCacheEnabled');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// 删除所有TTS缓存文件
  Future<void> deleteAllTtsCacheFiles() async {
    try {
      await _channel.invokeMethod('deleteAllTtsCacheFiles');
    } on PlatformException catch (e) {
      throw Exception('删除缓存失败: ${e.message}');
    }
  }

  /// 添加设备监听器
  void addDeviceListener(BleDeviceListener listener) {
    _deviceListeners.add(listener);
  }

  /// 移除设备监听器
  void removeDeviceListener(BleDeviceListener listener) {
    _deviceListeners.remove(listener);
  }

  /// 添加翻译监听器
  void addTranslationListener(TranslationListener listener) {
    _translationListeners.add(listener);
  }

  /// 移除翻译监听器
  void removeTranslationListener(TranslationListener listener) {
    _translationListeners.remove(listener);
  }

  /// 释放资源
  Future<void> release() async {
    try {
      await _channel.invokeMethod('release');
      _deviceEventSubscription?.cancel();
      _translationEventSubscription?.cancel();
      _deviceListeners.clear();
      _translationListeners.clear();
    } on PlatformException catch (e) {
      throw Exception('释放资源失败: ${e.message}');
    }
  }
}
