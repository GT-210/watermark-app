import 'package:flutter/material.dart';

/// ============================================================
/// 设计令牌体系（唯一事实来源）
/// 组件只引用语义层，禁止硬编码色值。暗色模式只需替换语义层。
/// 对比度按 WCAG AA 校验：正文 >= 4.5:1，大字/图形 >= 3:1
/// ============================================================
abstract final class AppColors {
  // ---------- 原始值层（不直接用于组件） ----------
  static const Color indigo50 = Color(0xFFEEF2FF);
  static const Color indigo100 = Color(0xFFE0E7FF);
  static const Color indigo500 = Color(0xFF6366F1);
  static const Color indigo600 = Color(0xFF4F46E5);
  static const Color indigo700 = Color(0xFF4338CA);
  static const Color amber500 = Color(0xFFF59E0B);
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color canvasDark = Color(0xFF11162B);
  static const Color green600 = Color(0xFF059669);
  static const Color red600 = Color(0xFFDC2626);

  // ---------- 语义层（组件引用这一层） ----------
  /// 主色：白底 5.8:1，按钮白字 >= 4.5:1
  static const Color primary = indigo600;
  static const Color primaryHover = indigo700;
  static const Color primarySubtle = indigo50;
  static const Color primaryBorder = indigo100;
  static const Color accent = amber500; // 仅作强调图形，非正文

  static const Color bg = slate50;
  static const Color surface = Colors.white;
  static const Color surfaceSubtle = slate100;

  /// 正文 slate-900 白底 18.4:1
  static const Color textPrimary = slate900;
  /// 次要 slate-600 白底 7.6:1
  static const Color textSecondary = slate600;
  /// 辅助 slate-500 白底 4.8:1（满足正文 4.5:1）
  static const Color textMuted = slate500;
  static const Color textOnPrimary = Colors.white;
  static const Color textOnCanvas = Color(0xFFE8ECFF);

  static const Color border = slate200;
  static const Color borderStrong = slate300;
  static const Color focus = indigo500;

  static const Color success = green600;
  static const Color error = red600;
  static const Color canvas = canvasDark;
}

/// 字号梯度 + 行高（sp）
abstract final class AppType {
  static const double xs = 12;
  static const double sm = 14;
  static const double base = 16;
  static const double lg = 18;
  static const double xl = 20;
  static const double xxl = 24;
  static const double h1 = 30;
  static const double h2 = 26;

  static const TextStyle display = TextStyle(
    fontSize: h1,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );
  static const TextStyle title = TextStyle(
    fontSize: xl,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle section = TextStyle(
    fontSize: base,
    height: 1.4,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle body = TextStyle(fontSize: base, height: 1.5);
  static const TextStyle secondary = TextStyle(fontSize: sm, height: 1.5);
  static const TextStyle caption = TextStyle(fontSize: xs, height: 1.5);
}

/// 间距（4px 基准）
abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// 圆角
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;
}

/// 统一主题
class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.bg,
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: AppType.lg,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(
            fontSize: AppType.base,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, 48),
          side: const BorderSide(color: AppColors.borderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(
            fontSize: AppType.base,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.md,
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.focus, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.border,
        thumbColor: AppColors.primary,
        overlayColor: AppColors.primarySubtle,
        valueIndicatorColor: AppColors.primary,
      ),
    );
    return base;
  }
}
