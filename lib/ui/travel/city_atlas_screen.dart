import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/generation_selection.dart';
import '../../domain/catalog/phrase_catalog.dart';
import '../../domain/entities/city.dart';
import '../../domain/entities/tourist_place.dart';
import '../../providers.dart';
import '../category/category_screen.dart';
import '../generation/generation_screen.dart';
import '../settings/settings_screen.dart';
import '../theme/atlas_theme.dart';
import 'city_atlas_map.dart';

class CityAtlasScreen extends ConsumerStatefulWidget {
  const CityAtlasScreen({required this.city, super.key});

  final City city;

  @override
  ConsumerState<CityAtlasScreen> createState() => _CityAtlasScreenState();
}

class _CityAtlasScreenState extends ConsumerState<CityAtlasScreen> {
  TouristPlace? _selectedPlace;
  bool _detailsOpen = false;

  @override
  Widget build(BuildContext context) {
    final places = ref.watch(touristPlacesProvider(widget.city.id));
    return Scaffold(
      backgroundColor: AtlasTheme.background,
      body: SafeArea(
        child: places.when(
          loading: () => Center(
            child: Semantics(
              label: 'Loading places',
              child: const CircularProgressIndicator(color: AtlasTheme.green),
            ),
          ),
          error: (error, stackTrace) => _AtlasMessage(
            icon: Icons.cloud_off_rounded,
            title: 'Couldn’t load places',
            message: 'Place data is temporarily unavailable. Try again.',
            action: FilledButton.icon(
              onPressed: () =>
                  ref.invalidate(touristPlacesProvider(widget.city.id)),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const _AtlasMessage(
                icon: Icons.location_off_outlined,
                title: 'No places available',
                message: 'There are no featured places for this city yet.',
              );
            }
            final selected = _selectedPlace == null
                ? items.first
                : items.firstWhere(
                    (place) => place.id == _selectedPlace!.id,
                    orElse: () => items.first,
                  );
            return _buildAtlas(items, selected);
          },
        ),
      ),
    );
  }

  Widget _buildAtlas(List<TouristPlace> places, TouristPlace selected) {
    final header = _AtlasHeader(
      city: widget.city,
      onSearch: () => _search(places),
      onSettings: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
    );
    final map = CityAtlasMap(
      places: places,
      selectedPlace: selected,
      onSelected: _selectPlace,
    );
    final sheet = _AtlasSheet(
      places: places,
      selected: selected,
      detailsOpen: _detailsOpen,
      onSelected: _selectPlace,
      onClose: () => setState(() => _detailsOpen = false),
      onScene: _openRecommendedScene,
      onAllSituations: _openAllSituations,
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxHeight < 600) {
              return SingleChildScrollView(
                key: const ValueKey('compact-atlas-scroll'),
                child: Column(
                  children: [
                    header,
                    SizedBox(height: 300, child: map),
                    sheet,
                    const SizedBox(height: 16),
                  ],
                ),
              );
            }
            return Column(
              children: [
                header,
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        bottom: _detailsOpen ? 260 : 250,
                        child: map,
                      ),
                      Align(alignment: Alignment.bottomCenter, child: sheet),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _selectPlace(TouristPlace place) {
    setState(() {
      _selectedPlace = place;
      _detailsOpen = true;
    });
  }

  Future<void> _search(List<TouristPlace> places) async {
    final place = await showSearch<TouristPlace?>(
      context: context,
      delegate: _PlaceSearchDelegate(places),
    );
    if (!mounted || place == null) return;
    _selectPlace(place);
  }

  void _openRecommendedScene(TouristPlace place, RecommendedScene scene) {
    final category = kPhraseCatalog.firstWhere(
      (candidate) => candidate.id == scene.categoryId,
    );
    final subtopic = category.subtopics.firstWhere(
      (candidate) => candidate.id == scene.subtopicId,
    );
    final selection = GenerationSelection(
      city: widget.city,
      category: category,
      subtopic: subtopic,
      place: place,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(arguments: selection),
        builder: (_) => GenerationScreen(selection: selection),
      ),
    );
  }

  void _openAllSituations() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(arguments: widget.city),
        builder: (_) => CategoryScreen(city: widget.city),
      ),
    );
  }
}

class _AtlasHeader extends StatelessWidget {
  const _AtlasHeader({
    required this.city,
    required this.onSearch,
    required this.onSettings,
  });

  final City city;
  final VoidCallback onSearch;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 128,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RoundIconButton(
              tooltip: 'Back',
              icon: Icons.arrow_back_rounded,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(city.nameEn, style: AtlasTheme.display),
                    const SizedBox(height: 7),
                    const Text(
                      'Choose a place to practise for your trip.',
                      style: AtlasTheme.mutedBody,
                    ),
                  ],
                ),
              ),
            ),
            _RoundIconButton(
              tooltip: 'Search places',
              icon: Icons.search_rounded,
              onPressed: onSearch,
            ),
            const SizedBox(width: 6),
            _RoundIconButton(
              tooltip: 'Settings',
              icon: Icons.settings_outlined,
              onPressed: onSettings,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      color: AtlasTheme.heading,
      style: IconButton.styleFrom(
        backgroundColor: AtlasTheme.paper,
        side: const BorderSide(color: AtlasTheme.line),
        minimumSize: const Size.square(AtlasTheme.minimumTarget),
      ),
    );
  }
}

