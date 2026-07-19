import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/entities/tourist_place.dart';
import '../theme/atlas_theme.dart';

class CityAtlasMap extends StatelessWidget {
  const CityAtlasMap({
    required this.places,
    required this.selectedPlace,
    required this.onSelected,
    super.key,
  });

  final List<TouristPlace> places;
  final TouristPlace? selectedPlace;
  final ValueChanged<TouristPlace> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactPins =
            constraints.maxWidth < 300 || constraints.maxHeight < 240;
        final pinWidth = compactPins ? 48.0 : 118.0;
        const pinHeight = AtlasTheme.minimumTarget;
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final pinSize = Size(
          math.min(pinWidth, size.width),
          math.min(pinHeight, size.height),
        );
        final placements = _layoutPins(
          places: places,
          size: size,
          pinSize: pinSize,
        );

        return Semantics(
          label: 'Schematic map of tourist places',
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: _AtlasMapPainter()),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _PinLeaderPainter(placements)),
                ),
              ),
              for (final placement in placements)
                Positioned(
                  left: placement.rect.left,
                  top: placement.rect.top,
                  child: Semantics(
                    label:
                        '${placement.place.nameEn}, ${placement.place.nameLocal}',
                    button: true,
                    selected: selectedPlace?.id == placement.place.id,
                    excludeSemantics: true,
                    child: Material(
                      key: ValueKey('place-pin-${placement.place.id}'),
                      color: AtlasTheme.paper,
                      elevation: selectedPlace?.id == placement.place.id
                          ? 5
                          : 2,
                      shadowColor: const Color(0x38243A32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: selectedPlace?.id == placement.place.id
                              ? AtlasTheme.green
                              : AtlasTheme.line,
                          width: selectedPlace?.id == placement.place.id
                              ? 2
                              : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => onSelected(placement.place),
                        child: SizedBox(
                          width: pinSize.width,
                          height: pinSize.height,
                          child: Row(
                            children: [
                              SizedBox(width: compactPins ? 13 : 7),
                              const Icon(
                                Icons.location_on_rounded,
                                color: AtlasTheme.pin,
                                size: 21,
                              ),
                              if (!compactPins) ...[
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        placement.place.nameEn,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AtlasTheme.heading,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        placement.place.nameLocal,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 9.5),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 5),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

List<_PinPlacement> _layoutPins({
  required List<TouristPlace> places,
  required Size size,
  required Size pinSize,
}) {
  final placements = <_PinPlacement>[];
  for (final place in places) {
    final anchor = Offset(place.mapX * size.width, place.mapY * size.height);
    final candidates = <Offset>[];
    for (var y = -4; y <= 4; y++) {
      for (var x = -4; x <= 4; x++) {
        candidates.add(Offset(x * 62.0, y * 54.0));
      }
    }
    candidates.sort((first, second) {
      final distance = first.distanceSquared.compareTo(second.distanceSquared);
      if (distance != 0) return distance;
      return first.dy.compareTo(second.dy);
    });

    Rect? chosen;
    Rect? inBoundsFallback;
    for (final offset in candidates) {
      final left = (anchor.dx - pinSize.width / 2 + offset.dx)
          .clamp(0.0, math.max(0, size.width - pinSize.width))
          .toDouble();
      final top = (anchor.dy - pinSize.height / 2 + offset.dy)
          .clamp(0.0, math.max(0, size.height - pinSize.height))
          .toDouble();
      final candidate = Offset(left, top) & pinSize;
      inBoundsFallback ??= candidate;
      if (placements.every(
        (placement) => !placement.rect.inflate(2).overlaps(candidate),
      )) {
        chosen = candidate;
        break;
      }
    }
    placements.add(
      _PinPlacement(
        place: place,
        anchor: anchor,
        rect: chosen ?? inBoundsFallback ?? (Offset.zero & pinSize),
      ),
    );
  }
  return placements;
}

class _PinPlacement {
  const _PinPlacement({
    required this.place,
    required this.anchor,
    required this.rect,
  });

  final TouristPlace place;
  final Offset anchor;
  final Rect rect;
}

class _PinLeaderPainter extends CustomPainter {
  const _PinLeaderPainter(this.placements);

  final List<_PinPlacement> placements;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = AtlasTheme.muted.withValues(alpha: 0.6)
      ..strokeWidth = 1.25;
    final anchorPaint = Paint()..color = AtlasTheme.pin;
    for (final placement in placements) {
      canvas.drawLine(placement.anchor, placement.rect.center, line);
      canvas.drawCircle(placement.anchor, 2.5, anchorPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PinLeaderPainter oldDelegate) {
    if (placements.length != oldDelegate.placements.length) return true;
    for (var index = 0; index < placements.length; index++) {
      final current = placements[index];
      final previous = oldDelegate.placements[index];
      if (current.place.id != previous.place.id ||
          current.anchor != previous.anchor ||
          current.rect != previous.rect) {
        return true;
      }
    }
    return false;
  }
}

class _AtlasMapPainter extends CustomPainter {
  const _AtlasMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF2F1EB),
    );

    final street = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var index = -1; index < 6; index++) {
      final x = index * size.width / 5;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.width * 0.55, size.height),
        street,
      );
    }
    for (var index = 1; index < 5; index++) {
      final y = index * size.height / 5;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y + size.height * 0.08),
        street,
      );
    }

    final water = Paint()..color = const Color(0xFFC8DFEB);
    final river = Path()
      ..moveTo(size.width * 0.82, -10)
      ..cubicTo(
        size.width * 0.67,
        size.height * 0.2,
        size.width * 0.86,
        size.height * 0.38,
        size.width * 0.72,
        size.height * 0.58,
      )
      ..cubicTo(
        size.width * 0.65,
        size.height * 0.72,
        size.width * 0.9,
        size.height * 0.82,
        size.width * 0.83,
        size.height + 10,
      )
      ..lineTo(size.width, size.height + 10)
      ..lineTo(size.width, -10)
      ..close();
    canvas.drawPath(river, water);

    final park = Paint()..color = const Color(0xFFDFE9DA);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.08,
          size.height * 0.16,
          size.width * 0.24,
          size.height * 0.18,
        ),
        const Radius.circular(18),
      ),
      park,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.12,
          size.height * 0.62,
          size.width * 0.27,
          size.height * 0.2,
        ),
        const Radius.circular(22),
      ),
      park,
    );
  }

  @override
  bool shouldRepaint(covariant _AtlasMapPainter oldDelegate) => false;
}
