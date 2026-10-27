# Code review completo — OktaPonto / Timesheet Banco de Horas

Data da revisão: 01/09/2026

## Objetivo

Revisar o projeto original + o patch de evolução anterior como código que será usado no fechamento real de horas, com prioridade para:

- não perder decisões manuais;
- não exportar dados ambíguos/corrompidos silenciosamente;
- não sobrescrever arquivos automaticamente;
- manter sessão/configuração recuperáveis mesmo após falhas;
- impedir que erros de OCR sejam confundidos com erros de programação;
- reduzir trabalho repetitivo sem esconder decisões importantes;
- manter UI, CLI e gerador com as mesmas regras de negócio.

## Escopo revisado

Foram revisados manualmente e por testes os módulos de modelos, settings, sessão, automações, parser OCR, parser de espelho XLSX/PDF, pré-processamento de imagem, engine Tesseract, geração Excel, CLI, logging e fluxo Qt. Também foram verificados os arquivos de build/documentação e os limites de integração entre as camadas.

A UI Qt não pôde ser instanciada neste container porque `PySide6` não está instalado no ambiente de revisão. Os módulos Qt foram compilados/analisados estaticamente e os contratos das camadas usadas por eles foram testados. Essa limitação é registrada explicitamente em vez de ser tratada como validação visual inexistente.

## Achados e correções

### Alta prioridade — integridade dos dados

1. **Registro editado manualmente não respeitava `include=False`.** Um item editado podia continuar entrando no Excel mesmo depois de ser ignorado. `eligible_for_excel()` agora exige decisão de inclusão coerente.
2. **Status pendente/incoerente podia atravessar a exportação.** Somente registros `ok` ou `editado`, com checkbox ligado e horas positivas, são elegíveis. `revisar`/`ignorado` não entram apenas porque um estado corrompido deixou `include=True`.
3. **Decisão manual podia ser perdida em uma reimportação.** Consolidação agora dá precedência à decisão humana, inclusive ignorar um dia positivo.
4. **Duas decisões manuais para a mesma data podiam preservar a mais antiga.** A decisão manual mais recente passa a vencer, preservando checkbox, atividade e metadados.
5. **Duplicata OCR idêntica podia apagar status/atividade manual.** Metadados da edição passam a ser preservados.
6. **Uma fonte estruturada confirmando um OCR em revisão herdava alertas antigos.** A confirmação mantém rastreabilidade da outra fonte, mas não herda notas de baixa confiança que já foram resolvidas.
7. **Datas duplicadas podiam chegar ao gerador em estado legado.** O gerador rejeita duplicatas incluídas antes de escrever o XLSX.
8. **Horas acima de 24:00 podiam chegar por edição/estado corrompido.** Parser, diálogo, sessão e gerador aplicam a mesma barreira de 24h.
9. **Dia da semana exportado confiava no texto persistido.** O Excel deriva o dia da própria `date`, evitando inconsistência de estado antigo.
10. **Persistência corrompida podia falhar aberta.** `include` inválido, status desconhecido, horas inválidas ou acima de 24h passam a exigir revisão/não inclusão.
11. **Truthiness de Python ainda permitia `include: [1]` virar verdadeiro.** Coerção booleana agora aceita apenas bool, 0/1 e strings reconhecidas.
12. **Configuração malformada podia transformar listas/dicionários em caminhos ou textos.** Strings de perfil/caminhos são aceitas somente quando realmente são strings.

### Alta prioridade — segurança de arquivos e transações

13. **XLSX era gravado diretamente no destino.** Configuração, sessão e Excel agora usam escrita atômica no mesmo diretório e `os.replace` somente após sucesso.
14. **Falha no meio do batch podia deixar meses anteriores gerados.** O lote é transacional e remove os arquivos criados pela tentativa se um mês falhar.
15. **`KeyboardInterrupt` não fazia rollback completo.** O rollback cobre `BaseException` para também tratar cancelamento/interrupção.
16. **No-overwrite automático tinha janela de corrida entre `exists()` e salvar.** O nome é reservado atomicamente com `O_EXCL`, evitando colisão entre duas instâncias simultâneas.
17. **Falha de limpeza de temporário podia esconder a exceção original.** Cleanup é best-effort e preserva a causa real.
18. **CLI/gerador aceitavam saída com extensão enganosa.** A camada de geração exige `.xlsx`.
19. **Texto do usuário começando com `=` podia virar fórmula no Excel.** Colaborador, cargo, modalidade e atividade são escritos explicitamente como string; caracteres de controle inválidos também são sanitizados.
20. **Proteção de fórmula cobria linhas de dados, mas não o bloco superior.** A mesma escrita segura agora é usada também em Colaborador/Cargo/Período.

