# OCR e limitações

## Como o OCR lê os prints

A aplicação executa o Tesseract duas vezes por imagem:

1. Saída de texto simples.
2. Saída TSV, que contém palavras com coordenadas.

O parser dá preferência ao TSV. Isso permite localizar o texto `Trabalhou` e pegar o horário que aparece logo abaixo dele, evitando confundir `Saldo` e `Extra`.

## Erros comuns de OCR

Erros prováveis:

```text
O -> 0
I, l, | -> 1
S -> 5
8:3O -> 8:30
7;09 -> 7:09
```

O parser possui normalização para alguns desses casos, mas não deve substituir revisão humana.

## Boas práticas para os prints

Use prints nítidos, sem cortes nas datas e no campo `Trabalhou`.

Evite enviar o mesmo cartão muito cortado em dois prints diferentes. Quando houver duplicidade conflitante, o app marca a linha como `revisar`.

Inclua o mês completo ou confira o alerta de dias úteis ausentes.

## Quando o OCR falhar

1. Abra Preferências e teste o Tesseract.
2. Confirme se o idioma `por` foi instalado.
3. Troque temporariamente o idioma para `eng` se o pacote português estiver ausente.
4. Use a opção **Importar texto** como alternativa manual.
5. Edite a tabela antes de gerar o Excel.

## Por que não foi usado modelo de IA local

Modelos locais de visão poderiam funcionar, mas aumentariam complexidade, tamanho do aplicativo, consumo de memória e tempo de execução. Como o layout do Banco de Horas é fixo, OCR + regras é uma abordagem mais simples e auditável.
