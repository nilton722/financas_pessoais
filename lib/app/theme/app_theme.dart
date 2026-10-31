import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'finance_colors.dart';

abstract final class AppTheme {
  /// Verde principal da identidade Nô Dinheru.
  static const Color _seedColor = Color(0xFF087F5B);

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme = _scheme(brightness);
    final textTheme = _textTheme(brightness, scheme);
    final financeColors = isLight ? FinanceColors.light : FinanceColors.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.card,
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: isLight ? 0.8 : 0.6),
          ),
        ),
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 22),
        actionsIconTheme: IconThemeData(
          color: scheme.onSurfaceVariant,
          size: 22,
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xxs,
        ),
        minVerticalPadding: AppSpacing.sm,
        titleTextStyle: textTheme.titleSmall?.copyWith(color: scheme.onSurface),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        iconColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.control),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: _inputBorder(scheme.outlineVariant),
        enabledBorder: _inputBorder(scheme.outlineVariant),
        focusedBorder: _inputBorder(scheme.primary, width: 2),
        errorBorder: _inputBorder(scheme.error),
        focusedErrorBorder: _inputBorder(scheme.error, width: 2),
        disabledBorder: _inputBorder(
          scheme.outlineVariant.withValues(alpha: 0.5),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        floatingLabelStyle: textTheme.labelLarge?.copyWith(
          color: scheme.primary,
        ),
        helperStyle: textTheme.bodySmall,
        errorStyle: textTheme.bodySmall?.copyWith(color: scheme.error),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        suffixStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.control),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.control),
          side: BorderSide(color: scheme.outline),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 40),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.small),
          textStyle: textTheme.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        focusElevation: 3,
        hoverElevation: 3,
        highlightElevation: 4,
        extendedTextStyle: textTheme.labelLarge,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.card),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: AppRadii.control,
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.primaryContainer,
        disabledColor: scheme.surfaceContainerHighest,
        checkmarkColor: scheme.onPrimaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.small),
        labelStyle: textTheme.labelLarge?.copyWith(color: scheme.onSurface),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadii.control),
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: scheme.outlineVariant),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        insetPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.control),
        elevation: 3,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.card),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xl,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.control),
        textStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: AppRadii.small,
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
        waitDuration: const Duration(milliseconds: 500),
      ),
      extensions: <ThemeExtension<dynamic>>[financeColors],
    );
  }

  static InputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: AppRadii.control,
        borderSide: BorderSide(color: color, width: width),
      );

  static ColorScheme _scheme(Brightness brightness) {
    final base = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );
    if (brightness == Brightness.light) {
      return base.copyWith(
        primary: const Color(0xFF087F5B),
        onPrimary: const Color(0xFFFFFFFF),
        primaryContainer: const Color(0xFFB0EEDB),
        onPrimaryContainer: const Color(0xFF002019),
        secondary: const Color(0xFFE8C66A),
        onSecondary: const Color(0xFF3B2E00),
        secondaryContainer: const Color(0xFFF6E8BF),
        onSecondaryContainer: const Color(0xFF3B2E00),
        tertiary: const Color(0xFF104B3C),
        onTertiary: const Color(0xFFFFFFFF),
        tertiaryContainer: const Color(0xFFC6E9DB),
        onTertiaryContainer: const Color(0xFF002019),
        error: const Color(0xFFB3372B),
        onError: const Color(0xFFFFFFFF),
        errorContainer: const Color(0xFFF7D5CF),
        onErrorContainer: const Color(0xFF5B150D),
        surface: const Color(0xFFF5F8F5),
        onSurface: const Color(0xFF182923),
        surfaceContainerLowest: const Color(0xFFFFFFFF),
        surfaceContainerLow: const Color(0xFFEFF4F0),
        surfaceContainer: const Color(0xFFE9EFEA),
        surfaceContainerHigh: const Color(0xFFE3EAE5),
        surfaceContainerHighest: const Color(0xFFDCE4DE),
        onSurfaceVariant: const Color(0xFF52635C),
        outline: const Color(0xFF7C8B84),
        outlineVariant: const Color(0xFFD3DDD6),
      );
    }
    return base.copyWith(
      primary: const Color(0xFF6FDDB8),
      onPrimary: const Color(0xFF003829),
      primaryContainer: const Color(0xFF00513B),
      onPrimaryContainer: const Color(0xFFA9F2D8),
      secondary: const Color(0xFFE8C66A),
      onSecondary: const Color(0xFF3B2E00),
      secondaryContainer: const Color(0xFF554400),
      onSecondaryContainer: const Color(0xFFF6E8BF),
      tertiary: const Color(0xFF8FD4BE),
      onTertiary: const Color(0xFF00382A),
      tertiaryContainer: const Color(0xFF0B4E3C),
      onTertiaryContainer: const Color(0xFFC6E9DB),
      error: const Color(0xFFFFB4A9),
      onError: const Color(0xFF690005),
      errorContainer: const Color(0xFF7A2A20),
      onErrorContainer: const Color(0xFFFFDAD4),
      surface: const Color(0xFF0B1512),
      onSurface: const Color(0xFFE3EAE6),
      surfaceContainerLowest: const Color(0xFF0F1A16),
      surfaceContainerLow: const Color(0xFF131F1A),
      surfaceContainer: const Color(0xFF18241F),
      surfaceContainerHigh: const Color(0xFF1E2B25),
      surfaceContainerHighest: const Color(0xFF26342D),
      onSurfaceVariant: const Color(0xFFB7C6BE),
      outline: const Color(0xFF85968D),
      outlineVariant: const Color(0xFF34463C),
    );
  }

  static TextTheme _textTheme(Brightness brightness, ColorScheme scheme) {
    final base = Typography.material2021(platform: TargetPlatform.android);
    final theme = brightness == Brightness.light ? base.black : base.white;
    return theme
        .copyWith(
          headlineMedium: theme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            height: 1.2,
          ),
          headlineSmall: theme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            height: 1.25,
          ),
          titleLarge: theme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
          titleMedium: theme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          titleSmall: theme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          bodyLarge: theme.bodyLarge?.copyWith(height: 1.45),
          bodyMedium: theme.bodyMedium?.copyWith(height: 1.45),
          bodySmall: theme.bodySmall?.copyWith(
            height: 1.4,
            color: scheme.onSurfaceVariant,
          ),
          labelLarge: theme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
          labelMedium: theme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          labelSmall: theme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: scheme.onSurfaceVariant,
          ),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  }
}
