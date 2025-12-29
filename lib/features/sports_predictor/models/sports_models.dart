// Core models for Sports Predictor features
import 'package:flutter/material.dart';

// ============ PREDICTION HISTORY ============
enum PredictionResult { pending, won, lost, void_, push }

class PredictionRecord {
  final String id;
  final String matchId;
  final String homeTeam;
  final String awayTeam;
  final String league;
  final String sport;
  final DateTime matchDate;
  final String betType; // 1X2, Over/Under, BTTS, etc.
  final String selection; // Home, Away, Draw, Over 2.5, etc.
  final double odds;
  final double stake;
  final double confidence;
  final PredictionResult result;
  final String? actualScore;
  final DateTime createdAt;
  final String? homeTeamLogo;
  final String? awayTeamLogo;

  PredictionRecord({
    required this.id,
    required this.matchId,
    required this.homeTeam,
    required this.awayTeam,
    required this.league,
    required this.sport,
    required this.matchDate,
    required this.betType,
    required this.selection,
    required this.odds,
    required this.stake,
    required this.confidence,
    required this.result,
    this.actualScore,
    required this.createdAt,
    this.homeTeamLogo,
    this.awayTeamLogo,
  });

  double get potentialWin => stake * odds;
  double get profit => result == PredictionResult.won
      ? (stake * odds) - stake
      : result == PredictionResult.lost
          ? -stake
          : 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'matchId': matchId,
        'homeTeam': homeTeam,
        'awayTeam': awayTeam,
        'league': league,
        'sport': sport,
        'matchDate': matchDate.toIso8601String(),
        'betType': betType,
        'selection': selection,
        'odds': odds,
        'stake': stake,
        'confidence': confidence,
        'result': result.name,
        'actualScore': actualScore,
        'createdAt': createdAt.toIso8601String(),
        'homeTeamLogo': homeTeamLogo,
        'awayTeamLogo': awayTeamLogo,
      };

  factory PredictionRecord.fromJson(Map<String, dynamic> json) =>
      PredictionRecord(
        id: json['id'],
        matchId: json['matchId'],
        homeTeam: json['homeTeam'],
        awayTeam: json['awayTeam'],
        league: json['league'],
        sport: json['sport'],
        matchDate: DateTime.parse(json['matchDate']),
        betType: json['betType'],
        selection: json['selection'],
        odds: (json['odds'] as num).toDouble(),
        stake: (json['stake'] as num).toDouble(),
        confidence: (json['confidence'] as num).toDouble(),
        result:
            PredictionResult.values.firstWhere((e) => e.name == json['result']),
        actualScore: json['actualScore'],
        createdAt: DateTime.parse(json['createdAt']),
        homeTeamLogo: json['homeTeamLogo'],
        awayTeamLogo: json['awayTeamLogo'],
      );
}

// ============ BANKROLL TRACKER ============
class BankrollEntry {
  final String id;
  final double amount;
  final String type; // deposit, withdrawal, bet, win
  final String? predictionId;
  final String description;
  final DateTime timestamp;
  final double balanceAfter;

  BankrollEntry({
    required this.id,
    required this.amount,
    required this.type,
    this.predictionId,
    required this.description,
    required this.timestamp,
    required this.balanceAfter,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'type': type,
        'predictionId': predictionId,
        'description': description,
        'timestamp': timestamp.toIso8601String(),
        'balanceAfter': balanceAfter,
      };

  factory BankrollEntry.fromJson(Map<String, dynamic> json) => BankrollEntry(
        id: json['id'],
        amount: (json['amount'] as num).toDouble(),
        type: json['type'],
        predictionId: json['predictionId'],
        description: json['description'],
        timestamp: DateTime.parse(json['timestamp']),
        balanceAfter: (json['balanceAfter'] as num).toDouble(),
      );
}

// ============ LIVE SCORES ============
enum MatchStatus { scheduled, live, halftime, finished, postponed, cancelled }

class LiveMatch {
  final String id;
  final String homeTeam;
  final String awayTeam;
  final String league;
  final String sport;
  final int homeScore;
  final int awayScore;
  final MatchStatus status;
  final String? minute;
  final DateTime kickoff;
  final String? homeTeamLogo;
  final String? awayTeamLogo;
  final List<MatchEvent> events;
  final LiveOdds? currentOdds;

