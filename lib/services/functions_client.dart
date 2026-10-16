/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:cloud_functions/cloud_functions.dart';

/// Region der Cloud Functions (Frankfurt), siehe `functions/src/common.ts`.
const String kFunctionsRegion = 'europe-west3';

/// Zugriff auf die Cloud Functions in [kFunctionsRegion].
FirebaseFunctions get appFunctions =>
    FirebaseFunctions.instanceFor(region: kFunctionsRegion);

/// Ruft die Callable [name] auf und liefert das Ergebnis als JSON-Map.
Future<Map<String, dynamic>> callFunction(
  String name, [
  Map<String, dynamic>? data,
]) async {
  final result = await appFunctions.httpsCallable(name).call<Object?>(data);
  return jsonMapFrom(result.data);
}

/// Wandelt die verschachtelten `Map<Object?, Object?>` der Callable-Antwort
/// in `Map<String, dynamic>` um (für die `fromJson`-Fabriken).
Map<String, dynamic> jsonMapFrom(Object? data) {
  if (data is! Map) return <String, dynamic>{};
  return data.map((key, value) => MapEntry(key.toString(), _jsonValue(value)));
}

Object? _jsonValue(Object? value) {
  if (value is Map) return jsonMapFrom(value);
  if (value is List) return value.map(_jsonValue).toList();
  return value;
}
