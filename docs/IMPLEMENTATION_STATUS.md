# Status da implementação

Data da revisão/hardening: 2026-09-09.

## Implementado

- Aplicativo Flutter/Dart offline-first, sem backend, login, câmera, localização ou OCR.
- Drift/SQLite com `punches`, `work_days`, `punch_audit`, `profile_settings` e `reminders`.
- Batidas como fonte autoritativa; totais são derivados e o fechamento revalida a derivação.
- Máquina de estados Entrada → Saída → Retorno → Saída final e bloqueio da quinta batida.
- Validação fail-closed de ordem temporal, tipos, overnight e total >24h.
- Edição, inclusão manual, soft-delete e trilha de auditoria.
- Tela Hoje com rollover de meia-noite/resume, Histórico, editor de dia, Mês e Configurações.
- Banco de horas mensal derivado das batidas, com horas extras, saldo líquido e movimentações por dia.
- Perfil, atividade padrão e override diário.
- Lembretes com permissão explícita, timezone fail-closed, rollback e reconciliação de startup.
- Reset de banco + exports + notificações + invalidação de estado.
- Exportador XLSX Dart separado em builder puro + filesystem, com proteção contra stale share e overwrite concorrente.
- Contrato semântico XLSX e oráculo Python congelado.
- Schema SQLite v1 congelado e guards de integridade instalados idempotentemente.
- CI de qualidade, legado, contrato XLSX, integração Android e builds Android/iOS.
- Bootstrap das pastas nativas com Android API 24/36, Java 17/desugaring e iOS 15.
- `AGENTS.md`, template de PR, documentação, scripts de verificação e gate de release.

## Validação executada neste ambiente

- Legado: **142/142 testes Python aprovados**.
- Fixture XLSX do legado + contrato semântico: **aprovado**.
- Schema SQLite v1 executado em memória e guards negativos exercitados: **aprovado**.
- `python -m py_compile` nos scripts Python: **aprovado**.
- `bash -n` nos scripts shell: **aprovado**.
- `git diff --check`: **aprovado**.
- Resolução de imports locais dos fontes Dart: **aprovada**.
- YAML dos workflows: **parseado com sucesso** neste host.

## Gates que exigem runner Flutter

O host de montagem não contém Flutter/Dart e o terminal não possui conectividade para baixar o SDK. Portanto estes gates permanecem obrigatórios no CI/release, mas **não são declarados como executados localmente**:

- geração e commit de `pubspec.lock` com Flutter 3.47.2;
- `dart run build_runner build --delete-conflicting-outputs`;
- `dart format --output=none --set-exit-if-changed .`;
- `flutter analyze`;
- `flutter test --coverage`;
- geração inicial e commit dos PNGs golden via `app/tool/update_goldens.sh`;
- `flutter test integration_test -d <device-id>`;
- geração Dart do XLSX e comparação Python × Dart;
- build APK/AAB;
- build iOS sem codesign;
- smoke test em aparelho/simulador;
- QA manual do XLSX em Microsoft Excel e LibreOffice.

O `app/tool/release_gate.sh` falha explicitamente se lockfile, goldens ou device E2E estiverem ausentes. Nada disso é silenciosamente tratado como aprovado.

## Decisões propositalmente não inventadas

IDs definitivos do app, signing, publicação nas lojas, política de backup do SO, criptografia extra, histórico desktop → mobile e branding final continuam **não especificados**, conforme o plano original.
