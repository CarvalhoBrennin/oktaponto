# Evolução do HoraFolio — backlog completo e plano de implementação

## 1. Objetivo do produto

O HoraFolio não deve virar um sistema de ponto completo. O objetivo é mais simples e mais valioso: **reduzir ao mínimo o trabalho manual necessário para transformar dados do Banco de Horas em um timesheet confiável e pronto para entregar**.

A métrica principal de produto deve ser: **quantas decisões e cliques ainda são necessários por fechamento de mês**.

Princípios usados neste plano:

1. Automatizar tudo que é repetitivo e determinístico.
2. Manter revisão humana apenas onde existe ambiguidade real.
3. Nunca sobrescrever arquivo automaticamente.
4. Recuperar trabalho após fechamento inesperado do app.
5. Manter processamento local e privado por padrão.
6. Fazer o fluxo principal funcionar bem sem integrações externas.
7. Tratar OCR como fallback; quando existir fonte estruturada, preferi-la.
8. Melhorar a qualidade do resultado final, não apenas a quantidade de features.

## 2. Diagnóstico da versão recebida

A base já era funcional e tinha separação razoável entre OCR, parser, UI e Excel. O maior problema não era falta de capacidade técnica, mas **fricção operacional**.

Pontos encontrados:

- o app não recuperava a sessão anterior;
- a pasta dos últimos arquivos não era lembrada;
- prints precisavam ser adicionados como arquivos, sem importação de pasta;
- terminar OCR substituía a tabela existente em vez de consolidar com outras fontes já importadas;
- a revisão mostrava todos os dias, mesmo quando só poucos exigiam atenção;
- não havia busca na tabela de revisão;
- o campo `Atividades / Entregas` do Excel ficava vazio;
- o fluxo de geração sempre abria um diálogo de salvar;
- vários meses na mesma sessão bloqueavam a exportação;
- exportações automáticas não tinham estratégia de versionamento sem sobrescrita;
- a validação de dias úteis podia criar falsos alertas entre meses diferentes;
- a CLI só permitia um arquivo de saída e não tinha exportação mensal em lote;
- configurações de automação não existiam;
- não havia um comando explícito de “novo mês”.

## 3. Backlog completo de evoluções recomendadas

Legenda:

- **ENTREGUE**: implementado neste patch.
- **PRÓXIMA**: recomendação de alta prioridade para a próxima onda.
- **OPCIONAL**: útil, mas depende de uso real, integração ou aumento de escopo.

### 3.1 Automação do fluxo

1. **ENTREGUE — Autosave da sessão**: persistir registros, prints e etapa atual.
2. **ENTREGUE — Recuperação automática**: reabrir exatamente o trabalho anterior.
3. **ENTREGUE — Novo mês**: limpar o estado corrente com uma ação explícita e segura.
4. **ENTREGUE — Lembrar última pasta de entrada**.
5. **ENTREGUE — Lembrar última pasta de saída**.
6. **ENTREGUE — Pasta padrão de exportação configurável**.
7. **ENTREGUE — Importar uma pasta inteira de prints**.
8. **ENTREGUE — Importação recursiva opcional de subpastas**.
9. **ENTREGUE — Aceitar pasta via drag and drop**.
10. **ENTREGUE — OCR automático opcional após adicionar prints**.
11. **ENTREGUE — Consolidar OCR com registros já existentes, sem apagar importações anteriores**.
12. **ENTREGUE — Exportar automaticamente um arquivo por mês**.
13. **ENTREGUE — Criar nova versão do arquivo se o nome já existir**.
14. **ENTREGUE — Abrir a pasta de saída automaticamente, se configurado**.
15. **PRÓXIMA — Modo “fechamento rápido”**: importar → validar → mostrar somente exceções → exportar em um único fluxo.
16. **PRÓXIMA — Monitorar uma pasta de screenshots** e adicionar novos prints automaticamente enquanto o app estiver aberto.
17. **PRÓXIMA — Cache de OCR por hash da imagem** para nunca reler o mesmo print sem necessidade.
18. **PRÓXIMA — Detecção de imagem duplicada por hash/perceptual hash** antes do OCR.
19. **PRÓXIMA — Histórico de fechamentos** com mês, total, arquivos gerados e data de geração.
20. **PRÓXIMA — Presets de fluxo**: “prints”, “espelho XLSX”, “espelho PDF” e “misto”.
21. **OPCIONAL — Fechamento agendado do mês** com lembrete local.
22. **OPCIONAL — Importação automática de anexos de e-mail**, caso no futuro seja desejada integração com Gmail/Outlook.
23. **OPCIONAL — Sincronização com OneDrive/Google Drive** para uma pasta de entrada/saída.

