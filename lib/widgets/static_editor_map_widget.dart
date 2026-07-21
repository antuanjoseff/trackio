import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class StaticEditorMapWidget extends StatefulWidget {
  final Function(MapLibreMapController) onMapCreated;
  final VoidCallback onStyleLoaded;
  final Function(CameraPosition) onCameraMove;
  final VoidCallback onCameraIdle;
  final Function(LatLng coordinates)? onMouseHoverMap;
  final MouseCursor cursor;

  final Function(LatLng coordinates)? onMapClick;

  const StaticEditorMapWidget({
    super.key,
    required this.onMapCreated,
    required this.onStyleLoaded,
    required this.onCameraMove,
    required this.onCameraIdle,
    this.cursor = MouseCursor.defer,
    this.onMouseHoverMap,
    this.onMapClick,
  });

  @override
  State<StaticEditorMapWidget> createState() => _StaticEditorMapWidgetState();
}

class _StaticEditorMapWidgetState extends State<StaticEditorMapWidget> {
  MapLibreMapController? _mapController;
  DateTime? _suppressNativeMapClickUntil;

  bool get _hasMouse => RendererBinding.instance.mouseTracker.mouseIsConnected;

  Future<void> _handleMouseHover(PointerHoverEvent event) async {
    if (!_hasMouse ||
        widget.onMouseHoverMap == null ||
        _mapController == null) {
      return;
    }

    final latLng = await _mapController!.toLatLng(
      math.Point<num>(event.localPosition.dx, event.localPosition.dy),
    );
    if (!mounted) return;
    widget.onMouseHoverMap!(latLng);
  }

  Future<void> _handleMousePrimaryDown(PointerDownEvent event) async {
    if (!_hasMouse || widget.onMapClick == null || _mapController == null) {
      return;
    }
    if (event.kind != PointerDeviceKind.mouse ||
        event.buttons != kPrimaryMouseButton) {
      return;
    }

    final latLng = await _mapController!.toLatLng(
      math.Point<num>(event.localPosition.dx, event.localPosition.dy),
    );
    if (!mounted) return;

    _suppressNativeMapClickUntil = DateTime.now().add(
      const Duration(milliseconds: 120),
    );
    widget.onMapClick!(latLng);
  }

  @override
  void initState() {
    super.initState();
    debugPrint("trackio Map initState");
  }

  @override
  void dispose() {
    debugPrint("trackio trackio Map dispose");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("trackio Map build");
    return MouseRegion(
      cursor: widget.cursor,
      onHover: _hasMouse ? _handleMouseHover : null,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _handleMousePrimaryDown,
        child: MapLibreMap(
          key: widget.key,
          compassEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          styleString: "assets/map/style.json",
          trackCameraPosition: true,
          initialCameraPosition: const CameraPosition(
            target: LatLng(41.98311, 2.82493),
            zoom: 13.0,
          ),

          onMapCreated: (controller) {
            debugPrint("trackio Map created");
            _mapController = controller;
            widget.onMapCreated(controller);
          },

          onStyleLoadedCallback: () {
            widget.onStyleLoaded();
          },

          onCameraMove: (pos) {
            widget.onCameraMove(pos);
          },

          onCameraIdle: () {
            widget.onCameraIdle();
          },

          onMapClick: (point, coordinates) {
            final suppressUntil = _suppressNativeMapClickUntil;
            if (suppressUntil != null &&
                DateTime.now().isBefore(suppressUntil)) {
              return;
            }

            if (widget.onMapClick != null) {
              widget.onMapClick!(coordinates);
            }
          },
        ),
      ),
    );
  }
}
