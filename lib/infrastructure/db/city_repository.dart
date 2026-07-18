import 'package:sqflite/sqflite.dart';
import '../../domain/entities/city.dart';
import '../../domain/entities/country.dart';
import 'row_mappers.dart';

class CityRepository {
  const CityRepository(this._db);
  final Database _db;
  Future<List<City>> listByCountry(Country country) async => (await _db.query(
    'cities',
    where: 'country = ?',
    whereArgs: [country.dbValue],
    orderBy: 'id',
  )).map(cityFromRow).toList();
}