### 3.2 Revisão inteligente e redução de trabalho manual

24. **ENTREGUE — Filtro “Só pendências”**.
25. **ENTREGUE — Busca por data, atividade, observação, status ou fonte**.
26. **ENTREGUE — Filtros Incluídos / Ignorados / Editados**.
27. **ENTREGUE — Foco automático nas pendências depois da importação**.
28. **ENTREGUE — Diagnóstico centralizado** de pendências, dias úteis ausentes e horas extremamente altas.
29. **ENTREGUE — Correção da detecção de dias ausentes em sessões com múltiplos meses**.
30. **ENTREGUE — Feedback imediato após OCR/importação com quantidade de pendências**.
31. **PRÓXIMA — Painel lateral de detalhes** para revisar uma linha sem abrir modal.
32. **PRÓXIMA — Print lado a lado com o registro selecionado**.
33. **PRÓXIMA — Destaque visual de confiança OCR** em vez de deixar a informação escondida.
34. **PRÓXIMA — Navegação “próxima pendência / pendência anterior”** por teclado.
35. **PRÓXIMA — Edição em lote** de atividade, inclusão e observação.
36. **PRÓXIMA — Undo/redo** para exclusão, edição e inclusão.
37. **PRÓXIMA — Comparação explícita quando dois prints conflitam na mesma data**.
38. **PRÓXIMA — Regras configuráveis de jornada esperada** por dia da semana.
39. **PRÓXIMA — Calendário de feriados configurável** para reduzir falsos dias ausentes.
40. **PRÓXIMA — Ausências planejadas**: férias, atestado, banco de horas, viagem etc.
41. **OPCIONAL — Aprovação automática de registros de alta confiança**, mas apenas depois de termos telemetria local/estatísticas de acerto suficientes para definir uma regra segura.

### 3.3 Qualidade e produtividade do Excel

42. **ENTREGUE — Atividade padrão no perfil**.
43. **ENTREGUE — Atividade específica por registro**.
44. **ENTREGUE — Atividade específica sobrescreve a atividade padrão**.
45. **ENTREGUE — Exportação em lote por mês**.
46. **ENTREGUE — Nome automático por mês**.
47. **ENTREGUE — Versionamento automático sem sobrescrever**.
48. **ENTREGUE — Resumo da pasta de destino antes da geração**.
49. **PRÓXIMA — Presets de atividades** para escolher com dois cliques.
50. **PRÓXIMA — Preenchimento em lote da mesma atividade no mês**.
51. **PRÓXIMA — Campo Projeto / Centro de custo / Cliente**, caso seja necessário no processo real.
52. **PRÓXIMA — Template de Excel configurável** sem alterar código.
53. **PRÓXIMA — Validação de layout pós-geração** como teste automatizado de estilo/células obrigatórias.
54. **PRÓXIMA — Histórico de templates e versões de layout**.
55. **OPCIONAL — Exportar PDF junto com XLSX**.
56. **OPCIONAL — Gerar rascunho de e-mail com o timesheet anexado**.

### 3.4 OCR e importação

57. **PRÓXIMA — Cache persistente do resultado OCR** por imagem.
58. **PRÓXIMA — Pipeline adaptativo de pré-processamento** com 2–3 variantes e seleção do melhor resultado.
59. **PRÓXIMA — Avaliar múltiplos modos PSM do Tesseract** para layouts diferentes.
60. **PRÓXIMA — Score de qualidade por cartão/data**, não apenas por palavra.
61. **PRÓXIMA — Detecção mais robusta de screenshots longos e cartões parcialmente cortados**.
62. **PRÓXIMA — Processamento incremental**: resultado aparece conforme cada imagem termina.
63. **PRÓXIMA — Cancelamento de OCR em andamento**.
64. **PRÓXIMA — Reprocessar apenas imagens problemáticas**.
65. **PRÓXIMA — Paralelismo controlado**, se os testes mostrarem ganho real sem piorar estabilidade.
66. **OPCIONAL — Empacotar/instalar Tesseract automaticamente no Windows**, respeitando licença e tamanho de distribuição.
67. **OPCIONAL — Suporte a novos layouts/fontes de ponto por adaptadores de parser**.

### 3.5 UI/UX

