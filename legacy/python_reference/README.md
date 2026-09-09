# Timesheet Banco de Horas Desktop

Aplicação desktop local, gratuita e sem APIs pagas para transformar prints do aplicativo Banco de Horas em um timesheet Excel `.xlsx`.

Fluxo principal:

1. Adicionar prints, uma pasta inteira ou importar o Espelho de Ponto.
2. Executar OCR local com Tesseract quando necessário.
3. Revisar somente as pendências detectadas automaticamente.
4. Gerar o Excel com nome e pasta automáticos — inclusive um arquivo por mês em sessões multi-mês.

A aplicação agora salva a sessão automaticamente e pode recuperá-la na próxima abertura.

A aplicação usa o valor do campo **Trabalhou**. As batidas de ponto aparecem apenas como informação auxiliar durante a leitura.

Alternativa sem prints: use **Importar espelho de ponto** para subir o Espelho de Ponto exportado (`.xlsx`/`.xlsm` ou `.pdf`). A aplicação lê a tabela diretamente (colunas `Data`, `Hora Trab.`, `Obs`), pula o OCR e cai direto na etapa de revisão, já ignorando Folga/Feriado e sinalizando dias sem saída registrada para conferência manual.

## Decisão técnica

A aplicação foi construída com:

- Python 3.11+
- PySide6 (Qt) para a interface desktop (design system próprio, rail lateral, revisão com inspector e fluxo guiado em 3 etapas)
- Tesseract OCR local para leitura dos prints
- Pillow para pré-processamento das imagens
- openpyxl para geração do Excel
- PyInstaller opcional para empacotar como `.exe`

Nada depende de ChatGPT, Perplexity ou APIs pagas.

## Instalação rápida

### 1. Instale o Python

Use Python 3.11 ou superior.

### 2. Instale o Tesseract OCR

Windows: instale o Tesseract OCR e marque o idioma português quando disponível. O caminho comum é:

```text
C:\Program Files\Tesseract-OCR\tesseract.exe
```

Linux:

```bash
sudo apt install tesseract-ocr tesseract-ocr-por
```

macOS:

```bash
brew install tesseract tesseract-lang
```

### 3. Crie o ambiente Python

Windows:

```bat
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
python main.py
```

