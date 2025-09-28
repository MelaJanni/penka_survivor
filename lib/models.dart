class User {
  final String userId;
  final String name;
  final String email;
  final bool isTestUser;

  User({
    required this.userId,
    required this.name,
    required this.email,
    required this.isTestUser,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['userId'],
      name: json['name'],
      email: json['email'],
      isTestUser: json['isTestUser'],
    );
  }
}

class LoginResponse {
  final String message;
  final User user;

  LoginResponse({
    required this.message,
    required this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      message: json['message'],
      user: User.fromJson(json['user']),
    );
  }
}

class Team {
  final String id;
  final String name;
  final String flag;

  Team({
    required this.id,
    required this.name,
    required this.flag,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['_id'],
      name: json['name'],
      flag: json['flag'],
    );
  }
}

class Match {
  final String matchId;
  final Team home;
  final Team visitor;
  final int week;
  final bool finished;

  Match({
    required this.matchId,
    required this.home,
    required this.visitor,
    required this.week,
    required this.finished,
  });

  factory Match.fromJson(Map<String, dynamic> json) {
    return Match(
      matchId: json['matchId'],
      home: Team.fromJson(json['home']),
      visitor: Team.fromJson(json['visitor']),
      week: json['week'],
      finished: json['finished'],
    );
  }
}

class Survivor {
  final String id;
  final String name;
  final List<Match> competition;
  final DateTime startDate;
  final double lives;
  final int currentWeek;
  final int totalWeeks;
  final double prizePool;
  final String status;

  Survivor({
    required this.id,
    required this.name,
    required this.competition,
    required this.startDate,
    required this.lives,
    required this.currentWeek,
    required this.totalWeeks,
    required this.prizePool,
    required this.status,
  });

  factory Survivor.fromJson(Map<String, dynamic> json) {
    return Survivor(
      id: json['_id'],
      name: json['name'],
      competition: (json['competition'] as List)
          .map((match) => Match.fromJson(match))
          .toList(),
      startDate: DateTime.parse(json['startDate']),
      lives: json['lives'].toDouble(),
      currentWeek: json['currentWeek'],
      totalWeeks: json['totalWeeks'],
      prizePool: json['prizePool'].toDouble(),
      status: json['status'],
    );
  }
}

class UserLeague {
  final String survivorId;
  final String survivorName;
  final String status;
  final double lives;
  final DateTime joinedAt;
  final DateTime? eliminatedAt;
  final int currentWeek;
  final int totalWeeks;
  final double prizePool;
  final String leagueStatus;
  final int totalPicks;
  final int wins;
  final int losses;

  UserLeague({
    required this.survivorId,
    required this.survivorName,
    required this.status,
    required this.lives,
    required this.joinedAt,
    this.eliminatedAt,
    required this.currentWeek,
    required this.totalWeeks,
    required this.prizePool,
    required this.leagueStatus,
    required this.totalPicks,
    required this.wins,
    required this.losses,
  });

  factory UserLeague.fromJson(Map<String, dynamic> json) {
    return UserLeague(
      survivorId: json['survivorId'],
      survivorName: json['survivorName'],
      status: json['status'],
      lives: json['lives'].toDouble(),
      joinedAt: DateTime.parse(json['joinedAt']),
      eliminatedAt: json['eliminatedAt'] != null ? DateTime.parse(json['eliminatedAt']) : null,
      currentWeek: json['currentWeek'],
      totalWeeks: json['totalWeeks'],
      prizePool: json['prizePool'].toDouble(),
      leagueStatus: json['leagueStatus'],
      totalPicks: json['totalPicks'],
      wins: json['wins'],
      losses: json['losses'],
    );
  }
}

class UserInfo {
  final String userId;
  final String name;
  final String email;
  final bool isTestUser;
  final List<UserLeague> leagues;
  final int totalLeagues;
  final int activeLeagues;
  final int eliminatedLeagues;

  UserInfo({
    required this.userId,
    required this.name,
    required this.email,
    required this.isTestUser,
    required this.leagues,
    required this.totalLeagues,
    required this.activeLeagues,
    required this.eliminatedLeagues,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      userId: json['userId'],
      name: json['name'],
      email: json['email'],
      isTestUser: json['isTestUser'],
      leagues: (json['leagues'] as List)
          .map((league) => UserLeague.fromJson(league))
          .toList(),
      totalLeagues: json['totalLeagues'],
      activeLeagues: json['activeLeagues'],
      eliminatedLeagues: json['eliminatedLeagues'],
    );
  }
}