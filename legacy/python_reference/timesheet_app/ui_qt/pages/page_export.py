"""Resumo final e exportação do timesheet por mês."""

from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys

from PySide6.QtCore import Qt, Signal
from PySide6.QtWidgets import QFileDialog, QHBoxLayout, QLabel, QPushButton, QVBoxLayout, QWidget

from ...audit_log import get_logger
from ...automation import analyze_records, group_records_by_month, preferred_output_directory
from ...constants import default_filename_for_month, mes_ano_pt
from ...excel.generator import generate_timesheet_batch, generate_timesheet_xlsx
from ...models import AppSettings, TimesheetRecord
from ..dialogs import MessageDialog
from ..theme import COLORS, SPACE, scaled
from ..widgets import DetailRow, MetricCard, PageHeader, SectionCard, StateBanner, make_line_icon

_log = get_logger("excel")


class ExportPage(QWidget):
    status_message = Signal(str)
    output_directory_used = Signal(str)
    back_requested = Signal()

    def __init__(self, get_settings, get_records, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._get_settings = get_settings
        self._get_records = get_records
        self._last_outputs: list[Path] = []
        self._compact = False

        root = QVBoxLayout(self)
        root.setContentsMargins(scaled(SPACE["xl"]), scaled(SPACE["lg"]),
                                scaled(SPACE["xl"]), scaled(SPACE["lg"]))
        root.setSpacing(scaled(SPACE["md"]))

        header = PageHeader(
            "3 · Excel",
            "Feche o mês em um clique",
            "Revise o resumo, confirme o destino e gere os arquivos. Nenhum arquivo existente é sobrescrito.",
        )
        root.addWidget(header)

        self.readiness = StateBanner("Preparando resumo", "Analisando os registros da sessão…", "info", "info")
        root.addWidget(self.readiness)

        metrics = QHBoxLayout()
        metrics.setSpacing(scaled(SPACE["sm"]))
        self.metric_period = MetricCard("Período", "—", kind="accent")
        self.metric_days = MetricCard("Dias aprovados", "0", kind="success")
        self.metric_total = MetricCard("Total de horas", "0:00", kind="accent")
        self.metric_files = MetricCard("Arquivos", "0")
        for metric in (self.metric_period, self.metric_days, self.metric_total, self.metric_files):
            metrics.addWidget(metric, 1)
        root.addLayout(metrics)

        details_row = QHBoxLayout()
        details_row.setSpacing(scaled(SPACE["md"]))

        profile_card = SectionCard("Conteúdo do timesheet", "Dados que serão escritos no cabeçalho e nas linhas.")
        profile_body = profile_card.body()
        self.row_collaborator = DetailRow("Colaborador")
        self.row_role = DetailRow("Cargo")
        self.row_mode = DetailRow("Modalidade")
        self.row_activity = DetailRow("Atividade")
        for row in (self.row_collaborator, self.row_role, self.row_mode, self.row_activity):
            profile_body.addWidget(row)
        profile_body.addStretch(1)
        details_row.addWidget(profile_card, 1)

        destination_card = SectionCard("Saída", "Nomes são definidos por mês e recebem versão se já existirem.")
        destination_body = destination_card.body()
        path_title = QLabel("PASTA")
        path_title.setObjectName("Dim")
        self.destination_path = QLabel("—")
        self.destination_path.setObjectName("Mono")
        self.destination_path.setWordWrap(True)
        self.destination_path.setTextInteractionFlags(Qt.TextSelectableByMouse)
        files_title = QLabel("ARQUIVOS PREVISTOS")
        files_title.setObjectName("Dim")
        self.files_preview = QLabel("—")
        self.files_preview.setObjectName("Body")
        self.files_preview.setWordWrap(True)
        destination_body.addWidget(path_title)
        destination_body.addWidget(self.destination_path)
        destination_body.addSpacing(scaled(SPACE["sm"]))
        destination_body.addWidget(files_title)
        destination_body.addWidget(self.files_preview)
        destination_body.addStretch(1)
        details_row.addWidget(destination_card, 1)
        root.addLayout(details_row, 1)

        self.warning_card = SectionCard("Observações automáticas")
        self.warning_label = QLabel("")
        self.warning_label.setObjectName("Body")
        self.warning_label.setWordWrap(True)
        self.warning_card.body().addWidget(self.warning_label)
        root.addWidget(self.warning_card)

        self.success_banner = StateBanner("", "", "success", "check")
        self.success_banner.hide()
        success_actions = QHBoxLayout()
        success_actions.addStretch(1)
        self.btn_open_folder = QPushButton("Abrir pasta")
        self.btn_open_folder.setObjectName("ToolbarButton")
        self.btn_open_folder.setIcon(make_line_icon("folder"))
        self.btn_open_folder.clicked.connect(self._open_folder)
        success_actions.addWidget(self.btn_open_folder)
        root.addWidget(self.success_banner)
        root.addLayout(success_actions)
        self.btn_open_folder.hide()

        footer = QHBoxLayout()
        self.btn_back = QPushButton("Voltar à revisão")
        self.btn_back.setObjectName("Ghost")
        self.btn_back.setIcon(make_line_icon("chevron-left"))
        self.btn_back.clicked.connect(self.back_requested.emit)
        footer.addWidget(self.btn_back)
        footer.addStretch(1)
        self.btn_save_as = QPushButton("Escolher nome…")
        self.btn_save_as.setObjectName("Ghost")
        self.btn_save_as.clicked.connect(self._generate_save_as)
        footer.addWidget(self.btn_save_as)
        self.btn_generate = QPushButton("Gerar Excel")
        self.btn_generate.setObjectName("Accent")
        self.btn_generate.setIcon(make_line_icon("export", COLORS["on_accent"]))
        self.btn_generate.clicked.connect(self._generate_auto)
        footer.addWidget(self.btn_generate)
        root.addLayout(footer)

    def set_compact_mode(self, compact: bool) -> None:
        self._compact = compact
        self.metric_files.setVisible(not compact)

    def refresh(self) -> None:
        self.success_banner.hide()
        self.btn_open_folder.hide()
        settings: AppSettings = self._get_settings()
        records: list[TimesheetRecord] = self._get_records()
        report = analyze_records(records)
        grouped = group_records_by_month(records)

        if len(grouped) == 1:
            month_records = next(iter(grouped.values()))
            period = mes_ano_pt(month_records[0].data).title()
        elif len(grouped) > 1:
            period = f"{len(grouped)} meses"
        else:
            period = "—"
        self.metric_period.set_value(period)
        self.metric_days.set_value(str(report.included_count))
        self.metric_total.set_value(report.total_hhmm)
        self.metric_files.set_value(str(len(grouped)))

        self.row_collaborator.set_value(settings.profile.colaborador)
        self.row_role.set_value(settings.profile.cargo)
        self.row_mode.set_value(settings.profile.modalidade)
        self.row_activity.set_value(settings.profile.atividade_padrao or "Em branco")

        output_dir = preferred_output_directory(settings.automation)
        self.destination_path.setText(str(output_dir))
        predicted: list[str] = []
        for month_records in grouped.values():
            if month_records:
                predicted.append(default_filename_for_month(month_records[0].data))
        self.files_preview.setText("\n".join(f"• {name}" for name in predicted) if predicted else "Nenhum arquivo")

        warnings: list[str] = []
        if not report.included_count:
            warnings.append("Nenhum registro trabalhado está aprovado para inclusão.")
        if report.review_count:
            warnings.append(f"{report.review_count} registro(s) ainda pedem decisão na revisão.")
        if report.missing_weekdays:
            preview = ", ".join(item.strftime("%d/%m") for item in report.missing_weekdays[:10])
            if len(report.missing_weekdays) > 10:
                preview += "…"
            warnings.append(f"Possíveis dias úteis ausentes: {preview}.")
        if report.suspicious_dates:
            warnings.append("Horas acima de 16h: " + ", ".join(item.strftime("%d/%m") for item in report.suspicious_dates) + ".")
        if len(grouped) > 1:
            warnings.append(f"A sessão contém {len(grouped)} meses; será gerado um arquivo independente para cada mês.")

        can_export = report.included_count > 0 and report.review_count == 0
        if can_export:
            self.readiness.set_state(
                "Tudo pronto para gerar",
                f"{report.included_count} dia(s) · {report.total_hhmm} · {len(grouped)} arquivo(s).",
                "success",
                "check",
            )
        elif report.review_count:
            self.readiness.set_state(
                "A revisão ainda não terminou",
                f"Volte e resolva {report.review_count} pendência(s) antes de gerar o arquivo final.",
                "warning",
                "warning",
            )
        else:
            self.readiness.set_state(
                "Nada para exportar",
                "Aprove pelo menos um dia trabalhado na etapa Revisão.",
                "warning",
                "warning",
            )

        self.warning_card.setVisible(bool(warnings))
        self.warning_label.setText("\n".join(f"• {warning}" for warning in warnings))
        self.warning_label.setStyleSheet(f"color:{COLORS['warning']};")

        self.btn_generate.setEnabled(can_export)
        self.btn_generate.setText(f"Gerar {len(grouped)} arquivos" if len(grouped) > 1 else "Gerar Excel")
        self.btn_save_as.setEnabled(can_export and len(grouped) == 1)
        self.btn_generate.setToolTip(
            "Gera na pasta padrão sem sobrescrever arquivos existentes."
            if can_export else "Conclua a revisão antes de exportar."
        )
        self.btn_save_as.setToolTip(
            "Escolher manualmente nome e pasta do arquivo."
            if len(grouped) <= 1 else "Disponível apenas quando a sessão contém um único mês."
        )

    def _generate_auto(self) -> None:
        settings: AppSettings = self._get_settings()
        records: list[TimesheetRecord] = self._get_records()
        output_dir = preferred_output_directory(settings.automation)
        _log.info("Exportação automática iniciada → %s", output_dir)
        self.btn_generate.setEnabled(False)
        self.btn_generate.setText("Gerando…")
        try:
            results = generate_timesheet_batch(records, output_dir, profile=settings.profile)
        except Exception as exc:  # noqa: BLE001
            _log.error("Falha ao gerar Excel automaticamente: %s", exc, exc_info=True)
            MessageDialog.show_message(self, "Não foi possível gerar o Excel", str(exc), "error")
            self.refresh()
            return
        self._finish_generation([Path(result.output_path) for result in results], settings)
        self.refresh_success_state()

    def _generate_save_as(self) -> None:
        settings: AppSettings = self._get_settings()
        records: list[TimesheetRecord] = self._get_records()
        grouped = group_records_by_month(records)
        if not grouped:
            return
        if len(grouped) > 1:
            MessageDialog.show_message(
                self,
                "Mais de um mês",
                "Use a geração automática para criar um arquivo separado por mês.",
                "warning",
            )
            return
        month_records = next(iter(grouped.values()))
        initial_dir = preferred_output_directory(settings.automation)
        try:
            initial_dir.mkdir(parents=True, exist_ok=True)
        except OSError as exc:
            _log.error("Falha ao preparar pasta de saída: %s", exc, exc_info=True)
            MessageDialog.show_message(self, "Pasta de saída inválida", str(exc), "error")
            return
        suggested = initial_dir / default_filename_for_month(month_records[0].data)
        output, _ = QFileDialog.getSaveFileName(self, "Salvar timesheet", str(suggested), "Excel (*.xlsx)")
        if not output:
            return
        if not output.lower().endswith(".xlsx"):
            output += ".xlsx"
        try:
            result = generate_timesheet_xlsx(records, output, profile=settings.profile)
        except Exception as exc:  # noqa: BLE001
            _log.error("Falha ao gerar Excel: %s", exc, exc_info=True)
            MessageDialog.show_message(self, "Não foi possível gerar o Excel", str(exc), "error")
            return
        self._finish_generation([Path(result.output_path)], settings)
        self.refresh_success_state()

    def _finish_generation(self, outputs: list[Path], settings: AppSettings) -> None:
        if not outputs:
            return
        self._last_outputs = outputs
        self.output_directory_used.emit(str(outputs[0].parent))
        self.status_message.emit(f"{len(outputs)} Excel(s) gerado(s) em {outputs[0].parent}")
        _log.info("Exportação concluída: %s", ", ".join(str(path) for path in outputs))
        if settings.automation.open_output_folder:
            self._open_folder()

    def refresh_success_state(self) -> None:
        """Mostra resultado sem apagar o resumo recém-validado."""
        if not self._last_outputs:
            return
        preview = " · ".join(path.name for path in self._last_outputs[:3])
        if len(self._last_outputs) > 3:
            preview += f" · +{len(self._last_outputs) - 3}"
        self.success_banner.set_state(
            f"{len(self._last_outputs)} arquivo(s) gerado(s)",
            preview,
            "success",
            "check",
        )
        self.success_banner.show()
        self.btn_open_folder.show()
        self.btn_generate.setEnabled(True)
        self.btn_generate.setText("Gerar novamente")

    def _open_folder(self) -> None:
        if not self._last_outputs:
            return
        target = self._last_outputs[0]
        folder = target.parent
        try:
            if sys.platform.startswith("win"):
                from ...subprocess_utils import subprocess_no_window_kwargs

                subprocess.run(["explorer", "/select,", str(target)], **subprocess_no_window_kwargs())
            elif sys.platform == "darwin":
                subprocess.run(["open", "-R", str(target)], check=False)
            else:
                subprocess.run(["xdg-open", str(folder)], check=False)
        except Exception as exc:  # noqa: BLE001
            _log.warning("Não foi possível abrir a pasta de saída: %s", exc)
            if hasattr(os, "startfile"):
                try:
                    os.startfile(folder)  # type: ignore[attr-defined]
                except OSError as fallback_exc:
                    _log.warning("Fallback para abrir pasta também falhou: %s", fallback_exc)