### OCR e imagens

21. **Caminho normal executava Tesseract duas vezes por print.** O TSV passou a ser a fonte principal; texto bruto só roda como fallback quando não há palavras utilizáveis.
22. **Timeout/permissão podia ser confundido com idioma ausente e causar nova tentativa longa.** Fallback para inglês ocorre somente em erro real de `traineddata`/idioma.
23. **“Testar OCR” validava só o binário, não o idioma configurado.** O health check consulta `--list-langs` e informa fallback para inglês quando aplicável.
24. **Worker engolia qualquer `Exception` por print.** Apenas falhas esperadas de OCR/arquivo são recuperadas individualmente; bugs inesperados abortam e deixam traceback no log.
25. **OCR terminando sem nenhum registro podia avançar para revisão vazia.** Agora retorna erro claro.
26. **Lista de prints podia ser alterada durante OCR.** Drop, adicionar/remover/limpar/importar ficam bloqueados enquanto a thread está ativa; Cancelar permanece disponível.
27. **Novo mês/fechamento podiam colidir com OCR em execução.** O fluxo bloqueia essas ações até concluir/cancelar a leitura.
28. **Upscale de imagem estreita/extremamente alta podia explodir memória.** O pré-processamento limita fator de escala e orçamento de pixels intermediários.
29. **Falha ao salvar imagem temporária podia deixar lixo.** O temporário é removido em falha sem mascarar a exceção original.

### Parsing OCR

30. **Caracteres aceitos pela regex (`i`, `b`, `q`, `d`) não eram todos normalizados.** Normalização agora cobre as confusões comuns para 0/1/5/8.
31. **Lista de pontos podia capturar o valor de “Trabalhou”.** A busca de batidas é limitada à região anterior ao rótulo.
32. **Data com pontos, como `01.07.2026`, podia virar falso horário `01:07`.** Datas são removidas antes de procurar pontos/fallback de horário.
33. **Fallback textual pede revisão, mas a semântica de pendência não reconhecia todas as notas.** Notas “confira”, conflito e baixa confiança entram no filtro de pendências.
34. **Editar/aprovar uma pendência não encerrava necessariamente o alerta.** Decisão humana explícita muda o status para `editado`/`ignorado`; alertas OCR antigos deixam de manter o item eternamente pendente.
35. **Possíveis dias ausentes eram calculados atravessando meses.** Validação é feita separadamente por competência.
36. **Feriado/Folga explicitamente presentes podiam aparecer como data ausente.** Qualquer data reconhecida conta como presente na detecção de lacunas.

### Espelho XLSX/PDF

37. **Parser considerava só uma planilha.** Agora percorre todas as worksheets e aceita cabeçalhos repetidos/reordenados.
38. **Segunda entrada/saída podia ser ignorada.** Cabeçalhos numerados 1/2 são classificados e até quatro batidas são preservadas.
39. **Duração Excel `[h]:mm` pode chegar como `timedelta`.** `_cell_text` trata `timedelta`, inclusive negativo.
40. **`bool` é subclasse de `int` em Python.** Células `True/False` não viram mais `24:00/0:00` por acidente.
41. **PDF considerava somente uma tabela por página.** Todas as tabelas retornadas por `pdfplumber` são percorridas.
42. **Linha `None`/vazia extraída de PDF podia quebrar o parser.** Linhas vazias são ignoradas defensivamente.
43. **Dependência `pdfplumber` faltava no `pyproject.toml`.** Foi adicionada para manter metadata de instalação consistente com `requirements.txt`.

### Sessão, settings e UX