Linux/macOS:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python main.py
```

## Uso da interface

A interface foi redesenhada como um workspace mensal com navegação lateral persistente. O rail mostra a etapa atual, quantidade de prints, registros, pendências, total aprovado e saúde do OCR.

1. Em **Entrada**, arraste os prints, escolha uma pasta ou use os cartões **Importar espelho** / **Colar texto**.
2. Execute **Ler prints** quando estiver usando imagens. Espelho e texto pulam o OCR.
3. Em **Revisão**, o filtro abre priorizando pendências. A tabela fica enxuta e o inspector lateral mostra fonte, confiança, observações e atividade do dia selecionado.
4. Use **Aprovar**, **Ignorar** ou **Editar** para concluir as exceções, inclusive em lote.
5. Quando não houver pendências, avance para **Excel**. Confira perfil, competência, total, destino e nomes previstos.
6. Clique em **Gerar Excel**. Em sessões com mais de um mês, um arquivo é criado para cada competência.

Use `Ctrl+/` para abrir a referência de atalhos dentro da própria aplicação. Entre os principais: `Ctrl+1/2/3` navega pelas etapas, `Ctrl+I` importa espelho, `Ctrl+O` adiciona prints e `Ctrl+F` busca na revisão.

A revisão continua obrigatória antes do arquivo final. OCR local pode errar caracteres como `O/0`, `I/1` e horários pequenos.


## Automações de produtividade

- autosave e recuperação da última sessão;
- botão **Novo mês** para zerar o estado corrente;
- importação de uma pasta inteira de prints, com subpastas opcionais;
- OCR automático opcional ao adicionar imagens;
- última pasta de entrada/saída lembrada;
- revisão com busca e filtro **Só pendências**;
- validação de dias úteis ausentes e horários suspeitos;
- atividade padrão no perfil e atividade específica por dia;
- geração automática com gravação atômica e sem sobrescrever arquivos existentes, inclusive entre instâncias concorrentes;
- várias competências na mesma sessão geram um Excel por mês;
- opção de abrir a pasta de saída ao concluir.

Veja `docs/EVOLUCAO_E_PLANO_2026.md` para o backlog completo e o plano detalhado.

## Configuração do Tesseract

Abra **Preferências** na aplicação.

Campos principais:

- Caminho do `tesseract.exe` ou executável equivalente.
- Idioma OCR. Padrão: `por+eng`.
- Colaborador.
- Cargo.
- Modalidade.
- Atividade padrão para preencher `Atividades / Entregas`.
- Preferências de automação, sessão e pasta de saída.

As preferências são salvas em:

```text
~/.timesheet_banco_horas/config.json
```

## Uso por linha de comando

Com imagens:

```bash
python -m timesheet_app.cli --images print1.jpg print2.jpg --output output/timesheet_junho_2026.xlsx
```

Com texto OCR/manual:

```bash
python -m timesheet_app.cli --ocr-text samples/junho_2026_exemplo_ocr.txt --output output/timesheet_junho_2026.xlsx
```

Com Espelho de Ponto (Excel ou PDF), pulando OCR/prints:

```bash
python -m timesheet_app.cli --espelho "Espelho de Ponto.xlsx" --output output/timesheet_julho_2026.xlsx
```

Para gerar automaticamente um arquivo por mês:

```bash
python -m timesheet_app.cli --espelho "Espelho de Ponto.xlsx" --output-dir output/ --atividade-padrao "Desenvolvimento e manutenção"
```

## Testes

```bash
python -m unittest discover -s tests
```

A suíte atual possui 142 testes e cobre parsing, consolidação/precedência manual, sessão/configuração corrompida, OCR, automações, CLI e geração do Excel com escrita atômica, rollback e total numérico sem fórmula `SUM()`.

O relatório detalhado da revisão está em `docs/CODE_REVIEW_2026.md`. O redesign completo está documentado em `docs/UI_REFACTOR_2026.md`.

## Regras implementadas

- Extrai data, dia da semana e campo `Trabalhou`.
- Ignora `Folga`, `Feriado 0:00`, dias sem saída e registros `0:00`.
- Remove duplicidades por data.
- Marca conflitos para revisão.
- Ordena os registros por data.
- Gera arquivo por mês.
- Calcula total em Python como float de fração de dia.
- Não usa fórmula `=SUM()` no total.
- Não grava `datetime.time` nas células de horas.
- Usa formato `[h]:mm` nas horas diárias e no total, preservando corretamente jornadas de `24:00`.
- Remove gridlines.
- Congela painéis em `A7`.

## Arquivos relevantes

```text
main.py                                      # entrada da aplicação desktop
timesheet_app/ui_qt/                         # interface gráfica (PySide6/Qt)
timesheet_app/ui_qt/main_window.py          # shell, rail, navegação, atalhos e sessão
timesheet_app/ui_qt/widgets.py              # design system de componentes e ícones vetoriais
timesheet_app/ui_qt/dialogs.py              # modais, preferências, viewer e referência de atalhos
timesheet_app/ui_qt/pages/                   # Entrada, Revisão + inspector e Excel
timesheet_app/ui_qt/theme.py                 # tokens visuais, palette e QSS global
timesheet_app/ocr/engine.py                 # execução do Tesseract
timesheet_app/ocr/preprocess.py             # tratamento das imagens
timesheet_app/parser/banco_horas_parser.py  # extração de registros (prints/OCR)
timesheet_app/parser/espelho_parser.py      # extração de registros (Espelho de Ponto .xlsx/.pdf)
timesheet_app/excel/generator.py            # geração do Excel
tests/                                      # testes automatizados
docs/                                      # documentação técnica
```

## Observação operacional

A aplicação é local, mas depende do Tesseract instalado na máquina. O projeto não inclui binários do Tesseract para evitar empacotar executáveis externos e para manter a distribuição simples. O empacotamento como `.exe` pode incluir o Python e os pacotes, mas o Tesseract deve ser instalado ou apontado nas preferências.
