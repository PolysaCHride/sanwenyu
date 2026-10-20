import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

/// 时间表：韩国电视台常规档期。
class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key});

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  int _day = DateTime.now().weekday;

  static const Map<int, List<Map<String, String>>> _table =
      <int, List<Map<String, String>>>{
    1: <Map<String, String>>[
      <String, String>{'time': '21:00', 'slot': 'mon_tue', 'note': 'KBS2 / SBS'},
    ],
    2: <Map<String, String>>[
      <String, String>{'time': '21:00', 'slot': 'mon_tue', 'note': 'KBS2 / SBS'},
    ],
    3: <Map<String, String>>[
      <String, String>{'time': '21:00', 'slot': 'wed_thu', 'note': 'MBC / SBS'},
    ],
    4: <Map<String, String>>[
      <String, String>{'time': '21:00', 'slot': 'wed_thu', 'note': 'MBC / SBS'},
    ],
    5: <Map<String, String>>[
      <String, String>{'time': '20:50', 'slot': 'fri_sat', 'note': 'tvN / JTBC'},
    ],
    6: <Map<String, String>>[
      <String, String>{'time': '20:50', 'slot': 'fri_sat', 'note': 'tvN / JTBC'},
      <String, String>{'time': '19:00', 'slot': 'weekend', 'note': 'KBS2 / MBC'},
    ],
    7: <Map<String, String>>[
      <String, String>{'time': '19:00', 'slot': 'weekend', 'note': 'KBS2 / MBC'},
    ],
  };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final L10n l = L10n.of(context);
    final List<Map<String, String>> items = _table[_day] ?? const <Map<String, String>>[];

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            titleSpacing: 0,
            backgroundColor: scheme.surface,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: SafeArea(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: Text(
                    l.tabTimeline,
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w700, fontSize: 28),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 52,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                scrollDirection: Axis.horizontal,
                itemCount: 7,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (BuildContext context, int i) {
                  final int day = i + 1;
                  return ChoiceChip(
                    label: Text(l.weekdayLabel(day)),
                    selected: day == _day,
                    onSelected: (_) => setState(() => _day = day),
                  );
                },
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate(<Widget>[
                for (final Map<String, String> item in items)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: scheme.primaryContainer,
                        child: Icon(Icons.live_tv, size: 20, color: scheme.onPrimaryContainer),
                      ),
                      title: Text(l.slotLabel(item['slot'] ?? '')),
                      subtitle: Text('${item['note']} · ${item['time']}'),
                    ),
                  ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(Icons.info_outline, size: 18, color: scheme.outline),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.timelineNote,
                          style: TextStyle(fontSize: 12, height: 1.5, color: scheme.outline),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
