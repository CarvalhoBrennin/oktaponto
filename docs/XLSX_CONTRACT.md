# Contrato XLSX

O exporter Dart deve preservar o contrato executável de `legacy/python_reference/timesheet_app/excel/generator.py`.

- Worksheet `Planilha1`.
- Gridlines ocultas e freeze pane equivalente a `A7` (`rows: 6`).
- Colunas A:G com larguras 13, 18, 17, 25, 22, 22, 52.
- Merges: A1:G1, A2:B2, C2:G2, A3:B3, C3:G3, A4:B4, C4:G4, A(total):B(total), A(legenda):G(legenda).
- Fonte Segoe UI e paleta: 1F3864, 2E75B6, EEF4FB, FFFFFF, FFF2CC, 1E7145, C00000, C8D8EC.
- Datas como valores de data e formato `DD/MM/YYYY`.
- Duração como número Excel (`minutes / 1440.0`) e formato `[h]:mm`.
- Vermelho <8h, azul =8h, verde >8h.
- Sexta/sábado/domingo com fundo especial.
- Atividade do dia vence atividade padrão.
- Campos de usuário são sempre `TextCellValue`, inclusive quando começam com `=`.
- Controles XML ilegais são substituídos por espaço.
- Export falha fechado para dia incluído incoerente, duplicidade e >24h/dia.
- Nunca sobrescrever arquivo já existente.

`python scripts/xlsx_contract.py arquivo.xlsx` normaliza o workbook em JSON; `compare_xlsx_contract.py` compara semanticamente.

## Extrato de horas extras

O extrato é um segundo arquivo XLSX, separado do timesheet. Ele não adiciona
abas nem colunas ao contrato acima.

- Worksheet `Horas extras`, com linhas congeladas até o cabeçalho.
- Competência e período exibidos no topo.
- Resumo com total de horas extras e dias com saldo positivo.
- Uma linha por dia completo e consistente, com as quatro batidas, horas
  trabalhadas, meta diária e horas extras derivadas.
- Duração armazenada como valor numérico do Excel e formatada como `[h]:mm`.
- Dias incompletos ficam fora do total e são contados no aviso do extrato.
- Batidas inconsistentes, dias duplicados ou resumos desatualizados bloqueiam
  a exportação.
- O relatório apura somente minutos acima da meta diária configurada; não
  estima pagamento em dinheiro nem altera o banco de horas ou o timesheet.
- Nunca sobrescrever arquivo já existente.
