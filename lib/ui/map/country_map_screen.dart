import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/city.dart';
import '../../domain/entities/country.dart';
import '../../providers.dart';
import '../travel/city_atlas_screen.dart';
import 'city_marker_layout.dart';
import 'country_map_painter.dart';
import 'country_outline.dart';
import 'country_outlines_data.dart';

class CountryMapScreen extends ConsumerWidget {
  const CountryMapScreen({required this.country, super.key});

  final Country country;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cities = ref.watch(citiesProvider(country));

    return Scaffold(
      appBar: AppBar(title: Text('Explore ${country.labelEn}')),
      body: SafeArea(
        child: cities.when(
          loading: () => Center(
            child: Semantics(
              label: 'Loading cities',
              child: const CircularProgressIndicator(),
            ),
          ),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'Couldn’t load cities',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('Check your connection and try again.'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => ref.invalidate(citiesProvider(country)),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
          data: (items) => _CountryMapContent(country: country, cities: items),
        ),
      ),
    );
  }
}

class _CountryMapContent extends StatelessWidget {
  const _CountryMapContent({required this.country, required this.cities});

  final Country country;
  final List<City> cities;

  @override
  Widget build(BuildContext context) {
    final outline = kOutlineByCountry[country]!;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${country.flag} Choose a city',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Pick a destination to prepare phrases for your trip.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    height: math.min(constraints.maxWidth * 0.72, 360),
                    child: _CityMap(
                      outline: outline,
                      cities: cities,
                      onSelected: (city) => _selectCity(context, city),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final city in cities)
                      ActionChip(
                        key: ValueKey('city-chip-${city.id}'),
                        avatar: const Icon(Icons.location_on_rounded, size: 18),
                        label: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(city.nameEn),
                            Text(
                              city.nameLocal,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        onPressed: () => _selectCity(context, city),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectCity(BuildContext context, City city) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(arguments: city),
        builder: (_) => CityAtlasScreen(city: city),
      ),
    );
  }
}

class _CityMap extends StatelessWidget {
  const _CityMap({
    required this.outline,
    required this.cities,
    required this.onSelected,
  });

  final CountryOutline outline;
  final List<City> cities;
  final ValueChanged<City> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final placements = layoutCityMarkers(
          outline: outline,
          cities: cities,
          size: size,
        );

        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: CountryMapPainter(outline)),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _MarkerLeaderPainter(placements)),
              ),
            ),
            for (final placement in placements)
              _positionedMarker(context, placement),
          ],
        );
      },
    );
  }

  Widget _positionedMarker(
    BuildContext context,
    CityMarkerPlacement placement,
  ) {
    final city = placement.city;
    return Positioned(
      left: placement.rect.left,
      top: placement.rect.top,
      child: Semantics(
        label: '${city.nameEn}, ${city.nameLocal}',
        button: true,
        child: Tooltip(
          message: city.nameEn,
          child: Material(
            key: ValueKey('city-marker-${city.id}'),
            color: Theme.of(context).colorScheme.primary,
            shape: const CircleBorder(),
            elevation: 2,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onSelected(city),
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: placement.touchSize,
                height: placement.touchSize,
                child: Icon(
                  Icons.location_on_rounded,
                  size: 24,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkerLeaderPainter extends CustomPainter {
  const _MarkerLeaderPainter(this.placements);

  final List<CityMarkerPlacement> placements;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0x996B5E4F)
      ..strokeWidth = 1.5;
    final anchor = Paint()..color = const Color(0xFF6B5E4F);
    for (final placement in placements) {
      if ((placement.center - placement.anchor).distance > 2) {
        canvas.drawLine(placement.anchor, placement.center, line);
        canvas.drawCircle(placement.anchor, 3, anchor);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MarkerLeaderPainter oldDelegate) => true;
}
