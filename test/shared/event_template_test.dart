import 'package:event_radio_app/src/shared/domain/event_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('blank template adds no channels beyond default Produccion', () {
    final blank = EventTemplate.all.firstWhere((t) => t.id == 'blank');
    expect(blank.additionalChannels, isEmpty);
  });

  test('festival template includes an emergency channel', () {
    final festival = EventTemplate.all.firstWhere((t) => t.id == 'festival');
    expect(
      festival.additionalChannels.any((channel) => channel.isEmergency),
      isTrue,
    );
  });

  test('additionalChannels never includes the default produccion channel', () {
    for (final template in EventTemplate.all) {
      expect(
        template.additionalChannels.any((channel) => channel.code == 'produccion'),
        isFalse,
        reason: 'template ${template.id} must not duplicate produccion',
      );
    }
  });

  test('every template channel code is unique within the template', () {
    for (final template in EventTemplate.all) {
      final codes = template.channels.map((channel) => channel.code).toList();
      expect(codes.toSet().length, codes.length,
          reason: 'template ${template.id} has duplicate channel codes');
    }
  });

  test('all templates expose a name and tagline', () {
    for (final template in EventTemplate.all) {
      expect(template.name.trim(), isNotEmpty);
      expect(template.tagline.trim(), isNotEmpty);
    }
  });
}
