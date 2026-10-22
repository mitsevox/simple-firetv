import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Where the weather line under the clock reports from (Naperville, IL). Set to null to hide it.
const ({double lat, double lon})? weatherLocation = (lat: 41.7508, lon: -88.1535);

class Weather {
  const Weather({required this.temperature, required this.code, required this.isDay});

  final int temperature;

  /// WMO weather code, as returned by Open-Meteo.
  final int code;
  final bool isDay;

  String get summary => switch (code) {
        0 => 'Clear',
        1 || 2 => 'Partly cloudy',
        3 => 'Cloudy',
        45 || 48 => 'Fog',
        >= 51 && <= 57 => 'Drizzle',
        (>= 61 && <= 67) || (>= 80 && <= 82) => 'Rain',
        (>= 71 && <= 77) || 85 || 86 => 'Snow',
        >= 95 => 'Thunderstorms',
        _ => '',
      };

  IconData get icon => switch (code) {
        0 => isDay ? Icons.wb_sunny_outlined : Icons.nightlight_outlined,
        1 || 2 => Icons.wb_cloudy_outlined,
        3 => Icons.cloud_outlined,
        45 || 48 => Icons.foggy,
        (>= 51 && <= 67) || (>= 80 && <= 82) => Icons.water_drop_outlined,
        (>= 71 && <= 77) || 85 || 86 => Icons.ac_unit,
        >= 95 => Icons.thunderstorm_outlined,
        _ => Icons.cloud_outlined,
      };
}

/// Current conditions from Open-Meteo (free, no account), refreshed every 15 minutes.
class WeatherStore extends ChangeNotifier {
  Weather? current;
  Timer? _timer;

  void start() {
    if (weatherLocation == null) return;
    _refresh();
    _timer = Timer.periodic(const Duration(minutes: 15), (_) => _refresh());
  }

  Future<void> _refresh() async {
    final location = weatherLocation!;
    try {
      final res = await http.get(Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '${location.lat}',
        'longitude': '${location.lon}',
        'current': 'temperature_2m,weather_code,is_day',
        'temperature_unit': 'fahrenheit',
      }));
      final now = jsonDecode(res.body)['current'] as Map<String, dynamic>;
      current = Weather(
        temperature: (now['temperature_2m'] as num).round(),
        code: now['weather_code'] as int,
        isDay: now['is_day'] == 1,
      );
      notifyListeners();
    } catch (_) {
      // Offline: keep the last reading, try again next cycle.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
