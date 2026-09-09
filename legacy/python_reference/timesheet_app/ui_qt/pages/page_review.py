"""Revisão dos registros: tabela enxuta + inspector contextual."""

from __future__ import annotations

from pathlib import Path

from PySide6.QtCore import QAbstractTableModel, QModelIndex, QRect, QSize, QSortFilterProxyModel, Qt, Signal
from PySide6.QtGui import QColor, QKeySequence, QPainter, QPen, QShortcut
from PySide6.QtWidgets import (
    QAbstractItemView,
    QButtonGroup,
    QHBoxLayout,
    QHeaderView,
    QLabel,
    QLineEdit,
    QPushButton,
    QSplitter,
    QStackedWidget,
    QStyle,
    QStyledItemDelegate,
    QTableView,
    QVBoxLayout,
    QWidget,
)

from ...automation import analyze_records, apply_include_decision, is_review_exception
from ...models import AppSettings, TimesheetRecord
from ...parser.banco_horas_parser import consolidate_records
from ..dialogs import MessageDialog, RecordDialog, open_image_path
from ..theme import COLORS, SPACE, scaled
from ..widgets import (
    DetailRow,
    EmptyState,
    MetricPill,
    PageHeader,
    SectionCard,
    StateBanner,
    StatusChip,
    chip_label_for,
    chip_style_for,
    make_line_icon,
)

_HEADERS = ["Incluir", "Data", "Dia", "Horas", "Status", "Atividade"]


class RecordsTableModel(QAbstractTableModel):
    """Modelo de tabela ligado diretamente à lista consolidada da página."""

    def __init__(self, records: list[TimesheetRecord]) -> None:
        super().__init__()
        self._records = records

    def set_records(self, records: list[TimesheetRecord]) -> None:
        self.beginResetModel()
        self._records = records
        self.endResetModel()

    def records(self) -> list[TimesheetRecord]:
        return self._records

    def record_at(self, row: int) -> TimesheetRecord:
        return self._records[row]

    def rowCount(self, parent: QModelIndex = QModelIndex()) -> int:  # noqa: N802
        return 0 if parent.isValid() else len(self._records)

    def columnCount(self, parent: QModelIndex = QModelIndex()) -> int:  # noqa: N802
        return len(_HEADERS)

    def headerData(self, section: int, orientation: Qt.Orientation, role: int = Qt.DisplayRole):  # noqa: N802
        if orientation == Qt.Horizontal and role == Qt.DisplayRole:
            return _HEADERS[section]
        return None

    def flags(self, index: QModelIndex) -> Qt.ItemFlags:
        if not index.isValid():
            return Qt.NoItemFlags
        flags = Qt.ItemIsEnabled | Qt.ItemIsSelectable
        if index.column() == 0:
            flags |= Qt.ItemIsUserCheckable
        return flags

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole):
        if not index.isValid():
            return None
        record = self._records[index.row()]
        col = index.column()

        if role == Qt.CheckStateRole and col == 0:
            return Qt.Checked if record.include else Qt.Unchecked

        if role == Qt.DisplayRole:
            if col == 0:
                return None
            if col == 1:
                return record.data.strftime("%d/%m/%Y")
            if col == 2:
                return record.dia_semana
            if col == 3:
                return record.worked_hhmm or "—"
            if col == 4:
                return chip_label_for(record.status)
            if col == 5:
                return record.atividade or "Atividade padrão"

        if role == Qt.UserRole:
            if col == 0:
                return 1 if record.include else 0
            if col == 1:
                return record.data.toordinal()
            if col == 2:
                return record.data.weekday()
            if col == 3:
                return record.worked_minutes if isinstance(record.worked_minutes, int) else -1
            if col == 4:
                return {"revisar": 0, "ok": 1, "editado": 2, "ignorado": 3}.get(record.status, 4)
            if col == 5:
                return (record.atividade or "").casefold()

        if role == Qt.ToolTipRole:
            if col == 0:
                return "Marcar/desmarcar registra uma decisão manual."
            if col == 4:
                return "Status interno: " + record.status
            if col == 5:
                return record.atividade or "Sem atividade específica; será usada a atividade padrão do perfil."

        if role == Qt.TextAlignmentRole and col in (1, 2, 3, 4):
            return int(Qt.AlignCenter)

        if role == Qt.ForegroundRole and col == 4:
            color, _ = chip_style_for(record.status)
            return QColor(color)
        if role == Qt.ForegroundRole and not record.include:
            return QColor(COLORS["text_dim"])
        return None

    def setData(self, index: QModelIndex, value, role: int = Qt.EditRole) -> bool:  # noqa: N802
        if index.column() == 0 and role == Qt.CheckStateRole:
            record = self._records[index.row()]
            include = value == Qt.Checked.value or value == Qt.Checked
            apply_include_decision(record, include)
            self.dataChanged.emit(self.index(index.row(), 0), self.index(index.row(), self.columnCount() - 1))
            return True
        return False


