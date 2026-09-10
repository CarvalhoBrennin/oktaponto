import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/hf_semantics.dart';
import '../design/hf_tokens.dart';

/// Design system OktaPonto — "tempo vivo".
///
/// As paletas são escritas à mão em vez de derivadas de `fromSeed`. A
/// identidade é o laranja: no claro um laranja forte sobre branco e cinzas
/// neutros; no escuro um laranja neon sobre preto e cinza-chumbo. O gerador
/// tonal do Material achata justamente o que dá caráter a essa combinação —
/// no claro ele lava o laranja, no escuro ele o empurra para pastel — então
/// os dois esquemas são declarados cor a cor.
///
/// Os cinzas são neutros de propósito (sem viés azul), para que o laranja
/// seja a única cor com temperatura na tela.
///
/// Cores de estado da jornada vivem em [HfSemantics], registrada como
/// extensão do tema.
abstract final class AppTheme {
  /// Cor de marca no tema claro. Pública para previews e ferramentas.
  static const brand = Color(0xFFC04D08);

  /// Cor de marca no tema escuro — o mesmo laranja, com brilho de neon.
  static const brandNeon = Color(0xFFFF8A3D);

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: brand,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFFFE3D0),
    onPrimaryContainer: Color(0xFF451900),
    // Secundária neutra e quente: papel de apoio que não disputa com a marca.
    secondary: Color(0xFF6D5B50),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFF0E9E3),
    onSecondaryContainer: Color(0xFF2A211B),
    // Terciária fria: o contraponto do laranja, usado no intervalo.
    tertiary: Color(0xFF1F5F86),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFD6E8F5),
    onTertiaryContainer: Color(0xFF062A3F),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),
    surface: Color(0xFFFAFAF9),
    onSurface: Color(0xFF1A1917),
    onSurfaceVariant: Color(0xFF57534E),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFCFCFB),
    surfaceContainer: Color(0xFFF3F3F1),
    surfaceContainerHigh: Color(0xFFECECE9),
    surfaceContainerHighest: Color(0xFFE5E5E1),
    surfaceDim: Color(0xFFDDDDD8),
    surfaceBright: Color(0xFFFFFFFF),
    surfaceTint: brand,
    outline: Color(0xFF8A857E),
    outlineVariant: Color(0xFFDAD8D3),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF2B2926),
    onInverseSurface: Color(0xFFF5F4F2),
    inversePrimary: Color(0xFFFFB68A),
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: brandNeon,
    onPrimary: Color(0xFF2E1000),
    primaryContainer: Color(0xFF6B2A00),
    onPrimaryContainer: Color(0xFFFFDCC6),
    secondary: Color(0xFFD2C7BF),
    onSecondary: Color(0xFF2B221C),
    secondaryContainer: Color(0xFF3A322C),
    onSecondaryContainer: Color(0xFFEFE6DF),
    tertiary: Color(0xFF7FC0E8),
    onTertiary: Color(0xFF06304A),
    tertiaryContainer: Color(0xFF0E4562),
    onTertiaryContainer: Color(0xFFCBE7F7),
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF601410),
    errorContainer: Color(0xFF8C1D18),
    onErrorContainer: Color(0xFFF9DEDC),
    // Preto quase absoluto na base, cinza-chumbo nos níveis acima: é o
    // degrau de superfície que dá profundidade, não sombra.
    surface: Color(0xFF0A0A0B),
    onSurface: Color(0xFFECEBEA),
    onSurfaceVariant: Color(0xFFA9A5A0),
    surfaceContainerLowest: Color(0xFF050505),
    surfaceContainerLow: Color(0xFF121213),
    surfaceContainer: Color(0xFF18181A),
    surfaceContainerHigh: Color(0xFF202023),
    surfaceContainerHighest: Color(0xFF2A2A2E),
    surfaceDim: Color(0xFF0A0A0B),
    surfaceBright: Color(0xFF333338),
    surfaceTint: brandNeon,
    outline: Color(0xFF6E6963),
    outlineVariant: Color(0xFF2E2D2F),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFECEBEA),
    onInverseSurface: Color(0xFF1E1D1C),
    inversePrimary: brand,
  );

  // ThemeData é imutável e caro de montar; construir uma vez evita recriar a
  // cada rebuild do MaterialApp.
  static final ThemeData light = _build(_lightScheme, HfSemantics.light);
  static final ThemeData dark = _build(_darkScheme, HfSemantics.dark);

  static ThemeData _build(ColorScheme scheme, HfSemantics semantics) {
    final isDark = scheme.brightness == Brightness.dark;
    final text = _textTheme(scheme);

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      textTheme: text,
      extensions: <ThemeExtension<dynamic>>[semantics],
      splashFactory: InkSparkle.splashFactory,
      highlightColor: scheme.primary.withValues(alpha: isDark ? 0.07 : 0.05),
      splashColor: scheme.primary.withValues(alpha: isDark ? 0.06 : 0.04),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: HfSpace.xl,
        titleTextStyle: text.headlineSmall,
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        actionsIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      // Cards continuam existindo, mas deixaram de ser o recipiente padrão de
      // tudo: sem sombra e com borda discreta, para que a hierarquia venha de
      // espaçamento e tipografia.
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: HfRadius.large,
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        height: 68,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: HfRadius.pill,
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return text.labelMedium!.copyWith(
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
            size: 24,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: HfRadius.pill,
        ),
        selectedLabelTextStyle: text.labelMedium!.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: text.labelMedium,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: scheme.surfaceContainerLow,
        modalElevation: 0,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: HfRadius.extraLargeR),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: HfRadius.extraLarge),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium!.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        shape: const RoundedRectangleBorder(borderRadius: HfRadius.medium),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: HfSpace.lg,
          vertical: HfSpace.xs,
        ),
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall,
        shape: const RoundedRectangleBorder(borderRadius: HfRadius.medium),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedColor: scheme.primaryContainer,
        secondarySelectedColor: scheme.primaryContainer,
        labelStyle: text.labelLarge,
        secondaryLabelStyle: text.labelLarge!.copyWith(
          color: scheme.onPrimaryContainer,
        ),
        shape: const RoundedRectangleBorder(borderRadius: HfRadius.small),
        side: BorderSide(color: scheme.outlineVariant),
        elevation: 0,
        pressElevation: 0,
        showCheckmark: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: HfSpace.lg,
          vertical: HfSpace.lg,
        ),
        floatingLabelStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: const OutlineInputBorder(
          borderRadius: HfRadius.medium,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: HfRadius.medium,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: HfRadius.medium,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: HfRadius.medium,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: HfRadius.medium,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.surfaceContainerHighest,
          disabledForegroundColor: scheme.onSurfaceVariant,
          shape: const RoundedRectangleBorder(borderRadius: HfRadius.medium),
          padding: const EdgeInsets.symmetric(
            horizontal: HfSpace.xxl,
            vertical: HfSpace.md,
          ),
          minimumSize: const Size(0, HfSize.minTouchTarget),
          textStyle: text.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
          shape: const RoundedRectangleBorder(borderRadius: HfRadius.medium),
          padding: const EdgeInsets.symmetric(
            horizontal: HfSpace.xl,
            vertical: HfSpace.md,
          ),
          minimumSize: const Size(0, HfSize.minTouchTarget),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          shape: const RoundedRectangleBorder(borderRadius: HfRadius.small),
          minimumSize: const Size(0, HfSize.minTouchTarget),
          textStyle: text.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.surfaceContainerHigh,
          foregroundColor: scheme.onSurface,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(borderRadius: HfRadius.medium),
          minimumSize: const Size(0, HfSize.minTouchTarget),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          highlightColor: scheme.primary.withValues(alpha: 0.08),
          minimumSize: const Size.square(HfSize.minTouchTarget),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          // O segmento escolhido usa a marca: é uma seleção, e seleção é
          // laranja em toda a interface.
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.primaryContainer
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: scheme.outlineVariant),
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: HfRadius.medium),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: HfRadius.large),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        circularTrackColor: semantics.track,
        linearTrackColor: semantics.track,
        linearMinHeight: 4,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : scheme.outlineVariant,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(scheme.onPrimary),
        side: BorderSide(color: scheme.outline, width: 1.6),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        dialBackgroundColor: scheme.surfaceContainerHigh,
        dialHandColor: scheme.primary,
        entryModeIconColor: scheme.onSurfaceVariant,
        helpTextStyle: text.labelMedium,
        shape: const RoundedRectangleBorder(borderRadius: HfRadius.extraLarge),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        headerBackgroundColor: scheme.surfaceContainerLow,
        headerForegroundColor: scheme.onSurface,
        shape: const RoundedRectangleBorder(borderRadius: HfRadius.extraLarge),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: HfRadius.small,
        ),
        textStyle: text.bodySmall!.copyWith(color: scheme.onInverseSurface),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: HfRadius.medium,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }

  /// Números da interface (relógios, totais, contadores) usam algarismos de
  /// largura fixa para que o contador vivo não dance a cada minuto.
  static const List<FontFeature> tabularFigures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static TextTheme _textTheme(ColorScheme scheme) {
    final onSurface = scheme.onSurface;
    final variant = scheme.onSurfaceVariant;
    return TextTheme(
      // Reservado ao contador da jornada.
      displayLarge: TextStyle(
        color: onSurface,
        fontSize: 54,
        height: 1.04,
        fontWeight: FontWeight.w600,
        letterSpacing: -1.8,
        fontFeatures: tabularFigures,
      ),
      displayMedium: TextStyle(
        color: onSurface,
        fontSize: 44,
        height: 1.06,
        fontWeight: FontWeight.w600,
        letterSpacing: -1.4,
        fontFeatures: tabularFigures,
      ),
      displaySmall: TextStyle(
        color: onSurface,
        fontSize: 34,
        height: 1.1,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.8,
        fontFeatures: tabularFigures,
      ),
      headlineLarge: TextStyle(
        color: onSurface,
        fontSize: 28,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      headlineMedium: TextStyle(
        color: onSurface,
        fontSize: 24,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      headlineSmall: TextStyle(
        color: onSurface,
        fontSize: 21,
        height: 1.25,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleLarge: TextStyle(
        color: onSurface,
        fontSize: 19,
        height: 1.3,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        color: onSurface,
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        color: onSurface,
        fontSize: 15,
        height: 1.35,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: onSurface,
        fontSize: 16,
        height: 1.45,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: TextStyle(
        color: variant,
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: TextStyle(
        color: variant,
        fontSize: 13,
        height: 1.4,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: TextStyle(
        color: onSurface,
        fontSize: 15,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelMedium: TextStyle(
        color: variant,
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
      // Sobrelinha de seção: curta, caixa alta, muito espaçada.
      labelSmall: TextStyle(
        color: variant,
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }
}
