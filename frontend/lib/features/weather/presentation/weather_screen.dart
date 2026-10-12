import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../l10n/app_localizations.dart';
import '../data/weather_models.dart';
import '../data/weather_repository.dart';

class WeatherScreen extends ConsumerStatefulWidget {
  const WeatherScreen({super.key});

  @override
  ConsumerState<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends ConsumerState<WeatherScreen> {
  final TextEditingController _locationController = TextEditingController();
  WeatherQuery? _query;
  bool _locating = false;

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.weatherTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          TextField(
            controller: _locationController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: l10n.enterLocation,
              prefixIcon: const Icon(Icons.place_outlined),
            ),
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: _search,
                  icon: const Icon(Icons.search),
                  label: Text(l10n.searchLocation),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _locating ? null : _useMyLocation,
                  icon: _locating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: Text(l10n.useMyLocation),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_query == null)
            _EmptyState(message: l10n.enterLocation)
          else
            _WeatherResult(query: _query!),
        ],
      ),
    );
  }

  void _search() {
    final String value = _locationController.text.trim();
    if (value.isEmpty) {
      _snack(AppLocalizations.of(context).fieldRequired);
      return;
    }
    setState(() => _query = WeatherQuery.byName(value));
  }

  Future<void> _useMyLocation() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    setState(() => _locating = true);
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _snack(l10n.locationServicesDisabled);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _snack(l10n.locationPermissionDenied);
        return;
      }
      final Position position = await Geolocator.getCurrentPosition();
      if (!mounted) {
        return;
      }
      setState(() {
        _query = WeatherQuery.byCoords(position.latitude, position.longitude);
      });
    } catch (_) {
      if (mounted) {
        _snack(l10n.weatherUnavailable);
      }
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.cloud_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _WeatherResult extends ConsumerWidget {
  const _WeatherResult({required this.query});

  final WeatherQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<WeatherData> weather = ref.watch(weatherProvider(query));

    return weather.when(
      data: (WeatherData data) => _WeatherContent(data: data),
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace _) {
        String message = l10n.weatherUnavailable;
        if (error is ApiException) {
          if (error.statusCode == 400) {
            message = l10n.invalidLocation;
          } else if (error.statusCode == 503) {
            message = l10n.weatherUnavailable;
          } else {
            message = error.message;
          }
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                Icon(Icons.cloud_off, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(weatherProvider(query)),
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.retry),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WeatherContent extends StatelessWidget {
  const _WeatherContent({required this.data});

  final WeatherData data;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final WeatherNow now = data.current;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(data.location.label, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  now.tempC == null ? '--' : '${now.tempC!.round()}°C',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                if (now.condition != null)
                  Text(now.condition!, style: Theme.of(context).textTheme.titleMedium),
                if (now.feelsLikeC != null)
                  Text('${l10n.feelsLike}: ${now.feelsLikeC!.round()}°C'),
                const SizedBox(height: 16),
                _MetricRow(
                  icon: Icons.water_drop_outlined,
                  label: l10n.humidity,
                  value: now.humidity == null ? '--' : '${now.humidity}%',
                ),
                _MetricRow(
                  icon: Icons.air,
                  label: l10n.wind,
                  value: now.windKph == null
                      ? '--'
                      : '${now.windKph!.round()} km/h ${now.windDir ?? ''}'.trim(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (data.forecast.isNotEmpty) ...<Widget>[
          Text(l10n.forecast, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final WeatherDayData day in data.forecast)
            _ForecastTile(day: day),
        ],
        if (data.updatedAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '${l10n.lastUpdated}: '
              '${DateFormat.yMMMd().add_jm().format(data.updatedAt!.toLocal())}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _ForecastTile extends StatelessWidget {
  const _ForecastTile({required this.day});

  final WeatherDayData day;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String temps = <String>[
      if (day.maxTempC != null) '${day.maxTempC!.round()}°',
      if (day.minTempC != null) '${day.minTempC!.round()}°',
    ].join(' / ');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(day.condition ?? '--'),
      subtitle: Text(
        <String>[
          if (day.chanceOfRain != null)
            '${l10n.rainChance}: ${day.chanceOfRain}%',
          if (day.avgHumidity != null) '${l10n.humidity}: ${day.avgHumidity}%',
        ].join('  •  '),
      ),
      trailing: Text(temps, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}
