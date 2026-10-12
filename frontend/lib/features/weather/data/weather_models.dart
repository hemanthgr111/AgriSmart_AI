// Weather models mirroring the backend `/api/weather` response.

/// A query for a weather lookup: either by place name or by coordinates.
class WeatherQuery {
  const WeatherQuery.byName(String this.name)
      : lat = null,
        lon = null;
  const WeatherQuery.byCoords(double this.lat, double this.lon) : name = null;

  final String? name;
  final double? lat;
  final double? lon;

  Map<String, String> toQueryParameters() {
    if (name != null) {
      return <String, String>{'q': name!};
    }
    return <String, String>{'lat': '$lat', 'lon': '$lon'};
  }

  @override
  bool operator ==(Object other) =>
      other is WeatherQuery &&
      other.name == name &&
      other.lat == lat &&
      other.lon == lon;

  @override
  int get hashCode => Object.hash(name, lat, lon);
}

class WeatherPlace {
  const WeatherPlace({this.name, this.region, this.country, this.localtime});

  final String? name;
  final String? region;
  final String? country;
  final String? localtime;

  String get label {
    final List<String> parts = <String>[
      if (name != null && name!.isNotEmpty) name!,
      if (region != null && region!.isNotEmpty && region != name) region!,
      if (country != null && country!.isNotEmpty) country!,
    ];
    return parts.join(', ');
  }

  factory WeatherPlace.fromJson(Map<String, dynamic> json) => WeatherPlace(
        name: json['name'] as String?,
        region: json['region'] as String?,
        country: json['country'] as String?,
        localtime: json['localtime'] as String?,
      );
}

class WeatherNow {
  const WeatherNow({
    this.tempC,
    this.feelsLikeC,
    this.humidity,
    this.windKph,
    this.windDir,
    this.precipMm,
    this.condition,
    this.icon,
  });

  final double? tempC;
  final double? feelsLikeC;
  final int? humidity;
  final double? windKph;
  final String? windDir;
  final double? precipMm;
  final String? condition;
  final String? icon;

  factory WeatherNow.fromJson(Map<String, dynamic> json) => WeatherNow(
        tempC: (json['temp_c'] as num?)?.toDouble(),
        feelsLikeC: (json['feelslike_c'] as num?)?.toDouble(),
        humidity: (json['humidity'] as num?)?.toInt(),
        windKph: (json['wind_kph'] as num?)?.toDouble(),
        windDir: json['wind_dir'] as String?,
        precipMm: (json['precip_mm'] as num?)?.toDouble(),
        condition: json['condition'] as String?,
        icon: json['icon'] as String?,
      );
}

class WeatherDayData {
  const WeatherDayData({
    this.date,
    this.maxTempC,
    this.minTempC,
    this.avgHumidity,
    this.chanceOfRain,
    this.condition,
    this.icon,
  });

  final String? date;
  final double? maxTempC;
  final double? minTempC;
  final int? avgHumidity;
  final int? chanceOfRain;
  final String? condition;
  final String? icon;

  factory WeatherDayData.fromJson(Map<String, dynamic> json) => WeatherDayData(
        date: json['date'] as String?,
        maxTempC: (json['max_temp_c'] as num?)?.toDouble(),
        minTempC: (json['min_temp_c'] as num?)?.toDouble(),
        avgHumidity: (json['avg_humidity'] as num?)?.toInt(),
        chanceOfRain: (json['chance_of_rain'] as num?)?.toInt(),
        condition: json['condition'] as String?,
        icon: json['icon'] as String?,
      );
}

class WeatherData {
  const WeatherData({
    required this.location,
    required this.current,
    required this.forecast,
    this.updatedAt,
  });

  final WeatherPlace location;
  final WeatherNow current;
  final List<WeatherDayData> forecast;
  final DateTime? updatedAt;

  factory WeatherData.fromJson(Map<String, dynamic> json) => WeatherData(
        location: WeatherPlace.fromJson(
          (json['location'] as Map<String, dynamic>?) ?? <String, dynamic>{},
        ),
        current: WeatherNow.fromJson(
          (json['current'] as Map<String, dynamic>?) ?? <String, dynamic>{},
        ),
        forecast: ((json['forecast'] as List<dynamic>?) ?? <dynamic>[])
            .map((dynamic e) =>
                WeatherDayData.fromJson(e as Map<String, dynamic>))
            .toList(),
        updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
      );
}
