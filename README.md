# OktaPonto Mobile

Migração integral do OktaPonto desktop para Flutter, offline-first, com as **batidas locais como fonte da verdade**.

## Fluxo

`Entrada → Saída → Retorno → Saída final → Revisão → Banco de horas → Fechamento → XLSX → Compartilhar`

## Estrutura

- `app/`: runtime Flutter/Dart móvel.
- `legacy/python_reference/`: implementação Python congelada como oráculo de comportamento/XLSX.
- `scripts/`: contrato semântico Python × Dart e verificação completa.
- `docs/`: baseline, decisões, contrato XLSX, QA e release.
- `.github/`: quality gates, builds e template de PR.

## Bootstrap

O projeto mantém `applicationId`/Bundle ID definitivos como decisão **não especificada**. Para gerar as pastas nativas com IDs temporários de build:

```bash
cd app
./tool/bootstrap_platforms.sh
dart run build_runner build --delete-conflicting-outputs
```

O bootstrap exige Flutter 3.47.2 por padrão, configura Android API 24/36 + Java 17/desugaring e iOS 15.

## Verificação

Checks que não exigem Flutter e, quando o SDK estiver presente, a suíte móvel:

```bash
./scripts/verify_all.sh
```

Gate estrito de release (exige lockfile, goldens e device/emulador):

```bash
cd app
OKTAPONTO_DEVICE_ID=<device-id> ./tool/release_gate.sh
```

Ou manualmente:

```bash
cd app
./tool/bootstrap_platforms.sh
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --coverage
flutter test integration_test -d <device-id>
```

Legado:

```bash
cd legacy/python_reference
python -m unittest discover -s tests
```

Goldens de UI (primeira renderização/atualização dos baselines):

```bash
cd app
./tool/update_goldens.sh
```

Também existe o workflow manual `Render Flutter goldens`, que produz os PNGs em Flutter 3.47.2 como artifact para revisão/commit. Os testes golden falham se os baselines não estiverem versionados; não há skip silencioso.

> Este pacote foi endurecido num host sem Flutter/Dart. Por isso `pubspec.lock` e os PNGs golden não foram fabricados. Gere-os com Flutter 3.47.2 e versione-os antes de uma release; `tool/release_gate.sh` bloqueia a release enquanto isso não acontecer.

## Build

```bash
cd app
./tool/bootstrap_platforms.sh
flutter build apk --release
flutter build appbundle --release
# em macOS
flutter build ios --release --no-codesign
```

Signing, IDs definitivos e publicação em lojas permanecem **não especificados**, conforme `docs/DECISIONS.md`.
