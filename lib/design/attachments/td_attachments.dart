/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// Anhang-Bausteine des Design-Systems (Auswahl, Galerie, Liste, Vollbild).
/// Kalender und Aufgaben nutzen dieselben Widgets; der Storage-Pfad kommt
/// vom Aufrufer über den [AttachmentService].
///
/// `import 'package:togetherdo/design/attachments/td_attachments.dart';`
library;

export '../../services/attachment_service.dart';
export 'anhang_texte.dart';
export 'td_anhang_auswahl.dart';
export 'td_anhang_bild.dart';
export 'td_anhang_galerie.dart';
export 'td_anhang_vollbild.dart';