  LiveMatch({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.league,
    required this.sport,
    required this.homeScore,
    required this.awayScore,
    required this.status,
    this.minute,
    required this.kickoff,
    this.homeTeamLogo,
    this.awayTeamLogo,
    this.events = const [],
    this.currentOdds,
  });

  String get scoreDisplay => '$homeScore - $awayScore';
  bool get isLive =>
      status == MatchStatus.live || status == MatchStatus.halftime;
}

class MatchEvent {
  final String type; // goal, card, substitution
  final String team;
  final String player;
  final String minute;
  final String? detail;

  MatchEvent({
    required this.type,
    required this.team,
    required this.player,
    required this.minute,
    this.detail,
  });
}

class LiveOdds {
  final double homeWin;
  final double draw;
  final double awayWin;
  final double? over25;
  final double? under25;
  final DateTime updatedAt;
  final double? homeWinChange;
  final double? drawChange;
  final double? awayWinChange;

  LiveOdds({
    required this.homeWin,
    required this.draw,
    required this.awayWin,
    this.over25,
    this.under25,
    required this.updatedAt,
    this.homeWinChange,
    this.drawChange,
    this.awayWinChange,
  });
}

// ============ LEADERBOARD ============
class LeaderboardEntry {
  final String oderId;
  final String username;
  final String? avatarUrl;
  final int totalPredictions;
  final int wins;
  final int losses;
  final double winRate;
  final double profit;
  final double roi;
  final int rank;
  final int streak;
  final List<String> badges;

  LeaderboardEntry({
    required this.oderId,
    required this.username,
    this.avatarUrl,
    required this.totalPredictions,
    required this.wins,
    required this.losses,
    required this.winRate,
    required this.profit,
    required this.roi,
    required this.rank,
    required this.streak,
    this.badges = const [],
  });
}

// ============ FAVORITE TEAMS ============
class FavoriteTeam {
  final String id;
  final String name;
  final String sport;
  final String league;
  final String? logoUrl;
  final bool notificationsEnabled;

  FavoriteTeam({
    required this.id,
    required this.name,
    required this.sport,
    required this.league,
    this.logoUrl,
    this.notificationsEnabled = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sport': sport,
        'league': league,
        'logoUrl': logoUrl,
        'notificationsEnabled': notificationsEnabled,
      };

  factory FavoriteTeam.fromJson(Map<String, dynamic> json) => FavoriteTeam(
        id: json['id'],
        name: json['name'],
        sport: json['sport'],
        league: json['league'],
        logoUrl: json['logoUrl'],
        notificationsEnabled: json['notificationsEnabled'] ?? true,
      );
}

// ============ BETTING SLIP ============
class BettingSlip {
  final String id;
  final List<SlipSelection> selections;
  final double totalStake;
  final double totalOdds;
  final double potentialWin;
  final String type; // single, accumulator, system
  final DateTime createdAt;
  final bool isPlaced;

  BettingSlip({
    required this.id,
    required this.selections,
    required this.totalStake,
    required this.totalOdds,
    required this.potentialWin,
    required this.type,
    required this.createdAt,
    this.isPlaced = false,
  });
}

class SlipSelection {
  final String matchId;
  final String homeTeam;
  final String awayTeam;
  final String betType;
  final String selection;
  final double odds;
  final DateTime matchDate;

  SlipSelection({
    required this.matchId,
    required this.homeTeam,
    required this.awayTeam,
    required this.betType,
    required this.selection,
    required this.odds,
    required this.matchDate,
  });
}

// ============ HEAD TO HEAD ============
class HeadToHead {
  final String team1;
  final String team2;
  final int team1Wins;
  final int team2Wins;
  final int draws;
  final int team1Goals;
  final int team2Goals;
  final List<H2HMatch> recentMatches;

  HeadToHead({
    required this.team1,
    required this.team2,
    required this.team1Wins,
    required this.team2Wins,
    required this.draws,
    required this.team1Goals,
    required this.team2Goals,
    required this.recentMatches,
  });

  int get totalMatches => team1Wins + team2Wins + draws;
}

class H2HMatch {
  final DateTime date;
  final String competition;
  final int team1Score;
  final int team2Score;
  final String venue;

