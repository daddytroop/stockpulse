/// Layout constants shared by every screen, so spacing and corners stay
/// consistent instead of being picked per widget.
class Sp {
  Sp._();

  /// Space between the screen edge and its content.
  static const double page = 16;

  /// Space between two cards or sections.
  static const double gap = 12;

  /// Space between small related items (tiles in a grid, chips in a row).
  static const double gapSmall = 8;

  /// Corner radius of a card.
  static const double radius = 18;

  /// Corner radius of things inside a card: tiles, inputs, buttons.
  static const double radiusSmall = 12;
}
