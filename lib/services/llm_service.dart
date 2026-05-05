import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

class LLMService {
  // ─────────────── Singleton ───────────────
  static final LLMService _instance = LLMService._internal();
  factory LLMService() => _instance;
  LLMService._internal() {
    _initEventChannel();
  }

  static const platform = MethodChannel('llm');
  static const _eventChannel = EventChannel('llm_events');

  // Internal broadcast controller — ONE subscription to the EventChannel,
  // re-broadcast to as many Dart listeners as needed.
  final StreamController<Map<Object?, Object?>> _controller =
      StreamController<Map<Object?, Object?>>.broadcast();

  StreamSubscription? _channelSubscription;

  void _initEventChannel() {
    _channelSubscription = _eventChannel
        .receiveBroadcastStream()
        .listen((event) {
      _controller.add(event as Map<Object?, Object?>);
    }, onError: (e) {
      _controller.addError(e);
    });
  }

  /// Subscribe to AI token events. Multiple listeners are safe.
  Stream<Map<Object?, Object?>> get onTokenStream => _controller.stream;

  void dispose() {
    _channelSubscription?.cancel();
    _controller.close();
  }

  // ─────────────── Model ───────────────

  Future<bool> loadModel(String modelPath) async {
    try {
      final bool result = await platform.invokeMethod('loadModel', {
        'modelPath': modelPath,
      });
      return result;
    } on PlatformException catch (e) {
      print("Failed to load model: '${e.message}'.");
      return false;
    }
  }

  // ─────────────── Generate ───────────────

  Future<bool> generate(String prompt) async {
    try {
      final bool result = await platform.invokeMethod('generate', {
        'prompt': prompt,
      });
      return result;
    } on PlatformException catch (e) {
      print("Failed to generate: '${e.message}'.");
      return false;
    }
  }

  // ─────────────── Download ───────────────

  Future<bool> downloadModel(
      String url, String fileName, Function(double) onProgress) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/$fileName';

      if (await File(savePath).exists()) {
        return await loadModel(savePath);
      }

      final dio = Dio();
      await dio.download(url, savePath,
          onReceiveProgress: (count, total) {
        if (total != -1) onProgress(count / total);
      });

      return await loadModel(savePath);
    } catch (e) {
      print("Download error: $e");
      return false;
    }
  }

  Future<bool> downloadAndLoadModel(
      String fileId, Function(double) onProgress) async {
    final url =
        'https://drive.google.com/uc?export=download&id=$fileId';
    return await downloadModel(url, 'gemma-1b-it.bin', onProgress);
  }
}
