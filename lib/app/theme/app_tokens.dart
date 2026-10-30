import 'package:flutter/widgets.dart';

/// Escala de espaçamento única para toda a aplicação.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  static const EdgeInsets page = EdgeInsets.all(lg);
  static const EdgeInsets pageHorizontal = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets card = EdgeInsets.all(lg);
  static const EdgeInsets cardHorizontal = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets listBottom = EdgeInsets.only(bottom: 96);
}

/// Raios de canto partilhados por cartões, campos e botões.
abstract final class AppRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;

  static const BorderRadius card = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius control = BorderRadius.all(Radius.circular(md));
  static const BorderRadius small = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius badge = BorderRadius.all(Radius.circular(pill));
}
