import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
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
  final Function(LatLng coordinates)? onMousePrimaryDownMap;
  final Function(LatLng coordinates)? onMousePrimaryDragMap;
  final VoidCallback? onMousePrimaryUpMap;
  final Function(LatLng coordinates)? onMouseDoubleClickMap;
  final MouseCursor cursor;
  final bool panEnabled;

  final Function(LatLng coordinates)? onMapClick;

  const StaticEditorMapWidget({
    super.key,
    required this.onMapCreated,
    required this.onStyleLoaded,
    required this.onCameraMove,
    required this.onCameraIdle,
    this.cursor = MouseCursor.defer,
    this.panEnabled = true,
    this.onMouseHoverMap,
    this.onMousePrimaryDownMap,
    this.onMousePrimaryDragMap,
    this.onMousePrimaryUpMap,
    this.onMouseDoubleClickMap,
    this.onMapClick,
  });

  @override
  State<StaticEditorMapWidget> createState() => _StaticEditorMapWidgetState();
}

class _StaticEditorMapWidgetState extends State<StaticEditorMapWidget> {
  MapLibreMapController? _mapController;
  DateTime? _suppressNativeMapClickUntil;
  Offset? _mousePrimaryDownOffset;
  bool _mousePrimaryMoved = false;
  DateTime? _lastMouseClickAt;
  Offset? _lastMouseClickOffset;

  static const double _mouseClickSlopPx = 8.0;
  static const Duration _mouseDoubleClickMaxDelay = Duration(milliseconds: 320);
  static const double _mouseDoubleClickSlopPx = 14.0;

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
    if (!_hasMouse || _mapController == null) {
      return;
    }
    if (event.kind != PointerDeviceKind.mouse ||
        event.buttons != kPrimaryMouseButton) {
      return;
    }

    _mousePrimaryDownOffset = event.localPosition;
    _mousePrimaryMoved = false;

    // Suprimim temporalment el click nadiu; el manual decidirà si és click o pan.
    _suppressNativeMapClickUntil = DateTime.now().add(
      const Duration(milliseconds: 300),
    );

    if (widget.onMousePrimaryDownMap != null) {
      final latLng = await _mapController!.toLatLng(
        math.Point<num>(event.localPosition.dx, event.localPosition.dy),
      );
      if (!mounted) return;
      widget.onMousePrimaryDownMap!(latLng);
    }
  }

  Future<void> _handleMousePrimaryMove(PointerMoveEvent event) async {
    if (event.kind != PointerDeviceKind.mouse) return;
    final Offset? down = _mousePrimaryDownOffset;
    if (down == null) return;

    final double dx = event.localPosition.dx - down.dx;
    final double dy = event.localPosition.dy - down.dy;
    if ((dx * dx + dy * dy) >= (_mouseClickSlopPx * _mouseClickSlopPx)) {
      _mousePrimaryMoved = true;

      if (widget.onMousePrimaryDragMap != null &&
          _mapController != null &&
          event.buttons == kPrimaryMouseButton) {
        final latLng = await _mapController!.toLatLng(
          math.Point<num>(event.localPosition.dx, event.localPosition.dy),
        );
        if (!mounted) return;
        widget.onMousePrimaryDragMap!(latLng);
      }
    }
  }

  Future<void> _handleMousePrimaryUp(PointerUpEvent event) async {
    if (!_hasMouse || _mapController == null) {
      _mousePrimaryDownOffset = null;
      _mousePrimaryMoved = false;
      return;
    }
    if (event.kind != PointerDeviceKind.mouse) {
      _mousePrimaryDownOffset = null;
      _mousePrimaryMoved = false;
      return;
    }

    final bool shouldTriggerClick =
        _mousePrimaryDownOffset != null && !_mousePrimaryMoved;

    _mousePrimaryDownOffset = null;
    _mousePrimaryMoved = false;

    if (widget.onMousePrimaryUpMap != null) {
      widget.onMousePrimaryUpMap!();
    }

    if (!shouldTriggerClick || widget.onMapClick == null) {
      return;
    }

    final latLng = await _mapController!.toLatLng(
      math.Point<num>(event.localPosition.dx, event.localPosition.dy),
    );
    if (!mounted) return;

    final DateTime now = DateTime.now();
    final Offset currentOffset = event.localPosition;
    final bool isDoubleClick =
        _lastMouseClickAt != null &&
        now.difference(_lastMouseClickAt!) <= _mouseDoubleClickMaxDelay &&
        _lastMouseClickOffset != null &&
        (currentOffset - _lastMouseClickOffset!).distance <=
            _mouseDoubleClickSlopPx;

    _lastMouseClickAt = now;
    _lastMouseClickOffset = currentOffset;

    if (isDoubleClick && widget.onMouseDoubleClickMap != null) {
      widget.onMouseDoubleClickMap!(latLng);
      return;
    }

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
    // 🌐 CONFIGURACIÓ EXCLUSIVA PER A WEB
    if (kIsWeb) {
      return MouseRegion(
        cursor: widget.cursor,
        onHover: _hasMouse ? _handleMouseHover : null,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          // 🛡️ Si el pan està desactivat (p.ex. modal obert), ignorem els
          // events del ratolí perquè no arribin al platform view del mapa.
          onPointerDown: widget.panEnabled ? _handleMousePrimaryDown : null,
          onPointerMove: widget.panEnabled ? _handleMousePrimaryMove : null,
          onPointerUp: widget.panEnabled ? _handleMousePrimaryUp : null,
          child: MapLibreMap(
            compassEnabled: false,
            scrollGesturesEnabled: widget.panEnabled,
            zoomGesturesEnabled: widget.panEnabled,
            doubleClickZoomEnabled: widget.panEnabled,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            styleString: "assets/map/style.json",
            trackCameraPosition: true,
            initialCameraPosition: const CameraPosition(
              target: LatLng(41.98311, 2.82493),
              zoom: 13.0,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              widget.onMapCreated(controller);
            },
            onStyleLoadedCallback: widget.onStyleLoaded,
            onCameraMove: widget.onCameraMove,
            onCameraIdle: widget.onCameraIdle,
            onMapClick: (point, coordinates) {
              final suppressUntil = _suppressNativeMapClickUntil;
              if (suppressUntil != null &&
                  DateTime.now().isBefore(suppressUntil))
                return;
              if (widget.onMapClick != null) widget.onMapClick!(coordinates);
            },
          ),
        ),
      );
    }

    // 📱 CONFIGURACIÓ EXCLUSIVA PER A MÒBIL (APK i iOS)
    // S'eliminen per complet els "MouseRegion" i "Listener" que donen problemes amb els dits
    return MapLibreMap(
      translucentTextureSurface: true,
      compassEnabled: false, // Aquí al mòbil sí que funcionarà perfectament
      scrollGesturesEnabled: widget.panEnabled,
      zoomGesturesEnabled: widget.panEnabled,
      doubleClickZoomEnabled: widget.panEnabled,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      styleString: "assets/map/style.json",
      trackCameraPosition: true,
      initialCameraPosition: const CameraPosition(
        target: LatLng(41.98311, 2.82493),
        zoom: 13.0,
      ),
      onMapCreated: (controller) {
        _mapController = controller;
        widget.onMapCreated(controller);
      },
      onStyleLoadedCallback: widget.onStyleLoaded,
      onCameraMove: widget.onCameraMove,
      onCameraIdle: widget.onCameraIdle,
      onMapClick: (point, coordinates) {
        if (widget.onMapClick != null) widget.onMapClick!(coordinates);
      },
    );
  }
}
