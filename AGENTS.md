# OpenRadar — notas para agentes

Aplicativo Flutter/Dart (Android) de monitoramento meteorologico em tempo real.

## Build e verificacao

```bash
export PATH=/opt/sdk/flutter/bin:$PATH
export ANDROID_SDK_ROOT=/opt/sdk/android ANDROID_HOME=/opt/sdk/android
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64

flutter pub get
flutter analyze        # deve terminar com "No issues found!"
flutter test           # testes unitarios em test/
flutter build apk --release   # build/app/outputs/flutter-apk/app-release.apk
```

Builds longos devem rodar em background com log em arquivo
(`nohup flutter build apk --release > /tmp/build.log 2>&1 &`) e ser
acompanhados com `tail`. O build de release leva ~2-4 min.

## Particularidades do ambiente

- O Android SDK precisa de `platforms;android-34`, `build-tools;34.0.0` e do
  NDK 27.0.12077973. Se o Gradle falhar pedindo um componente, instale com
  `/opt/sdk/android/cmdline-tools/latest/bin/sdkmanager <pacote>`.
- O gradle wrapper depende de `android/gradle/wrapper/gradle-wrapper.jar`;
  se faltar, o build quebra antes de compilar o Dart.

## Arquitetura

- `lib/models` — entidades de dominio; `lib/services` — clientes HTTP das APIs
  reais, cache com TTL e renderizacao de heatmap em isolate.
- `lib/state/weather_controller.dart` — `WeatherController extends ChangeNotifier`,
  servicos injetados pelo construtor. Orquestra polling, streaming e estado das
  camadas; e o ponto unico consumido pelos widgets.
- `lib/widgets/weather_map.dart` — camadas do `flutter_map`. `MarkerOverlay` e
  filho do mapa para acessar `MapCamera.of(context)`.

## Convencoes e limites

- flutter_map 8.x: o widget raiz e `FlutterMap` (nao `MapWidget`) e `TileLayer`
  nao tem `opacity` — use `tileBuilder` com `Opacity`.
- Toda camada precisa de fonte real. Se nao houver fonte publica confiavel,
  marque a camada como indisponivel na UI; nunca simule dados.
- Nao commite o APK nem segredos; o APK vai em GitHub Releases.
