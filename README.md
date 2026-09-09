# HoraFólio Mobile

Migração do HoraFólio desktop para Flutter, offline-first, com as batidas locais como fonte da verdade.

## Fluxo

`Entrada → Saída → Retorno → Saída final → Fechamento → XLSX → Compartilhar`

## Estrutura

- `app/`: Flutter/Dart runtime móvel.
- `legacy/python_reference/`: implementação Python congelada como oráculo de comportamento/XLSX.
- `scripts/`: contrato semântico do XLSX.
- `docs/`: baseline, decisões e documentação da migração.

## Bootstrap

O projeto mantém `applicationId`/Bundle ID como decisão não especificada. Para gerar as pastas nativas com identificadores temporários de build:

```bash
cd app
./tool/bootstrap_platforms.sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format .
flutter analyze
flutter test
```

## Testes legado

```bash
cd legacy/python_reference
python -m unittest discover -s tests
```

## Build

```bash
cd app
flutter build apk --release
flutter build appbundle --release
# macOS:
flutter build ios --release --no-codesign
```

Signing e publicação permanecem **não especificados**.
