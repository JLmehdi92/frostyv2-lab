import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/home/search/stores/search_store.dart';
import 'package:onset/screens/home/stream_list/stream_card.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/theme.dart';

class SearchRelatedLives extends StatelessWidget {
  const SearchRelatedLives({
    super.key,
    required this.store,
    this.gutter = OnsetSpacing.gutterPhone,
    this.cardWidth = 240,
  });

  final SearchStore store;
  final double gutter;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final window = MediaQuery.paddingOf(context);
    return Observer(
      builder: (context) {
        final streams = store.relatedLives;
        if (streams.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                gutter + window.left,
                20,
                gutter + window.right,
                8,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  context.l10n.searchRelatedLives,
                  style: TextStyle(
                    fontFamily: OnsetTokens.displayFamily,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.015 * 17,
                    color: colors.text,
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.fromLTRB(
                gutter + window.left - 8,
                0,
                gutter + window.right - 8,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final stream in streams)
                    SizedBox(
                      key: ValueKey('related-${stream.userId}'),
                      width: cardWidth,
                      child: MediaQuery.removePadding(
                        context: context,
                        removeLeft: true,
                        removeRight: true,
                        child: StreamCard(
                          streamInfo: stream,
                          showThumbnail: true,
                          tile: true,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
