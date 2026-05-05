package com.hazaroad.im

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {

    private var llmEngine: LLMEngine? = null
    private val engineLock = Any()           // guards llmEngine access
    private val isGenerating = AtomicBoolean(false)  // prevents concurrent inference

    private val METHOD_CHANNEL = "llm"
    private val EVENT_CHANNEL = "llm_events"

    @Volatile
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Event channel ───────────────────────────────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        // ── Method channel ──────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    // ── loadModel ──────────────────────────────────
                    "loadModel" -> {
                        val modelPath = call.argument<String>("modelPath")
                        if (modelPath == null) {
                            result.error("INVALID_ARGUMENT", "modelPath is required", null)
                            return@setMethodCallHandler
                        }

                        Thread {
                            try {
                                synchronized(engineLock) {
                                    llmEngine?.close()
                                    llmEngine = LLMEngine(this, modelPath) { partialResult, done ->
                                        // Safe callback: post to UI thread, guard against null sink
                                        runOnUiThread {
                                            try {
                                                eventSink?.success(
                                                    mapOf("text" to partialResult, "done" to done)
                                                )
                                            } catch (_: Exception) { /* sink disposed, ignore */ }

                                            // Reset generating flag when done
                                            if (done) isGenerating.set(false)
                                        }
                                    }
                                }
                                runOnUiThread { result.success(true) }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("MODEL_LOAD_ERROR", e.message, null)
                                }
                            }
                        }.start()
                    }

                    // ── generate ───────────────────────────────────
                    "generate" -> {
                        val prompt = call.argument<String>("prompt")

                        if (prompt == null) {
                            result.error("INVALID_ARGUMENT", "prompt is required", null)
                            return@setMethodCallHandler
                        }

                        // Guard: reject if already generating
                        if (isGenerating.getAndSet(true)) {
                            result.error("BUSY", "Inference already in progress", null)
                            return@setMethodCallHandler
                        }

                        // Capture engine reference safely
                        val engine = synchronized(engineLock) { llmEngine }

                        if (engine == null) {
                            isGenerating.set(false)
                            result.error("MODEL_NOT_LOADED", "Call loadModel first", null)
                            return@setMethodCallHandler
                        }

                        Thread {
                            try {
                                engine.generateAsync(prompt)
                                // generateAsync is non-blocking; reply immediately
                                runOnUiThread { result.success(true) }
                            } catch (e: Exception) {
                                isGenerating.set(false)
                                runOnUiThread {
                                    result.error("GENERATE_ERROR", e.message, null)
                                }
                            }
                        }.start()
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        synchronized(engineLock) {
            llmEngine?.close()
            llmEngine = null
        }
        super.onDestroy()
    }
}
