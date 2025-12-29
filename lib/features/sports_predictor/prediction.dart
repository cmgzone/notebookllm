/// Sports prediction model
class SportsPrediction {
  final String id;
  final String sport;
  final String league;
  final String homeTeam;
  final String awayTeam;
  final String? homeTeamLogo;
  final String? awayTeamLogo;
  final DateTime matchDate;
  final PredictionOdds odds;
  final String analysis;
  final List<String> keyFactors;
  final double confidence;
  final List<PredictionSource> sources;
  final DateTime createdAt;

  SportsPrediction({
    required this.id,
    required this.sport,
    required this.league,
    required this.homeTeam,
    required this.awayTeam,
    this.homeTeamLogo,
    this.awayTeamLogo,
    required this.matchDate,
    required this.odds,
    required this.analysis,
    required this.keyFactors,
    required this.confidence,
    required this.sources,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory SportsPrediction.fromJson(Map<String, dynamic> json) {
    return SportsPrediction(
      id: json['id'] ?? '',
      sport: json['sport'] ?? '',
      league: json['league'] ?? '',
      homeTeam: json['homeTeam'] ?? json['home_team'] ?? '',
      awayTeam: json['awayTeam'] ?? json['away_team'] ?? '',
      homeTeamLogo: json['homeTeamLogo'] ?? json['home_team_logo'],
      awayTeamLogo: json['awayTeamLogo'] ?? json['away_team_logo'],
      matchDate:
          DateTime.tryParse(json['matchDate'] ?? json['match_date'] ?? '') ??
              DateTime.now(),
      odds: PredictionOdds.fromJson(json['odds'] ?? {}),
      analysis: json['analysis'] ?? '',
      keyFactors:
          List<String>.from(json['keyFactors'] ?? json['key_factors'] ?? []),
      confidence: (json['confidence'] ?? 0.5).toDouble(),
      sources: (json['sources'] as List?)
              ?.map((s) => PredictionSource.fromJson(s))
              .toList() ??
          [],
      createdAt:
          DateTime.tryParse(json['createdAt'] ?? json['created_at'] ?? ''),
    );
  }

  SportsPrediction copyWith({
    String? homeTeamLogo,
    String? awayTeamLogo,
  }) {
    return SportsPrediction(
      id: id,
      sport: sport,
      league: league,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      homeTeamLogo: homeTeamLogo ?? this.homeTeamLogo,
      awayTeamLogo: awayTeamLogo ?? this.awayTeamLogo,
      matchDate: matchDate,
      odds: odds,
      analysis: analysis,
      keyFactors: keyFactors,
      confidence: confidence,
      sources: sources,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sport': sport,
        'league': league,
        'homeTeam': homeTeam,
        'awayTeam': awayTeam,
        'homeTeamLogo': homeTeamLogo,
        'awayTeamLogo': awayTeamLogo,
        'matchDate': matchDate.toIso8601String(),
        'odds': odds.toJson(),
        'analysis': analysis,
        'keyFactors': keyFactors,
        'confidence': confidence,
        'sources': sources.map((s) => s.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };
}

class PredictionOdds {
  final double homeWin;
  final double draw;
  final double awayWin;
  final double? over25;
  final double? under25;
  final double? btts; // Both teams to score

  PredictionOdds({
    required this.homeWin,
    required this.draw,
    required this.awayWin,
    this.over25,
    this.under25,
    this.btts,
  });

  factory PredictionOdds.fromJson(Map<String, dynamic> json) {
    return PredictionOdds(
      homeWin: (json['homeWin'] ?? json['home_win'] ?? 2.0).toDouble(),
      draw: (json['draw'] ?? 3.0).toDouble(),
      awayWin: (json['awayWin'] ?? json['away_win'] ?? 2.5).toDouble(),
      over25: json['over25']?.toDouble(),
      under25: json['under25']?.toDouble(),
      btts: json['btts']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'homeWin': homeWin,
        'draw': draw,
        'awayWin': awayWin,
        if (over25 != null) 'over25': over25,
        if (under25 != null) 'under25': under25,
        if (btts != null) 'btts': btts,
      };

  String get predictedOutcome {
    if (homeWin < draw && homeWin < awayWin) return 'Home Win';
    if (awayWin < draw && awayWin < homeWin) return 'Away Win';
    return 'Draw';
  }
}

class PredictionSource {
  final String title;
  final String url;
  final String snippet;

  PredictionSource({
    required this.title,
    required this.url,
    required this.snippet,
  });

  factory PredictionSource.fromJson(Map<String, dynamic> json) {
    return PredictionSource(
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      snippet: json['snippet'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'url': url,
        'snippet': snippet,
      };
}

/// Available sports for prediction
enum SportType {
  football('Football', '⚽'),
  basketball('Basketball', '🏀'),
  tennis('Tennis', '🎾'),
  baseball('Baseball', '⚾'),
  hockey('Hockey', '🏒'),
  americanFootball('American Football', '🏈'),
  cricket('Cricket', '🏏'),
  rugby('Rugby', '🏉'),
  mma('MMA/UFC', '🥊'),
  boxing('Boxing', '🥊');

  final String displayName;
  final String emoji;

  const SportType(this.displayName, this.emoji);
}
