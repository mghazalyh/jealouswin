typedef Json = Map<String, dynamic>;
Json object(Object? value) {
  if (value is! Map) throw const FormatException('Expected JSON object');
  return Map<String, dynamic>.from(value);
}

class ServerAddress {
  ServerAddress(String input) : uri = parse(input);
  final Uri uri;
  static Uri parse(String input) {
    final u = Uri.tryParse(input.trim());
    if (u == null || !['http','https'].contains(u.scheme) ||
        u.host.isEmpty || u.userInfo.isNotEmpty || u.hasQuery || u.hasFragment) {
      throw const FormatException('Enter a valid HTTP or HTTPS LAN server address.');
    }
    if (u.scheme == 'http' && !privateHost(u.host)) {
      throw const FormatException('Use HTTPS for non-LAN servers.');
    }
    return u.replace(path: u.path.replaceFirst(RegExp(r'/+$'), '') + '/');
  }
  static bool privateHost(String host) {
    if (host == 'localhost' || host == '::1' || host.endsWith('.local')) return true;
    final a = host.split('.').map(int.tryParse).toList();
    if (a.length != 4 || a.any((n) => n == null || n < 0 || n > 255)) return false;
    return a[0] == 10 || a[0] == 127 || (a[0] == 192 && a[1] == 168) ||
      (a[0] == 172 && a[1]! >= 16 && a[1]! <= 31);
  }
  Uri endpoint(String path, [Map<String,String> query = const {}]) {
    final v = uri.resolve(path);
    if (v.origin != uri.origin || v.userInfo.isNotEmpty || v.hasFragment) {
      throw const FormatException('Cross-origin server URL rejected.');
    }
    return query.isEmpty ? v : v.replace(queryParameters: query);
  }
}
enum Profile { english, malay }
enum ChannelFilter { all, favorites, sports, moviesSeries, hiatus }
extension FilterLabel on ChannelFilter {
  String get label => switch (this) {
    ChannelFilter.all => 'All Channels',
    ChannelFilter.favorites => 'Favorites',
    ChannelFilter.sports => 'Sports',
    ChannelFilter.moviesSeries => 'Movies & Series',
    ChannelFilter.hiatus => 'Hiatus / Banned',
  };
}
class ChannelHealth {
  const ChannelHealth({this.banned = false, this.hiatusUntil = 0,
    this.failures = 0, this.successes = 0, this.reason = '', this.lastAttempt = 0});
  factory ChannelHealth.fromJson(Json d) {
    final until = d['hiatusUntil'], banned = d['banned'];
    if (until is! num || !until.isFinite || until < 0 || banned is! bool) {
      throw const FormatException('Invalid gateway channel policy.');
    }
    return ChannelHealth(banned: banned, hiatusUntil: until.toDouble(),
      failures: (d['failures'] as num?)?.toInt() ?? 0,
      successes: (d['successes'] as num?)?.toInt() ?? 0,
      lastAttempt: (d['lastAttempt'] as num?)?.toDouble() ?? 0,
      reason: d['reason'] is String ? d['reason'] as String : '');
  }
  final bool banned;
  final double hiatusUntil, lastAttempt;
  final int failures, successes;
  final String reason;
  bool eligible(DateTime now) => !banned && hiatusUntil <= now.millisecondsSinceEpoch / 1000;
  String label(DateTime now) {
    if (banned) return 'Banned';
    if (!eligible(now)) {
      final date = DateTime.fromMillisecondsSinceEpoch((hiatusUntil * 1000).round()).toLocal();
      return 'Hiatus until '+date.toString().substring(0,16);
    }
    return successes > 0 ? 'Proven' : 'Eligible';
  }
}
class Channel {
  const Channel({required this.id, required this.name, this.programme = '',
    this.favorite = false, this.genres = const [], this.health = const ChannelHealth()});
  factory Channel.fromJson(Json d, ChannelHealth health) {
    final p = d['CurrentProgram'], user = d['UserData'];
    return Channel(id: d['Id'] as String, name: d['Name'] as String,
      programme: p is Map && p['Name'] is String ? p['Name'] as String : '',
      favorite: user is Map && user['IsFavorite'] == true,
      genres: [
        if (d['Genres'] is List) ...(d['Genres'] as List).whereType<String>(),
        if (d['Tags'] is List) ...(d['Tags'] as List).whereType<String>(),
      ], health: health);
  }
  final String id, name, programme;
  final bool favorite;
  final List<String> genres;
  final ChannelHealth health;
  Channel withFavorite(bool value) => Channel(id: id, name: name,
    programme: programme, favorite: value, genres: genres, health: health);
  bool matches(ChannelFilter filter, DateTime now) {
    final tags = genres.join(' ').toLowerCase(), eligible = health.eligible(now);
    return switch (filter) {
      ChannelFilter.all => eligible,
      ChannelFilter.favorites => eligible && favorite,
      ChannelFilter.sports => eligible && tags.contains('sport'),
      ChannelFilter.moviesSeries => eligible && RegExp(r'movie|series|film|cinema|drama').hasMatch(tags),
      ChannelFilter.hiatus => !eligible,
    };
  }
}
List<Channel> decodeCatalogue(Json data) {
  final items = data['Items'];
  if (items is! List) throw const FormatException('Channel catalogue missing.');
  // Never fail open when the authoritative Jealousfin policy is absent.
  final policy = object(data['JealousfinPolicy']);
  if (policy['revision'] != 'sqlite-policy-v2') {
    throw const FormatException('Unsupported gateway policy.');
  }
  final health = object(policy['channels']), ids = <String>{}, rows = <Channel>[];
  for (final item in items) {
    final row = object(item), id = row['Id'];
    if (id is! String || id.isEmpty || id.length > 128 || row['Name'] is! String ||
        !ids.add(id) || !health.containsKey(id)) {
      throw const FormatException('Gateway policy/catalogue mismatch.');
    }
    rows.add(Channel.fromJson(row, ChannelHealth.fromJson(object(health[id]))));
  }
  if (health.length != ids.length) throw const FormatException('Gateway policy/catalogue mismatch.');
  return rows;
}
class Rotation {
  int cycle = 1;
  final attempted = <String>{};
  String? next(List<Channel> channels, {String? current}) {
    if (channels.isEmpty) return null;
    var pool = channels.where((c) => !attempted.contains(c.id)).toList();
    if (pool.isEmpty) { attempted.clear(); cycle++; pool = List.of(channels); }
    if (pool.length > 1) pool.removeWhere((c) => c.id == current);
    pool.sort((a,b) {
      final order = a.health.lastAttempt.compareTo(b.health.lastAttempt);
      return order != 0 ? order : a.id.compareTo(b.id);
    });
    final id = pool.first.id;
    attempted.add(id);
    return id;
  }
  int remaining(List<Channel> channels) => channels.where((c) => !attempted.contains(c.id)).length;
}
