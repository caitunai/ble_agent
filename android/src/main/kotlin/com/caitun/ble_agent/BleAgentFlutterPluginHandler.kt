package com.caitun.ble_agent

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.caitun.sdk.ble.agent.BleAgent
import com.caitun.sdk.ble.agent.BleAgent.*

class BleAgentFlutterPluginHandler(context: Context) : MethodChannel.MethodCallHandler {

    private var bleAgent: BleAgent? = null
    private var deviceEventSink: EventChannel.EventSink? = null
    private var translationEventSink: EventChannel.EventSink? = null
    private val context: Context = context
    private val mainHandler = Handler(Looper.getMainLooper())

    private val deviceListener = object : BleDeviceListener {
        override fun onDeviceFound(deviceId: String, deviceName: String, mac: String, rssi: Int) {
            mainHandler.post {
                deviceEventSink?.success(mapOf(
                    "eventType" to "onDeviceFound",
                    "device" to mapOf(
                        "deviceId" to deviceId,
                        "deviceName" to deviceName,
                        "mac" to mac,
                        "rssi" to rssi
                    )
                ))
            }
        }

        override fun onConnected(deviceId: String, deviceName: String, mac: String) {
            mainHandler.post {
                deviceEventSink?.success(mapOf(
                    "eventType" to "onConnected",
                    "device" to mapOf(
                        "deviceId" to deviceId,
                        "deviceName" to deviceName,
                        "mac" to mac,
                        "rssi" to 0
                    )
                ))
            }
        }

        override fun onDisconnected(deviceId: String, deviceName: String, mac: String) {
            mainHandler.post {
                deviceEventSink?.success(mapOf(
                    "eventType" to "onDisconnected",
                    "device" to mapOf(
                        "deviceId" to deviceId,
                        "deviceName" to deviceName,
                        "mac" to mac,
                        "rssi" to 0
                    )
                ))
            }
        }

        override fun onError(error: String) {
            mainHandler.post {
                deviceEventSink?.success(mapOf(
                    "eventType" to "onError",
                    "error" to error
                ))
            }
        }

        override fun onAudioModeUpdated(errorCode: Int, errorMessage: String) {
            mainHandler.post {
                deviceEventSink?.success(mapOf(
                    "eventType" to "onAudioModeUpdated",
                    "errorCode" to errorCode,
                    "errorMessage" to errorMessage
                ))
            }
        }

        override fun onAudioStreamData(audioData: ByteArray) {
            mainHandler.post {
                deviceEventSink?.success(mapOf(
                    "eventType" to "onAudioStreamData",
                    "audioData" to audioData.toList()
                ))
            }
        }
    }

    private val translationListener = object : TranslationListener {
        override fun onRecognitionResult(id: String, text: String, isFinal: Boolean, isLeft: Boolean) {
            mainHandler.post {
                translationEventSink?.success(mapOf(
                    "eventType" to "onRecognitionResult",
                    "id" to id,
                    "text" to text,
                    "isFinal" to isFinal,
                    "isLeft" to isLeft
                ))
            }
        }

        override fun onTranslation(id: String, sourceText: String, translatedText: String, isLeft: Boolean) {
            mainHandler.post {
                translationEventSink?.success(mapOf(
                    "eventType" to "onTranslation",
                    "id" to id,
                    "sourceText" to sourceText,
                    "translatedText" to translatedText,
                    "isLeft" to isLeft
                ))
            }
        }

        override fun onError(errorCode: Int, error: String) {
            mainHandler.post {
                translationEventSink?.success(mapOf(
                    "eventType" to "onError",
                    "errorCode" to errorCode,
                    "error" to error
                ))
            }
        }

        override fun onTtsFile(id: String, filePath: String, isLeft: Boolean) {
            mainHandler.post {
                translationEventSink?.success(mapOf(
                    "eventType" to "onTtsFile",
                    "id" to id,
                    "filePath" to filePath,
                    "isLeft" to isLeft
                ))
            }
        }

        override fun onConsumeTokens(tokenType: String, tokens: Int) {
            mainHandler.post {
                translationEventSink?.success(mapOf(
                    "eventType" to "onConsumeTokens",
                    "tokenType" to tokenType,
                    "tokens" to tokens
                ))
            }
        }
    }

    fun setDeviceEventSink(sink: EventChannel.EventSink?) {
        this.deviceEventSink = sink
    }

