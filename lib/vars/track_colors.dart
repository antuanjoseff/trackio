import 'package:flutter/material.dart';

class TrackColors {
  static const List<String> paletteHex = [
    '#FF0000', // 1 Vermell
    '#FF2400', // 2 Vermell intens
    '#FF4800', // 3 Vermell-taronja
    '#FF6A00', // 4 Taronja intens
    '#FF8C00', // 5 Taronja
    '#FFAE00', // 6 Taronja-groc
    '#FFD000', // 7 Groc fosc
    '#FFF200', // 8 Groc pur
    '#E4FF00', // 9 Groc-verd
    '#C0FF00', // 10 Verd llima
    '#9CFF00', // 11 Verd llima intens
    '#78FF00', // 12 Verd clar
    '#55FF00', // 13 Verd
    '#31FF00', // 14 Verd intens
    '#0DFF00', // 15 Verd-neó
    '#00FF1E', // 16 Verd turquesa
    '#00FF42', // 17 Turquesa verdós
    '#00FF66', // 18 Turquesa
    '#00FF8A', // 19 Turquesa clar
    '#00FFAE', // 20 Cian verdós
    '#00FFD2', // 21 Cian suau
    '#00FFF6', // 22 Cian pur
    '#00E2FF', // 23 Blau-cian
    '#00BEFF', // 24 Blau cel
    '#009AFF', // 25 Blau clar
    '#0076FF', // 26 Blau intens
    '#0052FF', // 27 Blau pur
    '#002EFF', // 28 Blau fosc
    '#0A00FF', // 29 Blau-violeta
    '#2E00FF', // 30 Violeta intens
    '#5200FF', // 31 Violeta
    '#7600FF', // 32 Violeta clar
    '#9A00FF', // 33 Magenta-violeta
    '#BE00FF', // 34 Magenta intens
    '#E200FF', // 35 Magenta
    '#FF00F6', // 36 Magenta rosat
    '#FF00D2', // 37 Rosa intens
    '#FF00AE', // 38 Rosa
    '#FF008A', // 39 Rosa suau
    '#FF0066', // 40 Rosa fosc
  ];

  static Color fromHex(String hex) {
    return Color(int.parse(hex.replaceAll('#', '0xFF')));
  }
}
