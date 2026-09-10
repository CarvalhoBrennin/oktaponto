import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/work_schedule.dart';

const _kScheduleKey = 'oktaponto_work_schedule';
const _kOnboardingKey = 'oktaponto_onboarding_seen';
const _kLegacyScheduleKey = 'horafolio_work_schedule';
const _kLegacyOnboardingKey = 'horafolio_onboarding_seen';

/// Onde a jornada configurada é guardada.
abstract interface class WorkScheduleStore {
  Future<ScheduleSetup> load();
  Future<void> save(WorkSchedule schedule);
  Future<void> markOnboardingSeen();

  /// Volta o aparelho ao estado de primeira abertura.
  Future<void> clear();
}

/// Guarda a jornada nas preferências do aparelho.
///
/// Não vai para o SQLite de propósito. O schema v1 é um contrato congelado,
/// validado no CI e sem migração implementada, e esta configuração não é dado
/// de ponto: não entra no timesheet, não tem auditoria e vale só para este
/// aparelho — a mesma categoria do tema, que já mora aqui.
final class PrefsWorkScheduleStore implements WorkScheduleStore {
  const PrefsWorkScheduleStore();

  @override
  Future<ScheduleSetup> load() async {
    final prefs = await SharedPreferences.getInstance();
    // Migração legado: copia chaves antigas se novas ausentes.
    if (!prefs.containsKey(_kScheduleKey) &&
        prefs.containsKey(_kLegacyScheduleKey)) {
      final legacy = prefs.getString(_kLegacyScheduleKey);
      if (legacy != null) await prefs.setString(_kScheduleKey, legacy);
    }
    if (!prefs.containsKey(_kOnboardingKey) &&
        prefs.containsKey(_kLegacyOnboardingKey)) {
      final legacySeen = prefs.getBool(_kLegacyOnboardingKey);
      if (legacySeen != null) await prefs.setBool(_kOnboardingKey, legacySeen);
    }
    final seen = prefs.getBool(_kOnboardingKey) ?? false;
    final raw = prefs.getString(_kScheduleKey);
    if (raw == null) return ScheduleSetup(onboardingSeen: seen, schedule: null);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        return ScheduleSetup(onboardingSeen: seen, schedule: null);
      }
      return ScheduleSetup(
        onboardingSeen: seen,
        schedule: WorkSchedule.fromJson(decoded),
      );
    } catch (error) {
      // Preferência ilegível não pode impedir a abertura do app; o usuário
      // reconfigura a jornada em Configurações.
      debugPrint('OktaPonto: jornada gravada ilegível: $error');
      return ScheduleSetup(onboardingSeen: seen, schedule: null);
    }
  }

  @override
  Future<void> save(WorkSchedule schedule) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kScheduleKey, jsonEncode(schedule.toJson()));
  }

  @override
  Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingKey, true);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kScheduleKey);
    await prefs.remove(_kOnboardingKey);
  }
}
