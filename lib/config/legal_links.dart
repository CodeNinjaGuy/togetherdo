/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// Rechtliche Seiten von SeeBubble Media FlexCo. Einzige Stelle für diese
/// Adressen – App (Profil, Anmeldung, Registrierung) und Store-Einträge
/// verweisen hierauf.
class LegalLinks {
  LegalLinks._();

  static final Uri privacyPolicy = Uri.parse(
    'https://seebubble.me/datenschutz.html',
  );

  static final Uri imprint = Uri.parse('https://seebubble.me/impressum.html');
}
