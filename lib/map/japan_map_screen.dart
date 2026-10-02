import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/journey_host.dart';
import '../app/journey_scaffold.dart';
import '../navigation/journey_routes.dart';
import '../package_system/journey_catalog.dart';
import '../prefectures/prefecture_screen.dart';
import '../prefectures/unlock_evaluator.dart';
import '../progress/progress_service.dart';
import '../settings/journey_settings.dart';
import 'node_map.dart';

/// Country level: the whole route, in curriculum order. Prefectures with no
/// installed pack are "coming later" - never an error.
class JapanMapScreen extends StatelessWidget {
  const JapanMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<JourneyCatalog>();
    final progress = context.watch<ProgressService>();
    final settings = context.watch<JourneySettings>();
    final host = context.read<JourneyHost>();
    final unlocks = UnlockEvaluator(catalog, progress);

    NodeState stateOf(PrefectureEntry p) {
      if (!p.installed) return NodeState.comingLater;
      if (unlocks.isPrefectureComplete(p.id)) return NodeState.completed;
      return unlocks.isPrefectureUnlocked(p.id) ? NodeState.available : NodeState.locked;
    }

    final nodes = [
      for (final p in catalog.prefectures)
        MapNode(
          id: p.id,
          number: p.route.number,
          label: p.route.name,
          sublabel: p.route.nameEn,
          position: p.route.map,
          state: stateOf(p),
        ),
    ];

    void onTap(MapNode n) {
      switch (n.state) {
        case NodeState.comingLater:
          _say(context, '${n.sublabel ?? n.label} is coming later.');
        case NodeState.locked:
          _say(context, '${n.sublabel ?? n.label} is locked - finish the earlier stops first.');
        case NodeState.available:
        case NodeState.completed:
          zoomInTo<void>(context, PrefectureScreen(prefectureId: n.id));
      }
    }

    return JourneyScaffold(
      title: catalog.index.title,
      leading: host.embedded
          ? IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Close Journey',
              onPressed: () {
                host.onExit?.call();
                Navigator.of(context, rootNavigator: true).pop();
              },
            )
          : null,
      body: Column(
        children: [
          if (!settings.kanaNoticeDismissed) _KanaNotice(onDismiss: settings.dismissKanaNotice),
          Expanded(child: NodeMapView(nodes: nodes, onTap: onTap, aspectRatio: 0.7)),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Schematic map - artwork comes later', style: Theme.of(context).textTheme.labelSmall),
          ),
        ],
      ),
    );
  }
}

void _say(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _KanaNotice extends StatelessWidget {
  const _KanaNotice({required this.onDismiss});
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('kana-notice'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Journey assumes you know hiragana and katakana. If you are not there yet, '
              'please do the kana lessons first - the あ button always opens a quick chart.',
              style: TextStyle(color: cs.onSecondaryContainer),
            ),
          ),
          TextButton(onPressed: onDismiss, child: const Text('Got it')),
        ],
      ),
    );
  }
}
