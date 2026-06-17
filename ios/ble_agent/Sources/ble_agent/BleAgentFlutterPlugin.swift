import Flutter
import UIKit
import CaitunBleAgent

public class BleAgentFlutterPlugin: NSObject, FlutterPlugin {
    private var methodChannel: FlutterMethodChannel?
    private var deviceEventChannel: FlutterEventChannel?
    private var translationEventChannel: FlutterEventChannel?

    // 改为 internal 以便 StreamHandler 可以访问
    var deviceEventSink: FlutterEventSink?
    var translationEventSink: FlutterEventSink?

    private var bleAgent: BleAgent?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = BleAgentFlutterPlugin()

        let methodChannel = FlutterMethodChannel(name: "ble_agent", binaryMessenger: registrar.messenger())
        let deviceEventChannel = FlutterEventChannel(name: "ble_agent/device_events", binaryMessenger: registrar.messenger())
        let translationEventChannel = FlutterEventChannel(name: "ble_agent/translation_events", binaryMessenger: registrar.messenger())

        instance.methodChannel = methodChannel
        instance.deviceEventChannel = deviceEventChannel
        instance.translationEventChannel = translationEventChannel

        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        
        // 设置不同的 StreamHandler
        deviceEventChannel.setStreamHandler(DeviceEventStreamHandler(plugin: instance))
        translationEventChannel.setStreamHandler(TranslationEventStreamHandler(plugin: instance))
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            handleInitialize(call: call, result: result)
        case "scanDevices":
            handleScanDevices(result: result)
        case "stopScan":
            handleStopScan(result: result)
        case "connectDevice":
            handleConnectDevice(call: call, result: result)
        case "disconnectDevice":
            handleDisconnectDevice(result: result)
        case "isInitialized":
            handleIsInitialized(result: result)
        case "isDeviceConnected":
            handleIsDeviceConnected(result: result)
        case "fetchLanguages":
            handleFetchLanguages(result: result)
        case "startTranslation":
            handleStartTranslation(call: call, result: result)
        case "stopRecordingAndTranslation":
            handleStopRecordingAndTranslation(result: result)
        case "startCallRecording":
            handleStartCallRecording(result: result)
        case "setTtsCacheEnabled":
            handleSetTtsCacheEnabled(call: call, result: result)
        case "isTtsCacheEnabled":
            handleIsTtsCacheEnabled(result: result)
        case "deleteAllTtsCacheFiles":
            handleDeleteAllTtsCacheFiles(result: result)
        case "release":
            handleRelease(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Initialize
    private func handleInitialize(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let userId = args["userId"] as? String,
              let organizationId = args["organizationId"] as? String,
              let secret = args["secret"] as? String,
              let appPackageName = args["appPackageName"] as? String,
              let country = args["country"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }

        let builder = BleAgent.Builder(
            userId: userId,
            organizationId: organizationId,
            secret: secret,
            appPackageName: appPackageName,
            country: country
        )

        bleAgent = builder.build()
        
        // 使用 InitCallback
        let initCallback = InitCallbackImpl(
            onSuccess: { [weak self] message in
                result("初始化成功")
                self?.setupBleAgentListeners()
            },
            onError: { error in
                result(FlutterError(code: "INITIALIZATION_FAILED", message: error, details: nil))
            }
        )
        
        bleAgent?.initialize(callback: initCallback)
    }

    // MARK: - Device Management
    private func handleScanDevices(result: @escaping FlutterResult) {
        bleAgent?.scanDevices()
        result(nil)
    }

    private func handleStopScan(result: @escaping FlutterResult) {
        bleAgent?.stopScan()
        result(nil)
    }

    private func handleConnectDevice(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let deviceId = args["deviceId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }

        bleAgent?.connectDevice(deviceId: deviceId)
        result(nil)
    }

    private func handleDisconnectDevice(result: @escaping FlutterResult) {
        bleAgent?.disconnectDevice()
        result(nil)
    }

    private func handleIsInitialized(result: @escaping FlutterResult) {
        result(bleAgent?.isInitialized() ?? false)
    }

    private func handleIsDeviceConnected(result: @escaping FlutterResult) {
        result(bleAgent?.isDeviceConnected() ?? false)
    }

    // MARK: - Language Management
    private func handleFetchLanguages(result: @escaping FlutterResult) {
        bleAgent?.fetchLanguages { languagesResult in
            switch languagesResult {
            case .success(let languages):
                let languageMaps = languages.map { language in
                    return [
                        "key": language.key,
                        "value": language.value
                    ]
                }
                result(languageMaps)
            case .failure(let error):
                result(FlutterError(code: "FETCH_LANGUAGES_FAILED", message: error.message, details: nil))
            }
        }
    }

    // MARK: - Translation
    private func handleStartTranslation(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let workModeIndex = args["workMode"] as? Int,
              let sourceLang = args["sourceLang"] as? String,
              let targetLang = args["targetLang"] as? String,
              let stepModeIndex = args["stepMode"] as? Int else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }

        let workMode = WorkMode(rawValue: workModeIndex) ?? .callTranslation
        let stepMode: StepMode
        switch stepModeIndex {
        case 0:
            stepMode = .asr
        case 1:
            stepMode = .llm
        case 2:
            stepMode = .tts
        default:
            stepMode = .tts
        }

        bleAgent?.startTranslation(mode: workMode, sourceLang: sourceLang, targetLang: targetLang, stepMode: stepMode)
        result(nil)
    }

    private func handleStopRecordingAndTranslation(result: @escaping FlutterResult) {
        bleAgent?.stopRecordingAndTranslation()
        result(nil)
    }

    private func handleStartCallRecording(result: @escaping FlutterResult) {
        bleAgent?.startCallRecording()
        result(nil)
    }

    // MARK: - TTS Cache Management
    private func handleSetTtsCacheEnabled(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let enabled = args["enabled"] as? Bool else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }

        bleAgent?.setTtsCacheEnabled(enabled: enabled)
        result(nil)
    }

