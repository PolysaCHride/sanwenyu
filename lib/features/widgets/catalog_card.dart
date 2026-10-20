import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/style.dart';

/// 目录卡片：封面 + 标题，比例与网格一致。
class CatalogCard extends StatelessWidget {
  const CatalogCard({
    required this.title,
    this.cover,
    this.badge,
    this.onTap,
    this.enableHero = true,
    super.key,
  });

  final String title;
  final String? cover;
  final String? badge;
  final VoidCallback? onTap;
  final bool enableHero;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Widget image = cover == null || cover!.isEmpty
        ? ColoredBox(
            color: scheme.surfaceContainerHigh,
            child: Icon(Icons.movie_outlined, size: 28, color: scheme.outline),
          )
        : CachedNetworkImage(
            imageUrl: cover!,
            fit: BoxFit.cover,
            placeholder: (BuildContext c, String url) =>
                ColoredBox(color: scheme.surfaceContainerHigh),
            errorWidget: (BuildContext c, String url, Object e) => ColoredBox(
              color: scheme.surfaceContainerHigh,
              child: Icon(Icons.broken_image_outlined, size: 24, color: scheme.outline),
            ),
          );

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AspectRatio(
              aspectRatio: Style.coverAspect,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  enableHero ? Hero(tag: 'cover-$title', child: image) : image,
                  if (badge != null && badge!.isNotEmpty)
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(5, 4, 5, 2),
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                    height: 1.25,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}