# OpenRadar

Monitoramento meteorologico em tempo real, radar de chuva, camadas atmosfericas
e acompanhamento de eventos severos. Desenvolvido em Flutter/Dart para Android.

![OpenRadar](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter) ![Android](https://img.shields.io/badge/Android-APK-3DDC84?logo=android)

## Download

O APK assinado esta disponivel na pagina de
[Releases](https://github.com/DaviGayDaSilva/OpenRadar/releases) deste repositorio.

## Funcionalidades

### Mapa meteorologico
- Mapa interativo (flutter_map + OpenStreetMap) com zoom e deslocamento livres.
- Localizacao atual do usuario (GPS) com botao de recentralizar.
- Rotulos de cidades, estados, paises e fronteiras via tiles do OSM.
- Animacao temporal das imagens de radar.
- Atualizacao automatica dos dados meteorologicos.

### Camadas (combinaveis, com opacidade ajustavel)
| Camada | Fonte real |
| --- | --- |
| Temperatura (2 m, °C) | Open-Meteo |
| Radar de chuva | RainViewer (mosaico global) |
| Tornados | NOAA/NWS (avisos) + SPC Storm Reports (confirmados) |
| Tempestades (CAPE/LI) | Open-Meteo |
| Raios | Blitzortung.org (WebSocket ao vivo) |
| Ventos (10 m, velocidade/direcao) | Open-Meteo |
| Rajadas | Open-Meteo |
| Umidade relativa | Open-Meteo |
| Pressao atmosferica (hPa) | Open-Meteo |
| Nuvens (cobertura %) | Open-Meteo |
| Granizo | Open-Meteo (nivel de congelamento) - indisponivel como observacao |
| Sensacao termica | Open-Meteo |
| Alertas meteorologicos | NOAA/NWS + INMET (quando acessivel) |

### Informacoes detalhadas (ao tocar no mapa)
Temperatura atual, minima e maxima, sensacao termica, vento (velocidade e
direcao), umidade relativa, pressao, probabilidade de chuva, volume de
precipitacao e horario da ultima atualizacao. Inclui a previsao diaria do
CPTEC/INPE para municipios brasileiros.

### Sistema de tornados
Secao dedicada com avisos ativos, ocorrencias confirmadas (SPC Storm Reports),
localizacao, horario, intensidade (escala Fujita quando oficialmente disponivel)
e historico. A interface diferencia claramente observacoes, suspeitas e
confirmacoes. Nenhuma ocorrencia e inventada.

### Linha do tempo do radar
Barra temporal na base do mapa com quadros passados e nowcast do RainViewer:
retroceder, avancar, reproduzir/pausar a animacao, botao LIVE para o quadro mais
recente e exibicao do horario de cada imagem.

### Monitoramento ao vivo
Indicador LIVE, atualizacao periodica por camada respeitando a frequencia de cada
fonte, horario exato da ultima atualizacao por camada, deteccao de dados
atrasados/indisponiveis, tratamento de perda de conexao e reconexao automatica
(WebSocket de raios e polling das demais fontes).

### Interface
Tema escuro profissional inspirado em softwares meteorologicos, mapa em tela
ampla, paineis com efeito de vidro (blur), icones meteorologicos, animacoes
suaves e layout adaptavel para celulares Android.

## Fontes de dados

- **Open-Meteo** - grade meteorologica global (temperatura, vento, umidade, pressao, nuvens, CAPE, sensacao termica).
- **RainViewer** - mosaico global de radar de chuva (passado + nowcast).
- **Blitzortung.org** - deteccao de descargas eletricas em tempo real.
- **NOAA/NWS** - avisos meteorologicos oficiais e alertas.
- **NOAA SPC Storm Reports** - ocorrencias confirmadas de tornado, granizo e vento.
- **CPTEC/INPE** - previsao diaria de municipios brasileiros.
- **INMET** - avisos oficiais (usado quando o servico esta acessivel).
- **OpenStreetMap** - tiles do mapa base.

Camadas sem fonte publica confiavel (por exemplo, observacao de granizo em escala
global) sao sinalizadas explicitamente como indisponiveis na interface, com a
melhor aproximacao disponivel e uma nota honesta. Nenhum dado e simulado.

## Tecnologia

- **Linguagem:** Dart
- **Framework:** Flutter
- **Plataforma inicial:** Android
- Arquitetura modular (models, services, state, widgets, screens).
- Componentes reutilizaveis.
- Cache em memoria com TTL por tipo de dado.
- Tratamento de erros de conexao e reconexao.
- Renderizacao de mapas de calor em isolates para performance em hardware limitado.

## Estrutura do projeto

```
lib/
  core/       tema, formatadores
  models/     entidades de dominio (ponto, radar, alerta, tornado, raio, camada)
  services/   clientes das APIs reais, cache, renderizacao de heatmaps
  state/      WeatherController (ChangeNotifier) - orquestra atualizacoes
  widgets/    mapa, linha do tempo, painel de camadas, paineis de dados
  screens/    tela principal
```

## Build

```bash
flutter pub get
flutter run                 # execucao em dispositivo/emulador
flutter build apk --release # gera build/app/outputs/flutter-apk/app-release.apk
flutter test                # testes unitarios
```

