class WorkGoSpacing {
  WorkGoSpacing._();
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // Touch target minimum per WCAG / PRD
  static const double minTouchTarget = 48.0;

  // Border radius — bumped for premium rounded language
  static const double radiusSm = 10.0;     // Small pills / tags
  static const double radiusMd = 16.0;     // Standard cards / inputs
  static const double radiusLg = 24.0;     // Hero cards / bottom sheets
  static const double radiusXl = 28.0;     // Large hero cards
  static const double radiusFull = 999.0;  // Full pill (buttons, chips, nav)

  // Spacing helpers
  static const double outerMargin = 20.0;  // Screen edge margin
  static const double cardGap = 12.0;      // Gap between cards
  static const double sectionGap = 28.0;   // Gap between sections
}
