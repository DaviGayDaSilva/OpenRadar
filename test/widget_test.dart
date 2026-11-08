import 'package:flutter_test/flutter_test.dart';
import 'package:openradar/models/radar_frame.dart';
import 'package:openradar/services/lightning_service.dart';

void main() {
  group('RadarTimeline', () {
    test('constroi quadros passados e nowcast a partir do JSON real', () {
      final json = {
        'host': 'https://tilecache.rainviewer.com',
        'radar': {
          'past': [
            {'time': 1700000000, 'path': '/v2/radar/1700000000'},
          ],
          'nowcast': [
            {'time': 1700000600, 'path': '/v2/radar/nowcast_1700000600'},
          ],
        },
        'generated': 1700000000,
      };
      final timeline = RadarTimeline.fromJson(json);
      expect(timeline.past.length, 1);
      expect(timeline.nowcast.length, 1);
      expect(timeline.all.length, 2);
      expect(timeline.latest?.path, '/v2/radar/1700000000');
      expect(
        timeline.tileUrl(timeline.past.first),
        'https://tilecache.rainviewer.com/v2/radar/1700000000/256/{z}/{x}/{y}/4/1_1.png',
      );
    });
  });

  group('LightningService.decodeBlitzortung', () {
    test('decodifica mensagem compacta preservando caracteres UTF-8', () {
      // Caso base: string curta sem sequencias repetidas.
      expect(LightningService.decodeBlitzortung('{"a":111}'), '{"a":111}');
    });

    test('reconstroi sequencias usando dicionario LZW', () {
      // Primeira ocorrencia literal, depois referencia ao dicionario (codigo 256+).
      final input = 'abc${String.fromCharCode(256)}';
      final out = LightningService.decodeBlitzortung(input);
      expect(out.startsWith('abcab'), true);
    });
  });
}
