import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette brute — miroir de la collection Figma « Primitives ».
/// Nommée par teinte, jamais utilisée directement dans les écrans :
/// passer par les tokens de [AppTheme], qui portent la fonction.
abstract class _Palette {
  static const Color black           = Color(0xFF000000); // color/black
  static const Color white           = Color(0xFFFFFFFF); // color/white
  static const Color navy950         = Color(0xFF0A0A12); // color/navy-950
  static const Color navy900         = Color(0xFF12122A); // color/navy-900
  static const Color navy800         = Color(0xFF1E1E38); // color/navy-800
  static const Color navy500         = Color(0xFF555577); // color/navy-500
  static const Color lavender400     = Color(0xFF7C7CA8); // color/lavender-400
  static const Color lavender300     = Color(0xFF9999CC); // color/lavender-300
  static const Color purple700       = Color(0xFF6E2D76); // color/purple-700
  static const Color purple700Clear  = Color(0x006E2D76); // color/purple-700-transparent
  static const Color yellow400       = Color(0xFFFFCC01); // color/yellow-400
  static const Color orange500       = Color(0xFFD85A30); // color/orange-500
  static const Color amber400        = Color(0xFFEF9F27); // color/amber-400
  static const Color green500        = Color(0xFF27A862); // color/green-500
  static const Color red500          = Color(0xFFE24B4A); // color/red-500
  static const Color pink500         = Color(0xFFFF2D55); // color/pink-500
}

/// Thème de l'application — miroir de la collection Figma « Thème » (mode Base)
/// du fichier RunSemi — Prototype UI. Chaque token décrit une fonction, pas une couleur.
abstract class AppTheme {
  // ── Fond (color/bg/*) ──────────────────────────────────────────────────────
  static const Color bgApp      = _Palette.black;          // fond de chaque écran
  static const Color bgGlow     = _Palette.purple700;      // halo violet, début du dégradé
  static const Color bgGlowFade = _Palette.purple700Clear; // halo violet, fin transparente

  // ── Surfaces (color/surface/*) ──────────────────────────────────────────────
  static const Color surfaceCard     = _Palette.navy900; // cartes, popups, tuiles de stats
  static const Color surfaceCardHero = _Palette.black;   // carte de séance de l'accueil
  static const Color surfaceRaised   = _Palette.navy800; // pistes, puces, éléments posés sur une carte
  static const Color surfaceSunken   = _Palette.navy950; // zones en creux

  // ── Texte et icônes (color/text/*) ──────────────────────────────────────────
  static const Color textPrimary     = _Palette.white;
  static const Color textSecondary   = _Palette.lavender400; // libellés, sous-titres
  static const Color textMuted       = _Palette.navy500;     // désactivé, à venir
  static const Color textOnHighlight = _Palette.navy950;     // texte sur accentHighlight

  // ── Bordures (color/border/*) ───────────────────────────────────────────────
  static const Color borderDefault = _Palette.lavender400;
  static const Color borderSubtle  = _Palette.navy500;

  // ── Accents (color/accent/*) ────────────────────────────────────────────────
  /// Action principale : CTA, onglet actif, interrupteurs, sélection (surfaces pleines).
  static const Color accentPrimary   = _Palette.purple700;
  /// Mise en avant fine : progression, pastille de phase, liens, indicateurs, pagination.
  static const Color accentHighlight = _Palette.yellow400;

  // ── Statuts (color/status/*) ────────────────────────────────────────────────
  static const Color statusSuccess      = _Palette.green500;   // terminé, aucune douleur, course
  static const Color statusWarning      = _Palette.amber400;   // légère gêne, en attente
  static const Color statusInfo         = _Palette.lavender300;// marche, récupération
  static const Color statusDanger       = _Palette.red500;     // arrêt, reset, douleur forte
  static const Color statusPainModerate = _Palette.orange500;  // douleur modérée (donnée)

  // ── Marques (color/brand/*) ─────────────────────────────────────────────────
  static const Color brandAppleHealth = _Palette.pink500;

  // ── Barre de navigation (color/nav/*) ───────────────────────────────────────
  static const Color navGlassBg     = Color(0x1AFFFFFF); // blanc 10 %
  static const Color navGlassBorder = Color(0x40FFFFFF); // blanc 25 %

  // ── Espacements (space/*) ───────────────────────────────────────────────────
  static const double space2  = 2;
  static const double space4  = 4;
  static const double space6  = 6;
  static const double space8  = 8;
  static const double space10 = 10;
  static const double space12 = 12;
  static const double space14 = 14;
  static const double space16 = 16;
  static const double space18 = 18;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space30 = 30;
  static const double space32 = 32;
  static const double space40 = 40;
  static const double space48 = 48;

  // ── Rayons (radius/*) ───────────────────────────────────────────────────────
  static const double radius2    = 2;
  static const double radius3    = 3;
  static const double radius8    = 8;
  static const double radius10   = 10;
  static const double radius12   = 12;
  static const double radius14   = 14;
  static const double radius16   = 16;
  static const double radius18   = 18;
  static const double radius20   = 20;
  static const double radius24   = 24;
  static const double radius28   = 28;
  static const double radiusFull = 999;

  // ── Typographie (font/family-titles = Gasoek One, font/family-body = Inter) ─
  static TextStyle h1 = GoogleFonts.gasoekOne(fontSize: 45);           // text/h1
  static TextStyle h2 = GoogleFonts.gasoekOne(fontSize: 32);           // text/h2
  static TextStyle h3 = GoogleFonts.gasoekOne(fontSize: 20);           // text/h3
  static TextStyle h4 = GoogleFonts.gasoekOne(fontSize: 16);           // text/h4
  static TextStyle timerDisplay = GoogleFonts.gasoekOne(fontSize: 80); // text/timer-80
  static const TextStyle heading18 = TextStyle(fontSize: 18, fontWeight: FontWeight.w700); // text/heading-18

  /// Échelle Material utilisée par les écrans via Theme.of(context).textTheme.
  static const TextTheme textTheme = TextTheme(
    displayLarge:   TextStyle(fontSize: 124, fontWeight: FontWeight.bold),
    displayMedium:  TextStyle(fontSize: 100, fontWeight: FontWeight.bold),
    displaySmall:   TextStyle(fontSize: 34, fontWeight: FontWeight.w300),
    headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
    bodyLarge:      TextStyle(fontSize: 16),
    bodyMedium:     TextStyle(fontSize: 16),
    bodySmall:      TextStyle(fontSize: 12),
    labelSmall:     TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
  );
}
