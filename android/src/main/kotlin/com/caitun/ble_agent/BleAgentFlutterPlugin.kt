package com.caitun.ble_agent

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class BleAgentFlutterPlugin : FlutterPlugin {
    private lateinit var methodChannel: MethodChannel
    private lateinit var deviceEventChannel: EventChannel
    private lateinit var translationEventChannel: EventChannel

    private lateinit var pluginHandler: BleAgentFlutterPluginHandler

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val context = binding.applicationContext

        methodChannel = MethodChannel(binding.binaryMessenger, "ble_agent")
        deviceEventChannel = EventChannel(binding.binaryMessenger, "ble_agent/device_events")
        translationEventChannel = EventChannel(binding.binaryMessenger, "ble_agent/translation_events")

        pluginHandler = BleAgentFlutterPluginHandler(context)
        methodChannel.setMethodCallHandler(pluginHandler)

        deviceEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                pluginHandler.setDeviceEventSink(events)
            }

            override fun onCancel(arguments: Any?) {
                pluginHandler.setDeviceEventSink(null)
            }
        })

        translationEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                pluginHandler.setTranslationEventSink(events)
            }

            override fun onCancel(arguments: Any?) {
                pluginHandler.setTranslationEventSink(null)
            }
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        deviceEventChannel.setStreamHandler(null)
        translationEventChannel.setStreamHandler(null)
    }
}
