import 'package:flutter/material.dart';
import 'package:ble_agent/ble_agent.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

// 功能模块枚举
enum FunctionModule {
  translation,
  callRecording,
  ttsCache,
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BleAgent Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'BleAgent Flutter Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final BleAgentFlutter _bleAgent = BleAgentFlutter();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // 初始化配置（硬编码）
  static const String _userId = 'userId';
  static const String _orgId = 'orgId';
  static const String _secret = 'secret';
  static const String _packageName = 'packageName';
  static const String _country = 'country';

  final List<BleDevice> _devices = [];
  List<Language> _languages = [];
  bool _isInitialized = false;
  bool _isConnected = false;
  String _statusMessage = '未初始化';

  String? _selectedSourceLang;
  String? _selectedTargetLang;
  StepMode _selectedStepMode = StepMode.tts;
  WorkMode _selectedWorkMode = WorkMode.callTranslation;

  // 对话数据
  final List<DialogData> _dialogList = [];
  final Map<String, DialogData> _dialogDataMap = {};
  
  // Token消耗
  int _totalTokens = 0;

  // 录音相关
  bool _isRecording = false;
  final List<String> _recordingFiles = [];
  File? _currentRecordingFile;
  IOSink? _recordingSink;

  // 功能模块选择
  FunctionModule _selectedModule = FunctionModule.translation;

  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _setupListeners();
    // 延迟申请权限，确保 UI 已经构建完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermissionsAndInitialize();
    });
  }

  Future<void> _requestPermissionsAndInitialize() async {
    setState(() => _statusMessage = '正在申请权限...');

    // 申请蓝牙相关权限
    // iOS 和 Android 的权限不同，需要分别处理
    List<Permission> permissions;
    
    if (Platform.isIOS) {
      // iOS: 需要蓝牙和位置权限
      permissions = [
        Permission.bluetooth,
      ];
    } else {
      // Android: 需要蓝牙扫描、连接和位置权限
      permissions = [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ];
    }

    Map<Permission, PermissionStatus> statuses = await permissions.request();

    // 检查权限状态
    bool allGranted = statuses.values.every((status) => status.isGranted);
    bool hasPermanentlyDenied = statuses.values.any((status) => status.isPermanentlyDenied);

    if (allGranted) {
      _addLog('蓝牙权限申请成功');
      // 权限申请成功后自动初始化SDK
      await _initialize();
    } else if (hasPermanentlyDenied) {
      // 有权限被永久拒绝，需要引导用户去设置中开启
      setState(() => _statusMessage = '权限被拒绝，请手动开启');
      _addLog('部分权限被永久拒绝，请前往设置开启');
      
      // 显示提示对话框
      _showPermissionDialog();
    } else {
      setState(() => _statusMessage = '权限申请失败');
      _addLog('蓝牙权限申请失败: ${statuses}');
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('权限提示'),
          content: const Text(
            '应用需要蓝牙和位置权限才能扫描和连接BLE设备。\n\n'
            '您之前拒绝了位置权限，请前往设置中手动开启。\n\n'
            '路径：设置 > Ble Agent Flutter > 位置',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // 打开应用设置页面
                openAppSettings();
              },
              child: const Text('前往设置'),
            ),
          ],
        );
      },
    );
  }

  void _setupListeners() {
    _bleAgent.addDeviceListener(_DeviceListener(
      onDeviceFoundCallback: (device) {
        setState(() {
          // 避免重复添加设备
          if (!_devices.any((d) => d.deviceId == device.deviceId)) {
            _devices.add(device);
          }
        });
        _addLog('[Device] 发现设备: ${device.deviceName} (${device.mac})');
      },
      onConnectedCallback: (device) {
        setState(() {
          _isConnected = true;
          _statusMessage = '已连接: ${device.deviceName}';
        });
        _addLog('[Device] 已连接: ${device.deviceName}');
      },
      onDisconnectedCallback: (device) {
        setState(() {
          _isConnected = false;
          _statusMessage = '已断开: ${device.deviceName}';
        });
        _addLog('[Device] 已断开: ${device.deviceName}');
      },
      onErrorCallback: (error) {
        _addLog('[Device] 错误: $error');
      },
      onAudioModeUpdatedCallback: (errorCode, errorMessage) {
        _addLog('[Device] 音频模式更新: $errorCode - $errorMessage');
        
        // 如果errorCode != 0，停止翻译/通话录音并toast提醒
        if (errorCode != 0) {
          _stopTranslationOrRecording();
          _showToast('音频模式错误: $errorMessage (错误码: $errorCode)');
        }
      },
      onAudioStreamDataCallback: (audioData) {
        _addLog('[Device] 音频数据: ${audioData.length} bytes');
        // 保存PCM音频流到文件
        _saveAudioData(audioData);
      },
    ));

    _bleAgent.addTranslationListener(_TranslationListener(
      onRecognitionResultCallback: (id, text, isFinal, isLeft) {
        setState(() {
          DialogData? data = _dialogDataMap[id];
          if (data == null) {
            data = DialogData(id: id, isLeft: isLeft);
            _dialogDataMap[id] = data;
            _dialogList.add(data);
          }
          data.asr = text;
        });
        _addLog('[Translation] 识别结果: $text (最终: $isFinal, 左侧: $isLeft)');
      },
      onTranslationCallback: (id, sourceText, translatedText, isLeft) {
        setState(() {
          DialogData? data = _dialogDataMap[id];
          if (data == null) {
            data = DialogData(id: id, isLeft: isLeft);
            _dialogDataMap[id] = data;
            _dialogList.add(data);
          }
          data.translation = translatedText;
        });
        _addLog('[Translation] 翻译: $sourceText -> $translatedText (左侧: $isLeft)');
      },
      onErrorCallback: (errorCode, error) {
        _addLog('[Translation] 错误: [$errorCode] $error');
      },
      onTtsFileCallback: (id, filePath, isLeft) {
        setState(() {
          DialogData? data = _dialogDataMap[id];
          if (data != null) {
            data.ttsFilePath = filePath;
          }
        });
        _addLog('[Translation] TTS文件: $filePath (左侧: $isLeft)');
      },
      onConsumeTokensCallback: (tokenType, tokens) {
        setState(() {
          _totalTokens += tokens;
        });
        _addLog('[Translation] Token消耗: $tokenType - $tokens');
      },
    ));
  }

  Future<void> _initialize() async {
    try {
      setState(() => _statusMessage = '正在初始化...');

      await _bleAgent.initialize(
        userId: _userId,
        organizationId: _orgId,
        secret: _secret,
        appPackageName: _packageName,
        country: _country,
      );

      setState(() {
        _isInitialized = true;
        _statusMessage = '初始化成功';
      });

      _addLog('SDK初始化成功');
    } catch (e) {
      setState(() => _statusMessage = '初始化失败: $e');
      _addLog('初始化失败: $e');
    }
  }

  Future<void> _scanDevices() async {
    try {
      setState(() {
        _devices.clear();
      });
      await _bleAgent.scanDevices();
      _addLog('开始扫描设备');
    } catch (e) {
      _addLog('扫描失败: $e');
    }
  }

  Future<void> _connectDevice(BleDevice device) async {
    try {
      await _bleAgent.connectDevice(device.deviceId);
      _addLog('连接设备: ${device.deviceName}');
    } catch (e) {
      _addLog('连接失败: $e');
    }
  }

  Future<void> _disconnectDevice() async {
    try {
      await _bleAgent.disconnectDevice();
      _addLog('断开设备连接');
    } catch (e) {
      _addLog('断开连接失败: $e');
    }
  }

  Future<void> _startCallRecording() async {
    try {
      // 创建录音文件
      final directory = Directory.systemTemp;
      final fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.wav';
      _currentRecordingFile = File('${directory.path}/$fileName');
      
      // 写入WAV文件头（占位，后面会更新）
      await _writeWavHeader(_currentRecordingFile!, 0);
      _recordingSink = _currentRecordingFile!.openWrite(mode: FileMode.append);
      
      await _bleAgent.startCallRecording();
      setState(() {
        _isRecording = true;
      });
      _addLog('开始通话录音');
    } catch (e) {
      _addLog('开始录音失败: $e');
    }
  }

  Future<void> _stopCallRecording() async {
    try {
      await _bleAgent.stopRecordingAndTranslation();
      
      // 关闭录音文件
      if (_recordingSink != null) {
        await _recordingSink!.flush();
        await _recordingSink!.close();
        _recordingSink = null;
        
        if (_currentRecordingFile != null) {
          // 更新WAV文件头
          final fileSize = await _currentRecordingFile!.length();
          final audioDataSize = fileSize - 44; // 减去WAV头的大小
          await _updateWavHeader(_currentRecordingFile!, audioDataSize);
          
          setState(() {
            _recordingFiles.add(_currentRecordingFile!.path);
            _currentRecordingFile = null;
          });
          _addLog('录音文件已保存');
        }
      }
      
      setState(() {
        _isRecording = false;
      });
      _addLog('停止通话录音');
    } catch (e) {
      _addLog('停止录音失败: $e');
    }
  }

  // 写入WAV文件头
  Future<void> _writeWavHeader(File file, int audioDataSize) async {
    final bytes = <int>[];
    
    // WAV文件头格式
    // 音频参数：16kHz, 双声道, 16位
    const int sampleRate = 16000;
    const int numChannels = 2;
    const int bitsPerSample = 16;
    const int byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    const int blockAlign = numChannels * bitsPerSample ~/ 8;
    
    // RIFF chunk
    bytes.addAll('RIFF'.codeUnits);
    bytes.addAll(_intToBytes(36 + audioDataSize, 4)); // 文件大小 - 8
    bytes.addAll('WAVE'.codeUnits);
    
    // fmt chunk
    bytes.addAll('fmt '.codeUnits);
    bytes.addAll(_intToBytes(16, 4)); // fmt chunk大小
    bytes.addAll(_intToBytes(1, 2)); // 音频格式 (1 = PCM)
    bytes.addAll(_intToBytes(numChannels, 2)); // 声道数
    bytes.addAll(_intToBytes(sampleRate, 4)); // 采样率
    bytes.addAll(_intToBytes(byteRate, 4)); // 字节率
    bytes.addAll(_intToBytes(blockAlign, 2)); // 块对齐
    bytes.addAll(_intToBytes(bitsPerSample, 2)); // 位深度
    
    // data chunk
    bytes.addAll('data'.codeUnits);
    bytes.addAll(_intToBytes(audioDataSize, 4)); // 音频数据大小
    
    await file.writeAsBytes(bytes);
  }

  // 更新WAV文件头
  Future<void> _updateWavHeader(File file, int audioDataSize) async {
    final bytes = await file.readAsBytes();
    
    // 更新文件大小（位置4-7）
    final fileSize = audioDataSize + 36;
    bytes[4] = (fileSize & 0xFF);
    bytes[5] = ((fileSize >> 8) & 0xFF);
    bytes[6] = ((fileSize >> 16) & 0xFF);
    bytes[7] = ((fileSize >> 24) & 0xFF);
    
    // 更新音频数据大小（位置40-43）
    bytes[40] = (audioDataSize & 0xFF);
    bytes[41] = ((audioDataSize >> 8) & 0xFF);
    bytes[42] = ((audioDataSize >> 16) & 0xFF);
    bytes[43] = ((audioDataSize >> 24) & 0xFF);
    
    await file.writeAsBytes(bytes);
  }

  // 整数转字节数组
  List<int> _intToBytes(int value, int byteCount) {
    final bytes = <int>[];
    for (int i = 0; i < byteCount; i++) {
      bytes.add((value >> (i * 8)) & 0xFF);
    }
    return bytes;
  }

  void _saveAudioData(List<int> audioData) {
    try {
      if (_recordingSink != null) {
        _recordingSink!.add(audioData);
      }
    } catch (e) {
      _addLog('保存音频数据失败: $e');
    }
  }

  void _stopTranslationOrRecording() async {
    try {
      if (_isRecording) {
        await _stopCallRecording();
      } else {
        await _bleAgent.stopRecordingAndTranslation();
      }
    } catch (e) {
      _addLog('停止失败: $e');
    }
  }

  void _showToast(String message) {
    // Flutter中需要使用ScaffoldMessenger来显示SnackBar
    // 这个方法会在build方法中被调用
    _addLog('[Toast] $message');
  }

  Future<void> _fetchLanguages() async {
    try {
      final languages = await _bleAgent.fetchLanguages();
      setState(() {
        _languages = languages;
        if (languages.isNotEmpty) {
          _selectedSourceLang = languages.first.value;
          _selectedTargetLang = languages.length > 1 ? languages[1].value : languages.first.value;
        }
      });
      _addLog('获取语言列表成功: ${languages.length}种语言');
    } catch (e) {
      _addLog('获取语言列表失败: $e');
    }
  }

  Future<void> _startTranslation() async {
    if (_selectedSourceLang == null || _selectedTargetLang == null) {
      _addLog('请先选择语言');
      return;
    }

    try {
      await _bleAgent.startTranslation(
        workMode: _selectedWorkMode,
        sourceLang: _selectedSourceLang!,
        targetLang: _selectedTargetLang!,
        stepMode: _selectedStepMode,
      );
      _addLog('开始翻译');
    } catch (e) {
      _addLog('开始翻译失败: $e');
    }
  }

  Future<void> _stopTranslation() async {
    try {
      await _bleAgent.stopRecordingAndTranslation();
      _addLog('停止翻译');
    } catch (e) {
      _addLog('停止翻译失败: $e');
    }
  }

  Future<void> _release() async {
    try {
      await _bleAgent.release();
      setState(() {
        _isInitialized = false;
        _isConnected = false;
        _devices.clear();
        _statusMessage = '已释放';
      });
      _addLog('SDK已释放');
    } catch (e) {
      _addLog('释放失败: $e');
    }
  }

  // TTS缓存管理
  Future<void> _setTtsCacheEnabled(bool enabled) async {
    try {
      await _bleAgent.setTtsCacheEnabled(enabled);
      _addLog('TTS缓存${enabled ? "已启用" : "已禁用"}');
    } catch (e) {
      _addLog('设置TTS缓存失败: $e');
    }
  }

  Future<void> _checkTtsCacheStatus() async {
    try {
      final isEnabled = await _bleAgent.isTtsCacheEnabled();
      _addLog('TTS缓存状态: ${isEnabled ? "已启用" : "已禁用"}');
    } catch (e) {
      _addLog('检查TTS缓存状态失败: $e');
    }
  }

  Future<void> _deleteAllTtsCacheFiles() async {
    try {
      await _bleAgent.deleteAllTtsCacheFiles();
      _addLog('已删除所有TTS缓存文件');
    } catch (e) {
      _addLog('删除TTS缓存文件失败: $e');
    }
  }

  void _addLog(String message) {
    setState(() {
      _logs.insert(0, '${DateTime.now().toString().substring(11, 19)} - $message');
      if (_logs.length > 100) _logs.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 状态卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('状态: $_statusMessage', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('初始化: ${_isInitialized ? "是" : "否"}'),
                    Text('已连接: ${_isConnected ? "是" : "否"}'),
                    const SizedBox(height: 8),
                    Text('Token消耗: $_totalTokens', style: const TextStyle(fontSize: 14, color: Colors.blue)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 根据连接状态显示不同内容
            if (!_isConnected) ...[
              // 未连接：显示设备扫描和连接
              ElevatedButton(
                onPressed: _isInitialized ? _scanDevices : null, 
                child: const Text('扫描设备')
              ),
              const SizedBox(height: 8),
              
              // 设备列表
              if (_devices.isNotEmpty) ...[
                const Text('发现的设备', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...(_devices.map((device) => Card(
                  child: ListTile(
                    title: Text(device.deviceName),
                    subtitle: Text('MAC: ${device.mac}, RSSI: ${device.rssi}'),
                    trailing: ElevatedButton(
                      onPressed: () => _connectDevice(device),
                      child: const Text('连接'),
                    ),
                  ),
                ))),
                const SizedBox(height: 16),
              ],
              
              // 释放SDK按钮
              ElevatedButton(
                onPressed: _isInitialized ? _release : null, 
                child: const Text('释放SDK')
              ),
              const SizedBox(height: 16),
            ] else ...[
              // 已连接：显示断开连接和功能选择
              ElevatedButton(
                onPressed: _disconnectDevice, 
                child: const Text('断开连接')
              ),
              const SizedBox(height: 16),
              
              // 功能选择器
              const Text('功能选择', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SegmentedButton<FunctionModule>(
                segments: const [
                  ButtonSegment(value: FunctionModule.translation, label: Text('翻译')),
                  ButtonSegment(value: FunctionModule.callRecording, label: Text('通话录音')),
                  ButtonSegment(value: FunctionModule.ttsCache, label: Text('TTS缓存')),
                ],
                selected: {_selectedModule},
                onSelectionChanged: (Set<FunctionModule> newSelection) {
                  setState(() {
                    _selectedModule = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // 根据选择显示不同的功能模块
              if (_selectedModule == FunctionModule.translation) ...[
                _buildTranslationModule(),
              ] else if (_selectedModule == FunctionModule.callRecording) ...[
                _buildCallRecordingModule(),
              ] else if (_selectedModule == FunctionModule.ttsCache) ...[
                _buildTtsCacheModule(),
              ],
            ],

            // 日志
            const SizedBox(height: 16),
            const Text('日志', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(_logs[index], style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 翻译功能模块
  Widget _buildTranslationModule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('翻译功能', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        
        // 工作模式选择
        const Text('工作模式', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        SegmentedButton<WorkMode>(
          segments: const [
            ButtonSegment(value: WorkMode.telephoneSubtitle, label: Text('电话字幕')),
            ButtonSegment(value: WorkMode.callTranslation, label: Text('通话翻译')),
            ButtonSegment(value: WorkMode.bidirectionalTranslation, label: Text('双向翻译')),
          ],
          selected: {_selectedWorkMode},
          onSelectionChanged: (Set<WorkMode> newSelection) {
            setState(() {
              _selectedWorkMode = newSelection.first;
            });
          },
        ),
        const SizedBox(height: 16),

        // StepMode选择
        const Text('翻译步骤', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        SegmentedButton<StepMode>(
          segments: const [
            ButtonSegment(value: StepMode.asr, label: Text('ASR')),
            ButtonSegment(value: StepMode.translation, label: Text('翻译')),
            ButtonSegment(value: StepMode.tts, label: Text('TTS')),
          ],
          selected: {_selectedStepMode},
          onSelectionChanged: (Set<StepMode> newSelection) {
            setState(() {
              _selectedStepMode = newSelection.first;
            });
          },
        ),
        const SizedBox(height: 16),

        // 语言选择
        ElevatedButton(onPressed: _fetchLanguages, child: const Text('获取语言列表')),
        const SizedBox(height: 8),
        
        if (_languages.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            initialValue: _selectedSourceLang,
            decoration: const InputDecoration(labelText: '源语言'),
            items: _languages.map((lang) => DropdownMenuItem(value: lang.value, child: Text(lang.key))).toList(),
            onChanged: (value) => setState(() => _selectedSourceLang = value),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedTargetLang,
            decoration: const InputDecoration(labelText: '目标语言'),
            items: _languages.map((lang) => DropdownMenuItem(value: lang.value, child: Text(lang.key))).toList(),
            onChanged: (value) => setState(() => _selectedTargetLang = value),
          ),
          const SizedBox(height: 16),
        ],

        // 翻译按钮
        ElevatedButton(onPressed: _startTranslation, child: const Text('开始翻译')),
        const SizedBox(height: 8),
        ElevatedButton(onPressed: _stopTranslation, child: const Text('停止翻译')),
        const SizedBox(height: 16),

        // 对话列表
        if (_dialogList.isNotEmpty) ...[
          const Text('对话记录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            height: 300,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ListView.builder(
              itemCount: _dialogList.length,
              itemBuilder: (context, index) {
                final dialog = _dialogList[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              dialog.isLeft ? Icons.person : Icons.person_outline,
                              size: 16,
                              color: dialog.isLeft ? Colors.blue : Colors.green,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dialog.isLeft ? '左侧' : '右侧',
                              style: TextStyle(
                                fontSize: 12,
                                color: dialog.isLeft ? Colors.blue : Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (dialog.asr.isNotEmpty) ...[
                          Text('识别: ${dialog.asr}', style: const TextStyle(fontSize: 14)),
                          const SizedBox(height: 4),
                        ],
                        if (dialog.translation.isNotEmpty) ...[
                          Text('翻译: ${dialog.translation}', 
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue)),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  // 通话录音功能模块
  Widget _buildCallRecordingModule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('通话录音', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: !_isRecording ? _startCallRecording : null, 
          child: const Text('开始录音')
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _isRecording ? _stopCallRecording : null, 
          child: const Text('停止录音')
        ),
        const SizedBox(height: 16),
        
        // 录音文件列表
        if (_recordingFiles.isNotEmpty) ...[
          const Text('录音文件', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ListView.builder(
              itemCount: _recordingFiles.length,
              itemBuilder: (context, index) {
                final file = _recordingFiles[index];
                return ListTile(
                  title: Text(file.split('/').last),
                  subtitle: Text(file),
                  trailing: IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () => _playRecordingFile(file),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  // TTS缓存管理功能模块
  Widget _buildTtsCacheModule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('TTS缓存管理', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _setTtsCacheEnabled(true),
                child: const Text('启用缓存'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _setTtsCacheEnabled(false),
                child: const Text('禁用缓存'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _checkTtsCacheStatus,
                child: const Text('检查缓存状态'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: _deleteAllTtsCacheFiles,
                child: const Text('删除所有缓存'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _playRecordingFile(String filePath) async {
    try {
      _addLog('播放录音文件: $filePath');
      
      // 停止当前播放
      await _audioPlayer.stop();
      
      // 播放音频文件
      await _audioPlayer.play(DeviceFileSource(filePath));
      
      // 监听播放状态
      _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
        if (state == PlayerState.completed) {
          _addLog('录音播放完成');
        }
      });
    } catch (e) {
      _addLog('播放录音失败: $e');
    }
  }

  @override
  void dispose() {
    _bleAgent.release();
    _audioPlayer.dispose();
    super.dispose();
  }
}

class _DeviceListener extends BleDeviceListener {
  final Function(BleDevice) onDeviceFoundCallback;
  final Function(BleDevice) onConnectedCallback;
  final Function(BleDevice) onDisconnectedCallback;
  final Function(String) onErrorCallback;
  final Function(int, String) onAudioModeUpdatedCallback;
  final Function(List<int>) onAudioStreamDataCallback;

  _DeviceListener({
    required this.onDeviceFoundCallback,
    required this.onConnectedCallback,
    required this.onDisconnectedCallback,
    required this.onErrorCallback,
    required this.onAudioModeUpdatedCallback,
    required this.onAudioStreamDataCallback,
  });

  @override
  void onDeviceFound(BleDevice device) {
    onDeviceFoundCallback(device);
  }

  @override
  void onConnected(BleDevice device) {
    onConnectedCallback(device);
  }

  @override
  void onDisconnected(BleDevice device) {
    onDisconnectedCallback(device);
  }

  @override
  void onError(String error) {
    onErrorCallback(error);
  }

  @override
  void onAudioModeUpdated(int errorCode, String errorMessage) {
    onAudioModeUpdatedCallback(errorCode, errorMessage);
  }

  @override
  void onAudioStreamData(List<int> audioData) {
    onAudioStreamDataCallback(audioData);
  }
}

class _TranslationListener extends TranslationListener {
  final Function(String, String, bool, bool) onRecognitionResultCallback;
  final Function(String, String, String, bool) onTranslationCallback;
  final Function(int, String) onErrorCallback;
  final Function(String, String, bool) onTtsFileCallback;
  final Function(String, int) onConsumeTokensCallback;

  _TranslationListener({
    required this.onRecognitionResultCallback,
    required this.onTranslationCallback,
    required this.onErrorCallback,
    required this.onTtsFileCallback,
    required this.onConsumeTokensCallback,
  });

  @override
  void onRecognitionResult(String id, String text, bool isFinal, bool isLeft) {
    onRecognitionResultCallback(id, text, isFinal, isLeft);
  }

  @override
  void onTranslation(String id, String sourceText, String translatedText, bool isLeft) {
    onTranslationCallback(id, sourceText, translatedText, isLeft);
  }

  @override
  void onError(int errorCode, String error) {
    onErrorCallback(errorCode, error);
  }

  @override
  void onTtsFile(String id, String filePath, bool isLeft) {
    onTtsFileCallback(id, filePath, isLeft);
  }

  @override
  void onConsumeTokens(String tokenType, int tokens) {
    onConsumeTokensCallback(tokenType, tokens);
  }
}

// 对话数据类
class DialogData {
  String id;
  String asr;
  String translation;
  String? ttsFilePath;
  bool isLeft;

  DialogData({
    required this.id,
    required this.isLeft,
    this.asr = '',
    this.translation = '',
    this.ttsFilePath,
  });
}
