import 'package:flutter/material.dart';

class WorkGoMotion {
  WorkGoMotion._();
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 350);

  static const Curve curve = Curves.easeOutCubic;
  static const Curve curveIn = Curves.easeInCubic;
  static const Curve curveInOut = Curves.easeInOutCubic;
}
