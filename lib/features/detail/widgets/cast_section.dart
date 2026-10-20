import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../domain/models/credits.dart';
import '../../../l10n/l10n.dart';

/// 详情页的「主演」横向卡片 + 制作信息。
class CastSection extends StatelessWidget {
  const CastSection({required this.credits, super.key});

  final SeriesCredits credits;

  @override
  Widget build(BuildContext context) {
    final L10n l = L10n.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<String> directors = credits.directors.map((CrewMember c) => c.name).toList();
    final List<String> writers = credits.writers.map((CrewMember c) => c.name).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (credits.cast.isNotEmpty) ...<Widget>[
          Text(l.castSection, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: credits.cast.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (BuildContext context, int index) {
                final CastMember member = credits.cast[index];
                return SizedBox(
                  width: 72,
                  child: Column(
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(36),
                        child: SizedBox(
                          width: 64,
                          height: 64,
                          child: _Avatar(url: member.profileUrl()),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      if (member.character != null && member.character!.isNotEmpty)
                        Text(
                          member.character!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10, color: scheme.outline),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (directors.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${l.director}：${directors.take(2).join(' / ')}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        if (writers.isNotEmpty)
          Text(
            '${l.writer}：${writers.take(2).join(' / ')}',
            style: const TextStyle(fontSize: 12),
          ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String? imageUrl = url;
    if (imageUrl == null) {
      return ColoredBox(
        color: scheme.surfaceContainerHigh,
        child: Icon(Icons.person_outline, color: scheme.outline, size: 28),
      );
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (BuildContext context, String _) =>
          ColoredBox(color: scheme.surfaceContainerHigh),
      errorWidget: (BuildContext context, String _, Object __) => ColoredBox(
        color: scheme.surfaceContainerHigh,
        child: Icon(Icons.person_outline, color: scheme.outline, size: 28),
      ),
    );
  }
}
