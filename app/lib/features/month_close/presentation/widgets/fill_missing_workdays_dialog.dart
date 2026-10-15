import 'package:flutter/material.dart';

import 'package:oktaponto/core/design/hf_tokens.dart';
import 'package:oktaponto/core/ui/hf_notice.dart';
import 'package:oktaponto/features/month_close/domain/workday_fill.dart';

class FillMissingWorkdaysDialog extends StatefulWidget {
  const FillMissingWorkdaysDialog({
    required this.dayCount,
    required this.initialPattern,
    super.key,
  });

  final int dayCount;
  final WorkdayFillPattern initialPattern;

  @override
  State<FillMissingWorkdaysDialog> createState() =>
      _FillMissingWorkdaysDialogState();
}

class _FillMissingWorkdaysDialogState extends State<FillMissingWorkdaysDialog> {
  late WorkdayFillPattern _pattern;

  @override
  void initState() {
    super.initState();
    _pattern = widget.initialPattern;
  }

  Future<void> _pickTime({required bool isStart}) async {
    final currentMinute = isStart
        ? _pattern.startMinuteOfDay
        : _pattern.breakStartMinuteOfDay;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: currentMinute ~/ 60,
        minute: currentMinute % 60,
      ),
      helpText: isStart ? 'HORÁRIO DE ENTRADA' : 'INÍCIO DO ALMOÇO',
      confirmText: 'Confirmar',
      cancelText: 'Cancelar',
    );
    if (picked == null || !mounted) return;
    final minute = picked.hour * 60 + picked.minute;
    setState(() {
      _pattern = isStart
          ? _pattern.copyWith(startMinuteOfDay: minute)
          : _pattern.copyWith(breakStartMinuteOfDay: minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final issue = _pattern.problem;
    final breakOptions = <int>{
      for (var minute = 15; minute <= 180; minute += 15) minute,
      _pattern.breakMinutes,
    }.toList()..sort();
    final workedOptions = <int>[
      for (var minute = 60; minute <= 12 * 60; minute += 30) minute,
    ];
    if (!workedOptions.contains(_pattern.workedMinutes)) {
      workedOptions.add(_pattern.workedMinutes);
      workedOptions.sort();
    }

    return AlertDialog(
      title: Text('Preencher ${widget.dayCount} dias'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.65,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Serão adicionadas quatro batidas em cada dia útil vazio '
                'anterior a hoje. Dias com registros não serão alterados.',
              ),
              const SizedBox(height: HfSpace.md),
              _FillTimeRow(
                label: 'Entrada',
                value: formatFillMinute(_pattern.startMinuteOfDay),
                onTap: () => _pickTime(isStart: true),
              ),
              _FillTimeRow(
                label: 'Início do almoço',
                value: formatFillMinute(_pattern.breakStartMinuteOfDay),
                onTap: () => _pickTime(isStart: false),
              ),
              _FillDropdownRow(
                label: 'Horas trabalhadas',
                value: _pattern.workedMinutes,
                options: workedOptions,
                onChanged: (value) => setState(
                  () => _pattern = _pattern.copyWith(workedMinutes: value),
                ),
              ),
              _FillDropdownRow(
                label: 'Duração do almoço',
                value: _pattern.breakMinutes,
                options: breakOptions,
                onChanged: (value) => setState(
                  () => _pattern = _pattern.copyWith(breakMinutes: value),
                ),
              ),
              const SizedBox(height: HfSpace.sm),
              Text(
                'Saída do almoço às '
                '${formatFillMinute(_pattern.breakEndMinuteOfDay)}. '
                'Saída final às ${formatFillMinute(_pattern.endMinuteOfDay)}.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (issue != null) ...[
                const SizedBox(height: HfSpace.sm),
                HfNotice(tone: HfNoticeTone.error, message: issue),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _pattern.isValid
              ? () => Navigator.of(context).pop(_pattern)
              : null,
          child: Text('Aplicar em ${widget.dayCount} dias'),
        ),
      ],
    );
  }
}

class _FillTimeRow extends StatelessWidget {
  const _FillTimeRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: HfSpace.xs),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label),
        const SizedBox(height: HfSpace.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(onPressed: onTap, child: Text(value)),
        ),
      ],
    ),
  );
}

class _FillDropdownRow extends StatelessWidget {
  const _FillDropdownRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final int value;
  final List<int> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: HfSpace.xs),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label),
        DropdownButton<int>(
          value: value,
          isExpanded: true,
          items: [
            for (final option in options)
              DropdownMenuItem<int>(
                value: option,
                child: Text(formatFillDuration(option)),
              ),
          ],
          onChanged: (selected) {
            if (selected != null) onChanged(selected);
          },
        ),
      ],
    ),
  );
}