44. **Sessão/configuração JSON parcialmente corrompida podia derrubar toda a recuperação.** Registros válidos são recuperados individualmente; estruturas inválidas caem para defaults seguros.
45. **Autosave desligado com restore ligado criava estado incoerente/stale.** Restore depende de autosave tanto na normalização quanto na UI.
46. **Sessão antiga podia restaurar datas duplicadas.** Restore consolida antes de apresentar à UI.
47. **Preferências eram abertas duas vezes.** Chamada duplicada removida.
48. **Checkbox alterado diretamente na tabela não disparava autosave.** `dataChanged` atualiza resumo e sessão.
49. **Filtro “Ignorados” na prática mostrava qualquer item não exportável.** Rótulo passou a “Não incluídos”.
50. **Toast configurava sombra e a substituía imediatamente pelo efeito de opacidade.** Código morto removido.
51. **Atividade/Entrega ficava sempre vazia.** Perfil ganhou atividade padrão e cada dia pode sobrescrever individualmente.
52. **Importar novo OCR podia substituir registros já existentes.** Fontes são consolidadas com a sessão atual.
53. **Importação de pasta e automação de OCR reprocessavam mais do que o necessário.** Auto-OCR trabalha apenas nos prints recém-adicionados; execução manual continua reprocessando todos quando desejado.
54. **Feedback da importação do espelho contava apenas status literal `revisar`.** Agora usa a mesma análise central de pendências usada no restante da UI.
55. **Mensagem de horário manual não deixava o limite claro.** O diálogo explicita `0:00` a `24:00`.
56. **Logs eram direcionados ao diretório do pacote, problemático em builds read-only/PyInstaller.** Logs passam para o diretório de configuração do usuário, com fallback para temporário.

## Segunda rodada independente — novos achados e correções

Esta rodada partiu do patch já revisado, mas repetiu a análise procurando principalmente invariantes entre módulos, ordem de importação, cancelamento, múltiplas instâncias, arquivos extremos/corrompidos e inconsistências entre o que a UI promete e o que a última barreira de exportação realmente aceita.

### Integridade e determinismo

57. **`24:00` era válido internamente, mas a célula diária usava `h:mm` e o Excel podia exibi-lo como `0:00`.** As linhas diárias agora usam `[h]:mm`, igual ao total.
58. **A própria entidade `TimesheetRecord` não impunha sozinha o teto de 24h.** A elegibilidade passou a exigir minutos inteiros, positivos e no máximo `24:00`.
59. **O batch agrupava apenas itens elegíveis antes da validação final.** Um registro inválido acima de 24h podia sumir do agrupamento e o restante ser exportado. O conjunto original é validado antes de agrupar.
60. **Um estado corrompido com `include=True`, mas status/horas incoerentes, podia ser simplesmente filtrado.** A última barreira diferencia agora “decisão de não incluir” de “marcado para incluir, porém inválido” e falha fechado.
61. **`worked_minutes=480.9` em sessão corrompida era truncado para 480.** Floats só são aceitos quando finitos e exatamente integrais.
62. **Metadados não textuais de uma sessão corrompida podiam virar strings como `{'x': 1}`.** Atividade, fonte e tipo só são recuperados quando o valor original é string.
63. **Duas fontes automáticas com o mesmo valor podiam produzir resultado diferente conforme a ordem de importação.** A fonte preferida é escolhida por qualidade determinística.
64. **Com três ou mais fontes conflitantes, maioria/ordem podia resolver acidentalmente um conflito.** Qualquer divergência exclusivamente automática permanece `revisar`; o maior valor é apenas candidato provisório.
65. **`consolidate_records()` mutava objetos recebidos.** A consolidação trabalha em cópias, evitando efeitos laterais na lista original/estado de UI.
66. **Uma atividade manual propositalmente vazia podia ser repopulada por outra fonte.** Vazio em decisão humana passa a significar explicitamente “usar padrão do perfil”.
67. **Um conflito histórico já consolidado podia desaparecer quando uma nova fonte repetia apenas o candidato escolhido.** A evidência de conflito permanece pendente até decisão humana.
68. **Confiança `NaN/Inf` injetada programaticamente podia reintroduzir desempate dependente de ordem.** Confiança não finita é tratada como desconhecida e os desempates finais também são estáveis.
69. **Status runtime desconhecido podia escapar do contador de pendências, embora o gerador o bloqueasse.** Status fora do domínio agora é pendência e uma ação humana explícita pode resolvê-lo de forma coerente.
70. **O modelo não distinguia “ignorado automaticamente” de “ignorado pelo usuário”.** Foi adicionado `manual_decision`, persistido na sessão e marcado por ações humanas.
71. **Ignorar explicitamente uma pendência sem horas podia ser perdido numa reimportação.** A decisão manual persistida passa a vencer importações futuras da mesma data.
72. **Um `0:00` ignorado automaticamente, mas com OCR de baixa confiança/nota “confira”, podia desaparecer das pendências.** Ignorado automático com alerta continua pedindo decisão; ignorado manual encerra a pendência.
73. **Sessões antigas não possuíam `manual_decision`.** Um valor positivo já salvo como `ignorado` é migrado conservadoramente como decisão humana, porque os parsers automáticos antigos só ignoravam valores zerados.
74. **A UI só tinha uma ação de alternar checkbox, insuficiente para confirmar “ignorar” quando a pendência já vinha desmarcada.** A revisão ganhou ações explícitas e em lote **Aprovar** e **Ignorar**.

