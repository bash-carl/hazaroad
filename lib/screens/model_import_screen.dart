import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../services/llm_service.dart';
import '../services/map_provider.dart';
import '../main.dart';

class ModelImportScreen extends StatefulWidget {
  const ModelImportScreen({super.key});

  @override
  State<ModelImportScreen> createState() => _ModelImportScreenState();
}

class _ModelImportScreenState extends State<ModelImportScreen> {
  final LLMService _llm = LLMService();
  bool _isLoading = false;
  bool _isDownloading = false;
  double _progress = 0.0;
  String _status = '';
  bool _isSuccess = false;

  static const _url = 'https://github.com/bash-carl/haza-ai/releases/download/hazaroad/hazaai_1b.task';
  static const _fileName = 'hazaai_1b.task';

  Future<void> _download() async {
    setState(() {
      _isDownloading = true;
      _isLoading = true;
      _isSuccess = false;
      _status = 'Connecting...';
      _progress = 0;
    });

    final ok = await _llm.downloadModel(_url, _fileName, (p) {
      setState(() {
        _progress = p;
        _status = 'Downloading  ${(p * 100).toStringAsFixed(0)}%';
      });
    });

    if (mounted) Provider.of<MapProvider>(context, listen: false).setModelLoaded(ok);

    setState(() {
      _isDownloading = false;
      _isLoading = false;
      _isSuccess = ok;
      _status = ok ? 'Model ready.' : 'Download failed. Please try again.';
    });
  }

  Future<void> _pick() async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result?.files.single.path == null) return;

    setState(() { _isLoading = true; _isSuccess = false; _status = 'Loading...'; });
    final ok = await _llm.loadModel(result!.files.single.path!);
    if (mounted) Provider.of<MapProvider>(context, listen: false).setModelLoaded(ok);

    setState(() {
      _isLoading = false;
      _isSuccess = ok;
      _status = ok ? 'Model loaded.' : 'Failed to load model.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final loaded = context.watch<MapProvider>().isModelLoaded;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('AI Model'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          // ── Status Row ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: loaded ? AppColors.success : AppColors.muted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(loaded ? 'HazaAI — Active' : 'HazaAI — Not loaded',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(loaded ? 'Gemma 1B Q4 · Ready for inference' : 'Download or import the model to enable AI',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ])),
            ]),
          ),

          const SizedBox(height: 24),
          _label('ACTIONS'),
          const SizedBox(height: 10),

          // ── Download ──────────────────────────────────
          _actionTile(
            icon: Icons.download_outlined,
            title: 'Download from GitHub',
            subtitle: 'hazaai_1b.task  ·  ~529 MB',
            onTap: _isLoading ? null : _download,
          ),
          const Divider(height: 1, color: AppColors.border),
          _actionTile(
            icon: Icons.folder_outlined,
            title: 'Import from storage',
            subtitle: 'Select a .task file from your device',
            onTap: _isLoading ? null : _pick,
          ),

          const SizedBox(height: 24),

          // ── Progress / Status ──────────────────────────
          if (_isDownloading) ...[
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(_status, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              Text('${(_progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: AppColors.border,
                color: AppColors.accent,
                minHeight: 3,
              ),
            ),
          ] else if (_isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
            ))
          else if (_status.isNotEmpty)
            Row(children: [
              Icon(_isSuccess ? Icons.check : Icons.error_outline,
                  size: 14, color: _isSuccess ? AppColors.success : AppColors.danger),
              const SizedBox(width: 8),
              Text(_status, style: TextStyle(color: _isSuccess ? AppColors.success : AppColors.danger, fontSize: 13)),
            ]),

          const SizedBox(height: 32),
          _label('ABOUT'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('HazaAI  ·  Powered by Google Gemma',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text(
                'Runs Gemma 1B (Q4) fully on-device via MediaPipe. '
                'No data leaves your phone. The model is cached after the first download.',
                style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.6),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({required IconData icon, required String title, required String subtitle, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 18, color: onTap == null ? AppColors.muted : Colors.white),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: onTap == null ? AppColors.muted : Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ])),
          Icon(Icons.chevron_right, size: 16, color: onTap == null ? AppColors.border : AppColors.muted),
        ]),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.0),
  );
}