    private func handleIsTtsCacheEnabled(result: @escaping FlutterResult) {
        result(bleAgent?.isTtsCacheEnabled() ?? true)
    }

    private func handleDeleteAllTtsCacheFiles(result: @escaping FlutterResult) {
        bleAgent?.deleteAllTtsCacheFiles()
        result(nil)
    }

    // MARK: - Release
    private func handleRelease(result: @escaping FlutterResult) {
        bleAgent?.release()
        bleAgent = nil
        result(nil)
    }

    // MARK: - Listeners Setup
    private func setupBleAgentListeners() {
        // Device Listener - 传入 plugin 引用，动态获取 eventSink
        let deviceListener = BleAgentDeviceListener(plugin: self)
        bleAgent?.addDeviceListener(deviceListener)

        // Translation Listener - 传入 plugin 引用，动态获取 eventSink
        let translationListener = BleAgentTranslationListener(plugin: self)
        bleAgent?.addTranslationListener(translationListener)
    }
}

// MARK: - Event Stream Handlers

// Device Event Stream Handler
class DeviceEventStreamHandler: NSObject, FlutterStreamHandler {
    private weak var plugin: BleAgentFlutterPlugin?
    
    init(plugin: BleAgentFlutterPlugin) {
        self.plugin = plugin
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("BleAgentFlutterPlugin: DeviceEventStreamHandler onListen called")
        plugin?.deviceEventSink = events
        print("BleAgentFlutterPlugin: deviceEventSink set successfully")
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("BleAgentFlutterPlugin: DeviceEventStreamHandler onCancel called")
        plugin?.deviceEventSink = nil
        return nil
    }
}

// Translation Event Stream Handler
class TranslationEventStreamHandler: NSObject, FlutterStreamHandler {
    private weak var plugin: BleAgentFlutterPlugin?
    
    init(plugin: BleAgentFlutterPlugin) {
        self.plugin = plugin
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("BleAgentFlutterPlugin: TranslationEventStreamHandler onListen called")
        plugin?.translationEventSink = events
        print("BleAgentFlutterPlugin: translationEventSink set successfully")
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("BleAgentFlutterPlugin: TranslationEventStreamHandler onCancel called")
        plugin?.translationEventSink = nil
        return nil
    }
}

// MARK: - Callback Implementations

// InitCallback implementation
class InitCallbackImpl: InitCallback {
    private let onSuccessCallback: (String) -> Void
    private let onErrorCallback: (String) -> Void
    
    init(onSuccess: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
        self.onSuccessCallback = onSuccess
        self.onErrorCallback = onError
    }
    
    func onSuccess(message: String) {
        onSuccessCallback(message)
    }
    
    func onError(error: String) {
        onErrorCallback(error)
    }
}

// FetchLanguagesCallback implementation (using closure-based API)
class FetchLanguagesCallbackImpl {
    private let onSuccessCallback: ([Language]) -> Void
    private let onErrorCallback: (String) -> Void
    
