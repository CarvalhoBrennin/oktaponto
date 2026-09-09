from __future__ import annotations

from datetime import date

DIAS_SEMANA_PT = {
    0: "Segunda-feira",
    1: "Terça-feira",
    2: "Quarta-feira",
    3: "Quinta-feira",
    4: "Sexta-feira",
    5: "Sábado",
    6: "Domingo",
}

MESES_PT = {
    1: "JANEIRO",
    2: "FEVEREIRO",
    3: "MARÇO",
    4: "ABRIL",
    5: "MAIO",
    6: "JUNHO",
    7: "JULHO",
    8: "AGOSTO",
    9: "SETEMBRO",
    10: "OUTUBRO",
    11: "NOVEMBRO",
    12: "DEZEMBRO",
}

MESES_PT_SLUG = {
    1: "janeiro",
    2: "fevereiro",
    3: "marco",
    4: "abril",
    5: "maio",
    6: "junho",
    7: "julho",
    8: "agosto",
    9: "setembro",
    10: "outubro",
    11: "novembro",
    12: "dezembro",
}


def dia_semana_pt(d: date) -> str:
    return DIAS_SEMANA_PT[d.weekday()]


def mes_ano_pt(d: date) -> str:
    return f"{MESES_PT[d.month]} {d.year}"


def month_bounds(d: date) -> tuple[date, date]:
    if d.month == 12:
        next_month = date(d.year + 1, 1, 1)
    else:
        next_month = date(d.year, d.month + 1, 1)
    last_day = next_month.toordinal() - 1
    return date(d.year, d.month, 1), date.fromordinal(last_day)


def default_filename_for_month(d: date) -> str:
    return f"timesheet_{MESES_PT_SLUG[d.month]}_{d.year}.xlsx"
