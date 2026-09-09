# Plano de implementação

## Objetivo

Criar uma aplicação desktop local que automatize o processo atual:

```text
prints do Banco de Horas -> OCR local -> tabela revisável -> Excel timesheet
```

A aplicação não usa APIs pagas. O OCR é feito localmente, e a geração do Excel é feita em Python.

## Escopo do MVP entregue

O MVP implementado contém:

1. Interface desktop com Tkinter.
2. Upload de múltiplos prints.
3. OCR local com Tesseract.
4. Pré-processamento de imagens com Pillow.
5. Parser especializado para o layout do Banco de Horas.
6. Consolidação por data e deduplicação.
7. Tabela editável/revisável.
8. Inclusão manual de registros.
9. Importação de texto OCR/manual.
10. Validação de dias úteis ausentes.
11. Geração do Excel `.xlsx` no layout definido.
12. CLI para uso sem interface.
13. Testes automatizados.
14. Documentação de uso e build.

## Plano técnico revalidado

### 1. Interface

Escolha: Tkinter.

Motivo: já acompanha Python, não exige dependência visual pesada e é suficiente para o fluxo necessário. O foco do produto é confiabilidade da extração e geração do Excel, não uma interface sofisticada.

Elementos implementados:

- lista de prints;
- botão de OCR;
- tabela de registros;
- edição de registro;
- importação de texto;
- validação;
- geração do Excel;
- preferências do Tesseract e perfil.

### 2. OCR

Escolha: Tesseract local.

Motivo: gratuito, executa offline e é adequado para prints com texto grande e layout repetitivo.

Estratégia implementada:

- localizar Tesseract por configuração, variável de ambiente, PATH ou caminhos comuns;
- pré-processar imagem;
- executar OCR em texto e TSV;
- usar TSV para identificar posições das palavras;
- usar texto bruto como fallback.

### 3. Pré-processamento

Escolha: Pillow.

Motivo: reduz dependências. OpenCV seria mais poderoso, mas aumentaria o peso do projeto. Para prints de celular com alto contraste, Pillow é suficiente para o MVP.

Tratamentos implementados:

- correção EXIF;
- conversão RGB;
- upscale de prints estreitos;
- escala de cinza;
- aumento de contraste;
- sharpness.

### 4. Parser

Escolha: parser determinístico com regex e coordenadas.

Motivo: o layout do app é previsível. Não é necessário modelo generativo.

Regras implementadas:

- detectar cabeçalho por data `DD/MM/AAAA`;
- dividir a imagem em blocos/cartões;
- identificar o rótulo `Trabalhou`;
- buscar o horário abaixo do rótulo usando coordenadas do OCR;
- fallback por texto bruto;
- ignorar saldo/extra/falta com sinais `+` ou `-`;
- ignorar 0:00;
- detectar Folga, Feriado e Expediente.

### 5. Consolidação

Problema: prints de rolagem podem repetir dias.

Regras implementadas:

- agrupar por data;
- remover duplicata idêntica;
- em conflito, manter temporariamente o maior valor e marcar `revisar`;
- ordenar por data crescente.

### 6. Revisão humana

Decisão mantida: revisão é obrigatória.

Motivo: OCR local pode errar caracteres. A automação reduz o trabalho, mas a confirmação visual evita gerar timesheet incorreto.

### 7. Excel

Escolha: openpyxl.

Regras implementadas:

- total calculado em Python como `float(total_segundos) / 86400.0`;
- horas diárias como float puro;
- total com formato `[h]:mm`;
- sem `=SUM()`;
- sem `datetime.time` para horas;
- gridlines desativadas;
- freeze panes em `A7`;
- cores, bordas, larguras e legenda conforme o layout informado.

### 8. Empacotamento

Escolha: PyInstaller opcional.

Motivo: permite gerar `.exe` com o Python e pacotes do app. O Tesseract continua sendo dependência externa configurável.

## Revalidação final do plano

O plano original previa:

```text
Python + app desktop + OCR local + parser + revisão + openpyxl + zip documentado
```

Status:

- Python: implementado.
- Desktop: implementado com Tkinter.
- OCR local: implementado com Tesseract.
- Parser: implementado.
- Revisão: implementada.
- Excel: implementado.
- CLI: implementada.
- Testes: implementados.
- Documentação: implementada.
- Zip: preparado para entrega.

O único ponto externo é o Tesseract instalado na máquina. Isso é esperado para manter a solução gratuita e local.