class RecordsFilterProxyModel(QSortFilterProxyModel):
    """Filtro e ordenação do conjunto sem modificar a consolidação original."""

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.mode = "issues"
        self.query = ""
        self.setDynamicSortFilter(True)
        self.setSortRole(Qt.UserRole)

    def set_mode(self, mode: str) -> None:
        self.mode = mode
        self.invalidateFilter()

    def set_query(self, query: str) -> None:
        self.query = query.strip().casefold()
        self.invalidateFilter()

    def filterAcceptsRow(self, source_row: int, source_parent: QModelIndex) -> bool:  # noqa: N802
        model = self.sourceModel()
        if not isinstance(model, RecordsTableModel):
            return True
        record = model.record_at(source_row)
        if self.mode == "issues" and not is_review_exception(record):
            return False
        if self.mode == "included" and not record.eligible_for_excel():
            return False
        if self.mode == "ignored" and record.status != "ignorado":
            return False
        if self.mode == "edited" and record.status != "editado":
            return False
        if self.query:
            haystack = " ".join((
                record.data.strftime("%d/%m/%Y"),
                record.dia_semana,
                record.worked_hhmm,
                record.status,
                record.atividade,
                " ".join(record.notes),
                record.source_file,
            )).casefold()
            if self.query not in haystack:
                return False
        return True

    def record_at(self, row: int) -> TimesheetRecord:
        source_index = self.mapToSource(self.index(row, 0))
        model = self.sourceModel()
        assert isinstance(model, RecordsTableModel)
        return model.record_at(source_index.row())


