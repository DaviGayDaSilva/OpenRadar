import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Entrada de cache com valor, horario de gravacao e TTL.
class CacheEntry {
  CacheEntry(this.value, this.savedAt, this.ttl);

  final dynamic value;
  final DateTime savedAt;
  final Duration ttl;

  bool get isFresh => DateTime.now().difference(savedAt) < ttl;
  DateTime get expiresAt => savedAt.add(ttl);
}

/// Cache em memoria com espelhamento opcional em disco (SharedPreferences).
/// Permite que o app mostre o ultimo dado conhecido quando a rede cai,
/// sempre informando o horario da ultima atualizacao bem-sucedida.
class CacheStore {
  CacheStore._();
  static final CacheStore instance = CacheStore._();

  final Map<String, CacheEntry> _memory = {};
  SharedPreferences? _prefs;
  static const String _prefix = 'openradar_cache_';

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  T? get<T>(String key, {bool allowStale = true}) {
    final e = _memory[key];
    if (e == null) return null;
    if (!allowStale && !e.isFresh) return null;
    return e.value as T?;
  }

  DateTime? savedAt(String key) => _memory[key]?.savedAt;

  bool isFresh(String key) => _memory[key]?.isFresh ?? false;

  Future<void> put(String key, dynamic value, Duration ttl) async {
    _memory[key] = CacheEntry(value, DateTime.now(), ttl);
    // Persiste apenas estruturas serializaveis simples.
    try {
      final encoded = jsonEncode({'t': DateTime.now().toIso8601String(), 'v': value});
      if (encoded.length < 400000) {
        await _prefs?.setString('$_prefix$key', encoded);
      }
    } catch (_) {
      // Valores nao serializaveis permanecem apenas em memoria.
    }
  }

  /// Restaura cache persistido para a memoria no inicio do app.
  Future<void> restore(List<String> keys, Map<String, Duration> ttls) async {
    await init();
    for (final k in keys) {
      final raw = _prefs?.getString('$_prefix$k');
      if (raw == null) continue;
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        final savedAt = DateTime.parse(m['t'] as String);
        _memory[k] = CacheEntry(m['v'], savedAt, ttls[k] ?? const Duration(minutes: 10));
      } catch (_) {}
    }
  }

  Future<void> clear() async {
    _memory.clear();
    final keys = _prefs?.getKeys().where((k) => k.startsWith(_prefix)).toList() ?? [];
    for (final k in keys) {
      await _prefs?.remove(k);
    }
  }
}

/// Resultado padronizado de uma chamada remota, com metadados de frescor.
class FetchResult<T> {
  const FetchResult({
    required this.data,
    required this.fetchedAt,
    required this.fromCache,
    this.error,
  });

  final T? data;
  final DateTime fetchedAt;
  final bool fromCache;
  final String? error;

  bool get hasData => data != null;
  bool get isError => error != null;
}

/// Cliente HTTP com timeout, retentativas com backoff, verificacao de
/// conectividade e integracao com o cache.
class ApiClient {
  ApiClient({http.Client? client, this.timeout = const Duration(seconds: 20)})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  static const String userAgent =
      'OpenRadar/1.0 (Flutter; +https://github.com/DaviGayDaSilva/OpenRadar)';

  final ValueNotifier<bool> online = ValueNotifier<bool>(true);
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  void startConnectivityWatch() {
    _connSub ??= Connectivity().onConnectivityChanged.listen((results) {
      online.value = results.any((r) => r != ConnectivityResult.none);
    });
    Connectivity().checkConnectivity().then((results) {
      online.value = results.any((r) => r != ConnectivityResult.none);
    }).catchError((_) {});
  }

  Future<bool> get isOnline async {
    try {
      final r = await Connectivity().checkConnectivity();
      return r.any((c) => c != ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  /// Executa uma requisicao GET retornando o corpo decodificado.
  /// [parser] converte o corpo em texto no objeto desejado.
  Future<T> getJson<T>(
    String url,
    T Function(dynamic json) parser, {
    Map<String, String>? headers,
    int retries = 2,
  }) async {
    final body = await _get(url, headers: headers, retries: retries);
    return parser(jsonDecode(body));
  }

  /// Requisicao GET retornando texto bruto (XML, CSV).
  Future<String> getText(
    String url, {
    Map<String, String>? headers,
    int retries = 2,
    Encoding encoding = utf8,
  }) =>
      _get(url, headers: headers, retries: retries, encoding: encoding);

  Future<String> _get(
    String url, {
    Map<String, String>? headers,
    int retries = 2,
    Encoding encoding = utf8,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        final resp = await _client.get(
          Uri.parse(url),
          headers: {'User-Agent': userAgent, 'Accept': '*/*', ...?headers},
        ).timeout(timeout);
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          online.value = true;
          return encoding.decode(resp.bodyBytes);
        }
        if (resp.statusCode >= 500 && attempt < retries) {
          await Future.delayed(Duration(milliseconds: 400 * (attempt + 1)));
          continue;
        }
        throw ApiException('HTTP ${resp.statusCode} em $url', resp.statusCode);
      } on ApiException {
        rethrow;
      } catch (e) {
        lastError = e;
        online.value = false;
        if (attempt < retries) {
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
        }
      }
    }
    throw ApiException('Falha de conexao com $url: $lastError');
  }

  void dispose() {
    _connSub?.cancel();
    _client.close();
  }
}

class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}
