# Refactor completo de UI/UX — OktaPonto 2026

## Objetivo

O refactor transforma a interface de um conjunto de três telas sequenciais em um **workspace mensal persistente**, com estado da sessão sempre visível, revisão orientada a exceções e ações prioritárias previsíveis.

A regra central foi: **a UI pode mudar totalmente; a regra de negócio não**. Parsing, consolidação, decisões manuais, validação, sessão e geração de Excel continuam nas camadas existentes. A interface apenas apresenta e orquestra essas regras.

## Princípios de produto

1. **Menos decisões repetitivas** — o caminho comum deve ser importar → revisar exceções → gerar.
2. **Estado sempre visível** — prints, registros, pendências e total do mês aparecem no rail lateral.
3. **Exceção antes de detalhe** — a revisão abre focada em pendências e mostra o contexto completo só quando necessário.
4. **Uma ação primária por contexto** — botões de destaque representam a próxima ação natural da etapa.
5. **Erros perto da causa** — validação e feedback aparecem na própria tela/modal antes de depender de mensagens bloqueantes.
6. **Mouse e teclado equivalentes** — atalhos aceleram o fluxo, mas nenhuma função depende deles.
7. **Design system, não estilos soltos** — cor, espaçamento, tipografia, raios, estados e componentes ficam centralizados.
8. **Dados antes de decoração** — densidade visual é usada onde ajuda comparação; superfícies vazias não recebem informação ornamental.

## Nova arquitetura visual

```text
MainWindow
├── TitleBar
│   ├── marca + contexto atual
│   ├── Atalhos
│   ├── Preferências
│   └── controles da janela
├── NavigationRail
│   ├── Entrada
│   ├── Revisão
│   ├── Excel
│   ├── resumo da sessão
│   ├── saúde do OCR
│   └── Novo mês
├── QStackedWidget
│   ├── PrintsPage
│   ├── ReviewPage
│   └── ExportPage
└── StatusBar
```

O antigo stepper horizontal foi retirado do fluxo principal. `StepHeader` permanece apenas como classe de compatibilidade para consumidores externos, sem uso pela aplicação.

## Design system

`timesheet_app/ui_qt/theme.py` agora concentra:

- paleta base e cores semânticas;
- superfícies, bordas e estados de hover/focus/disabled;
- espaçamento e raios;
- escala de UI;
- palette Qt;
- QSS global;
- tipografia baseada na fonte nativa configurada pelo Qt, evitando forçar uma família exclusiva do Windows em outros sistemas.

`widgets.py` concentra os componentes reutilizáveis:

- `PageHeader`;
- `SectionCard`;
- `MetricCard` e `MetricPill`;
- `StateBanner`;
- `EmptyState`;
- `DetailRow`;
- `ActionCard`;
- `DropZone`;
- `NavigationRail`;
- `StatusChip`;
- `ShortcutHint`;
- `Toast`;
- biblioteca de ícones vetoriais via `QPainter`.

Isso evita dependência de assets externos para ícones e mantém aparência consistente em builds PyInstaller.

## Shell e navegação

### Rail lateral persistente

A navegação passou a ocupar uma coluna fixa à esquerda e mostra:

- etapa atual;
- número de prints;
- número de registros;
- pendências;
- total aprovado;
- disponibilidade do OCR;
- acesso a **Novo mês**.

Abaixo do breakpoint de largura, o rail vira modo compacto e mantém os ícones e o status OCR, liberando espaço para os dados.

### Navegação protegida

A etapa Excel continua inacessível quando:

- não existem registros;
- existem pendências de revisão;
- não há nenhum dia aprovado.

Clicar diretamente no rail não contorna essas regras.

### Restauração de sessão

Se uma sessão antiga apontava para Excel, mas as regras atuais detectam pendências, a restauração retorna para Revisão. O shell nunca reabre em uma etapa incompatível com o estado real dos dados.

## Entrada

A página de Entrada foi reorganizada por intenção:

1. área principal de drag-and-drop para prints;
2. cartões rápidos para Espelho e Texto;
3. fila de prints com miniaturas e ações de seleção;
4. estado e progresso do OCR em um card próprio.

Mudanças de UX:

- caminho do Espelho é destacado como alternativa mais precisa ao OCR;
- fila tem estado vazio explícito;
- seleção tem ações contextualizadas;
- mutações ficam bloqueadas enquanto OCR está rodando;
- cancelamento continua disponível;
- drag-and-drop e cards são operáveis por teclado;
- lista possui nomes/descrições acessíveis;
- thumbnails preservam o limite de memória já implementado.

## Revisão

A revisão recebeu a maior mudança estrutural.

### Antes

A tabela tentava carregar quase todo o contexto de cada registro, aumentando largura e ruído.

### Agora

A área vira um split-view:

```text
Filtros + busca
┌───────────────────────────────────────┬──────────────────┐
│ Tabela de comparação                  │ Inspector        │
│ Incluir | Data | Dia | Horas | ...   │ Data / status    │
│                                       │ Horas            │
│                                       │ Atividade        │
│                                       │ Confiança        │
│                                       │ Fonte            │
│                                       │ Observações      │
│                                       │ Editar / Print   │
└───────────────────────────────────────┴──────────────────┘
Ações em lote                         Continuar para Excel
```

A tabela ficou limitada ao que é útil para comparação rápida:

- incluir;
- data;
- dia;
- horas;
- status;
- atividade.

