package com.hazaroad.im

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var llmEngine: LLMEngine? = null
    private val METHOD_CHANNEL = "llm"
    private val EVENT_CHANNEL = "llm_events"
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "loadModel" -> {
                        val modelPath = call.argument<String>("modelPath")
                        if (modelPath != null) {
                            Thread {
                                try {
                                    llmEngine?.close()
                                    llmEngine = LLMEngine(this, modelPath) { partialResult, done ->
                                        runOnUiThread {
                                            eventSink?.success(mapOf(
                                                "text" to partialResult,
                                                "done" to done
                                            ))
                                        }
                                    }
                                    runOnUiThread {
                                        result.success(true)
                                    }
                                } catch (e: Exception) {
                                    runOnUiThread {
                                        result.error("MODEL_LOAD_ERROR", e.message, null)
                                    }
                                }
                            }.start()
                        } else {
                            result.error("INVALID_ARGUMENT", "modelPath is required", null)
                        }
                    }
                    "generate" -> {
                        val prompt = call.argument<String>("prompt")
                        if (prompt != null && llmEngine != null) {
                            Thread {
                                try {
                                    llmEngine!!.generateAsync(prompt)
                                    runOnUiThread {
                                        result.success(true)
                                    }
                                } catch (e: Exception) {
                                    runOnUiThread {
                                        result.error("GENERATE_ERROR", e.message, null)
                                    }
                                }
                            }.start()
                        } else {
                            if (llmEngine == null) {
                                result.error("MODEL_NOT_LOADED", "Call loadModel first", null)
                            } else {
                                result.error("INVALID_ARGUMENT", "prompt is required", null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
