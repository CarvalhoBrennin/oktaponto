# Design system OktaPonto — "tempo vivo"

Referência curta do redesign de 2026-09. O conceito é que a interface acompanhe
a jornada enquanto ela acontece: **tempo, progresso, jornada**.

## Onde as coisas vivem

| Arquivo | Papel |
| --- | --- |
| `lib/core/design/hf_tokens.dart` | Espaçamento, raio, duração/curva, tamanhos-chave |
| `lib/core/design/hf_semantics.dart` | Cores de estado da jornada (`ThemeExtension`) |
| `lib/core/theme/app_theme.dart` | `ColorScheme` claro/escuro escritos à mão, tipografia e temas de componente |
| `lib/core/ui/` | Primitivas compartilhadas (seção, folha, aviso, selo, vazio/esqueleto, seletor de mês) |
| `lib/features/punch/presentation/workday_visuals.dart` | Tradução única de estado do domínio → cor + ícone + palavra |

## Paleta

Marca: **laranja**. No claro é um laranja forte e saturado (`#C04D08`) sobre
branco e cinzas neutros (`#FAFAF9` → `#E5E5E1`); no escuro é o mesmo laranja
com brilho de neon (`#FF8A3D`) sobre preto e cinza-chumbo (`#0A0A0B` →
`#2A2A2E`).

Os cinzas não têm viés de temperatura de propósito: o laranja é a única cor
quente da tela, e qualquer azul nos neutros brigaria com ele. A seleção da
navegação, o chip do mês e o CTA da jornada usam a família `primary`, então a
marca aparece exatamente onde há ação — não pintando tudo.

O `ColorScheme` é escrito cor a cor em vez de derivado de `fromSeed`: o gerador
tonal lava o laranja no claro e o empurra para pastel no escuro, que é o oposto
do que esta identidade precisa.

Estados da jornada ficam fora do `ColorScheme` porque são conceitos do produto,
não papéis do Material:

| Papel | Significado | Claro | Escuro |
| --- | --- | --- | --- |
| `working` | jornada em andamento | `#C04D08` | `#FF8A3D` |
| `resting` | intervalo | `#1F5F86` | `#7FC0E8` |
| `done` | jornada concluída | `#2C6B4B` | `#7FCBA3` |
| `attention` | pendência a resolver | `#8A5A00` | `#F0C255` |
| `idle` | ainda não aconteceu | `#6B6660` | `#9C978F` |

A jornada em andamento carrega o laranja da marca — é o estado que o app existe
para mostrar. Por consequência o intervalo saiu do âmbar (laranja e âmbar lado a
lado no mesmo anel viram a mesma cor) e virou azul frio, que também lê bem como
"pausa"; o âmbar ficou para a pendência.

**Nenhum estado é comunicado só por cor.** Todo lugar que usa um `HfRole` usa
junto um ícone e uma palavra — `HfStatusBadge`, `WorkdayVisual` e as marcas do
calendário existem para tornar isso o caminho mais fácil.

Todos os pares texto/fundo acima passam em AA (4.5:1) contra a superfície em
que aparecem. O `track` é a exceção proposital: ele é o trilho vazio de anéis
e timelines, nunca carrega estado sozinho, então vale como fundo e não precisa
de contraste de conteúdo.

### O XLSX continua navy

O cabeçalho do timesheet exportado segue em `1F3864`. Isso é contrato
congelado, verificado por `scripts/compare_xlsx_contract.py` contra
`test/goldens/xlsx/reference_contract.json` — a identidade do app mudou, o
formato do arquivo entregue não. Mudar exige um ADR.

## Tipografia

Fonte do sistema, sem dependência nova. `displayLarge` (54sp, tabular) é
reservado ao contador da jornada e ao total do mês; `labelSmall` em caixa alta
e muito espaçado é a sobrelinha de seção. Números de relógio e totais usam
`FontFeature.tabularFigures()` para o contador não dançar a cada minuto.

## Espaço, forma e movimento

- Espaçamento sai de `HfSpace` (4 → 48). Margem de página: 20.
- Raio sai de `HfRadius` (10 / 14 / 20 / 28, mais `hero` e `pill`).
- **Elevação é zero em todo o app.** Hierarquia vem de superfície, borda de
  1px e espaço — nada flutua.
- Movimento entre 180 ms e 340 ms (`HfMotion`), sempre para explicar mudança de
  estado: o anel avança quando uma batida entra, o CTA troca de rótulo com
  transição, o total do mês aparece. Nada fica em movimento permanente.

## Componentes de assinatura

- **`TimeHero`** — arco de 270° com duas leituras. Com jornada configurada,
  mede o progresso rumo à meta do dia e fecha em verde ao atingi-la. Sem
  jornada, divide-se nos quatro registros e acende um segmento por batida —
  inventar uma meta que o usuário nunca informou seria mentir sobre o domínio.
- **`WorkdayTimeline`** — trilho vertical ligando os quatro registros. O trecho
  entre "saída para intervalo" e "retorno" usa a cor de intervalo, então a
  forma conta a história do dia sem legenda.
- **`PunchButton`** — uma ação por contexto, sempre o próximo passo real.
  Concluída, deixa de ser botão e vira estado.

## Regra de domínio preservada

A UI não calcula horas. `WorkDaySummary.workedMinutes` continua sendo o total
autoritativo. `describeWorkday()`
(`lib/features/punch/domain/workday_progress.dart`) apenas acrescenta o tempo
decorrido do período ainda aberto, para exibição, e nunca chega ao timesheet.
O cálculo roda em instantes UTC — comparar `occurredAtLocal` com o agora local
injetaria o fuso do aparelho no contador.

## Jornada configurada e lembretes

A configuração inicial (`lib/features/onboarding/`) pergunta nome, horários e
intervalo, e o resultado vira uma `WorkSchedule`
(`lib/features/schedule/domain/work_schedule.dart`). Dela saem duas coisas:

1. **A meta do dia**, consumida pelo `TimeHero` via `describeWorkday(...,
   targetMinutes:)`. Continua sendo derivação para exibição — os totais
   autoritativos não mudam.
2. **Os lembretes automáticos.** `plannedReminders()` gera os avisos
   recorrentes; com intervalo livre, o fim do intervalo não tem hora marcada e
   é `planBreakReminder()` que arma um aviso pontual a partir da batida real,
   com uma única insistência 15 min depois.

Os avisos da jornada e a lista manual de lembretes passam pelo mesmo agendador
(`syncRecurringReminders`), porque cada um chamando `cancelAll` por conta
própria apagaria os do outro. O aviso de fim de intervalo vive numa faixa de
identificadores separada, que o reagendamento recorrente não toca.

### Por que a jornada não está no SQLite

O schema v1 é um contrato congelado, validado no CI por
`scripts/validate_schema_snapshot.py`, e `onUpgrade` lança em qualquer
migração. A jornada é configuração de comportamento deste aparelho — não entra
no timesheet, não tem auditoria — a mesma categoria do tema, que já mora em
`SharedPreferences`. Levá-la ao banco custaria schema v2, migração e alteração
do contrato de CI sem nenhum ganho.
