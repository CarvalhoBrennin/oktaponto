# Estrutura do projeto

```text
timesheet_banco_horas_desktop/
  main.py
  requirements.txt
  requirements-dev.txt
  pyproject.toml
  README.md
  timesheet_app/
    automation.py               # análise, agrupamento, decisões e reserva de saída
    file_utils.py               # escrita atômica de arquivos
    session_store.py            # autosave/restore da sessão
    constants.py
    models.py
    settings.py
    audit_log.py
    cli.py
    excel/
      generator.py
    ocr/
      engine.py
      preprocess.py
    parser/
      banco_horas_parser.py
      espelho_parser.py
      normalizer.py
      timeparse.py
    ui_qt/
      main_window.py              # shell, rail, navegação, sessão e atalhos
      dialogs.py                  # dialogs unificados, settings, viewer e atalhos
      widgets.py                  # componentes reutilizáveis + ícones vetoriais
      theme.py                    # design tokens, palette e QSS global
      title_bar.py                # chrome superior frameless
      workers.py
      pages/
        page_prints.py
        page_review.py
        page_export.py
  tests/
  samples/
  assets/
  docs/
    EVOLUCAO_E_PLANO_2026.md
    CODE_REVIEW_2026.md
    UI_REFACTOR_2026.md
```

## Principais responsabilidades

`main.py`: inicia a interface desktop e logging.

`automation.py`: concentra análise de pendências, agrupamento mensal, decisões de inclusão, destino padrão e reserva atômica de nomes sem sobrescrita.

`file_utils.py`: primitives de escrita atômica usadas por settings, sessão e Excel.

`session_store.py`: persiste a sessão atual de forma atômica e tolerante a corrupção.

`settings.py`: configurações de OCR, perfil e automações.

`ui_qt/main_window.py`: shell da aplicação, NavigationRail, atalhos, navegação protegida, autosave/restore, novo mês e integração entre as páginas.

`ui_qt/pages/page_prints.py`: importação de arquivos/pastas, drag and drop e OCR.

`ui_qt/pages/page_review.py`: tabela enxuta + inspector, filtros, busca, decisões em lote, edição e validação inteligente.

`ui_qt/pages/page_export.py`: conferência pré-exportação, métricas, destino, avisos e exportação automática/salvar como.

`ocr/engine.py`: localiza e executa o Tesseract.

`ocr/preprocess.py`: prepara a imagem para OCR.

`parser/banco_horas_parser.py`: interpreta texto/TSV e consolida registros.

`parser/espelho_parser.py`: importa Espelho de Ponto XLSX/XLSM/PDF.

`excel/generator.py`: gera um XLSX ou um lote separado por mês.

`cli.py`: automação por terminal, com saída única ou diretório em lote.

`tests/`: valida parsing, consolidação, sessão, settings, automações, OCR, CLI, segurança de arquivos, Excel e contratos estáticos da arquitetura UI.

`docs/CODE_REVIEW_2026.md`: achados, correções, validações e limitações conhecidas da revisão completa.

`docs/UI_REFACTOR_2026.md`: arquitetura, componentes, navegação, acessibilidade, atalhos e decisões do redesign completo de UI/UX.
