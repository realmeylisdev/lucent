import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucent/features/display_lab/cubit/display_lab_cubit.dart';
import 'package:lucent/features/display_lab/models/lab_pattern_catalog.dart';
import 'package:lucent/features/display_lab/view/pattern_viewer_page.dart';
import 'package:lucent/features/display_lab/view/pixel_fixer_page.dart';
import 'package:lucent/features/display_lab/widgets/pattern_tile.dart';

/// Display Lab entry: a dark catalog browser. Pick a category, then a pattern
/// tile to enter the full-screen viewer. Also opens the Pixel Fixer.
class DisplayLabPage extends StatelessWidget {
  const DisplayLabPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
    builder: (_) => BlocProvider(
      create: (_) => DisplayLabCubit(),
      child: const DisplayLabPage(),
    ),
    fullscreenDialog: true,
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.85),
          radius: 1.3,
          colors: [cs.surfaceContainerHigh, cs.surface],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Display Lab'),
          actions: [
            TextButton.icon(
              onPressed: () => unawaited(
                Navigator.of(context).push(PixelFixerPage.route()),
              ),
              icon: const Icon(Icons.healing_outlined),
              label: const Text('Pixel Fixer'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: const _CatalogBody(),
      ),
    );
  }
}

class _CatalogBody extends StatelessWidget {
  const _CatalogBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DisplayLabCubit, DisplayLabState>(
      builder: (context, state) {
        final cubit = context.read<DisplayLabCubit>();
        final categories = LabPatternCatalog.categories;
        final patterns = LabPatternCatalog.byCategory(state.activeCategory);
        return Column(
          children: [
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final category in categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(category.label),
                        selected: state.activeCategory == category,
                        onSelected: (_) => cubit.selectCategory(category),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 240,
                  childAspectRatio: 1.3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: patterns.length,
                itemBuilder: (context, index) {
                  final pattern = patterns[index];
                  return PatternTile(
                    pattern: pattern,
                    onTap: () {
                      cubit.openPattern(pattern);
                      unawaited(
                        Navigator.of(
                          context,
                        ).push(PatternViewerPage.route(context)),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
