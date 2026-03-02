// MS CoPilot code mostly
// A single-file Flutter Web demo using the modern web bindings.
// Uses package:web (no dart:html). Works in DartPad after adding the `web` package.
//
// Features:
// - Get current position
// - Watch / Stop watching
// - Display lat/lng/accuracy/timestamp
// - Open in Google Maps
//
// Notes:
// • Geolocation works only in secure contexts (HTTPS) and is permission-gated.
// • In cross-origin iframes, the parent must allow geolocation (Permissions-Policy).
// • This sample uses JS interop (.toJS) to pass Dart closures to JS callbacks.

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;       // modern browser API bindings
import 'dart:js_interop';                   // for .toJS on Dart closures

void main() => runApp(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GeolocationWebDemo(),
    ));

class GeolocationWebDemo extends StatefulWidget {
  const GeolocationWebDemo({super.key});
  @override
  State<GeolocationWebDemo> createState() => _GeolocationWebDemoState();
}

class _GeolocationWebDemoState extends State<GeolocationWebDemo> {
  String _status = 'Ready';
  String _error = '';
  int? _watchId;

  double? _lat, _lng, _accuracy, _altitude, _heading, _speed;
  DateTime? _timestamp;

  bool get _supported => web.window.navigator.geolocation != null;
  bool get _hasPosition => _lat != null && _lng != null;

  void _onSuccess(web.GeolocationPosition pos) {
    final c = pos.coords;
    setState(() {
      _lat = c.latitude;//?.toDartDouble;     // JSNumber? → double?
      _lng = c.longitude;//?.toDartDouble;
      _accuracy = c.accuracy;//?.toDartDouble;
      _altitude = c.altitude;//?.toDartDouble;
      _heading = c.heading;//?.toDartDouble;
      _speed = c.speed;//?.toDartDouble;
      _timestamp = DateTime.fromMillisecondsSinceEpoch(pos.timestamp.toInt());
      _status = 'Location updated';
      _error = '';
    });
  }

  void _onError(web.GeolocationPositionError err) {
    setState(() {
      _status = 'Error';
      _error = 'ERROR(${err.code}): ${err.message ?? 'Unknown'}';
    });
  }

  void _getCurrent() {
    final geo = web.window.navigator.geolocation;
    if (geo == null) {
      setState(() {
        _status = 'Geolocation not supported in this browser/page.';
        _error = 'navigator.geolocation is null';
      });
      return;
    }

    setState(() {
      _status = 'Requesting current position…';
      _error = '';
    });

    // Options dictionary (all fields optional)
    final options = web.PositionOptions(
      enableHighAccuracy: true,
      timeout: 10000,     // ms
      maximumAge: 0,      // ms
    );

    // getCurrentPosition(success, [error, options])
    geo.getCurrentPosition(
      ((web.GeolocationPosition p) => _onSuccess(p)).toJS,
      ((web.GeolocationPositionError e) => _onError(e)).toJS,
      options,
    );
  }

  void _startWatch() {
    final geo = web.window.navigator.geolocation;
    if (geo == null) {
      setState(() {
        _status = 'Geolocation not supported.';
        _error = 'navigator.geolocation is null';
      });
      return;
    }
    if (_watchId != null) return;

    setState(() {
      _status = 'Starting watch…';
      _error = '';
    });

    final options = web.PositionOptions(
      enableHighAccuracy: true,
      timeout: 10000,
      maximumAge: 0,
    );

    // watchPosition returns an ID which you must clear later.
    final id = geo.watchPosition(
      ((web.GeolocationPosition p) => _onSuccess(p)).toJS,
      ((web.GeolocationPositionError e) => _onError(e)).toJS,
      options,
    );

    setState(() {
      _watchId = id;
      _status = 'Watching position…';
    });
  }

  void _stopWatch() {
    final geo = web.window.navigator.geolocation;
    if (geo != null && _watchId != null) {
      geo.clearWatch(_watchId!);
    }
    setState(() {
      _watchId = null;
      _status = 'Watch stopped';
    });
  }

  String _fmt(num? v, {int frac = 6}) => v == null ? '—' : v.toStringAsFixed(frac);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canWatch = _watchId == null;
    final canStop = _watchId != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Geolocation (package:web)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _supported
                    ? '$_status\n(HTTPS + user permission required)'
                    : 'Geolocation not supported here.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _getCurrent,
                icon: const Icon(Icons.my_location),
                label: const Text('Get current'),
              ),
              FilledButton.icon(
                onPressed: canWatch ? _startWatch : null,
                icon: const Icon(Icons.play_circle),
                label: const Text('Start watch'),
              ),
              OutlinedButton.icon(
                onPressed: canStop ? _stopWatch : null,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Stop watch'),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Latest position', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _kv('Latitude', _fmt(_lat)),
                  _kv('Longitude', _fmt(_lng)),
                  _kv('Accuracy (m)', _fmt(_accuracy, frac: 1)),
                  _kv('Altitude (m)', _fmt(_altitude, frac: 1)),
                  _kv('Heading (°)', _fmt(_heading, frac: 1)),
                  _kv('Speed (m/s)', _fmt(_speed, frac: 1)),
                  _kv('Timestamp', _timestamp?.toLocal().toString() ?? '—'),
                  const SizedBox(height: 8),
                  if (_hasPosition)
                    FilledButton.tonalIcon(
                      onPressed: () {
                        final url = Uri.parse(
                          'https://maps.google.com/?q=$_lat,$_lng',
                        );
                        // Open in a new tab (web.window.open equivalent is not needed here;
                        // using Link-style navigation is fine in DartPad context).
                        web.window.open(url.toString(), '_blank');
                      },
                      icon: const Icon(Icons.map),
                      label: const Text('Open in Google Maps'),
                    ),
                ],
              ),
            ),
          ),

          if (_error.isNotEmpty) ...[
            const SizedBox(height: 8),
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),
          Opacity(
            opacity: 0.85,
            child: Text(
              'Tips:\n'
              '• The browser prompts for location permission the first time.\n'
              '• This API requires HTTPS (secure context).\n'
              '• If embedded in a cross‑origin iframe, the parent must allow geolocation (Permissions‑Policy).',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(k)),
          Expanded(child: Text(v, style: const TextStyle(fontFamily: 'monospace'))),
        ],
      ),
    );
  }
}