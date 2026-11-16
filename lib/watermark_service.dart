import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 水印类型
enum WatermarkType { text, image }

/// 一条水印配置（编辑页所有可调参数）
class WatermarkConfig {
  final WatermarkType type;
  final ui.Image? image; // 透明 PNG 水印解码后的图像
  final String text; // 文字水印内容
  final Color color; // 文字颜色
  final double scale; // 水印块宽度占原图宽度比例
  final double spacing; // 平铺间距倍数（越大越稀疏）
  final double opacity; // 透明度 0~1
  final double angle; // 旋转角度（度）

  const WatermarkConfig({
    required this.type,
    this.image,
    this.text = '版权所有',
    this.color = Colors.grey,
    this.scale = 0.18,
    this.spacing = 1.8,
    this.opacity = 0.35,
    this.angle = -20,
  });
}

/// 给颜色附加透明度（避开 withOpacity 在最新版 SDK 的弃用告警）
Color withAlpha(Color c, double a) => Color.fromRGBO(
      (c.r * 255).round(),
      (c.g * 255).round(),
      (c.b * 255).round(),
      a,
    );

/// 从字节解码为可绘制图像
Future<ui.Image> decodeImageFromBytes(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}

/// 从文件解码
Future<ui.Image> decodeImageFromFile(String path) async {
  return decodeImageFromBytes(await File(path).readAsBytes());
}

/// 解码缩略图（长边限制，仅用于编辑页快速预览，不降低成品质量）
Future<ui.Image> decodeThumbnail(String path, {int maxSide = 1200}) async {
  final bytes = await File(path).readAsBytes();
  final first = await decodeImageFromBytes(bytes);
  final longest = math.max(first.width, first.height);
  if (longest <= maxSide) return first;
  final ratio = maxSide / longest;
  final codec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: (first.width * ratio).round(),
    targetHeight: (first.height * ratio).round(),
  );
  final frame = await codec.getNextFrame();
  return frame.image;
}

/// 核心：把水印按参数平铺到原图，返回 PNG 字节
Future<Uint8List> composeWatermark({
  required ui.Image source,
  required WatermarkConfig cfg,
}) async {
  final w = source.width.toDouble();
  final h = source.height.toDouble();

  double blockW;
  double blockH;
  double textScale = 1.0;
  TextPainter? painter;

  if (cfg.type == WatermarkType.image && cfg.image != null) {
    blockW = w * cfg.scale;
    blockH = cfg.image!.height * (blockW / cfg.image!.width);
  } else {
    painter = TextPainter(
      text: TextSpan(
        text: cfg.text.trim().isEmpty ? '水印' : cfg.text,
        style: TextStyle(
          color: withAlpha(cfg.color, cfg.opacity),
          fontSize: 40,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    blockW = w * cfg.scale;
    textScale = blockW / math.max(painter.width, 1.0);
    blockH = painter.height * textScale;
  }

  final stepX = math.max(blockW * cfg.spacing, 1.0);
  final stepY = math.max(blockH * cfg.spacing, 1.0);
  final cover = math.max(w, h) * 2.4; // 放大画布，保证旋转后仍铺满

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawImage(source, ui.Offset.zero, ui.Paint());

  canvas.save();
  canvas.translate(w / 2, h / 2);
  canvas.rotate(cfg.angle * math.pi / 180);
  canvas.translate(-cover / 2, -cover / 2);

  if (cfg.type == WatermarkType.image && cfg.image != null) {
    // 白色作为调制色，保留透明 PNG 原色，仅叠加透明度
    final paint = ui.Paint()
      ..color = withAlpha(const Color(0xFFFFFFFF), cfg.opacity);
    final srcRect = ui.Rect.fromLTWH(
      0,
      0,
      cfg.image!.width.toDouble(),
      cfg.image!.height.toDouble(),
    );
    int row = 0;
    for (double y = -stepY; y < cover + stepY; y += stepY, row++) {
      final shift = row.isOdd ? stepX / 2 : 0.0;
      for (double x = -stepX; x < cover + stepX; x += stepX) {
        canvas.drawImageRect(
          cfg.image!,
          srcRect,
          ui.Rect.fromLTWH(x + shift, y, blockW, blockH),
          paint,
        );
      }
    }
  } else if (painter != null) {
    int row = 0;
    for (double y = -stepY; y < cover + stepY; y += stepY, row++) {
      final shift = row.isOdd ? stepX / 2 : 0.0;
      for (double x = -stepX; x < cover + stepX; x += stepX) {
        canvas.save();
        canvas.translate(x + shift, y);
        canvas.scale(textScale);
        painter.paint(canvas, ui.Offset.zero);
        canvas.restore();
      }
    }
  }
  canvas.restore();

  final picture = recorder.endRecording();
  final out = await picture.toImage(source.width, source.height);
  final byteData = await out.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

/// 保存 PNG 字节到系统相册
Future<void> saveBytesToGallery(Uint8List bytes, String baseName) async {
  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path, '$baseName.png'));
  await file.writeAsBytes(bytes, flush: true);
  await Gal.putImage(file.path);
}
