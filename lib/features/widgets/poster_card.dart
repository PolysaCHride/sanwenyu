import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// 统一的海报卡片。
class PosterCard extends StatelessWidget {
  const PosterCard({
    required this.title,
    this.cover,
    this.subtitle,
    this.badge,
    this.width = 120,
    this.onTap,
    super.key,
  });

  final String title;
  final String? cover;
  final String? subtitle;
  final String? badge;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AspectRatio(
              aspectRatio: 2 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    if (cover != null && cover!.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: cover!,
                        fit: BoxFit.cover,
                        placeholder: (BuildContext c, String url) =>
                            ColoredBox(color: scheme.surfaceContainerHigh),
                        errorWidget: (BuildContext c, String url, Object e) =>
                            _placeholder(scheme),
                      )
                    else
                      _placeholder(scheme),
                    if (badge != null)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge!,
                            style: TextStyle(fontSize: 10, color: scheme.onPrimary),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.25),
            ),
            if (subtitle != null && subtitle!.isNotEmpty)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: scheme.outline),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme scheme) {
    return ColoredBox(
      color: scheme.surfaceContainerHigh,
      child: Icon(Icons.movie_outlined, color: scheme.outline, size: 28),
    );
  }
}