### OCR, formatos extremos e parsing defensivo

75. **`por + eng` passava na inspeção de idiomas, mas podia ser enviado com espaços ao Tesseract real.** A especificação é normalizada para `por+eng`, com componentes vazios/duplicados removidos.
76. **TSV malformado com `NaN`, `Inf`, coordenadas negativas ou dimensões inválidas podia contaminar/quebrar o OCR.** Campos numéricos são validados como finitos e a geometria impossível é descartada.
77. **Coordenadas fracionárias malformadas eram truncadas silenciosamente (`10.9 -> 10`).** Geometria TSV precisa ser integral.
78. **O limite de upscale não protegia uma imagem que já chegasse gigantesca.** Existe agora um teto de pixels de origem antes de qualquer decode pesado.
79. **Imagens acima do orçamento de processamento eram mantidas grandes mesmo sem upscale.** O mesmo cálculo passa a reduzir fontes acima do orçamento antes dos filtros.
80. **A lista de prints usava decodificação potencialmente em resolução total para criar ícones pequenos.** `QImageReader` solicita thumbnail escalado ao decoder.
81. **O visualizador também carregava o screenshot inteiro antes de ajustá-lo à janela.** A prévia é decodificada no máximo no tamanho útil do diálogo.
82. **Células numéricas `NaN/Inf` no espelho podiam gerar texto/horas inválidos.** Números não finitos são tratados como célula vazia.
83. **Caminhos/preferências com whitespace incidental eram persistidos literalmente.** Campos textuais relevantes são normalizados com `strip()`.

### CLI, filesystem, concorrência e operação

84. **Uma única imagem ruim abortava a CLI inteira mesmo quando outras entradas eram válidas.** Falhas esperadas de OCR/arquivo são isoladas por imagem e as demais fontes continuam.
85. **Quando todas as imagens falhavam, o resultado não era distinguido claramente de uma execução sem dados.** A CLI retorna erro de processamento e mensagem específica.
86. **Entrada fornecida, mas sem nenhum registro reconhecido, gerava mensagem dizendo para informar uma entrada.** O diagnóstico agora separa erro de uso de erro de reconhecimento.
87. **`os.replace` atômico não garantia que os bytes já estivessem sincronizados em disco.** Temporário recebe `fsync` antes da troca e o diretório POSIX é sincronizado best-effort depois.
88. **Duas instâncias iniciadas no mesmo segundo podiam escolher o mesmo nome de log.** O arquivo é reservado com criação exclusiva e recebe sufixo quando necessário.
89. **Rotação de logs podia falhar se outra instância removesse ou mantivesse um arquivo bloqueado no Windows.** `stat/unlink` concorrentes são tolerados sem impedir o app de iniciar.
90. **Duas adições rápidas com auto-OCR antes do próximo ciclo de eventos podiam deixar o segundo lote sem processamento.** Os novos prints entram numa fila única e são iniciados em conjunto.
91. **Drag-and-drop/pasta importada não atualizava sempre a última pasta usada.** O diretório de entrada é lembrado também nesses fluxos.
92. **Deduplicação de caminhos podia falhar no Windows apenas por diferença de caixa e sessões antigas podiam restaurar o mesmo arquivo mais de uma vez.** A identidade usa caminho resolvido + `normcase`.
93. **Erro de permissão durante varredura de pasta podia abortar a importação.** Caminhos inacessíveis são contabilizados/ignorados com aviso.
94. **O rollback de batch só registrava o arquivo depois que a geração retornava.** A reserva entra no tracking antes da escrita, fechando a janela após um `KeyboardInterrupt` imediatamente posterior ao save.
95. **O script de build podia reutilizar venv antiga e tinha caminhos de erro pouco confiáveis.** Valida Python >=3.11, valida a própria venv e propaga falha de pip/PyInstaller.
96. **`iniciar.bat` podia usar Python antigo, reinstalar/instalar Tesseract desnecessariamente ou terminar com sucesso depois de falhas.** O launcher valida versão/venv, procura Tesseract no PATH e devolve códigos de erro coerentes.
97. **Scripts auxiliares de execução Windows/Linux e testes ainda tinham regras diferentes dos entrypoints principais.** Todos foram alinhados para Python >=3.11, venv válida e propagação de erro.
98. **Artefatos de pytest/coverage podiam entrar no repositório/ZIP.** `.gitignore` cobre cache e relatórios de cobertura.

