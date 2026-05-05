package com.hazaroad.im

import android.content.Context
import com.google.mediapipe.tasks.genai.llminference.LlmInference
import java.io.File

class LLMEngine(context: Context, modelPath: String, private val onPartialResult: (String, Boolean) -> Unit) {
    private var llm: LlmInference

    init {
        val options = LlmInference.LlmInferenceOptions.builder()
            .setModelPath(modelPath)
            .build()
        llm = LlmInference.createFromOptions(context, options)
    }

    fun generateAsync(prompt: String) {
        llm.generateResponseAsync(prompt) { partialResult, done ->
            onPartialResult(partialResult, done)
        }
    }
    
    fun close() {
        llm.close()
    }
}
