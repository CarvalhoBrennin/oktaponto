# Release e rollback

## Pré-requisitos

- Flutter 3.47.2 stable.
- Java 17 para Android.
- macOS/Xcode para iOS.
- Python 3.13 para o oráculo temporário XLSX.

## Verificação completa

```bash
./scripts/verify_all.sh
```

## Android

```bash
cd app
./tool/bootstrap_platforms.sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build apk --release
flutter build appbundle --release
```

`applicationId`, keystore e Play signing continuam **não especificados**.

## iOS

```bash
cd app
./tool/bootstrap_platforms.sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build ios --release --no-codesign
```

Bundle ID definitivo, Apple Team ID, provisioning, TestFlight/App Store continuam **não especificados**.

## Rollback

O legado foi preservado integralmente em `legacy/python_reference/`. O runtime móvel não depende dele. Uma regressão no exporter Dart deve bloquear release no job `xlsx-contract`; não se deve remover o oráculo Python até a paridade ser comprovada em runner Flutter e aceita.
