import 'package:flutter/material.dart';

import '../../application/generation_selection.dart';
import '../../domain/catalog/phrase_catalog.dart';
import '../../domain/entities/city.dart';
import '../generation/generation_screen.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({required this.city, super.key});

  final City city;

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Situations')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CityHeading(city: widget.city),
                  const SizedBox(height: 20),
                  Text(
                    'Choose a situation',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Open a category, then choose what you want to practise.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  for (final category in kPhraseCatalog) ...[
                    _CategoryTile(
                      key: ValueKey('category-${category.id}'),
                      city: widget.city,
                      category: category,
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CityHeading extends StatelessWidget {
  const _CityHeading({required this.city});

  final City city;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.location_on_rounded,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    city.nameEn,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text('${city.nameLocal} · ${city.country.labelEn}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.city, required this.category, super.key});

  final City city;
  final PhraseCategory category;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(category.labelEn),
        subtitle: Text('${category.subtopics.length} topics'),
        leading: const Icon(Icons.chat_bubble_outline_rounded),
        children: [
          Column(
            key: ValueKey('category-panel-${category.id}'),
            children: [
              const Divider(height: 1),
              for (final subtopic in category.subtopics)
                ListTile(
                  key: ValueKey('subtopic-${category.id}-${subtopic.id}'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  title: Text(subtopic.labelEn),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _selectSubtopic(context, subtopic),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _selectSubtopic(BuildContext context, Subtopic subtopic) {
    final selection = GenerationSelection(
      city: city,
      category: category,
      subtopic: subtopic,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(arguments: selection),
        builder: (_) => GenerationScreen(selection: selection),
      ),
    );
  }
}