  H2HMatch({
    required this.date,
    required this.competition,
    required this.team1Score,
    required this.team2Score,
    required this.venue,
  });
}

// ============ TEAM FORM ============
class TeamForm {
  final String teamName;
  final String teamLogo;
  final List<FormMatch> lastMatches;
  final double goalsScored;
  final double goalsConceded;
  final int position;
  final int points;

  TeamForm({
    required this.teamName,
    required this.teamLogo,
    required this.lastMatches,
    required this.goalsScored,
    required this.goalsConceded,
    required this.position,
    required this.points,
  });

  String get formString => lastMatches.take(5).map((m) => m.result).join();
  int get formPoints => lastMatches.take(5).fold(
      0,
      (sum, m) =>
          sum +
          (m.result == 'W'
              ? 3
              : m.result == 'D'
                  ? 1
                  : 0));
}

class FormMatch {
  final String opponent;
  final String result; // W, D, L
  final String score;
  final DateTime date;
  final bool isHome;

  FormMatch({
    required this.opponent,
    required this.result,
    required this.score,
    required this.date,
    required this.isHome,
  });

  Color get resultColor => result == 'W'
      ? Colors.green
      : result == 'D'
          ? Colors.orange
          : Colors.red;
}

// ============ INJURY REPORT ============
class InjuryReport {
  final String teamName;
  final List<PlayerInjury> injuries;
  final DateTime updatedAt;

  InjuryReport({
    required this.teamName,
    required this.injuries,
    required this.updatedAt,
  });
}

class PlayerInjury {
  final String playerName;
  final String position;
  final String injuryType;
  final String status; // out, doubtful, questionable
  final String? expectedReturn;
  final String? photoUrl;

  PlayerInjury({
    required this.playerName,
    required this.position,
    required this.injuryType,
    required this.status,
    this.expectedReturn,
    this.photoUrl,
  });

  Color get statusColor => status == 'out'
      ? Colors.red
      : status == 'doubtful'
          ? Colors.orange
          : Colors.yellow;
}

// ============ WEATHER ============
class MatchWeather {
  final String condition;
  final double temperature;
  final double windSpeed;
  final int humidity;
  final String icon;
  final String impact; // favorable, neutral, unfavorable

  MatchWeather({
    required this.condition,
    required this.temperature,
    required this.windSpeed,
    required this.humidity,
    required this.icon,
    required this.impact,
  });
}

// ============ MATCH PREVIEW ============
class MatchPreview {
  final String matchId;
  final String homeTeam;
  final String awayTeam;
  final String league;
  final DateTime matchDate;
  final String analysis;
  final List<String> keyStats;
  final HeadToHead? h2h;
  final TeamForm? homeForm;
  final TeamForm? awayForm;
  final InjuryReport? homeInjuries;
  final InjuryReport? awayInjuries;
  final MatchWeather? weather;
  final String prediction;
  final double confidence;
  final List<String> bettingTips;

  MatchPreview({
    required this.matchId,
    required this.homeTeam,
    required this.awayTeam,
    required this.league,
    required this.matchDate,
    required this.analysis,
    required this.keyStats,
    this.h2h,
    this.homeForm,
    this.awayForm,
    this.homeInjuries,
    this.awayInjuries,
    this.weather,
    required this.prediction,
    required this.confidence,
    required this.bettingTips,
  });
}

// ============ ALERTS ============
class SportsAlert {
  final String id;
  final String type; // odds_change, kickoff, goal, result
  final String matchId;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? data;

  SportsAlert({
    required this.id,
    required this.type,
    required this.matchId,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.data,
  });
}

// ============ TIPSTER ============
class Tipster {
  final String id;
  final String username;
  final String? avatarUrl;
  final String bio;
  final int followers;
  final double winRate;
  final double roi;
  final int totalTips;
  final List<String> specialties;
  final bool isFollowing;
  final bool isVerified;

  Tipster({
    required this.id,
    required this.username,
    this.avatarUrl,
    required this.bio,
    required this.followers,
    required this.winRate,
    required this.roi,
    required this.totalTips,
    required this.specialties,
    this.isFollowing = false,
    this.isVerified = false,
  });
}
