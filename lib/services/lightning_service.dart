import 'dart:async';
import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

import '../models/lightning_strike.dart';

/// Servico de raios ao vivo.
///
/// Fonte: rede Blitzortung.org. O servidor entrega cada descarga detectada
/// em tempo real por WebSocket, em um formato compactado (LZW customizado)
/// que decodificamos aqui. Nao ha simulacao: se a conexao cai, a interface
/// mostra o estado de reconexao.
class LightningService {
  LightningService();

  static const List<String> _servers = [
    'wss://ws1.blitzortung.org/',
    'wss://ws7.blitzortung.org/',
    'wss://ws8.blitzortung.org/',
  ];

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  Timer? _staleTimer;

  int _serverIndex = 0;
  bool _disposed = false;

  final _strikes = <LightningStrike>[];
  final _controller = StreamController<List<LightningStrike>>.broadcast();

  /// Stream com a lista (janela movel) de descargas mais recentes.
  Stream<List<LightningStrike>> get strikes => _controller.stream;

  List<LightningStrike> get current => List.unmodifiable(_strikes);

  DateTime? lastMessageAt;
  bool connected = false;
  String? lastError;

  /// Mantem descargas das ultimas [window] na lista.
  static const Duration window = Duration(minutes: 45);
  static const int maxStrikes = 4000;

  void connect() {
    if (_disposed) return;
    _open();
    _staleTimer ??= Timer.periodic(const Duration(seconds: 30), (_) => _prune());
  }

  void _open() {
    try {
      final url = _servers[_serverIndex % _servers.length];
      _channel = IOWebSocketChannel.connect(
        Uri.parse(url),
        headers: const {'Origin': 'https://www.blitzortung.org'},
        pingInterval: const Duration(seconds: 30),
        connectTimeout: const Duration(seconds: 15),
      );
      _sub = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: true,
      );
      // Assina o fluxo de dados (formato conhecido do servidor).
      _channel!.sink.add('{"a":111}');
      connected = true;
      lastError = null;
    } catch (e) {
      lastError = e.toString();
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final text = raw is String ? raw : utf8.decode((raw as List<int>), allowMalformed: true);
      final decoded = decodeBlitzortung(text);
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      final lat = (json['lat'] as num?)?.toDouble();
      final lon = (json['lon'] as num?)?.toDouble();
      final t = (json['time'] as num?)?.toInt();
      if (lat == null || lon == null || t == null) return;
      // O tempo vem em nanossegundos desde a epoca.
      final time = DateTime.fromMicrosecondsSinceEpoch(t ~/ 1000, isUtc: true);
      _strikes.add(LightningStrike(
        time: time,
        position: LatLng(lat, lon),
        amplitude: (json['mds'] as num?)?.toInt(),
        region: (json['region'] as num?)?.toInt(),
      ));
      lastMessageAt = DateTime.now();
      connected = true;
      _prune();
      _emit();
    } catch (_) {
      // Mensagens parciais sao ignoradas.
    }
  }

  void _prune() {
    final cutoff = DateTime.now().toUtc().subtract(window);
    _strikes.removeWhere((s) => s.time.isBefore(cutoff));
    if (_strikes.length > maxStrikes) {
      _strikes.removeRange(0, _strikes.length - maxStrikes);
    }
  }

  void _emit() {
    if (!_controller.isClosed) _controller.add(List.unmodifiable(_strikes));
  }

  void _onError(Object e) {
    lastError = e.toString();
    connected = false;
    _scheduleReconnect();
  }

  void _onDone() {
    connected = false;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    final delay = Duration(seconds: (2 + _serverIndex * 2).clamp(2, 12));
    _serverIndex++;
    _reconnectTimer = Timer(delay, () {
      _sub?.cancel();
      _channel?.sink.close();
      _open();
    });
  }

  /// Decodifica o formato compactado do Blitzortung (LZW modificado).
  /// Referencia: implementacao publica do cliente blitzortung (MIT).
  static String decodeBlitzortung(String data) {
    if (data.isEmpty) return '';
    const h = 256;
    final e = <int, String>{};
    final c = data[0];
    var f = c;
    var g = c;
    var o = h;
    for (var i = 1; i < data.length; i++) {
      final ch = data[i];
      final aCode = ch.codeUnitAt(0);
      final String a;
      if (h > aCode) {
        a = ch;
      } else {
        a = e[aCode] ?? '$f$c';
      }
      g += a;
      final cNew = a[0];
      e[o] = '$f$cNew';
      o++;
      f = a;
    }
    return g;
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _staleTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _controller.close();
  }
}