class _AtlasSheet extends StatelessWidget {
  const _AtlasSheet({
    required this.places,
    required this.selected,
    required this.detailsOpen,
    required this.onSelected,
    required this.onClose,
    required this.onScene,
    required this.onAllSituations,
  });

  final List<TouristPlace> places;
  final TouristPlace selected;
  final bool detailsOpen;
  final ValueChanged<TouristPlace> onSelected;
  final VoidCallback onClose;
  final void Function(TouristPlace, RecommendedScene) onScene;
  final VoidCallback onAllSituations;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: detailsOpen ? 390 : 310),
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: AtlasTheme.paper,
        border: Border.fromBorderSide(BorderSide(color: AtlasTheme.line)),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AtlasTheme.sheetRadius),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1C243A32),
            blurRadius: 25,
            offset: Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFD1CEC7),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Flexible(
            child: detailsOpen
                ? _PlaceDetail(
                    place: selected,
                    onClose: onClose,
                    onScene: onScene,
                    onAllSituations: onAllSituations,
                  )
                : ListView.builder(
                    key: const ValueKey('atlas-place-list'),
                    padding: const EdgeInsets.fromLTRB(11, 0, 11, 12),
                    itemCount: places.length,
                    itemBuilder: (context, index) {
                      final place = places[index];
                      return _PlaceRow(
                        place: place,
                        selected: place.id == selected.id,
                        onTap: () => onSelected(place),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.place,
    required this.selected,
    required this.onTap,
  });

  final TouristPlace place;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${place.nameEn}, ${place.nameLocal}',
      button: true,
      selected: selected,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('place-row-${place.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 55),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AtlasTheme.selected : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: selected ? AtlasTheme.green : AtlasTheme.line,
              ),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: AtlasTheme.pin,
                size: 23,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      place.nameEn,
                      style: const TextStyle(
                        color: AtlasTheme.heading,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(place.nameLocal, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceDetail extends StatelessWidget {
  const _PlaceDetail({
    required this.place,
    required this.onClose,
    required this.onScene,
    required this.onAllSituations,
  });

  final TouristPlace place;
  final VoidCallback onClose;
  final void Function(TouristPlace, RecommendedScene) onScene;
  final VoidCallback onAllSituations;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: ValueKey('place-detail-${place.id}'),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: AtlasTheme.pin,
                size: 27,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(place.nameEn, style: AtlasTheme.sectionTitle),
                    Text(place.nameLocal),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close details',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
                constraints: const BoxConstraints.tightFor(
                  width: AtlasTheme.minimumTarget,
                  height: AtlasTheme.minimumTarget,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            place.descriptionEn,
            style: const TextStyle(color: AtlasTheme.muted, height: 1.5),
          ),
          const SizedBox(height: 12),
          const Text(
            'Recommended situations',
            style: TextStyle(
              color: AtlasTheme.green,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          for (var index = 0; index < place.recommendedScenes.length; index++)
            _SceneButton(
              key: ValueKey('recommended-scene-${place.id}-$index'),
              scene: place.recommendedScenes[index],
              onTap: () => onScene(place, place.recommendedScenes[index]),
            ),
          const SizedBox(height: 10),
          SizedBox(
            height: AtlasTheme.minimumTarget,
            child: FilledButton(
              onPressed: onAllSituations,
              style: FilledButton.styleFrom(backgroundColor: AtlasTheme.green),
              child: const Text('All situations'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SceneButton extends StatelessWidget {
  const _SceneButton({required this.scene, required this.onTap, super.key});

  final RecommendedScene scene;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AtlasTheme.minimumTarget,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AtlasTheme.heading,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          side: const BorderSide(color: AtlasTheme.line),
          shape: const RoundedRectangleBorder(),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.chat_bubble_outline_rounded,
              color: AtlasTheme.green,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                scene.labelEn,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _PlaceSearchDelegate extends SearchDelegate<TouristPlace?> {
  _PlaceSearchDelegate(this.places) : super(searchFieldLabel: 'Search places');

  final List<TouristPlace> places;

  List<TouristPlace> get _matches {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return places;
    return places
        .where(
          (place) =>
              place.nameEn.toLowerCase().contains(normalized) ||
              place.nameLocal.toLowerCase().contains(normalized),
        )
        .toList(growable: false);
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        tooltip: 'Clear search',
        onPressed: () => query = '',
        icon: const Icon(Icons.clear_rounded),
      ),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    tooltip: 'Back',
    onPressed: () => close(context, null),
    icon: const Icon(Icons.arrow_back_rounded),
  );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final matches = _matches;
    if (matches.isEmpty) {
      return const Center(child: Text('No matching places'));
    }
    return ListView(
      children: [
        for (final place in matches)
          ListTile(
            minTileHeight: AtlasTheme.minimumTarget,
            leading: const Icon(
              Icons.location_on_rounded,
              color: AtlasTheme.pin,
            ),
            title: Text(place.nameEn),
            subtitle: Text(place.nameLocal),
            onTap: () => close(context, place),
          ),
      ],
    );
  }
}

class _AtlasMessage extends StatelessWidget {
  const _AtlasMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AtlasTheme.muted),
            const SizedBox(height: 12),
            Text(title, style: AtlasTheme.sectionTitle),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (action case final action?) ...[
              const SizedBox(height: 16),
              action,
            ],
          ],
        ),
      ),
    );
  }
}