### Fluxo Qt e barreiras de revisão

99. **Era possível chegar ao gerador com pendências por caminhos de navegação diferentes do botão principal.** Avançar e botões de exportação respeitam a mesma análise central.
100. **O stepper permitia clicar diretamente em Excel e contornar o bloqueio visual da revisão.** Navegação direta é recusada enquanto houver pendências.
101. **Uma sessão antiga salva na etapa Excel podia reabrir nessa etapa mesmo contendo pendências sob as regras novas.** O restore recua automaticamente para Revisar quando necessário.

## Validações executadas na árvore revisada

- `python -m compileall -q main.py timesheet_app tests`: OK.
- `python -m unittest discover -s tests -q`: **133/133 testes OK**.
- `python -m pytest -q`: **133/133 testes OK**.
- `git diff --check`: OK.
- scanner AST: sem `bare except`, mutable default, `eval/exec`, `subprocess(..., shell=True)` ou definição top-level duplicada.
- scanner simples de imports: imports mortos encontrados na revisão foram removidos (re-export intencional de `ui_qt.__init__` mantido).
- fuzz de parser: **10.000** strings aleatórias sem crash.
- fuzz de deserialização: **5.000** payloads de registro malformados + **1.000** formatos de sessão inválidos sem crash.
- fuzz de consolidação: **800** cenários automáticos válidos, amostrando permutações de ordem, com resultado invariável.
- Tesseract real: `5.5.0`, `por+eng` disponível; na segunda rodada uma imagem sintética legível retornou **13 palavras / 8 linhas**, sem warnings, e foi parseada como `08/06/2026 · 8:00`.
- A planilha histórica de referência foi removida por privacidade; os casos sintéticos e o contrato XLSX versionado permanecem como validação reproduzível.
- geração/reabertura XLSX via openpyxl: OK; atividade padrão, dia da semana, total, formato diário `[h]:mm` e proteção contra fórmula conferidos.
- patch completo aplicado sobre uma extração nova do ZIP original: OK; **133/133 unittest + 133/133 pytest**, reverse-check, AST e smokes funcionais OK.
- a validação em árvore limpa também detectou e descartou uma versão preliminar do artefato que não continha arquivos novos untracked; o patch foi regenerado incluindo explicitamente esses arquivos antes da entrega.

## Limitações conhecidas que não foram “corrigidas por adivinhação”

1. **Calendário de feriados externo:** a detecção de dias úteis ausentes não inventa feriados que não aparecem nos dados. No arquivo de abril/2026, 03/04 e 21/04 aparecem como possíveis lacunas porque não existem como linhas no espelho. A evolução correta é calendário de exceções configurável, já prevista no roadmap.
2. **Runtime visual Qt:** PySide6 não está instalado no container desta revisão. Não é correto afirmar que a janela foi testada visualmente aqui. Recomenda-se CI com PySide6 + `pytest-qt`/modo offscreen e um smoke manual no Windows alvo.
3. **PDF real de produção:** não existe amostra PDF no repositório. O parser PDF foi coberto com tabelas simuladas e contrato de `pdfplumber`, mas deve receber uma amostra anonimizada real quando disponível.
4. **OCR depende do Tesseract externo:** o app valida binário/idiomas e trata falhas, mas a qualidade final ainda depende da instalação e do conteúdo dos prints.
5. **Detecção de “dias ausentes” é heurística:** hoje encontra lacunas úteis entre datas observadas dentro de cada mês; início/fim da competência e feriados não presentes precisam de regra de calendário para validação definitiva.

## Conclusão

O patch revisado fortalece principalmente o que mais importa para uso pessoal recorrente: decisões manuais não são desfeitas por automação, estado corrompido falha fechado, a exportação tem barreiras próprias, gravações são atômicas, batch tem rollback, nomes automáticos são reservados sem corrida, OCR não esconde bug de código e parsers são mais tolerantes a formatos reais.

O próximo investimento de maior retorno continua sendo OCR incremental por hash/cache + revisão visual lado a lado + calendário de exceções/feriados + histórico mensal. Esses itens ampliam produtividade sem enfraquecer as garantias adicionadas nesta revisão.
