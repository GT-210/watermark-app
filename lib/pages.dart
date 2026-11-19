import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'theme.dart';
import 'watermark_service.dart';

// ============================================================
// 首页：品牌展示 + 选择图片（可多选）
// ============================================================
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _pick(BuildContext context) async {
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

  Widget _feature(IconData icon, String title, String desc) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpace.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: AppColors.primary),
            const SizedBox(height: AppSpace.md),
            Text(title, style: AppType.section),
            const SizedBox(height: AppSpace.xs),
            Text(desc, style: AppType.caption.copyWith(color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpace.xxl),
              // 品牌标识
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.indigo500, AppColors.indigo700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.28),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(Icons.layers_outlined,
                    size: 36, color: AppColors.textOnPrimary),
              ),
              const SizedBox(height: AppSpace.xl),
              Text('图片水印大师', style: AppType.display),
              const SizedBox(height: AppSpace.sm),
              Text(
                '给图片快速盖上你的专属印记。支持透明 PNG 与文字水印，'
                '自动平铺，一次处理多张，全程只在本机完成。',
                style: AppType.body.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpace.xxl),
              // 功能亮点
              Row(
                children: [
                  _feature(Icons.text_fields, '文字水印', '输入任意文字，可调颜色'),
                  const SizedBox(width: AppSpace.md),
                  _feature(Icons.image_outlined, '透明 PNG', '上传你的 Logo 图片'),
                  const SizedBox(width: AppSpace.md),
                  _feature(Icons.grid_view_outlined, '自动平铺', '满屏水印一次搞定'),
                ],
              ),
              const SizedBox(height: AppSpace.xxl),
              // 主行动
              FilledButton.icon(
                onPressed: () => _pick(context),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('选择图片开始'),
              ),
              const SizedBox(height: AppSpace.lg),
              // 信任说明
              Container(
                padding: const EdgeInsets.all(AppSpace.md),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.privacy_tip_outlined,
                        size: 20, color: AppColors.primary),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Text(
                        '隐私优先：图片不上传，全部在本机处理',
                        style: AppType.secondary
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 编辑页：水印设置 + 实时预览
// ============================================================
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
  Color _color = AppColors.slate700;
  double _scale = 0.18;
  double _spacing = 1.8;
  double _opacity = 0.35;
  double _angle = -20;

  ui.Image? _previewSource;
  Future<Uint8List>? _preview;
  Timer? _debounce;
  bool _loadingSource = true;
  String? _error;

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
      setState(() {
        _loadingSource = false;
        _error = '图片读取失败，请重新选择';
      });
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
        _preview = composeWatermark(source: _previewSource!, cfg: _config());
      });
    });
  }

  Future<void> _pickWatermark() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return;
    try {
      final img = await decodeImageFromFile(x.path);
      if (!mounted) return;
      setState(() {
        _wmImage = img;
        _type = WatermarkType.image;
      });
      _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('水印图片读取失败，请换一张试试')),
      );
    }
  }

  Widget _slider(String label, double value, double min, double max,
      ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
      child: Row(
        children: [
          SizedBox(width: 44, child: Text(label, style: AppType.secondary)),
          Expanded(
            child: Slider(value: value, min: min, max: max, onChanged: onChanged),
          ),
          SizedBox(
            width: 40,
            child: Text(
              value.toStringAsFixed(2),
              textAlign: TextAlign.right,
              style: AppType.caption.copyWith(color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewBox() {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: _loadingSource
          ? const CircularProgressIndicator(color: AppColors.textOnCanvas)
          : _error != null
              ? Text(_error!,
                  style: AppType.secondary
                      .copyWith(color: AppColors.textOnCanvas))
              : FutureBuilder<Uint8List>(
                  future: _preview,
                  builder: (context, snap) {
                    if (snap.hasData) {
                      return Image.memory(snap.data!, fit: BoxFit.contain);
                    }
                    if (snap.hasError) {
                      return Text('预览失败',
                          style: AppType.secondary
                              .copyWith(color: AppColors.textOnCanvas));
                    }
                    return Text('生成预览中…',
                        style: AppType.secondary
                            .copyWith(color: AppColors.textOnCanvas));
                  },
                ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('水印设置'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.lg),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.md, vertical: AppSpace.xs),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '${widget.images.length} 张图片',
                  style: AppType.caption.copyWith(color: AppColors.primary),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _previewBox(),
            const SizedBox(height: AppSpace.xl),

            // 水印类型
            Text('水印类型', style: AppType.section),
            const SizedBox(height: AppSpace.sm),
            SegmentedButton<WatermarkType>(
              segments: const [
                ButtonSegment(
                  value: WatermarkType.text,
                  label: Text('文字水印'),
                  icon: Icon(Icons.text_fields, size: 18),
                ),
                ButtonSegment(
                  value: WatermarkType.image,
                  label: Text('图片水印'),
                  icon: Icon(Icons.image_outlined, size: 18),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) {
                setState(() => _type = s.first);
                _refresh();
              },
            ),
            const SizedBox(height: AppSpace.md),

            if (_type == WatermarkType.text)
              TextField(
                controller: _textCtrl,
                decoration: const InputDecoration(
                  labelText: '水印文字',
                  prefixIcon: Icon(Icons.edit_outlined),
                ),
                onChanged: (_) => _refresh(),
              )
            else
              OutlinedButton.icon(
                onPressed: _pickWatermark,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(_wmImage == null
                    ? '上传透明 PNG 水印'
                    : '已上传水印 · 点击更换'),
              ),
            const SizedBox(height: AppSpace.xl),

            // 平铺参数
            Row(
              children: [
                const Icon(Icons.tune, size: 18, color: AppColors.primary),
                const SizedBox(width: AppSpace.sm),
                Text('平铺参数', style: AppType.section),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.lg, vertical: AppSpace.sm),
                child: Column(
                  children: [
                    _slider('大小', _scale, 0.05, 0.6, (v) {
                      setState(() => _scale = v);
                      _refresh();
                    }),
                    _slider('密度', _spacing, 1.0, 4.0, (v) {
                      setState(() => _spacing = v);
                      _refresh();
                    }),
                    _slider('透明', _opacity, 0.05, 1.0, (v) {
                      setState(() => _opacity = v);
                      _refresh();
                    }),
                    _slider('角度', _angle, -90, 90, (v) {
                      setState(() => _angle = v);
                      _refresh();
                    }),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.palette_outlined,
                          size: 20, color: AppColors.textSecondary),
                      title: Text('水印颜色', style: AppType.secondary),
                      trailing: GestureDetector(
                        onTap: () async {
                          final c = await _pickColor(context, _color);
                          if (c != null) {
                            setState(() => _color = c);
                            _refresh();
                          }
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _color,
                            border: Border.all(
                                color: AppColors.borderStrong, width: 1.5),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpace.xl),

            FilledButton.icon(
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
            const SizedBox(height: AppSpace.sm),
          ],
        ),
      ),
    );
  }

  Future<Color?> _pickColor(BuildContext context, Color current) async {
    const colors = [
      AppColors.slate700,
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
                      width: 44,
                      height: 44,
                      margin: const EdgeInsets.all(AppSpace.sm / 2),
                      decoration: BoxDecoration(
                        color: c,
                        border: c == current
                            ? Border.all(color: AppColors.primary, width: 3)
                            : Border.all(color: AppColors.borderStrong),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

// ============================================================
// 进度页：批量处理 + 完成反馈
// ============================================================
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
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success),
            const SizedBox(width: AppSpace.sm),
            const Text('处理完成'),
          ],
        ),
        content: Text(
          '已成功保存 $_done 张到相册'
          '${_failed > 0 ? '，$_failed 张处理失败' : ''}。',
          style: AppType.body,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
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
      appBar: AppBar(title: const Text('正在处理')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 10,
                  backgroundColor: AppColors.border,
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
              const SizedBox(height: AppSpace.xl),
              Text(
                _finished
                    ? '全部完成'
                    : '正在处理 ${_done + _failed + 1} / $total',
                style: AppType.title,
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                '成功 $_done 张 · 失败 $_failed 张',
                style: AppType.secondary.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpace.xl),
              Container(
                padding: const EdgeInsets.all(AppSpace.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: AppSpace.sm),
                    Text('处理中请勿退出应用',
                        style: AppType.caption
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
