class Race {
  final String id;
  final String title;
  final double distance; // em km
  final DateTime date;
  final String location;
  final String locationDescription;
  final int participants;
  final double startLatitude;
  final double startLongitude;
  final double endLatitude;
  final double endLongitude;
  final String startAddress;
  final String endAddress;
  final String? imageUrl;

  Race({
    required this.id,
    required this.title,
    required this.distance,
    required this.date,
    required this.location,
    required this.locationDescription,
    required this.participants,
    required this.startLatitude,
    required this.startLongitude,
    required this.endLatitude,
    required this.endLongitude,
    required this.startAddress,
    required this.endAddress,
    this.imageUrl,
  });

  String get formattedDistance {
    return distance >= 1
        ? '${distance.toStringAsFixed(1)} km'
        : '${(distance * 1000).toInt()} m';
  }

  String get formattedDate {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} - ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  factory Race.fromJson(Map<String, dynamic> json) {
    return Race(
      id: json['id'],
      title: json['title'],
      distance: json['distance'].toDouble(),
      date: DateTime.parse(json['date']),
      location: json['location'],
      locationDescription: json['locationDescription'] ?? '',
      participants: json['participants'] ?? 0,
      startLatitude: json['startLatitude'].toDouble(),
      startLongitude: json['startLongitude'].toDouble(),
      endLatitude: json['endLatitude'].toDouble(),
      endLongitude: json['endLongitude'].toDouble(),
      startAddress: json['startAddress'] ?? 'Endereço de início',
      endAddress: json['endAddress'] ?? 'Endereço de término',
      imageUrl: json['imageUrl'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'distance': distance,
    'date': date.toIso8601String(),
    'location': location,
    'locationDescription': locationDescription,
    'participants': participants,
    'startLatitude': startLatitude,
    'startLongitude': startLongitude,
    'endLatitude': endLatitude,
    'endLongitude': endLongitude,
    'startAddress': startAddress,
    'endAddress': endAddress,
    'imageUrl': imageUrl,
  };
}