import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/generation_selection.dart';
import '../../domain/catalog/phrase_catalog.dart';
import '../../domain/catalog/practice_catalog.dart';
import '../../domain/entities/city.dart';
import '../../domain/entities/country.dart';
import '../../domain/entities/tourist_place.dart';
import '../../providers.dart';
import '../generation/generation_screen.dart';
import '../theme/atlas_theme.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  Country _country = Country.korea;

  @override
  Widget build(BuildContext context) {
    final groups = practiceGroupsFor(_country);
    return Scaffold(
      backgroundColor: AtlasTheme.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
          children: [
            const Text('Practice', style: AtlasTheme.display),
            const SizedBox(height: 8),
            const Text(
              'Choose a situation and practise useful phrases.',
              style: AtlasTheme.mutedBody,
            ),
            const SizedBox(height: 24),
            _CountrySegments(
              selected: _country,
              onSelected: (country) => setState(() => _country = country),
            ),
            const SizedBox(height: 24),
            const Row(
              children: [
                Expanded(
                  child: Text(
                    'All situations',
                    style: TextStyle(
                      color: AtlasTheme.heading,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _SituationCount(),
              ],
            ),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AtlasTheme.paper,
                border: Border.all(color: AtlasTheme.line),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Column(
                  children: [
                    for (var index = 0; index < groups.length; index++) ...[
                      if (index > 0)
                        const Divider(height: 1, color: AtlasTheme.line),
                      _PracticeGroupRow(
                        key: ValueKey(
                          '${_country.dbValue}-${groups[index].id}',
                        ),
                        group: groups[index],
                        ordinal: index + 1,
                        onSceneSelected: (scene) => _chooseScene(scene),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _chooseScene(RecommendedScene scene) async {
    final city = await showModalBottomSheet<City>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AtlasTheme.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AtlasTheme.sheetRadius),
        ),
      ),
      builder: (_) => _CityChooser(country: _country),
    );
    if (city == null || !mounted) return;
    final category = findCategory(scene.categoryId);
    final subtopic = findSubtopic(scene.categoryId, scene.subtopicId);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GenerationScreen(
          selection: GenerationSelection(
            city: city,
            category: category,
            subtopic: subtopic,
          ),
        ),
      ),
    );
  }
}

class _CountrySegments extends StatelessWidget {
  const _CountrySegments({required this.selected, required this.onSelected});

  final Country selected;
  final ValueChanged<Country> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        border: Border.all(color: AtlasTheme.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final country in Country.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: country == selected,
                label: 'Show ${country.labelEn} practice situations',
                child: SizedBox(
                  height: 44,
                  child: TextButton(
                    key: ValueKey('practice-country-${country.dbValue}'),
                    onPressed: () => onSelected(country),
                    style: TextButton.styleFrom(
                      foregroundColor: country == selected
                          ? Colors.white
                          : const Color(0xFF4B534F),
                      backgroundColor: country == selected
                          ? AtlasTheme.green
                          : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                      minimumSize: const Size(44, 44),
                    ),
                    child: Text(country.labelEn),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SituationCount extends StatelessWidget {
  const _SituationCount();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEFede7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        '15',
        semanticsLabel: '15 situations',
        style: TextStyle(color: AtlasTheme.muted, fontSize: 12),
      ),
    );
  }
}

class _PracticeGroupRow extends StatelessWidget {
  const _PracticeGroupRow({
    required this.group,
    required this.ordinal,
    required this.onSceneSelected,
    super.key,
  });

  final PracticeGroup group;
  final int ordinal;
  final ValueChanged<RecommendedScene> onSceneSelected;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: ValueKey('practice-group-${group.id}'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        minTileHeight: 60,
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: AtlasTheme.green, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$ordinal',
            style: const TextStyle(
              color: AtlasTheme.green,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Text(
          group.labelEn,
          style: const TextStyle(
            color: AtlasTheme.heading,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: const Text(
          '3 situations',
          style: TextStyle(color: AtlasTheme.muted, fontSize: 12),
        ),
        children: [
          KeyedSubtree(
            key: ValueKey('practice-group-panel-${group.id}'),
            child: Column(
              children: [
                for (var index = 0; index < group.scenes.length; index++)
                  SizedBox(
                    width: double.infinity,
                    height: AtlasTheme.minimumTarget,
                    child: OutlinedButton.icon(
                      key: ValueKey('practice-scene-${group.id}-$index'),
                      onPressed: () => onSceneSelected(group.scenes[index]),
                      icon: const Icon(Icons.chat_bubble_outline, size: 19),
                      label: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(group.scenes[index].labelEn),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AtlasTheme.heading,
                        side: const BorderSide(color: AtlasTheme.line),
                        shape: const RoundedRectangleBorder(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CityChooser extends ConsumerWidget {
  const _CityChooser({required this.country});

  final Country country;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cities = ref.watch(citiesProvider(country));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1CEC7),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Choose a city', style: AtlasTheme.sectionTitle),
            const SizedBox(height: 4),
            Text(
              '${country.flag} ${country.labelEn} · where will you practise?',
              style: AtlasTheme.mutedBody,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: cities.when(
                loading: () => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Semantics(
                      label: 'Loading cities',
                      child: const CircularProgressIndicator(
                        color: AtlasTheme.green,
                      ),
                    ),
                  ),
                ),
                error: (_, _) => _CityMessage(
                  icon: Icons.cloud_off_outlined,
                  title: 'Couldn’t load cities',
                  message: 'City data is temporarily unavailable.',
                  action: FilledButton.icon(
                    onPressed: () => ref.invalidate(citiesProvider(country)),
                    icon: const Icon(Icons.refresh_outlined),
                    label: const Text('Try again'),
                  ),
                ),
                data: (items) => items.isEmpty
                    ? const _CityMessage(
                        icon: Icons.location_off_outlined,
                        title: 'No cities available',
                        message: 'Choose a different country and try again.',
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: AtlasTheme.line),
                        itemBuilder: (context, index) {
                          final city = items[index];
                          return Semantics(
                            button: true,
                            label: 'Choose ${city.nameEn}, ${city.nameLocal}',
                            child: ListTile(
                              key: ValueKey('practice-city-${city.id}'),
                              minTileHeight: AtlasTheme.minimumTarget,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              leading: const Icon(
                                Icons.location_on_outlined,
                                color: AtlasTheme.pin,
                              ),
                              title: Text(city.nameEn),
                              subtitle: Text(city.nameLocal),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.pop(context, city),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CityMessage extends StatelessWidget {
  const _CityMessage({
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 38, color: AtlasTheme.muted),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}
