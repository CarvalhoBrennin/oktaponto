import 'package:flutter/widgets.dart';

/// Escalas base do OktaPonto.
///
/// Todo espaçamento, raio e duração da interface sai daqui. O objetivo é
/// impedir que cada tela invente seus próprios números e a composição perca
/// ritmo — o app precisa parecer desenhado por uma única mão.
abstract final class HfSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double huge = 32;
  static const double giant = 40;
  static const double section = 48;

  /// Margem horizontal padrão do conteúdo em telas compactas.
  static const EdgeInsets page = EdgeInsets.symmetric(horizontal: xl);
}

abstract final class HfRadius {
  static const Radius smallR = Radius.circular(10);
  static const Radius mediumR = Radius.circular(14);
  static const Radius largeR = Radius.circular(20);
  static const Radius extraLargeR = Radius.circular(28);

  static const BorderRadius small = BorderRadius.all(smallR);
  static const BorderRadius medium = BorderRadius.all(mediumR);
  static const BorderRadius large = BorderRadius.all(largeR);
  static const BorderRadius extraLarge = BorderRadius.all(extraLargeR);

  /// Reservado para o herói de tempo e para o CTA principal.
  static const BorderRadius hero = BorderRadius.all(Radius.circular(36));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}

/// Durações e curvas. Movimento existe para explicar mudança de estado —
/// nunca para enfeitar. Nada acima de [slow] na navegação cotidiana.
abstract final class HfMotion {
  static const Duration instant = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration base = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 340);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve standard = Curves.easeInOutCubic;
}

abstract final class HfSize {
  /// Área tocável mínima para qualquer alvo interativo.
  static const double minTouchTarget = 48;

  /// Altura do CTA principal da jornada.
  static const double primaryAction = 60;

  /// Diâmetro base do anel de jornada em telas compactas.
  static const double heroDial = 252;
  static const double heroDialMax = 300;

  /// A partir daqui o app usa navegação lateral e duas colunas.
  static const double wideBreakpoint = 720;
  static const double contentMaxWidth = 560;
}