Fonte, confiança e observações ficam no inspector do registro selecionado.

### Filtros

- Pendências;
- Todos;
- Aprovados;
- Ignorados;
- Editados;
- busca textual transversal.

Ao resolver a última pendência, o filtro muda automaticamente para **Todos**, evitando uma tela vazia que pareça perda de dados.

### Decisões explícitas

As ações ficam semanticamente claras:

- **Aprovar**;
- **Ignorar**;
- **Editar**;
- **Excluir**;
- **Ver print**.

As mesmas ações podem operar sobre múltiplas linhas quando aplicável.

## Excel

A página final funciona como uma conferência pré-exportação:

- estado de prontidão;
- competência;
- dias aprovados;
- total de horas;
- quantidade de arquivos;
- perfil que irá para o XLSX;
- pasta de destino;
- nomes previstos;
- avisos automáticos;
- feedback de sucesso e ação para abrir a pasta.

Em sessões multi-mês, a UI deixa explícito que será criado um arquivo por competência.

## Diálogos

Todos os modais foram migrados para uma linguagem visual comum, com header próprio e hierarquia consistente.

### Editar registro

- contexto da fonte;
- confiança;
- data + dia calculado;
- horas;
- atividade;
- observações;
- validação inline;
- decisão manual preservada.

### Preferências

As abas genéricas foram substituídas por navegação lateral:

- Perfil;
- OCR;
- Automação.

O conteúdo é rolável para evitar corte em janelas/telas menores.

### Visualizador de print

- Ajustar;
- 100%;
- zoom + / −;
- Ctrl + roda do mouse;
- abrir no sistema;
- limite de pixels tanto na decodificação quanto no bitmap renderizado.

### Atalhos

Uma nova referência interna (`Ctrl+/`) documenta os atalhos sem depender do README.

## Teclado

### Globais da janela principal

| Atalho | Ação |
|---|---|
| `Ctrl+1` | Entrada |
| `Ctrl+2` | Revisão |
| `Ctrl+3` | Excel, se permitido |
| `Ctrl+N` | Novo mês |
| `Ctrl+,` | Preferências |
| `Ctrl+/` | Referência de atalhos |
| `Ctrl+O` | Adicionar prints |
| `Ctrl+Shift+O` | Adicionar pasta |
| `Ctrl+I` | Importar espelho |
| `Ctrl+Shift+I` | Importar texto |
| `Ctrl+F` | Buscar na revisão |

### Contextuais da revisão

| Atalho | Ação |
|---|---|
| `Enter` | Editar seleção |
| `Ctrl+Enter` | Aprovar seleção |
| `Ctrl+Backspace` | Ignorar seleção |
| `Delete` | Excluir seleção |

### Segurança de escopo

Atalhos destrutivos da lista/tabela usam `WidgetWithChildrenShortcut`. Assim `Delete` ou `Enter` não executam uma ação sobre registros enquanto o usuário digita em outro campo. Atalhos globais usam `WindowShortcut`, evitando vazamento para dialogs modais.

## Acessibilidade

O refactor adiciona ou reforça:

- foco visível em botões e inputs;
- navegação completa por teclado nos fluxos principais;
- nomes e descrições acessíveis em rail, DropZone, cards e fila;
- tooltips com atalhos relevantes;
- texto selecionável em caminhos, mensagens e detalhes;
- contraste semântico para sucesso/alerta/erro;
- nenhuma ação crítica comunicada apenas por cor;
- fonte nativa do sistema em vez de família obrigatória exclusiva de uma plataforma.

## Responsividade desktop

A UI não tenta virar uma interface mobile, mas responde a janelas menores:

- rail lateral recolhe;
- inspector da revisão recolhe;
- métricas secundárias são ocultadas;
- banner introdutório da Entrada pode ser reduzido;
- Preferências usa scroll interno;
- cards usam stretch em vez de larguras rígidas sempre que possível.

O breakpoint é calculado em logical pixels do design system.

## Testes do refactor

Além dos testes de negócio, `tests/test_ui_refactor_contracts.py` adiciona contratos estáticos que não dependem de PySide6 instalado no runner. Eles verificam:

- sintaxe de todos os módulos Qt;
- presença do novo NavigationRail;
- ausência de StepHeader no shell;
- primitives visuais compartilhadas;
- split-view/inspector na revisão;
- Preferências sem `QTabWidget`;
- limites de memória do visualizador;
- estados de foco no design system;
- atalhos principais;
- escopo seguro de atalhos destrutivos.

Esses testes não substituem testes de interação com Qt; impedem regressões arquiteturais mesmo em um ambiente sem runtime gráfico.

## Limitação de validação desta execução

O ambiente usado para este refactor não possui PySide6 e não tem acesso de rede funcional para instalá-lo. Por isso não foi possível executar uma sessão gráfica real ou `pytest-qt` nesta máquina.

Foram executados:

- `compileall` de toda a aplicação e testes;
- parsing AST de todos os módulos Qt;
- suíte completa de negócio + contratos estáticos;
- revisão manual das APIs, estados e atalhos;
- reaplicação do patch sobre fonte limpa antes da entrega.

Para fechar a lacuna de teste visual de forma permanente, o próximo passo técnico recomendado é CI Windows com PySide6 + `pytest-qt` em modo headless para automatizar navegação, seleção, dialogs e lifecycle do worker OCR.
