/// Especificacion de un canal dentro de una plantilla de evento.
class EventTemplateChannel {
  const EventTemplateChannel({
    required this.name,
    required this.code,
    required this.description,
    required this.priority,
    this.isEmergency = false,
  });

  final String name;
  final String code;
  final String description;
  final int priority;
  final bool isEmergency;
}

/// Plantilla de evento: arma canales tipicos en un toque para que el
/// organizador no empiece de cero. El backend siempre crea un canal
/// "Produccion" inicial, asi que las plantillas aportan los canales
/// adicionales (todos menos el de codigo `produccion`).
class EventTemplate {
  const EventTemplate({
    required this.id,
    required this.name,
    required this.tagline,
    required this.icon,
    required this.channels,
  });

  final String id;
  final String name;
  final String tagline;

  /// Nombre de un icono de Material (se resuelve en la UI).
  final String icon;
  final List<EventTemplateChannel> channels;

  /// Canales a crear ademas del "Produccion" inicial del backend.
  List<EventTemplateChannel> get additionalChannels =>
      channels.where((channel) => channel.code != 'produccion').toList();

  static const List<EventTemplate> all = [
    EventTemplate(
      id: 'blank',
      name: 'Evento en blanco',
      tagline: 'Solo el canal de Produccion. Agregas canales despues.',
      icon: 'tune',
      channels: [],
    ),
    EventTemplate(
      id: 'festival',
      name: 'Festival',
      tagline: 'Produccion, Seguridad, Tecnica, Accesos y Emergencia.',
      icon: 'festival',
      channels: [
        EventTemplateChannel(
          name: 'Seguridad',
          code: 'seguridad',
          description: 'Control de accesos, publico y perimetro.',
          priority: 80,
        ),
        EventTemplateChannel(
          name: 'Tecnica',
          code: 'tecnica',
          description: 'Sonido, luces y escenario.',
          priority: 60,
        ),
        EventTemplateChannel(
          name: 'Accesos',
          code: 'accesos',
          description: 'Ingresos, acreditaciones y pulseras.',
          priority: 50,
        ),
        EventTemplateChannel(
          name: 'Emergencia',
          code: 'emergencia',
          description: 'Canal prioritario para SOS y medica.',
          priority: 100,
          isEmergency: true,
        ),
      ],
    ),
    EventTemplate(
      id: 'recital',
      name: 'Recital / Show',
      tagline: 'Produccion, Escenario, Seguridad y Emergencia.',
      icon: 'music_note',
      channels: [
        EventTemplateChannel(
          name: 'Escenario',
          code: 'escenario',
          description: 'Stage manager, banda y cambios de set.',
          priority: 70,
        ),
        EventTemplateChannel(
          name: 'Seguridad',
          code: 'seguridad',
          description: 'Vallas, foso y publico.',
          priority: 80,
        ),
        EventTemplateChannel(
          name: 'Emergencia',
          code: 'emergencia',
          description: 'Canal prioritario para SOS y medica.',
          priority: 100,
          isEmergency: true,
        ),
      ],
    ),
    EventTemplate(
      id: 'corporativo',
      name: 'Evento corporativo',
      tagline: 'Produccion, Salon, Catering y Recepcion.',
      icon: 'business_center',
      channels: [
        EventTemplateChannel(
          name: 'Salon',
          code: 'salon',
          description: 'Coordinacion de sala y oradores.',
          priority: 60,
        ),
        EventTemplateChannel(
          name: 'Catering',
          code: 'catering',
          description: 'Servicio de comida y bebida.',
          priority: 40,
        ),
        EventTemplateChannel(
          name: 'Recepcion',
          code: 'recepcion',
          description: 'Acreditacion e ingreso de invitados.',
          priority: 50,
        ),
      ],
    ),
    EventTemplate(
      id: 'maraton',
      name: 'Maraton / Deportivo',
      tagline: 'Produccion, Recorrido, Hidratacion y Emergencia.',
      icon: 'directions_run',
      channels: [
        EventTemplateChannel(
          name: 'Recorrido',
          code: 'recorrido',
          description: 'Postas, cortes de calle y senalizacion.',
          priority: 70,
        ),
        EventTemplateChannel(
          name: 'Hidratacion',
          code: 'hidratacion',
          description: 'Puestos de agua y avituallamiento.',
          priority: 40,
        ),
        EventTemplateChannel(
          name: 'Emergencia',
          code: 'emergencia',
          description: 'Canal prioritario para SOS y medica.',
          priority: 100,
          isEmergency: true,
        ),
      ],
    ),
  ];
}
