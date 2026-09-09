# Status da implementação

Data de empacotamento: 2026-09-09.

## Implementado

- Aplicativo Flutter/Dart offline-first, sem backend, login, câmera, localização ou OCR.
- Drift/SQLite com `punches`, `work_days`, `punch_audit`, `profile_settings` e `reminders`.
- Batidas como fonte autoritativa; total diário/mensal é sempre derivado.
- Máquina de estados Entrada → Saída → Retorno → Saída final e bloqueio da quinta batida.
- Validação fail-closed de ordem temporal, tipos, overnight e total >24h.
- Edição, inclusão manual, soft-delete e trilha de auditoria.
- Tela Hoje, Histórico, editor de dia, Mês/fechamento e Configurações.
- Perfil, atividade padrão e override diário.
- Lembretes locais configuráveis por horário/dias da semana.
- Limpeza explícita de dados com confirmação.
- Exportador XLSX Dart separado em builder puro + filesystem, com share sheet nativo.
- Contrato semântico XLSX e oráculo Python congelado.
- CI de qualidade, legado e contrato XLSX; builds Android/iOS separados.
- Bootstrap das pastas nativas com Android API 24/36, Java 17, desugaring e iOS 15.
- `AGENTS.md`, template de PR, documentação e scripts de verificação.

## Validação executada neste ambiente

- `python -m unittest discover -s tests` no legado: **142/142 aprovados**.
- Fixture XLSX gerada pelo legado e normalizada pelo contrato semântico: **aprovada**.
- Verificação explícita de `freeze A7`, gridlines ocultas, `[h]:mm`, `24:00` e proteção de texto iniciado em `=`: **aprovada no oráculo Python**.
- `python -m py_compile` nos scripts Python e `bash -n` nos scripts shell: **aprovados**.

## Gates que exigem runner Flutter

O ambiente usado para montar este pacote não possui Flutter/Dart. Por isso os seguintes gates estão implementados no CI, mas não podem ser honestamente marcados como executados localmente:

- `dart run build_runner build --delete-conflicting-outputs`;
- `dart format --output=none --set-exit-if-changed .`;
- `flutter analyze`;
- `flutter test` e `flutter test integration_test`;
- geração Dart do XLSX e comparação Python × Dart;
- build APK/AAB;
- build iOS sem codesign;
- smoke test em aparelho/simulador;
- QA manual do XLSX em Microsoft Excel e LibreOffice.

`pubspec.lock` e os diretórios `android/`/`ios/` são gerados pelo bootstrap num ambiente com Flutter 3.47.2.

## Decisões propositalmente não inventadas

IDs definitivos do app, signing, publicação nas lojas, política de backup do SO, criptografia extra, histórico desktop → mobile e branding final continuam marcados como **não especificado**, conforme o plano original.
