# Correções do code review — 2026-09-09

Este documento registra as correções aplicadas depois do review completo da migração Flutter.

## Bloqueadores corrigidos em código

1. **Export stale / compartilhamento incorreto**
   - O mês exportado recebe uma assinatura determinística de todas as entradas que afetam o XLSX.
   - Antes de compartilhar, mês e perfil são recarregados e a assinatura é recalculada.
   - Alterações de batidas, metadados ou perfil invalidam o compartilhamento do arquivo antigo.

2. **Reset incompleto**
   - O reset remove exports XLSX, batidas, auditoria, work days, perfil e lembretes.
   - As famílias Riverpod de dia/mês e os providers de perfil/lembretes são invalidados.
   - Notificações do SO são canceladas antes do reset.
   - Se a limpeza de exports falhar, o SQLite autoritativo é preservado para que o reset não seja reportado como completo.

3. **Reprodutibilidade**
   - Dependências diretas estão pinadas em versões exatas no `pubspec.yaml`.
   - `tool/verify_lockfile.sh` e `tool/release_gate.sh` bloqueiam release sem `pubspec.lock` versionado.
   - O lockfile não foi fabricado neste host: ele deve ser produzido pelo Flutter 3.47.2 real e versionado.

## Robustez corrigida

- Timezone de lembretes passou a falhar fechado; não há fallback silencioso para UTC.
- Permissão negada impede persistir um lembrete como se estivesse ativo.
- Alterações de lembrete possuem rollback de intenção e restauração best-effort da agenda anterior.
- Startup reconcilia o estado persistido com a agenda do sistema operacional.
- Exportação utiliza criação exclusiva + serialização de processo; duas exportações concorrentes não sobrescrevem o mesmo arquivo.
- Tela Hoje atualiza no resume e na virada de data.
- Offset de horário manual é recalculado no instante escolhido, inclusive em edição.
- Fechamento mensal recalcula cada dia a partir das batidas antes de confiar em status/minutos derivados.
- SQLite instala guards para `kind` e limites de lembretes e preserva FK/índices.
- Schema v1 está congelado em `app/drift_schemas/schema_v1.sql` e validável sem Flutter.
- Erros de perfil, metadata, edição, exclusão, share e reset são apresentados ao usuário sem deixar flags de loading presas.
- Weekdays usam rótulos inequívocos e Semantics.

## Testes e CI adicionados/endurecidos

- Testes de assinatura de origem do timesheet.
- Teste de reset incluindo filesystem.
- Validator mensal com re-derivação e detecção de resumo forjado.
- Export concorrente com nomes únicos.
- Guards do schema exercitados com dados inválidos.
- Integration test conduz o fluxo pela UI.
- Workflow de integração Android cria emulador e executa `integration_test`.
- Goldens não são mais pulados silenciosamente; ausência de baseline é falha explícita.
- Workflow manual `render-goldens.yml` produz os PNGs com Flutter 3.47.2 para serem versionados.
- Actions de Flutter e upload de artefatos foram pinadas por SHA; `upload-artifact` foi elevado para a linha Node 24.
- `scripts/validate_schema_snapshot.py` valida o contrato SQLite v1 independentemente do SDK Flutter.

## Gate de release

A release deve usar:

```bash
cd app
OKTAPONTO_DEVICE_ID=<device-id> ./tool/release_gate.sh
```

O script exige, sem bypass silencioso:

- Flutter/Dart disponíveis;
- bootstrap nativo;
- `pubspec.lock` versionado e limpo;
- baselines golden versionados;
- build_runner;
- format;
- analyze;
- testes Flutter;
- integration test em device/emulador;
- geração Dart do XLSX;
- comparação semântica Python × Dart.

## Limite do host usado nesta correção

Este ambiente não contém Flutter/Dart e não consegue baixá-los pelo terminal. Por isso dois artefatos que só podem ser produzidos honestamente pelo toolchain real permanecem como gate obrigatório, e não como arquivos inventados:

- `app/pubspec.lock`;
- `app/test/goldens/ui/*.png`.

Pelo mesmo motivo, `flutter analyze`, `flutter test`, XLSX Dart × Python e builds Android/iOS não são marcados como executados localmente.
