import 'package:flutter/material.dart';
import 'api_service.dart';
import 'models.dart';
import 'league_detail_screen.dart';
import 'login_screen.dart';

class LeaguesScreen extends StatefulWidget {
  final User user;

  const LeaguesScreen({super.key, required this.user});

  @override
  State<LeaguesScreen> createState() => _LeaguesScreenState();
}

class _LeaguesScreenState extends State<LeaguesScreen> {
  List<Survivor> availableLeagues = [];
  UserInfo? userInfo;
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final results = await Future.wait([
        ApiService.getAllSurvivors(),
        ApiService.getUserInfo(widget.user.userId),
      ]);

      final leagues = results[0] as List<Survivor>;
      final userInfoData = results[1] as Map<String, dynamic>;

      setState(() {
        availableLeagues = leagues;
        userInfo = UserInfo.fromJson(userInfoData);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error cargando datos: $e';
        isLoading = false;
      });
    }
  }

  Future<void> joinLeague(Survivor league) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Colors.orange),
        ),
      );

      await ApiService.joinSurvivor(widget.user.userId, league.id);

      Navigator.pop(context);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LeagueDetailScreen(
            user: widget.user,
            league: league,
          ),
        ),
      );
    } catch (e) {
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uniéndose a la liga: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> enterLeague(UserLeague userLeague, Survivor survivor) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LeagueDetailScreen(
          user: widget.user,
          league: survivor,
        ),
      ),
    );
  }

  Future<void> logout() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Colors.orange),
        ),
      );

      await ApiService.logout(widget.user.userId);

      Navigator.pop(context);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cerrando sesión: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Survivor _createSurvivorFromUserLeague(UserLeague userLeague) {
    return Survivor(
      id: userLeague.survivorId,
      name: userLeague.survivorName,
      competition: [],
      startDate: DateTime.now(),
      lives: userLeague.lives,
      currentWeek: userLeague.currentWeek,
      totalWeeks: userLeague.totalWeeks,
      prizePool: userLeague.prizePool,
      status: userLeague.leagueStatus,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1B24),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.orange,
                        child: Text(
                          widget.user.name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hola, ${widget.user.name}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              userInfo != null
                                  ? '${userInfo!.activeLeagues} liga${userInfo!.activeLeagues != 1 ? 's' : ''} activa${userInfo!.activeLeagues != 1 ? 's' : ''}'
                                  : 'Elige una liga para jugar',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (userInfo != null && userInfo!.activeLeagues > 0)
                        IconButton(
                          onPressed: () => logout(),
                          icon: const Icon(Icons.logout, color: Colors.white70),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.orange),
                    )
                  : errorMessage.isNotEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                errorMessage,
                                style: const TextStyle(color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    isLoading = true;
                                    errorMessage = '';
                                  });
                                  loadData();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                ),
                                child: const Text(
                                  'Reintentar',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (userInfo != null && userInfo!.leagues.isNotEmpty) ...[
                                const Text(
                                  'MIS LIGAS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...userInfo!.leagues.map((userLeague) {
                                  final survivor = availableLeagues.firstWhere(
                                    (s) => s.id == userLeague.survivorId,
                                    orElse: () => _createSurvivorFromUserLeague(userLeague),
                                  );
                                  return UserLeagueCard(
                                    userLeague: userLeague,
                                    survivor: survivor,
                                    onEnter: () => enterLeague(userLeague, survivor),
                                  );
                                }).toList(),
                                const SizedBox(height: 24),
                              ],

                              const Text(
                                'LIGAS DISPONIBLES',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...availableLeagues.where((league) {
                                return userInfo?.leagues.every((ul) => ul.survivorId != league.id) ?? true;
                              }).map((league) {
                                return LeagueCard(
                                  league: league,
                                  onJoin: () => joinLeague(league),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class LeagueCard extends StatelessWidget {
  final Survivor league;
  final VoidCallback onJoin;

  const LeagueCard({
    super.key,
    required this.league,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF5A0D0D).withOpacity(0.8),
            const Color(0xFF8B1D1D).withOpacity(0.6),
            const Color(0xFF1F1B24).withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  league.name.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: league.status == 'active'
                      ? Colors.green.withOpacity(0.2)
                      : Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: league.status == 'active'
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
                child: Text(
                  league.status.toUpperCase(),
                  style: TextStyle(
                    color: league.status == 'active'
                        ? Colors.green
                        : Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              _InfoChip(
                icon: Icons.favorite,
                value: league.lives == league.lives.round()
                    ? '${league.lives.toInt()}'
                    : '${league.lives}',
                label: 'VIDAS',
              ),
              const SizedBox(width: 8),
              _InfoChip(
                icon: Icons.calendar_today,
                value: '${league.currentWeek}',
                label: 'JORNADA',
                suffix: '/${league.totalWeeks}',
              ),
              const SizedBox(width: 8),
              _InfoChip(
                icon: Icons.attach_money,
                value: '\$${league.prizePool.toInt()}',
                label: 'PREMIO',
              ),
            ],
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: league.currentWeek > 1 ? null : onJoin,
              style: ElevatedButton.styleFrom(
                backgroundColor: league.currentWeek > 1 ? Colors.red.shade700 : Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                league.currentWeek > 1 ? 'LIGA YA COMENZÓ' : 'UNIRSE A ESTA LIGA',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UserLeagueCard extends StatelessWidget {
  final UserLeague userLeague;
  final Survivor survivor;
  final VoidCallback onEnter;

  const UserLeagueCard({
    super.key,
    required this.userLeague,
    required this.survivor,
    required this.onEnter,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = userLeague.status == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isActive
              ? [
                  const Color(0xFF0D5A2A).withOpacity(0.8),
                  const Color(0xFF1D8B3A).withOpacity(0.6),
                  const Color(0xFF1F1B24).withOpacity(0.9),
                ]
              : [
                  const Color(0xFF5A0D0D).withOpacity(0.5),
                  const Color(0xFF8B1D1D).withOpacity(0.3),
                  const Color(0xFF1F1B24).withOpacity(0.9),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  userLeague.survivorName.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isActive ? Colors.green : Colors.red),
                ),
                child: Text(
                  isActive ? 'ACTIVA' : 'ELIMINADO',
                  style: TextStyle(
                    color: isActive ? Colors.green : Colors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.favorite, size: 12, color: isActive ? Colors.green : Colors.red),
                          const SizedBox(width: 4),
                          Text(
                            userLeague.lives == userLeague.lives.round()
                                ? '${userLeague.lives.toInt()}'
                                : '${userLeague.lives}',
                            style: TextStyle(
                              color: isActive ? Colors.green : Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'VIDAS',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_today, size: 12, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            '${userLeague.currentWeek}/${userLeague.totalWeeks}',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'JORNADA',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onEnter,
              style: ElevatedButton.styleFrom(
                backgroundColor: isActive ? Colors.green : Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isActive ? 'JUGAR AHORA' : 'VER LIGA',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String? suffix;

  const _InfoChip({
    required this.icon,
    required this.value,
    required this.label,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 12, color: Colors.white70),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (suffix != null)
                  Text(
                    suffix!,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 8,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}