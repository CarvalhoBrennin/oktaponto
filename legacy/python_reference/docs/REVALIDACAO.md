# Revalidação antes da entrega

Checklist aplicado ao projeto:

## Plano

- O fluxo substitui ChatGPT + Perplexity por uma aplicação local.
- O OCR é local e gratuito.
- Há tabela de revisão antes da geração.
- O Excel mantém as regras críticas do layout.

## Código

- Código separado por responsabilidade.
- Interface não depende de bibliotecas pagas.
- Parser não usa IA generativa.
- Geração do Excel não depende de fórmulas para total.
- Configurações são persistidas em arquivo local.
- CLI disponível para automação futura.

## Excel

- Horas gravadas como float de fração de dia.
- Total gravado como float de fração de dia.
- Total formatado como `[h]:mm`.
- Gridlines desativadas.
- Painéis congelados em `A7`.
- Dados fixos configuráveis.

## Riscos conhecidos

- A precisão depende da qualidade do OCR.
- Tesseract precisa estar instalado na máquina.
- Prints muito cortados podem exigir correção manual.
- O layout do app Banco de Horas, se mudar muito, pode exigir ajuste no parser.

## Mitigações

- Tabela editável.
- Importação manual de texto.
- Status `revisar` em conflitos.
- Alerta de dias úteis ausentes.
- Testes automatizados para parser e Excel.