class ReviewPage(QWidget):
    advance_requested = Signal()
    status_message = Signal(str)
    records_changed = Signal()

    def __init__(self, get_settings=None, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._get_settings = get_settings or (lambda: AppSettings())
        self._records: list[TimesheetRecord] = []
        self._compact = False
        self.model = RecordsTableModel(self._records)
        self.proxy = RecordsFilterProxyModel(self)
        self.proxy.setSourceModel(self.model)

        root = QVBoxLayout(self)
        root.setContentsMargins(scaled(SPACE["xl"]), scaled(SPACE["lg"]),
                                scaled(SPACE["xl"]), scaled(SPACE["lg"]))
        root.setSpacing(scaled(SPACE["md"]))

        header = PageHeader(
            "2 · Revisão",
            "Confira só o que importa",
            "Pendências ficam em evidência. Abra um dia para ver fonte, confiança e observações sem poluir a tabela.",
        )
        self.metric_total = MetricPill("0 registros")
        self.metric_included = MetricPill("0 aprovados", "success")
        self.metric_hours = MetricPill("0:00", "accent")
        header.actions.addWidget(self.metric_total)
        header.actions.addWidget(self.metric_included)
        header.actions.addWidget(self.metric_hours)
        root.addWidget(header)

        self.validation_banner = StateBanner(
            "Aguardando registros",
            "Importe uma fonte ou adicione uma linha manual para começar.",
            "info",
            "info",
        )
        root.addWidget(self.validation_banner)

        self.content_stack = QStackedWidget()
        self.empty = EmptyState(
            "Nada para revisar ainda",
            "Volte à Entrada para importar dados ou adicione um registro manual aqui.",
            "check",
        )
        empty_layout = self.empty.layout()
        if isinstance(empty_layout, QVBoxLayout):
            btn_empty_add = QPushButton("Adicionar registro manual")
            btn_empty_add.setObjectName("Accent")
            btn_empty_add.setIcon(make_line_icon("plus", COLORS["on_accent"]))
            btn_empty_add.clicked.connect(self._add_record)
            empty_layout.insertWidget(max(0, empty_layout.count() - 1), btn_empty_add, 0, Qt.AlignHCenter)
        self.content_stack.addWidget(self.empty)

        self.splitter = QSplitter(Qt.Horizontal)
        self.splitter.setChildrenCollapsible(False)
        self.splitter.setHandleWidth(scaled(8))

        table_card = SectionCard()
        table_body = table_card.body()
        filters = QHBoxLayout()
        filters.setSpacing(scaled(SPACE["xs"]))
        self.filter_group = QButtonGroup(self)
        self.filter_group.setExclusive(True)
        self._filter_buttons: dict[str, QPushButton] = {}
        for label, mode in (
            ("Pendências", "issues"),
            ("Todos", "all"),
            ("Aprovados", "included"),
            ("Ignorados", "ignored"),
            ("Editados", "edited"),
        ):
            button = QPushButton(label)
            button.setObjectName("FilterChip")
            button.setCheckable(True)
            button.clicked.connect(lambda _checked=False, m=mode: self._set_filter(m))
            self.filter_group.addButton(button)
            self._filter_buttons[mode] = button
            filters.addWidget(button)
        self._filter_buttons["issues"].setChecked(True)
        filters.addStretch(1)

        self.search_edit = QLineEdit()
        self.search_edit.setPlaceholderText("Buscar dia, atividade, nota ou fonte…")
        self.search_edit.setClearButtonEnabled(True)
        self.search_edit.setMaximumWidth(scaled(300))
        self.search_edit.textChanged.connect(self.proxy.set_query)
        filters.addWidget(self.search_edit)
        btn_add = QPushButton("Novo")
        btn_add.setObjectName("ToolbarButton")
        btn_add.setIcon(make_line_icon("plus"))
        btn_add.setToolTip("Adicionar registro manual")
        btn_add.clicked.connect(self._add_record)
        filters.addWidget(btn_add)
        table_body.addLayout(filters)

        self.table = QTableView()
        self.table.setObjectName("RecordsTable")
        self.table.setModel(self.proxy)
        self.table.setItemDelegateForColumn(4, StatusChipDelegate(self.table))
        self.table.setAlternatingRowColors(True)
        self.table.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.table.setSelectionMode(QAbstractItemView.ExtendedSelection)
        self.table.verticalHeader().setVisible(False)
        self.table.verticalHeader().setDefaultSectionSize(scaled(40))
        self.table.setEditTriggers(QAbstractItemView.NoEditTriggers)
        self.table.setWordWrap(False)
        self.table.setSortingEnabled(True)
        self.table.sortByColumn(1, Qt.AscendingOrder)
        self.table.doubleClicked.connect(self._on_double_click)
        self.model.dataChanged.connect(self._on_model_data_changed)
        self.table.selectionModel().selectionChanged.connect(self._update_inspector)
        self.table.setAccessibleName("Tabela de registros para revisão")
        self.search_edit.setAccessibleName("Buscar registros")
        self._install_table_shortcuts()

        table_header = self.table.horizontalHeader()
        table_header.setStretchLastSection(True)
        table_header.setSectionResizeMode(5, QHeaderView.Stretch)
        for col in (0, 1, 2, 3, 4):
            table_header.setSectionResizeMode(col, QHeaderView.ResizeToContents)
        table_body.addWidget(self.table, 1)

        bulk = QHBoxLayout()
        bulk.setSpacing(scaled(SPACE["xs"]))
        self.selection_label = QLabel("Selecione um ou mais dias")
        self.selection_label.setObjectName("Dim")
        bulk.addWidget(self.selection_label)
        bulk.addStretch(1)
        self.btn_open = self._bulk_button("Ver print", "eye", self._open_source_image)
        self.btn_edit = self._bulk_button("Editar", "edit", self._edit_selected)
        self.btn_include = self._bulk_button("Aprovar", "check", self._include_selected)
        self.btn_ignore = self._bulk_button("Ignorar", "close", self._ignore_selected)
        self.btn_delete = self._bulk_button("Excluir", "trash", self._delete_selected, danger=True)
        self.btn_edit.setToolTip("Editar o registro selecionado · Enter")
        self.btn_include.setToolTip("Aprovar seleção · Ctrl+Enter")
        self.btn_ignore.setToolTip("Ignorar seleção · Ctrl+Backspace")
        self.btn_delete.setToolTip("Excluir seleção · Delete")
        self.btn_open.setToolTip("Abrir o print associado ao registro")
        for button in (self.btn_open, self.btn_edit, self.btn_include, self.btn_ignore, self.btn_delete):
            bulk.addWidget(button)
        table_body.addLayout(bulk)
        self.splitter.addWidget(table_card)

        self.inspector = self._build_inspector()
        self.splitter.addWidget(self.inspector)
        self.splitter.setStretchFactor(0, 1)
        self.splitter.setStretchFactor(1, 0)
        self.splitter.setSizes([scaled(900), scaled(300)])
        self.content_stack.addWidget(self.splitter)
        root.addWidget(self.content_stack, 1)

        footer = QHBoxLayout()
        self.btn_validate = QPushButton("Executar validação")
        self.btn_validate.setObjectName("Ghost")
        self.btn_validate.setIcon(make_line_icon("warning"))
        self.btn_validate.clicked.connect(self._validate)
        footer.addWidget(self.btn_validate)
        footer.addStretch(1)
        self.btn_advance = QPushButton("Continuar para Excel")
        self.btn_advance.setObjectName("Accent")
        self.btn_advance.setIcon(make_line_icon("chevron-right", COLORS["on_accent"]))
        self.btn_advance.clicked.connect(self.advance_requested.emit)
        footer.addWidget(self.btn_advance)
        root.addLayout(footer)

        self._update_summary()


    def _install_table_shortcuts(self) -> None:
        self._table_shortcuts: list[QShortcut] = []
        for sequence, callback in (
            ("Return", self._edit_selected),
            ("Enter", self._edit_selected),
            ("Delete", self._delete_selected),
            ("Ctrl+Return", self._include_selected),
            ("Ctrl+Backspace", self._ignore_selected),
        ):
            shortcut = QShortcut(QKeySequence(sequence), self.table)
            shortcut.setContext(Qt.ShortcutContext.WidgetWithChildrenShortcut)
            shortcut.activated.connect(callback)
            self._table_shortcuts.append(shortcut)

    # ------------------------------------------------------------------
    # Inspector
    # ------------------------------------------------------------------

    def _build_inspector(self) -> SectionCard:
        card = SectionCard("Detalhes", "Selecione um registro para inspecionar origem e decisão.")
        card.setObjectName("Inspector")
        card.setMinimumWidth(scaled(260))
        card.setMaximumWidth(scaled(360))
        body = card.body()

        self.inspector_stack = QStackedWidget()
        summary = QWidget()
        summary_layout = QVBoxLayout(summary)
        summary_layout.setContentsMargins(0, 0, 0, 0)
        summary_layout.setSpacing(scaled(SPACE["sm"]))
        self.inspector_summary_title = QLabel("Nenhum dia selecionado")
        self.inspector_summary_title.setObjectName("H2")
        self.inspector_summary_text = QLabel("Selecione uma linha para ver todos os detalhes e ações rápidas.")
        self.inspector_summary_text.setObjectName("Subtle")
        self.inspector_summary_text.setWordWrap(True)
        summary_layout.addWidget(self.inspector_summary_title)
        summary_layout.addWidget(self.inspector_summary_text)
        summary_layout.addStretch(1)
        self.inspector_stack.addWidget(summary)

        detail = QWidget()
        detail_layout = QVBoxLayout(detail)
        detail_layout.setContentsMargins(0, 0, 0, 0)
        detail_layout.setSpacing(scaled(SPACE["sm"]))
        top = QHBoxLayout()
        self.detail_date = QLabel("-")
        self.detail_date.setObjectName("H1")
        self.detail_status = StatusChip("ok")
        top.addWidget(self.detail_date, 1)
        top.addWidget(self.detail_status, 0, Qt.AlignTop)
        detail_layout.addLayout(top)
        self.detail_day = DetailRow("Dia", "-")
        self.detail_hours = DetailRow("Horas", "-")
        self.detail_activity = DetailRow("Atividade", "-")
        self.detail_confidence = DetailRow("Confiança", "-")
        self.detail_source = DetailRow("Fonte", "-")
        for row in (self.detail_day, self.detail_hours, self.detail_activity, self.detail_confidence, self.detail_source):
            detail_layout.addWidget(row)
        notes_title = QLabel("Observações")
        notes_title.setObjectName("Dim")
        self.detail_notes = QLabel("-")
        self.detail_notes.setObjectName("Body")
        self.detail_notes.setWordWrap(True)
        self.detail_notes.setTextInteractionFlags(Qt.TextSelectableByMouse)
        detail_layout.addWidget(notes_title)
        detail_layout.addWidget(self.detail_notes)
        detail_layout.addStretch(1)

        detail_actions = QHBoxLayout()
        self.inspect_edit = QPushButton("Editar")
        self.inspect_edit.setObjectName("ToolbarButton")
        self.inspect_edit.setIcon(make_line_icon("edit"))
        self.inspect_edit.clicked.connect(self._edit_selected)
        self.inspect_open = QPushButton("Print")
        self.inspect_open.setObjectName("ToolbarButton")
        self.inspect_open.setIcon(make_line_icon("eye"))
        self.inspect_open.clicked.connect(self._open_source_image)
        detail_actions.addWidget(self.inspect_edit)
        detail_actions.addWidget(self.inspect_open)
        detail_layout.addLayout(detail_actions)
        self.inspector_stack.addWidget(detail)
        body.addWidget(self.inspector_stack, 1)
        return card

    def _bulk_button(self, text: str, icon: str, slot, danger: bool = False) -> QPushButton:
        button = QPushButton(text)
        button.setObjectName("Danger" if danger else "Ghost")
        button.setIcon(make_line_icon(icon))
        button.clicked.connect(slot)
        return button

    # ------------------------------------------------------------------
    # Public API / responsive
    # ------------------------------------------------------------------

    def set_records(self, records: list[TimesheetRecord], focus_issues: bool = False) -> None:
        self._records = records
        self.model.set_records(self._records)
        report = analyze_records(self._records)
        settings: AppSettings = self._get_settings()
        if focus_issues and settings.automation.focus_review_issues and report.review_count:
            self._set_filter("issues")
        elif self.proxy.mode == "issues" and not report.review_count:
            self._set_filter("all")
        self._update_summary()
        self._update_inspector()
        self.records_changed.emit()

    def records(self) -> list[TimesheetRecord]:
        return self._records

    def add_records(self, new_records: list[TimesheetRecord]) -> None:
        self.set_records(consolidate_records([*self._records, *new_records]))

    def focus_search(self) -> None:
        self.search_edit.setFocus(Qt.ShortcutFocusReason)
        self.search_edit.selectAll()

    def refresh_from_settings(self) -> None:
        self._update_summary()

    def set_compact_mode(self, compact: bool) -> None:
        self._compact = compact
        self.inspector.setVisible(not compact and bool(self._records))
        self.metric_total.setVisible(not compact)

    # ------------------------------------------------------------------
    # Filters / selection
    # ------------------------------------------------------------------

    def _set_filter(self, mode: str) -> None:
        if mode not in self._filter_buttons:
            mode = "all"
        self._filter_buttons[mode].setChecked(True)
        self.proxy.set_mode(mode)
        self._update_selection_label()

    def _selected_rows(self) -> list[int]:
        selection = self.table.selectionModel()
        if selection is None:
            return []
        proxy_rows = sorted({index.row() for index in selection.selectedRows()}) or \
            sorted({index.row() for index in self.table.selectedIndexes()})
        source_rows: set[int] = set()
        for row in proxy_rows:
            source = self.proxy.mapToSource(self.proxy.index(row, 0))
            if source.isValid():
                source_rows.add(source.row())
        return sorted(source_rows)

    def _update_selection_label(self) -> None:
        count = len(self._selected_rows())
        self.selection_label.setText(
            f"{count} registro(s) selecionado(s)" if count else f"{self.proxy.rowCount()} registro(s) neste filtro"
        )
        self.btn_open.setEnabled(count == 1)
        self.btn_edit.setEnabled(count == 1)
        self.btn_include.setEnabled(count > 0)
        self.btn_ignore.setEnabled(count > 0)
        self.btn_delete.setEnabled(count > 0)

    def _update_inspector(self, *_args) -> None:
        rows = self._selected_rows()
        self._update_selection_label()
        if len(rows) != 1:
            self.inspector_stack.setCurrentIndex(0)
            if len(rows) > 1:
                self.inspector_summary_title.setText(f"{len(rows)} dias selecionados")
                self.inspector_summary_text.setText("Use Aprovar/Ignorar para registrar uma decisão em lote.")
            else:
                self.inspector_summary_title.setText("Nenhum dia selecionado")
                self.inspector_summary_text.setText("Selecione uma linha para ver todos os detalhes e ações rápidas.")
            return
        record = self._records[rows[0]]
        self.inspector_stack.setCurrentIndex(1)
        self.detail_date.setText(record.data.strftime("%d/%m/%Y"))
        self.detail_status.set_status(record.status)
        self.detail_day.set_value(record.dia_semana)
        self.detail_hours.set_value(record.worked_hhmm or "Não reconhecido")
        self.detail_activity.set_value(record.atividade or self._get_settings().profile.atividade_padrao or "Não definida")
        confidence = f"{record.confidence:.0f}%" if isinstance(record.confidence, (int, float)) else "Não disponível"
        self.detail_confidence.set_value(confidence)
        self.detail_source.set_value(Path(record.source_file).name if record.source_file else "Manual")
        self.detail_notes.setText("\n".join(f"• {note}" for note in record.notes) if record.notes else "Sem observações.")
        self.inspect_open.setEnabled(bool(record.source_file and record.source_file not in {"manual", "texto_importado"}))

    # ------------------------------------------------------------------
    # Actions
    # ------------------------------------------------------------------

    def _on_model_data_changed(self, *_args) -> None:
        self._update_summary()
        self._update_inspector()
        self.records_changed.emit()

    def _add_record(self) -> None:
        record = RecordDialog.get_record(self, "Adicionar registro")
        if record:
            self.set_records(consolidate_records([*self._records, record]))

    def _on_double_click(self, _index) -> None:
        self._edit_selected()

    def _open_source_image(self) -> None:
        rows = self._selected_rows()
        if len(rows) != 1:
            if len(rows) > 1:
                self.status_message.emit("Selecione apenas um registro para abrir o print.")
            return
        record = self._records[rows[0]]
        if open_image_path(self, record.source_file):
            self.status_message.emit(f"Print aberto: {record.source_file}")

    def _edit_selected(self) -> None:
        rows = self._selected_rows()
        if len(rows) != 1:
            if len(rows) > 1:
                self.status_message.emit("Selecione apenas um registro para editar.")
            return
        row = rows[0]
        updated = RecordDialog.get_record(self, "Editar registro", self._records[row])
        if updated:
            remaining = [record for index, record in enumerate(self._records) if index != row]
            self.set_records(consolidate_records([*remaining, updated]))

    def _set_selected_include(self, include: bool) -> None:
        rows = self._selected_rows()
        if not rows:
            return
        for row in rows:
            apply_include_decision(self._records[row], include)
        self.model.set_records(self._records)
        self._update_summary()
        self._update_inspector()
        self.records_changed.emit()
        action = "aprovado(s)" if include else "ignorado(s)"
        self.status_message.emit(f"{len(rows)} registro(s) {action} manualmente.")

    def _include_selected(self) -> None:
        self._set_selected_include(True)

    def _ignore_selected(self) -> None:
        self._set_selected_include(False)

    def _delete_selected(self) -> None:
        rows = self._selected_rows()
        if not rows:
            return
        if not MessageDialog.ask(
            self,
            "Excluir registros",
            f"Excluir {len(rows)} registro(s) selecionado(s)? Esta ação não pode ser desfeita.",
            "Excluir",
            "Cancelar",
            "warning",
        ):
            return
        for row in reversed(rows):
            del self._records[row]
        self.model.set_records(self._records)
        self._update_summary()
        self._update_inspector()
        self.records_changed.emit()

    def _validate(self) -> None:
        report = analyze_records(self._records)
        issues: list[str] = []
        if not report.included_count:
            issues.append("Nenhum registro positivo está aprovado para inclusão.")
        if report.review_count:
            issues.append(f"Há {report.review_count} registro(s) que ainda pedem decisão.")
        if report.missing_weekdays:
            issues.append("Possíveis dias úteis ausentes: " + ", ".join(
                item.strftime("%d/%m/%Y") for item in report.missing_weekdays
            ))
        if report.suspicious_dates:
            issues.append("Horas acima de 16h: " + ", ".join(
                item.strftime("%d/%m/%Y") for item in report.suspicious_dates
            ))
        if len(report.months) > 1:
            issues.append(f"Há {len(report.months)} meses. A exportação criará um Excel por mês.")
        if issues:
            MessageDialog.show_message(self, "Validação da sessão", "\n\n".join(issues), "warning")
        else:
            MessageDialog.show_message(self, "Validação da sessão", "Tudo certo. A sessão está pronta para exportar.", "success")

    # ------------------------------------------------------------------
    # Summary state
    # ------------------------------------------------------------------

    def _update_summary(self) -> None:
        report = analyze_records(self._records)
        self.metric_total.setText(f"{report.record_count} registros")
        self.metric_included.setText(f"{report.included_count} aprovados")
        self.metric_hours.setText(report.total_hhmm)
        has_records = bool(self._records)
        self.content_stack.setCurrentIndex(1 if has_records else 0)
        self.inspector.setVisible(has_records and not self._compact)
        if has_records and self.proxy.mode == "issues" and report.review_count == 0:
            # Evita uma tela aparentemente vazia logo após resolver a última pendência.
            self._set_filter("all")

        if not has_records:
            self.validation_banner.set_state(
                "Aguardando registros",
                "Importe uma fonte na etapa Entrada ou adicione um registro manual.",
                "info",
                "info",
            )
        elif report.review_count:
            self.validation_banner.set_state(
                f"{report.review_count} pendência(s) precisam de decisão",
                "Aprove, ignore ou edite os itens destacados. O Excel só é liberado quando nenhuma pendência resta.",
                "warning",
                "warning",
            )
        elif not report.included_count:
            self.validation_banner.set_state(
                "Nenhum dia aprovado",
                "A sessão não tem horas válidas selecionadas para exportação.",
                "warning",
                "warning",
            )
        else:
            extra = ""
            if report.missing_weekdays:
                extra = f" · {len(report.missing_weekdays)} possível(is) dia(s) útil(eis) ausente(s) para conferir."
            self.validation_banner.set_state(
                "Revisão concluída",
                f"{report.included_count} dia(s) aprovado(s) · total {report.total_hhmm}{extra}",
                "success",
                "check",
            )

        self.btn_advance.setEnabled(report.included_count > 0 and report.review_count == 0)
        self.btn_advance.setToolTip(
            "Resolva ou ignore todas as pendências primeiro."
            if report.review_count else "Abrir a etapa de geração do Excel"
        )
        self.btn_validate.setEnabled(has_records)
        self._update_selection_label()
        self.status_message.emit(
            f"{report.record_count} registro(s) · {report.included_count} aprovado(s) · "
            f"{report.review_count} pendência(s) · {report.total_hhmm}"
        )


class StatusChipDelegate(QStyledItemDelegate):
    """Pinta o status como chip centralizado na tabela."""

    def paint(self, painter: QPainter, option, index) -> None:
        status = str(index.model().record_at(index.row()).status)
        label = chip_label_for(status)
        color, _ = chip_style_for(status)
        bg_color = QColor(color)
        bg_color.setAlpha(28)

        if option.state & QStyle.State_Selected:
            selected = QColor(COLORS["accent"])
            selected.setAlpha(28)
            painter.fillRect(option.rect, selected)

        rect = QRect(option.rect)
        chip_w = min(rect.width() - scaled(10), max(scaled(68), scaled(8) * len(label) + scaled(24)))
        chip_h = scaled(22)
        chip_rect = QRect(
            rect.x() + (rect.width() - chip_w) // 2,
            rect.y() + (rect.height() - chip_h) // 2,
            chip_w,
            chip_h,
        )
        painter.save()
        painter.setRenderHint(QPainter.Antialiasing, True)
        painter.setPen(QPen(QColor(color), 1))
        painter.setBrush(bg_color)
        painter.drawRoundedRect(chip_rect, scaled(11), scaled(11))
        painter.setPen(QColor(color))
        painter.drawText(chip_rect, int(Qt.AlignCenter), label)
        painter.restore()

    def sizeHint(self, option, index) -> QSize:  # noqa: N802
        return QSize(scaled(86), scaled(36))