    init(onSuccess: @escaping ([Language]) -> Void, onError: @escaping (String) -> Void) {
        self.onSuccessCallback = onSuccess
        self.onErrorCallback = onError
    }
    
    func call(_ result: Result<[Language], CaitunStringError>) {
        switch result {
        case .success(let languages):
            onSuccessCallback(languages)
        case .failure(let error):
            onErrorCallback(error.message)
        }
    }
}

// MARK: - Device Listener
class BleAgentDeviceListener: BleDeviceListener {
    private weak var plugin: BleAgentFlutterPlugin?

    init(plugin: BleAgentFlutterPlugin) {
        self.plugin = plugin
    }

    func onDeviceFound(deviceId: String, deviceName: String, mac: String, rssi: Int) {
        print("BleAgentFlutterPlugin: onDeviceFound called - deviceId: \(deviceId), deviceName: \(deviceName), mac: \(mac), rssi: \(rssi)")
        print("BleAgentFlutterPlugin: eventSink is \(plugin?.deviceEventSink != nil ? "not nil" : "nil")")
        
        // Flutter 平台通道要求在主线程发送事件
        DispatchQueue.main.async { [weak self] in
            self?.plugin?.deviceEventSink?([
                "eventType": "onDeviceFound",
                "device": [
                    "deviceId": deviceId,
                    "deviceName": deviceName,
                    "mac": mac,
                    "rssi": rssi
                ]
            ])
            print("BleAgentFlutterPlugin: onDeviceFound event sent")
        }
    }

    func onConnected(deviceId: String, deviceName: String, mac: String) {
        DispatchQueue.main.async { [weak self] in
            self?.plugin?.deviceEventSink?([
                "eventType": "onConnected",
                "device": [
                    "deviceId": deviceId,
                    "deviceName": deviceName,
                    "mac": mac,
                    "rssi": 0
                ]
            ])
        }
    }

    func onDisconnected(deviceId: String, deviceName: String, mac: String) {
        DispatchQueue.main.async { [weak self] in
            self?.plugin?.deviceEventSink?([
                "eventType": "onDisconnected",
                "device": [
                    "deviceId": deviceId,
                    "deviceName": deviceName,
                    "mac": mac,
                    "rssi": 0
                ]
            ])
        }
    }

    func onError(error: String) {
        DispatchQueue.main.async { [weak self] in
            self?.plugin?.deviceEventSink?([
                "eventType": "onError",
                "error": error
            ])
        }
    }

    func onAudioModeUpdated(errorCode: Int, errorMessage: String) {
        DispatchQueue.main.async { [weak self] in
            self?.plugin?.deviceEventSink?([
                "eventType": "onAudioModeUpdated",
                "errorCode": errorCode,
                "errorMessage": errorMessage
            ])
        }
    }

    func onAudioStreamData(audioData: Data) {
        DispatchQueue.main.async { [weak self] in
            self?.plugin?.deviceEventSink?([
                "eventType": "onAudioStreamData",
                "audioData": Array(audioData)
            ])
        }
    }
}

// MARK: - Translation Listener
class BleAgentTranslationListener: TranslationListener {
    private weak var plugin: BleAgentFlutterPlugin?

    init(plugin: BleAgentFlutterPlugin) {
        self.plugin = plugin
    }

    func onRecognitionResult(id: String, text: String, isFinal: Bool, isLeft: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.plugin?.translationEventSink?([
                "eventType": "onRecognitionResult",
                "id": id,
                "text": text,
                "isFinal": isFinal,
                "isLeft": isLeft
            ])
        }
    }

    func onTranslation(id: String, sourceText: String, translatedText: String, isLeft: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.plugin?.translationEventSink?([
                "eventType": "onTranslation",
                "id": id,
                "sourceText": sourceText,
                "translatedText": translatedText,
                "isLeft": isLeft
            ])
        }
    }

    func onError(errorCode: Int, error: String) {
        DispatchQueue.main.async { [weak self] in
            self?.plugin?.translationEventSink?([
                "eventType": "onError",
                "errorCode": errorCode,
                "error": error
            ])
        }
    }

    func onTtsFile(id: String, filePath: String, isLeft: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.plugin?.translationEventSink?([
                "eventType": "onTtsFile",
                "id": id,
                "filePath": filePath,
                "isLeft": isLeft
            ])
        }
    }

    func onConsumeTokens(tokenType: String, tokens: Int) {
        DispatchQueue.main.async { [weak self] in
            self?.plugin?.translationEventSink?([
                "eventType": "onConsumeTokens",
                "tokenType": tokenType,
                "tokens": tokens
            ])
        }
    }
}