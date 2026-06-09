# Notas & Avisos

App Android (Flutter) de **notas e lembretes** que disparam por **hora** ou por
**localização** (geofence) — ou pelos dois ao mesmo tempo. Pensada para o
dia‑a‑dia: «avisa‑me quando chegar à horta», «todos os dias às 8h», «só entre
as 9h e as 18h neste fim‑de‑semana».

> Tema escuro, verde‑lima, mapa OpenStreetMap, armazenamento local (Hive) e
> monitorização de localização em segundo plano com baixo consumo de bateria.

---

## Índice

- [Funcionalidades](#funcionalidades)
- [Como funciona](#como-funciona)
- [Estrutura do projeto](#estrutura-do-projeto)
- [Começar](#começar)
- [Permissões Android](#permissões-android)
- [Testes](#testes)
- [Ferramentas (`tools/`)](#ferramentas-tools)
- [Backup / Restauro](#backup--restauro)
- [Consumo de bateria](#consumo-de-bateria)
- [Stack técnica](#stack-técnica)

---

## Funcionalidades

| Área | Detalhe |
|------|---------|
| **Notas** | Título, descrição, marcar como concluída, arquivar, apagar. |
| **Aviso por hora** | Data/hora únicos ou recorrentes (diário, semanal, mensal). Usa _exact alarms_. |
| **Aviso por localização** | Geofence com raio ajustável (50 m–2 km) sobre OpenStreetMap. |
| **Combinar GPS + tempo** | Restringir o aviso de localização a um **intervalo de horas**, a uma **data** ou a um **período** de datas. |
| **Mapa** | Vê todos os avisos de localização e locais guardados num só mapa, com legenda. |
| **Locais guardados** | Guarda pontos favoritos (casa, horta, trabalho) e reutiliza‑os ao criar notas. |
| **Pesquisa & filtros** | Procura por texto e filtra por _Hora_, _Local_ ou _Concluídas_. |
| **Arquivo** | Notas concluídas saem da lista principal sem serem apagadas; podem ser desarquivadas. |
| **Anular (undo)** | Apagar e arquivar mostram um _snackbar_ com **Anular**. |
| **Backup** | Exporta/importa tudo em JSON (ficheiro + área de transferência). |

## Como funciona

### Avisos por hora
São agendados no [`awesome_notifications`](https://pub.dev/packages/awesome_notifications)
via `NotificationCalendar`. Avisos únicos usam `preciseAlarm`; recorrentes usam
`repeats: true`. Ao concluir/arquivar/apagar a nota, a notificação é cancelada.

### Avisos por localização (geofence)
`LocationService` mantém um _foreground service_ que recebe posições do GPS e,
para cada nota com localização, calcula a distância ao centro do geofence:

```
notificar  ⇔  distância ≤ raio
             ∧ ainda não disparou desde a última entrada
             ∧ restrição de hora/data satisfeita
```

A decisão é lógica **pura** e vive em
[`GeofenceChecker`](lib/services/geofence_checker.dart) +
[`RestrictionChecker`](lib/services/restriction_checker.dart), o que a torna
testável sem plugins. Há **histerese** (`triggerResetMultiplier = 1.5×`): só se
volta a poder notificar depois de sair claramente da zona — evita notificações
repetidas em cima da fronteira.

## Estrutura do projeto

```
lib/
├── main.dart                       # arranque: init Hive/Notifications + re‑agenda alertas
├── theme.dart                      # tema escuro (AppTheme)
├── models/
│   ├── note.dart / note.g.dart     # Note, TimeAlert, LocationAlert (+ adapters Hive escritos à mão)
│   └── saved_place.dart / .g.dart  # SavedPlace
├── services/
│   ├── hive_service.dart           # abertura de boxes e CRUD de notas
│   ├── places_service.dart         # CRUD de locais guardados
│   ├── notification_service.dart   # canais + agendamento de notificações
│   ├── location_service.dart       # foreground service + stream de posições
│   ├── location_config.dart        # constantes de bateria (intervalos, precisão)
│   ├── geofence_checker.dart       # lógica pura: deve disparar? deve repor?
│   ├── restriction_checker.dart    # lógica pura: restrição hora/data satisfeita?
│   ├── note_filter.dart            # lógica pura: pesquisa + filtros da lista
│   └── backup_service.dart         # lógica pura: export/import JSON
├── screens/
│   ├── home_screen.dart            # 3 tabs: Notas · Mapa · Arquivo
│   ├── note_form_screen.dart       # criar/editar nota (alertas + restrições)
│   ├── map_screen.dart             # mapa de avisos + locais guardados
│   ├── location_picker_screen.dart # escolher ponto + raio
│   └── settings_screen.dart        # backup, permissões, sobre
└── widgets/
    └── note_card.dart              # cartão de nota com chips de alerta
test/                               # ver secção «Testes»
tools/                              # scripts de bateria e geração de ícone
```

## Começar

Pré‑requisitos: **Flutter ≥ 3.x** (Dart `^3.12`) e um dispositivo/emulador Android.

```bash
flutter pub get          # instalar dependências
flutter run              # correr em debug num dispositivo ligado
flutter build apk --release   # gerar APK de produção
```

> Os _adapters_ Hive (`*.g.dart`) estão **escritos à mão** e versionados, por
> isso não é preciso correr o `build_runner` para arrancar. Se alterares os
> modelos, regenera com:
> `dart run build_runner build --delete-conflicting-outputs`.

## Permissões Android

| Permissão | Para quê | Quando é pedida |
|-----------|----------|-----------------|
| `POST_NOTIFICATIONS` | mostrar notificações (Android 13+) | no arranque |
| `SCHEDULE_EXACT_ALARM` | avisos por hora exatos (Android 12+) | no arranque |
| `ACCESS_FINE_LOCATION` / `ACCESS_BACKGROUND_LOCATION` | geofencing em segundo plano | ao ativar um aviso por localização |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | manter o serviço vivo com o ecrã desligado | no arranque |

As permissões de localização e de bateria também podem ser (re)pedidas a partir
do ecrã **Definições**.

## Testes

Suite só com testes — sem necessidade de dispositivo:

```bash
flutter test
```

Cobertura atual:

| Ficheiro | O que valida |
|----------|--------------|
| `geofence_checker_test.dart` | regras de disparo/reposição do geofence |
| `restriction_checker_test.dart` | janelas de hora (incl. atravessar a meia‑noite) e datas |
| `backup_service_test.dart` | round‑trip e robustez do export/import JSON |
| `note_filter_test.dart` | pesquisa e filtros (lógica pura) |
| `note_model_test.dart` | valores por omissão e getters do modelo |
| `hive_adapter_test.dart` | round‑trip dos adapters escritos à mão (write→close→reopen→read) |
| `note_card_test.dart` | cartão: strikethrough, botões e chips de alerta |
| `home_screen_test.dart` | tabs Notas/Arquivo e estados vazios |
| `home_search_test.dart` | campo de pesquisa e chips de filtro |
| `battery_config_test.dart` | limites de bateria em `LocationConfig` |

```bash
flutter test --coverage   # gera coverage/lcov.info
```

## Ferramentas (`tools/`)

- **`battery_test.ps1`** — mede via ADB o consumo do serviço de localização e
  produz um `battery_dump_*.txt` (ignorado pelo Git). Útil para validar que os
  parâmetros de `LocationConfig` se mantêm «balanced power».
- **`gen_icon.py`** — gera o ícone da app (pin verde‑lima em fundo escuro).

## Backup / Restauro

Em **Definições → Exportar backup** gera‑se um JSON com todas as notas e locais,
copiado para a área de transferência e guardado num ficheiro
`notas_backup_AAAAMMDD_HHMMSS.json`. Formato (resumido):

```json
{
  "version": 1,
  "exportedAt": "2026-06-09T10:00:00.000",
  "notes":  [ { "id": "…", "title": "…", "timeAlert": { … }, "locationAlert": { … } } ],
  "places": [ { "id": "…", "name": "…", "latitude": 39.8, "longitude": -8.08 } ]
}
```

**Restaurar backup** cola o JSON e adiciona/atualiza por `id`, voltando a armar
os alertas das notas ativas. O formato é independente do _layout_ Hive em disco,
por isso sobrevive a mudanças nos adapters.

## Consumo de bateria

`LocationConfig` centraliza o compromisso precisão↔bateria:

- Monitorização contínua a **precisão média** (célula/Wi‑Fi, evita o chip GPS).
- Intervalo de **15 s** entre posições.
- Uma única leitura de **alta precisão** (`checkNow()`) no arranque e ao guardar
  uma nota, com _timeout_ de 10 s.

Estes valores têm guardas em `battery_config_test.dart` para não regredirem.

## Stack técnica

Flutter · Hive · geolocator · flutter_map (OpenStreetMap) · awesome_notifications ·
permission_handler · intl · uuid · path_provider.
