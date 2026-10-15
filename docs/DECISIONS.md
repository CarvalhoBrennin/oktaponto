# Decisões

| Decisão | Status | Implementação conservadora |
|---|---|---|
| applicationId Android | `com.oktaponto.app` | preservado do APK 2.0.0 para permitir atualização sem trocar de aplicativo |
| Bundle ID iOS | não especificado | bootstrap usa `com.oktaponto.app` apenas para build sem signing |
| Publicação Play Store | não especificado | fora do CI inicial |
| Publicação App Store | não especificado | fora do CI inicial |
| Histórico desktop → mobile | não especificado | fora do MVP |
| Backup automático | não especificado | não é prometido/bloqueado pelo app |
| Criptografia extra SQLite | não especificado | não adicionada sem threat model |
| Tema/branding final | não especificado | Material 3 simples |
| Mais de quatro batidas | não especificado | bloqueado no MVP |
| Jornada overnight | não especificado | tratada como inválida/pendente para revisão |
| Política de segundos | não especificado | timestamps exatos são armazenados; cálculo/export convertem diferenças inteiras para minutos por truncamento |
| Signing Android/iOS | não especificado | não configurado |
