import 'country.dart';

class City {
  const City({
    required this.id,
    required this.country,
    required this.nameEn,
    required this.nameLocal,
    required this.lat,
    required this.lng,
  });

  final int id;
  final Country country;
  final String nameEn;
  final String nameLocal;

  /// 실제 위경도 (도 단위). 지도 투영은 CountryOutline.normalize가 담당.
  final double lat;
  final double lng;
}