68. **ENTREGUE — Botão global “Novo mês”**.
69. **ENTREGUE — Página de revisão orientada a exceções**.
70. **ENTREGUE — Busca e filtros no topo da tabela**.
71. **ENTREGUE — Exportação principal em um clique**.
72. **ENTREGUE — Resumo explícito de destino e quantidade de arquivos**.
73. **PRÓXIMA — Dashboard inicial com “Continuar sessão” / “Novo mês” / “Importar espelho”**.
74. **PRÓXIMA — Atalhos de teclado para adicionar, editar, próxima pendência e exportar**.
75. **PRÓXIMA — Command palette** para ações frequentes.
76. **PRÓXIMA — Melhor responsividade para janelas menores**.
77. **PRÓXIMA — Indicador de progresso por arquivo no OCR**.
78. **PRÓXIMA — Acessibilidade: foco, contraste, navegação integral por teclado e labels para leitores de tela**.
79. **OPCIONAL — Tema claro**.
80. **OPCIONAL — Modo compacto para telas pequenas**.

### 3.6 Confiabilidade, segurança e manutenção

81. **ENTREGUE — Escrita atômica das configurações**.
82. **ENTREGUE — Escrita atômica da sessão**.
83. **ENTREGUE — Sessão corrompida é ignorada de forma segura**.
84. **ENTREGUE — Persistência tolerante a configurações antigas**.
85. **ENTREGUE — Novos testes de automação, sessão, settings e exportação em lote**.
86. **PRÓXIMA — Versionamento/migração explícita do schema de configurações**.
87. **PRÓXIMA — Backup rotativo da sessão/configuração**.
88. **PRÓXIMA — Health check na abertura**: Tesseract, permissões de pasta, espaço em disco e dependências.
89. **PRÓXIMA — Log específico de ações do usuário** para diagnóstico local.
90. **PRÓXIMA — Testes de UI com pytest-qt/PySide6 em CI**.
91. **PRÓXIMA — Ruff + mypy/pyright** no pipeline.
92. **PRÓXIMA — GitHub Actions** em Windows e Linux para testes/build.
93. **PRÓXIMA — Build reproduzível do `.exe`**.
94. **PRÓXIMA — Assinatura de código do executável**, se houver distribuição para outras máquinas.
95. **OPCIONAL — Atualizador automático assinado**.
96. **OPCIONAL — Criptografia local da sessão**, se os dados passarem a incluir informações mais sensíveis.

### 3.7 Integrações que realmente podem poupar tempo no futuro

97. **PRÓXIMA — Sugestão de atividade baseada em commits Git locais** do dia.
98. **PRÓXIMA — Sugestão de atividade baseada em tickets Jira/Linear**, se esses serviços fizerem parte do fluxo real.
99. **PRÓXIMA — Importar eventos de calendário** para explicar ausências ou atividades.
100. **OPCIONAL — Criar rascunho de e-mail/Teams/Slack com o arquivo gerado**.
101. **OPCIONAL — API local/CLI estruturada** para ser chamada por outros scripts.
102. **OPCIONAL — Plugin de bandeja do sistema** para fechamento rápido do mês.

## 4. Escopo implementado neste patch

Este patch prioriza mudanças que trazem ganho imediato sem exigir serviços externos:

### Automação

- autosave da sessão;
- restore automático;
- novo mês;
- última pasta de entrada/saída;
- pasta padrão configurável;
- importar pasta completa;
- subpastas opcionais;
- drag and drop de pasta;
- OCR automático opcional;
- consolidação de OCR com dados já importados;
- exportação automática por mês;
- versionamento de arquivo sem sobrescrita;
- abrir pasta depois de gerar, opcionalmente.

### Revisão

- filtro por pendências;
- filtros por incluídos, ignorados e editados;
- busca textual;
- foco automático nas exceções;
- análise centralizada dos registros;
- detecção de horas acima de 16h;
- correção da detecção de dias úteis em múltiplos meses.

### Resultado

- atividade padrão no perfil;
- atividade por registro;
- preenchimento da coluna `Atividades / Entregas` no Excel;
- CLI com `--output-dir` para batch mensal;
- CLI com `--atividade-padrao`.

## 5. Plano de implementação detalhado

### Fase 0 — Baseline e segurança de regressão — CONCLUÍDA

Objetivo: garantir que a versão recebida estava saudável antes de alterar comportamento.

Tarefas:

1. Extrair fonte em workspace separado.
2. Preservar snapshot original para geração de diff.
3. Compilar todos os módulos Python.
4. Rodar a suíte original.
5. Executar geração de Excel com sample existente.
6. Mapear responsabilidades de cada módulo.

Critério de aceite: todos os 23 testes originais passando antes de qualquer mudança.

### Fase 1 — Fundação de automação e persistência — CONCLUÍDA

Objetivo: o usuário não deve perder estado nem configurar as mesmas pastas repetidamente.

Implementação:

