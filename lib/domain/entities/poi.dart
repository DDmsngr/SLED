import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

import 'poi_type.dart';

class Poi extends Equatable {
  const Poi({
    required this.id,
    required this.position,
    required this.type,
    required this.createdAt,
    this.photoPath,
    this.comment,
  });

  final String id;
  final LatLng position;
  final PoiType type;
  final DateTime createdAt;
  final String? photoPath;  // путь к локальному фото (только фото, без голоса)
  final String? comment;    // текстовый комментарий

  bool get hasPhoto => photoPath != null;
  bool get hasComment => comment != null && comment!.isNotEmpty;

  @override
  List<Object?> get props => [id];
}
