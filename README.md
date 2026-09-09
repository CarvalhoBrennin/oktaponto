# HoraFólio Mobile

Migração integral do HoraFólio desktop para Flutter, offline-first, com as **batidas locais como fonte da verdade**.

## Fluxo

`Entrada → Saída → Retorno → Saída final → Revisão → Fechamento → XLSX → Compartilhar`

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
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

O bootstrap exige Flutter 3.47.2 por padrão, configura Android API 24/36 + Java 17/desugaring e iOS 15.

## Verificação

```bash
./scripts/verify_all.sh
```

Ou manualmente:

```bash
cd app
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

## Build

```bash
cd app
flutter build apk --release
flutter build appbundle --release
# em macOS
flutter build ios --release --no-codesign
```

Signing, IDs definitivos e publicação em lojas permanecem **não especificados**, conforme `docs/DECISIONS.md`.