1. Criar `AutomationConfig` com defaults conservadores.
2. Evoluir `AppSettings` sem quebrar `config.json` antigo.
3. Salvar settings de forma atômica.
4. Criar `session_store.py` com schema versionado.
5. Serializar/deserializar `TimesheetRecord`.
6. Debounce de autosave para evitar escrita a cada microevento.
7. Recuperar sessão após construir a UI.
8. Descartar referências a imagens que não existem mais.
9. Salvar a etapa atual.
10. Adicionar “Novo mês” e limpar sessão de forma explícita.
11. Salvar sessão ao fechar o app.

Critérios de aceite:

- editar/incluir/excluir registro persiste;
- fechar e abrir recupera registros;
- session JSON inválido não derruba o app;
- configuração antiga carrega com defaults novos;
- novo mês não apaga XLSX gerados.

### Fase 2 — Entrada de dados sem fricção — CONCLUÍDA

Objetivo: reduzir tempo gasto selecionando arquivos e evitar perda de dados entre fontes.

Implementação:

1. Adicionar botão `Adicionar pasta`.
2. Permitir pasta em drag and drop.
3. Escanear extensões suportadas.
4. Tornar recursividade configurável.
5. Deduplicar paths.
6. Guardar última pasta usada.
7. Adicionar OCR automático opcional.
8. Mudar término de OCR de “replace” para “merge + consolidate”.
9. Guardar pasta usada pelo espelho de ponto.

Critérios de aceite:

- uma pasta com N imagens adiciona todas;
- a mesma imagem não aparece duas vezes;
- importação de espelho seguida de OCR não perde os registros do espelho;
- importar subpastas respeita a preferência.

### Fase 3 — Revisão por exceção — CONCLUÍDA

Objetivo: o usuário só deve olhar para linhas que realmente precisam de decisão.

Implementação:

1. Introduzir `RecordsFilterProxyModel`.
2. Adicionar filtro `Só pendências`.
3. Adicionar filtros de estado.
4. Adicionar busca textual.
5. Mapear seleção do proxy de volta ao source model para edição/exclusão corretas.
6. Criar `automation.analyze_records`.
7. Centralizar contagens e alertas.
8. Marcar confiança OCR baixa como exceção visual/lógica.
9. Detectar horas acima de 16h como suspeitas.
10. Corrigir detecção de dias ausentes para trabalhar mês a mês.
11. Focar automaticamente nas pendências quando configurado.
12. Garantir que checkboxes diretos também disparem autosave.

Critérios de aceite:

- editar um item filtrado edita o registro correto;
- busca não altera a lista real;
- filtros não afetam exportação;
- checkbox em tabela persiste na sessão;
- múltiplos meses não geram lacunas falsas entre eles.

### Fase 4 — Excel pronto para uso e exportação em um clique — CONCLUÍDA

Objetivo: reduzir o trabalho depois que os dados já estão corretos.

Implementação:

1. Adicionar `atividade_padrao` ao perfil.
2. Adicionar `atividade` por registro.
3. Editar atividade no diálogo do registro.
4. Mostrar atividade na tabela.
5. Usar atividade do registro ou fallback do perfil na coluna G.
6. Criar `generate_timesheet_batch`.
7. Agrupar registros elegíveis por mês.
8. Criar nome padrão de cada mês.
9. Evitar sobrescrita com sufixos `(2)`, `(3)`, etc.
10. Criar pasta automaticamente.
11. Exibir destino automático na UI.
12. Manter “Salvar como...” para um único mês.
13. Permitir multi-mês pela ação automática.
14. Opcionalmente abrir a pasta ao terminar.

Critérios de aceite:

- um mês = um XLSX;
- dois meses = dois XLSX;
- arquivo existente não é alterado;
- atividade aparece no Excel;
- override diário ganha do default.

### Fase 5 — CLI e automação externa — CONCLUÍDA

Objetivo: permitir que o mesmo motor seja usado por script.

Implementação:

1. Manter `--output` para compatibilidade.
2. Adicionar `--output-dir` como alternativa mutuamente exclusiva.
3. Quando usado `--output-dir`, gerar um arquivo por mês.
4. Adicionar `--atividade-padrao`.
5. Reutilizar exatamente o mesmo generator da UI.

Critério de aceite: sample de junho gera 24:47; sample multi-mês gera junho e julho separados.

### Fase 6 — Testes e revisão — CONCLUÍDA NESTE PATCH

Revisões executadas:

