import 'package:flutter/material.dart';

/// Um papel semântico completo: cor de traço/ícone, superfície de apoio e
/// cor de conteúdo sobre essa superfície.
@immutable
final class HfRole {
  const HfRole({
    required this.foreground,
    required this.container,
    required this.onContainer,
  });

  final Color foreground;
  final Color container;
  final Color onContainer;

  HfRole lerpTo(HfRole other, double t) => HfRole(
    foreground: Color.lerp(foreground, other.foreground, t)!,
    container: Color.lerp(container, other.container, t)!,
    onContainer: Color.lerp(onContainer, other.onContainer, t)!,
  );
}

/// Cores de estado da jornada.
///
/// Ficam fora do [ColorScheme] de propósito: "trabalhando", "intervalo" e
/// "concluída" são conceitos do produto, não papéis do Material. Manter isso
/// separado evita sequestrar `tertiary`/`secondary` para significados que o
/// Material vai reinterpretar em outro componente.
///
/// A jornada em andamento usa o laranja da marca: é o estado que o app
/// existe para mostrar, então ele carrega a identidade. Por consequência o
/// intervalo teve de sair do âmbar — laranja e âmbar lado a lado no mesmo
/// anel viram a mesma cor — e virou azul frio, que também lê bem como
/// "pausa". Sobra o âmbar para a pendência, e o verde para a conclusão.
///
/// Nenhum estado é comunicado só por cor — cada [HfRole] anda sempre
/// acompanhado de ícone e texto nos componentes que o consomem.
@immutable
final class HfSemantics extends ThemeExtension<HfSemantics> {
  const HfSemantics({
    required this.working,
    required this.resting,
    required this.done,
    required this.attention,
    required this.idle,
    required this.track,
  });

  /// Jornada em andamento.
  final HfRole working;

  /// Intervalo.
  final HfRole resting;

  /// Jornada concluída.
  final HfRole done;

  /// Pendência que exige revisão do usuário.
  final HfRole attention;

  /// Ainda não aconteceu / sem registro.
  final HfRole idle;

  /// Trilho neutro de anéis, timelines e barras.
  final Color track;

  static const HfSemantics light = HfSemantics(
    working: HfRole(
      foreground: Color(0xFFC04D08),
      container: Color(0xFFFFE7D8),
      onContainer: Color(0xFF451900),
    ),
    resting: HfRole(
      foreground: Color(0xFF1F5F86),
      container: Color(0xFFDCEAF5),
      onContainer: Color(0xFF06293C),
    ),
    done: HfRole(
      foreground: Color(0xFF2C6B4B),
      container: Color(0xFFDCEDE3),
      onContainer: Color(0xFF0F2F1E),
    ),
    attention: HfRole(
      foreground: Color(0xFF8A5A00),
      container: Color(0xFFFAEED2),
      onContainer: Color(0xFF3A2600),
    ),
    idle: HfRole(
      foreground: Color(0xFF6B6660),
      container: Color(0xFFEDECE9),
      onContainer: Color(0xFF33302C),
    ),
    track: Color(0xFFDCDAD5),
  );

  static const HfSemantics dark = HfSemantics(
    working: HfRole(
      foreground: Color(0xFFFF8A3D),
      container: Color(0xFF45200A),
      onContainer: Color(0xFFFFD9BE),
    ),
    resting: HfRole(
      foreground: Color(0xFF7FC0E8),
      container: Color(0xFF113445),
      onContainer: Color(0xFFC9E6F7),
    ),
    done: HfRole(
      foreground: Color(0xFF7FCBA3),
      container: Color(0xFF123626),
      onContainer: Color(0xFFCBEBD9),
    ),
    attention: HfRole(
      foreground: Color(0xFFF0C255),
      container: Color(0xFF3D2F0A),
      onContainer: Color(0xFFFBEBBD),
    ),
    idle: HfRole(
      foreground: Color(0xFF9C978F),
      container: Color(0xFF1C1C1F),
      onContainer: Color(0xFFDCD9D4),
    ),
    track: Color(0xFF2A2A2E),
  );

  /// Leitura tolerante: telas de teste e previews podem montar um
  /// [ThemeData] cru sem a extensão registrada.
  static HfSemantics of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<HfSemantics>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  HfSemantics copyWith({
    HfRole? working,
    HfRole? resting,
    HfRole? done,
    HfRole? attention,
    HfRole? idle,
    Color? track,
  }) {
    return HfSemantics(
      working: working ?? this.working,
      resting: resting ?? this.resting,
      done: done ?? this.done,
      attention: attention ?? this.attention,
      idle: idle ?? this.idle,
      track: track ?? this.track,
    );
  }

  @override
  HfSemantics lerp(ThemeExtension<HfSemantics>? other, double t) {
    if (other is! HfSemantics) return this;
    return HfSemantics(
      working: working.lerpTo(other.working, t),
      resting: resting.lerpTo(other.resting, t),
      done: done.lerpTo(other.done, t),
      attention: attention.lerpTo(other.attention, t),
      idle: idle.lerpTo(other.idle, t),
      track: Color.lerp(track, other.track, t)!,
    );
  }
}

extension HfSemanticsContext on BuildContext {
  HfSemantics get hf => HfSemantics.of(this);
}
