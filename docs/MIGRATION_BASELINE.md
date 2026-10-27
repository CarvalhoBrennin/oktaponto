# Migration baseline

Baseline executado em 2026-09-09.

- Python: 3.13.5
- Comando: `python -m unittest discover -s tests`
- Resultado: **142 testes executados, todos aprovados**.
- Dependências declaradas: Pillow >=10, openpyxl >=3.1, PySide6 >=6.6, pdfplumber >=0.11.
- Implementação original preservada integralmente em `legacy/python_reference/`.
- O código e os testes atuais são a especificação primária do XLSX.
- Divergência histórica: a planilha pessoal de referência, removida por privacidade, usava formato diário h:mm; o contrato atual exige [h]:mm, inclusive para 24:00 e totais acumulados.

## Ambiente desta implementação

O ambiente de execução usado para montar este pacote não possui Flutter/Dart instalados. Por isso, verificações locais `flutter analyze`, `flutter test` e builds móveis não puderam ser executadas aqui. O repositório inclui CI fixado em Flutter 3.47.2 para executar essas etapas em runner real.