1. suíte original antes das mudanças;
2. compilação integral depois das mudanças;
3. testes de session roundtrip e corrupção;
4. testes de compatibilidade de settings antigos;
5. testes de análise multi-mês;
6. teste de no-overwrite;
7. teste de atividade padrão/override no XLSX;
8. teste de batch com dois meses;
9. execução real da CLI em modo single;
10. execução real da CLI em batch;
11. inspeção do XLSX gerado via openpyxl;
12. parse AST de todos os módulos.

Limitação do ambiente de revisão: PySide6 não estava instalado no container usado para esta alteração, então a janela Qt não pôde ser instanciada em modo offscreen. A UI foi validada por compilação/análise estática; a recomendação para CI é adicionar teste com `pytest-qt` em ambiente que instale as dependências de `requirements.txt`.

### Fase 7 — Próxima onda: OCR incremental/cache — RECOMENDADA

Ordem proposta:

1. calcular SHA-256 de cada imagem;
2. persistir resultado OCR por hash;
3. invalidar cache quando versão do parser/preprocess mudar;
4. mostrar cada print como concluído individualmente;
5. permitir cancelar;
6. permitir reprocessar somente falhas;
7. coletar score de confiança por registro;
8. só depois testar paralelismo.

Meta: segundo processamento do mesmo conjunto deve ser praticamente instantâneo.

### Fase 8 — Próxima onda: revisão avançada — RECOMENDADA

1. side panel de edição;
2. preview da imagem ao lado;
3. próxima/anterior pendência;
4. bulk activity;
5. undo/redo;
6. calendário de exceções;
7. regras de jornada.

Meta: um mês correto deve exigir revisão apenas das exceções reais.

### Fase 9 — Próxima onda: histórico e fechamento — RECOMENDADA

1. banco local SQLite leve;
2. histórico mensal;
3. arquivos gerados;
4. totais e status;
5. reabrir fechamento antigo sem reutilizar a sessão corrente;
6. comparação entre meses;
7. botão “Duplicar atividade padrão do mês anterior”.

Meta: o app deixa de ser apenas um conversor e passa a ser um assistente pessoal de fechamento sem virar um sistema corporativo complexo.

### Fase 10 — Integrações opcionais — CONDICIONAL

Só implementar depois de confirmar que fazem parte do fluxo real:

- Git local → sugestões de atividades;
- Jira/Linear → tickets trabalhados;
- Calendar → ausências/reuniões;
- Gmail/Outlook → rascunho com anexo;
- OneDrive/Drive → sincronização de pasta.

A regra deve ser: integração só entra se eliminar uma tarefa real recorrente.

## 6. Métricas para saber se a evolução funcionou

Sugestão de métricas locais, sem telemetria externa obrigatória:

- cliques do início até exportar;
- tempo total de fechamento;
- quantidade de registros que exigiram edição;
- quantidade de OCRs reutilizados do cache;
- quantidade de alertas verdadeiros/falsos;
- vezes em que um arquivo precisou ser aberto e corrigido manualmente;
- quantidade de meses exportados em um clique;
- quantidade de sessões recuperadas após reabrir o app.

O produto está melhor quando o fluxo típico vira algo próximo de:

> abrir app → importar pasta/espelho → revisar 0–3 exceções → gerar automaticamente → pronto.

## 7. Arquivos principais alterados neste patch

- `timesheet_app/models.py`
- `timesheet_app/settings.py`
- `timesheet_app/session_store.py` (novo)
- `timesheet_app/automation.py` (novo)
- `timesheet_app/parser/banco_horas_parser.py`
- `timesheet_app/excel/generator.py`
- `timesheet_app/cli.py`
- `timesheet_app/ui_qt/main_window.py`
- `timesheet_app/ui_qt/widgets.py`
- `timesheet_app/ui_qt/dialogs.py`
- `timesheet_app/ui_qt/pages/page_prints.py`
- `timesheet_app/ui_qt/pages/page_review.py`
- `timesheet_app/ui_qt/pages/page_export.py`
- novos testes em `tests/`.

## 8. Onda de hardening pós-implementação — CONCLUÍDA

Depois da primeira implementação, foi feito um code review completo adicional. O hardening incluiu integridade da decisão manual, estados fail-closed, escrita atômica, rollback batch, reserva concorrente de nomes, proteção contra fórmula no XLSX, parser multi-sheet/PDF mais defensivo, OCR em uma passagem TSV, validação de idiomas, limites de memória no preprocess, consolidação de sessão legada e ampliação da suíte para 100 testes.

O inventário detalhado dos achados e das correções está em `docs/CODE_REVIEW_2026.md`. Este documento continua sendo o roadmap de produto; o relatório de code review é a fonte de verdade para o hardening técnico aplicado ao patch final.
