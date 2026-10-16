/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'dart:async';

/// Fasst mehrere Listen-Streams zu einem zusammen: Sobald jeder Teil
/// einmal geliefert hat, kommt bei jeder Änderung die Gesamtliste.
/// Ohne Teile liefert der Stream sofort eine leere Liste.
Stream<List<T>> combineLatestLists<T>(List<Stream<List<T>>> parts) {
  if (parts.isEmpty) return Stream.value(const []);
  late StreamController<List<T>> controller;
  final subs = <StreamSubscription<List<T>>>[];
  final latest = List<List<T>?>.filled(parts.length, null);

  void emit() {
    if (latest.any((l) => l == null)) return;
    controller.add([for (final l in latest) ...l!]);
  }

  controller = StreamController<List<T>>(
    onListen: () {
      for (var i = 0; i < parts.length; i++) {
        subs.add(
          parts[i].listen(
            (value) {
              latest[i] = value;
              emit();
            },
            onError: controller.addError,
          ),
        );
      }
    },
    onCancel: () async {
      for (final s in subs) {
        await s.cancel();
      }
    },
  );
  return controller.stream;
}

/// Firestore erlaubt bei `whereIn` höchstens 30 Werte je Abfrage.
Iterable<List<String>> chunked(List<String> ids, [int size = 30]) sync* {
  for (var i = 0; i < ids.length; i += size) {
    yield ids.sublist(i, i + size > ids.length ? ids.length : i + size);
  }
}
