import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'watermark_service.dart';

// ============ 首页：选择图片（可多选） ============
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _pick(BuildContext context) async {
    // Android 13+ 用 photos，旧版用 storage；请求失败也不阻断选图
    if (Platform.isAndroid) {
      await Permission.photos.request();
      await Permission.storage.request();
    }
    final files = await ImagePicker().pickMultiImage();
    if (files.isEmpty || !context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditorPage(images: files)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1B1E3C), Color(0xFF2C2160)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(Icons.watermark_outlined,
                        size: 84, color: Color(0xFFB9C4FF)),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    '图片水印大师',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '透明 PNG / 文字水印 · 自动平铺 · 一次处理多张',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Color(0xFFB9BFD8)),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => _pick(context),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('选择图片（可多选）',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_user_outlined,
                          size: 15, color: Color(0xFF8E96BC)),
                      SizedBox(width: 6),
                      Text('图片仅在本机处理，不上传网络',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF8E96BC))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============ 编辑页：设置水印 + 实时预览 ============
class EditorPage extends StatefulWidget {
  final List<XFile> images;
  const EditorPage({super.key, required this.images});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  WatermarkType _type = WatermarkType.text;
  ui.Image? _wmImage;
  final TextEditingController _textCtrl =
      TextEditingController(text: '版权所有');
  Color _color = Colors.grey;
  double _scale = 0.18;
  double _spacing = 1.8;
  double _opacity = 0.35;
  double _angle = -20;

  ui.Image? _previewSource;
  Future<Uint8List>? _preview;
  Timer? _debounce;
  bool _loadingSource = true;

  @override
  void initState() {
    super.initState();
    _loadSource();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSource() async {
    try {
      final img = await decodeThumbnail(widget.images.first.path);
      if (!mounted) return;
      setState(() {
        _previewSource = img;
        _loadingSource = false;
      });
      _refresh();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSource = false);
    }
  }

  WatermarkConfig _config() => WatermarkConfig(
        type: _type,
        image: _wmImage,
        text: _textCtrl.text,
        color: _color,
        scale: _scale,
        spacing: _spacing,
        opacity: _opacity,
        angle: _angle,
      );

  void _refresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted || _previewSource == null) return;
      setState(() {
        _preview = composeWatermark(
          source: _previewSource!,
          cfg: _config(),
        );
      });
    });
  }

  Future<void> _pickWatermark() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return;
    final img = await decodeImageFromFile(x.path);
    if (!mounted) return;
    setState(() {
      _wmImage = img;
      _type = WatermarkType.image;
    });
    _refresh();
  }

  Widget _slider(String label, double value, double min, double max,
      ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 64, child: Text(label, style: const TextStyle(fontSize: 13))),
        Expanded(
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
        SizedBox(
          width: 42,
          child: Text(value.toStringAsFixed(2),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('水印设置'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 240,
              decoration: BoxDecoration(
                color: const Color(0xFF12142A),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: _loadingSource
                  ? const CircularProgressIndicator()
                  : FutureBuilder<Uint8List>(
                      future: _preview,
                      builder: (context, snap) {
                        if (snap.hasData) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(snap.data!,
                                fit: BoxFit.contain),
                          );
                        }
                        if (snap.hasError) {
                          return const Text('预览失败',
                              style: TextStyle(color: Colors.white70));
                        }
                        return const Text('生成预览中…',
                            style: TextStyle(color: Colors.white70));
                      },
                    ),
            ),
            const SizedBox(height: 18),

            SegmentedButton<WatermarkType>(
              segments: const [
                ButtonSegment(
                    value: WatermarkType.text, label: Text('文字水印')),
                ButtonSegment(
                    value: WatermarkType.image, label: Text('图片水印')),
              ],
              selected: {_type},
              onSelectionChanged: (s) {
                setState(() => _type = s.first);
                _refresh();
              },
            ),
            const SizedBox(height: 14),

            if (_type == WatermarkType.text)
              TextField(
                controller: _textCtrl,
                decoration: const InputDecoration(
                  labelText: '水印文字',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _refresh(),
              )
            else
              OutlinedButton.icon(
                onPressed: _pickWatermark,
                icon: const Icon(Icons.upload_file),
                label: Text(_wmImage == null
                    ? '上传透明 PNG 水印'
                    : '已上传水印 · 点击更换'),
              ),
            const SizedBox(height: 18),

            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                child: Column(
                  children: [
                    _slider('大小', _scale, 0.05, 0.6,
                        (v) => setState(() => _scale = v).._refresh()),
                    _slider('密度', _spacing, 1.0, 4.0,
                        (v) => setState(() => _spacing = v).._refresh()),
                    _slider('透明', _opacity, 0.05, 1.0,
                        (v) => setState(() => _opacity = v).._refresh()),
                    _slider('角度', _angle, -90, 90,
                        (v) => setState(() => _angle = v).._refresh()),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('水印颜色',
                          style: TextStyle(fontSize: 13)),
                      trailing: GestureDetector(
                        onTap: () async {
                          final c = await _pickColor(context, _color);
                          if (c != null) {
                            setState(() => _color = c);
                            _refresh();
                          }
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: _color,
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _previewSource == null
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProgressPage(
                            images: widget.images,
                            config: _config(),
                          ),
                        ),
                      ),
              icon: const Icon(Icons.check_circle_outline),
              label: Text('开始处理 ${widget.images.length} 张'),
            ),
          ],
        ),
      ),
    );
  }

  Future<Color?> _pickColor(BuildContext context, Color current) async {
    const colors = [
      Colors.grey,
      Colors.white,
      Colors.black,
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
    ];
    return showDialog<Color>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('选择水印颜色'),
        content: Wrap(
          children: colors
              .map((c) => GestureDetector(
                    onTap: () => Navigator.pop(context, c),
                    child: Container(
                      width: 42,
                      height: 42,
                      margin: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: c,
                        border: c == current
                            ? Border.all(color: Colors.blue, width: 3)
                            : Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

// ============ 进度页：批量处理并保存 ============
class ProgressPage extends StatefulWidget {
  final List<XFile> images;
  final WatermarkConfig config;
  const ProgressPage({
    super.key,
    required this.images,
    required this.config,
  });

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  int _done = 0;
  int _failed = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    for (final x in widget.images) {
      setState(() {});
      try {
        final src = await decodeImageFromFile(x.path);
        final bytes = await composeWatermark(source: src, cfg: widget.config);
        await saveBytesToGallery(
          bytes,
          'WM_${DateTime.now().microsecondsSinceEpoch}',
        );
        _done++;
      } catch (_) {
        _failed++;
      }
      if (!mounted) return;
      setState(() {});
    }
    if (!mounted) return;
    setState(() => _finished = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('处理完成'),
        content: Text('成功保存 $_done 张到相册${_failed > 0 ? '，失败 $_failed 张' : ''}。'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.popUntil(context, (r) => r.isFirst),
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.images.length;
    final progress = total == 0 ? 0.0 : (_done + _failed) / total;
    return Scaffold(
      appBar: AppBar(
        title: const Text('正在处理'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: CircularProgressIndicator(value: progress, strokeWidth: 8),
              ),
              const SizedBox(height: 24),
              Text(
                _finished
                    ? '全部完成'
                    : '正在处理 ${_done + _failed + 1} / $total',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 10),
              Text(
                '成功 $_done 张 · 失败 $_failed 张',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
