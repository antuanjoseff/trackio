import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class StaticEditorMapWidget extends StatefulWidget {
  final Function(MapLibreMapController) onMapCreated;
  final VoidCallback onStyleLoaded;
  final Function(CameraPosition) onCameraMove;
  final VoidCallback onCameraIdle;

  const StaticEditorMapWidget({
    super.key,
    required this.onMapCreated,
    required this.onStyleLoaded,
    required this.onCameraMove,
    required this.onCameraIdle,
  });

  @override
  State<StaticEditorMapWidget> createState() => _StaticEditorMapWidgetState();
}

class _StaticEditorMapWidgetState extends State<StaticEditorMapWidget> {
  @override
  Widget build(BuildContext context) {
    return MapLibreMap(
      styleString: "assets/map/style.json",
      initialCameraPosition: const CameraPosition(
        target: LatLng(41.98311, 2.82493),
        zoom: 13.0,
      ),
      onMapCreated: widget.onMapCreated,
      onStyleLoadedCallback: widget.onStyleLoaded,
      onCameraMove: widget.onCameraMove,
      onCameraIdle: widget.onCameraIdle,
    );
  }
}
