enum PoiType {
  well,
  trash,
  store,
  viewpoint,
  camp,
  danger,
  other;

  String get label => switch (this) {
        PoiType.well      => 'Колодец',
        PoiType.trash     => 'Мусорка',
        PoiType.store     => 'Магазин',
        PoiType.viewpoint => 'Красивое место',
        PoiType.camp      => 'Стоянка',
        PoiType.danger    => 'Опасность',
        PoiType.other     => 'Другое',
      };

  String get emoji => switch (this) {
        PoiType.well      => '💧',
        PoiType.trash     => '🗑️',
        PoiType.store     => '🏪',
        PoiType.viewpoint => '📸',
        PoiType.camp      => '⛺',
        PoiType.danger    => '⚠️',
        PoiType.other     => '📍',
      };
}
