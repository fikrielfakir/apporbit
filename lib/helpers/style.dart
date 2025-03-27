import 'package:flutter/material.dart';

class StyleColors{
  mainColor(double opacity){
    return Color(0xFF9E1F63).withOpacity(opacity);
    return Colors.blue.withOpacity(opacity);
  }

  secondColor(double opacity){
    return Colors.red.withOpacity(opacity);
  }

  accentColor(double opacity){
    return Colors.white.withOpacity(opacity);
  }
}