    fun setTranslationEventSink(sink: EventChannel.EventSink?) {
        this.translationEventSink = sink
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> handleInitialize(call, result)
            "scanDevices" -> handleScanDevices(result)
            "stopScan" -> handleStopScan(result)
            "connectDevice" -> handleConnectDevice(call, result)
            "disconnectDevice" -> handleDisconnectDevice(result)
            "isInitialized" -> handleIsInitialized(result)
            "isDeviceConnected" -> handleIsDeviceConnected(result)
            "fetchLanguages" -> handleFetchLanguages(result)
            "startTranslation" -> handleStartTranslation(call, result)
            "stopRecordingAndTranslation" -> handleStopRecordingAndTranslation(result)
            "startCallRecording" -> handleStartCallRecording(result)
            "setTtsCacheEnabled" -> handleSetTtsCacheEnabled(call, result)
            "isTtsCacheEnabled" -> handleIsTtsCacheEnabled(result)
            "deleteAllTtsCacheFiles" -> handleDeleteAllTtsCacheFiles(result)
            "release" -> handleRelease(result)
            else -> result.notImplemented()
        }
    }

    private fun handleInitialize(call: MethodCall, result: MethodChannel.Result) {
        val userId = call.argument<String>("userId")
        val organizationId = call.argument<String>("organizationId")
        val secret = call.argument<String>("secret")
        val appPackageName = call.argument<String>("appPackageName")
        val country = call.argument<String>("country")

        if (userId == null || organizationId == null || secret == null || appPackageName == null || country == null) {
            result.error("INVALID_ARGUMENTS", "Invalid arguments", null)
            return
        }

        bleAgent = BleAgent.Builder(context, userId, organizationId, secret, appPackageName, country)
            .build()

        bleAgent?.initialize(object : InitCallback {
            override fun onSuccess(message: String) {
                result.success("初始化成功")
                setupBleAgentListeners()
            }

            override fun onError(error: String) {
                result.error("INITIALIZATION_FAILED", error, null)
            }
        })
    }

    private fun handleScanDevices(result: MethodChannel.Result) {
        bleAgent?.scanDevices()
        result.success(null)
    }

    private fun handleStopScan(result: MethodChannel.Result) {
        bleAgent?.stopScan()
        result.success(null)
    }

    private fun handleConnectDevice(call: MethodCall, result: MethodChannel.Result) {
        val deviceId = call.argument<String>("deviceId")
        if (deviceId == null) {
            result.error("INVALID_ARGUMENTS", "Invalid arguments", null)
            return
        }

        bleAgent?.connectDevice(deviceId)
        result.success(null)
    }

    private fun handleDisconnectDevice(result: MethodChannel.Result) {
        bleAgent?.disconnectDevice()
        result.success(null)
    }

    private fun handleIsInitialized(result: MethodChannel.Result) {
        result.success(bleAgent?.isInitialized() ?: false)
    }

    private fun handleIsDeviceConnected(result: MethodChannel.Result) {
        result.success(bleAgent?.isDeviceConnected() ?: false)
    }

    private fun handleFetchLanguages(result: MethodChannel.Result) {
        bleAgent?.fetchLanguages(object : LanguageCallback {
            override fun onSuccess(languages: List<Language>) {
                val languageMaps = languages.map { language ->
                    mapOf(
                        "key" to language.key,
                        "value" to language.value
                    )
                }
                result.success(languageMaps)
            }

            override fun onError(error: String) {
                result.error("FETCH_LANGUAGES_FAILED", error, null)
            }
        })
    }

    private fun handleStartTranslation(call: MethodCall, result: MethodChannel.Result) {
        val workModeIndex = call.argument<Int>("workMode")
        val sourceLang = call.argument<String>("sourceLang")
        val targetLang = call.argument<String>("targetLang")
        val stepModeIndex = call.argument<Int>("stepMode")

        if (workModeIndex == null || sourceLang == null || targetLang == null || stepModeIndex == null) {
            result.error("INVALID_ARGUMENTS", "Invalid arguments", null)
            return
        }

        val workMode = WorkMode.values()[workModeIndex]
        val stepMode = StepMode.values()[stepModeIndex]

        bleAgent?.startTranslation(workMode, sourceLang, targetLang, stepMode)
        result.success(null)
    }

    private fun handleStopRecordingAndTranslation(result: MethodChannel.Result) {
        bleAgent?.stopRecordingAndTranslation()
        result.success(null)
    }

    private fun handleStartCallRecording(result: MethodChannel.Result) {
        bleAgent?.startCallRecording()
        result.success(null)
    }

    private fun handleSetTtsCacheEnabled(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled")
        if (enabled == null) {
            result.error("INVALID_ARGUMENTS", "Invalid arguments", null)
            return
        }

        bleAgent?.setTtsCacheEnabled(enabled)
        result.success(null)
    }

    private fun handleIsTtsCacheEnabled(result: MethodChannel.Result) {
        result.success(bleAgent?.isTtsCacheEnabled() ?: false)
    }

    private fun handleDeleteAllTtsCacheFiles(result: MethodChannel.Result) {
        bleAgent?.deleteAllTtsCacheFiles()
        result.success(null)
    }

    private fun handleRelease(result: MethodChannel.Result) {
        bleAgent?.release()
        bleAgent = null
        result.success(null)
    }

    private fun setupBleAgentListeners() {
        bleAgent?.addDeviceListener(deviceListener)
        bleAgent?.addTranslationListener(translationListener)
    }
}
