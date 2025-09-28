import 'package:flutter/material.dart';
import 'api_service.dart';
import 'models.dart';
import 'game_modals.dart';

class LeagueDetailScreen extends StatefulWidget {
  final User user;
  final Survivor league;

  const LeagueDetailScreen({
    super.key,
    required this.user,
    required this.league,
  });

  @override
  State<LeagueDetailScreen> createState() => _LeagueDetailScreenState();
}

class _LeagueDetailScreenState extends State<LeagueDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Map<String, dynamic>? leaderboardData;
  List<dynamic> predictions = [];
  List<dynamic> gambles = [];
  Map<String, dynamic>? resultsData;
  bool isLoading = true;
  String errorMessage = '';

  double userLives = 0;
  int userPosition = 0;
  int survivorsCount = 0;
  late int currentWeek;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    currentWeek = widget.league.currentWeek;
    loadLeagueData();
  }

  Future<void> loadLeagueData() async {
    try {
      final results = await Future.wait([
        ApiService.getLeaderboard(widget.league.id),
        ApiService.getPredictions(widget.league.id),
        ApiService.getGambles(widget.league.id),
        ApiService.getResults(widget.league.id),
        ApiService.getUserInfo(widget.user.userId),
      ]);

      final leaderboard = results[0] as Map<String, dynamic>;
      final preds = results[1] as List<dynamic>;
      final gams = results[2] as List<dynamic>;
      final resultData = results[3] as Map<String, dynamic>;
      final userInfo = results[4] as Map<String, dynamic>;

      final userGamble = gams.firstWhere(
        (g) => g['userId'] == widget.user.userId,
        orElse: () => {'lives': widget.league.lives, 'status': 'active'},
      );

      final currentLeague = (userInfo['leagues'] as List<dynamic>).firstWhere(
        (league) => league['survivorId'] == widget.league.id,
        orElse: () => {'currentWeek': widget.league.currentWeek},
      );


      final leaderboardList = leaderboard['leaderboard'] as List<dynamic>;
      final userIndex = leaderboardList.indexWhere(
        (player) => player['userId'] == widget.user.userId,
      );

      setState(() {
        leaderboardData = leaderboard;
        predictions = preds;
        gambles = gams;
        resultsData = resultData;
        userLives = (userGamble['lives'] as num?)?.toDouble() ?? widget.league.lives;
        userPosition = userIndex >= 0 ? userIndex + 1 : 0;
        survivorsCount = leaderboardList.where((p) => p['status'] == 'active').length;
        currentWeek = currentLeague['currentWeek'];
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error cargando datos: $e';
        isLoading = false;
      });
    }
  }

  Future<void> processWeek() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Colors.orange),
        ),
      );

      final result = await ApiService.processWeek();

      Navigator.pop(context);

      if (result['leagues'] != null) {
        final leagues = result['leagues'] as List<dynamic>;
        final currentLeague = leagues.firstWhere(
          (league) => league['survivorId'] == widget.league.id,
          orElse: () => null,
        );

        if (currentLeague != null) {
          setState(() {
            currentWeek = currentLeague['currentWeek'];
          });
        }
      }

      await loadLeagueData();

      final activePlayers = leaderboardData?['leaderboard']?.where((p) => (p['lives'] as num).toDouble() > 0).length ?? 0;
      final totalWeeks = widget.league.totalWeeks;
      final isGameFinished = currentWeek > totalWeeks;

      print('🔍 DEBUG MODAL CONDITIONS:');
      print('activePlayers: $activePlayers');
      print('userLives: $userLives');
      print('currentWeek: $currentWeek');
      print('totalWeeks: $totalWeeks');
      print('isGameFinished: $isGameFinished');
      print('userPosition: $userPosition');
      print('result[livesLost]: ${result['livesLost']}');

      if (mounted) {
        final currentUserLives = userLives;
        final shouldShowWinner = (activePlayers == 1 && currentUserLives > 0) ||
                                (isGameFinished && userPosition == 1 && currentUserLives > 0);

        print('shouldShowWinner: $shouldShowWinner (activePlayers: $activePlayers, currentUserLives: $currentUserLives, isGameFinished: $isGameFinished, userPosition: $userPosition)');

        if (shouldShowWinner) {
          print('🏆 SHOWING WINNER MODAL');
          await GameModals.showError(
            context,
            '🏆 ¡FELICIDADES!',
            isGameFinished
              ? '¡Has ganado la liga! Completaste todas las jornadas como líder y te llevas todo el pozo de \$${leaderboardData?['prizePool'] ?? 0}!'
              : '¡Has ganado la liga! Eres el último superviviente y te llevas todo el pozo de \$${leaderboardData?['prizePool'] ?? 0}!',
          );
        } else if (currentUserLives <= 0) {
          print('🔴 SHOULD SHOW ELIMINATION MODAL: currentUserLives = $currentUserLives');
          await GameModals.showNoLivesLeft(context);
        } else if (result['livesLost'] != null && result['livesLost'] > 0) {
          print('🟡 PROCESSING LIVES LOST: ${result['livesLost']}');
          final livesLost = (result['livesLost'] as num).toDouble();
          final newLives = currentUserLives - livesLost;

          if (newLives <= 0) {
            print('🔴 SHOWING ELIMINATION MODAL FROM LIVES LOST');
            await GameModals.showNoLivesLeft(context);
          } else {
            print('🟡 SHOWING LIFE LOST MODAL');
            await GameModals.showLifeLost(context, newLives, widget.league.lives);
          }
        }
      }

      if (mounted) {
        await GameModals.showError(
          context,
          '✅ Semana procesada',
          'La semana se ha procesado exitosamente. Revisa la pestaña de Resultados.',
        );
      }

    } catch (e) {
      if (mounted) {
        Navigator.pop(context);

        final errorMessage = e.toString().replaceAll('Exception: ', '');
        print('🚨 ProcessWeek Error: $errorMessage');

        if (errorMessage.contains('All leagues have finished') || errorMessage.contains('finished') || errorMessage.contains('Error procesando semana: 400') || errorMessage.contains('Error de conexión: Error procesando semana: 400')) {
          await loadLeagueData();

          final activePlayers = leaderboardData?['leaderboard']?.where((p) => (p['lives'] as num).toDouble() > 0).length ?? 0;
          final totalWeeks = widget.league.totalWeeks;
          final isGameFinished = currentWeek >= totalWeeks;

          print('🔍 ERROR CASE - DEBUG MODAL CONDITIONS:');
          print('activePlayers: $activePlayers');
          print('userLives: $userLives');
          print('currentWeek: $currentWeek');
          print('totalWeeks: $totalWeeks');
          print('isGameFinished: $isGameFinished');
          print('userPosition: $userPosition');

          if (mounted) {
            final currentUserLives = userLives;
            final shouldShowWinner = (activePlayers == 1 && currentUserLives > 0) ||
                                    (isGameFinished && userPosition == 1 && currentUserLives > 0);

            print('shouldShowWinner: $shouldShowWinner (activePlayers: $activePlayers, currentUserLives: $currentUserLives, isGameFinished: $isGameFinished, userPosition: $userPosition)');

            if (shouldShowWinner) {
              print('🏆 SHOWING WINNER MODAL (ERROR CASE)');
              await GameModals.showError(
                context,
                '🏆 ¡FELICIDADES!',
                isGameFinished
                  ? '¡Has ganado la liga! Completaste todas las jornadas como líder y te llevas todo el pozo de \$${leaderboardData?['prizePool'] ?? 0}!'
                  : '¡Has ganado la liga! Eres el último superviviente y te llevas todo el pozo de \$${leaderboardData?['prizePool'] ?? 0}!',
              );
            } else if (currentUserLives <= 0) {
              print('🔴 SHOWING ELIMINATION MODAL (ERROR CASE): currentUserLives = $currentUserLives');
              await GameModals.showNoLivesLeft(context);
            } else {
              await GameModals.showError(
                context,
                '🏁 Liga Finalizada',
                'Todas las ligas han terminado. Revisa los resultados finales en la pestaña de Tabla.',
              );
            }
          }
        } else {
          await GameModals.showError(
            context,
            '❌ Error',
            errorMessage,
          );
        }
      }
    }
  }

  Future<void> makePick(Match match, String teamId) async {
    final selectedTeam = teamId == match.home.id ? match.home : match.visitor;

    final confirmed = await GameModals.showPickConfirmation(
      context,
      match,
      selectedTeam,
    );

    if (confirmed != true) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Colors.orange),
        ),
      );

      await ApiService.makePick(
        userId: widget.user.userId,
        survivorId: widget.league.id,
        matchId: match.matchId,
        predictedTeamId: teamId,
        week: currentWeek,
      );

      Navigator.pop(context);

      await GameModals.showPickSuccess(context, selectedTeam);

      loadLeagueData();
    } catch (e) {
      Navigator.pop(context);

      await GameModals.showError(
        context,
        '❌ Error al hacer pick',
        e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF1F1B24),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.orange),
        ),
      );
    }

    if (errorMessage.isNotEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF1F1B24),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
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
                  loadLeagueData();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Reintentar', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFF1F1B24),
        body: Column(
          children: [
            HeroHeader(
              leagueName: widget.league.name,
              userLives: userLives,
              totalLives: widget.league.lives,
              userPosition: userPosition,
              prizePool: leaderboardData?['prizePool'] ?? widget.league.prizePool,
              survivorsCount: survivorsCount,
            ),

            Container(
              color: const Color(0xFF1F1B24),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.orange,
                unselectedLabelColor: Colors.white60,
                indicatorColor: Colors.orange,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                tabs: const [
                  Tab(text: 'Por jugar'),
                  Tab(text: 'Resultados'),
                  Tab(text: 'Tabla'),
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  PorJugarTab(
                    matches: widget.league.competition,
                    currentWeek: currentWeek,
                    onPickTeam: makePick,
                    predictions: predictions,
                    userId: widget.user.userId,
                  ),
                  ResultadosTab(resultsData: resultsData),
                  TablaTab(leaderboardData: leaderboardData),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: processWeek,
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.fast_forward),
          label: const Text('Procesar Semana'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class HeroHeader extends StatelessWidget {
  final String leagueName;
  final double userLives;
  final double totalLives;
  final int userPosition;
  final double prizePool;
  final int survivorsCount;

  const HeroHeader({
    super.key,
    required this.leagueName,
    required this.userLives,
    required this.totalLives,
    required this.userPosition,
    required this.prizePool,
    required this.survivorsCount,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 230,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF5A0D0D),
                  Color(0xFF8B1D1D),
                  Color(0xFF1F1B24),
                ],
              ),
            ),
          ),

          Container(color: Colors.black.withOpacity(0.25)),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        _CircIcon(Icons.arrow_back_ios_new_rounded, onTap: () {
                          Navigator.pop(context);
                        }),
                      ]),
                      Row(children: [
                        _CircIcon(Icons.share_rounded, onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Compartir liga')),
                          );
                        }),
                        const SizedBox(width: 8),
                        _CircIcon(Icons.info_outline_rounded, onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: const Color(0xFF2A2735),
                              title: const Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.orange),
                                  SizedBox(width: 8),
                                  Text('Cómo Jugar', style: TextStyle(color: Colors.white)),
                                ],
                              ),
                              content: Container(
                                width: double.maxFinite,
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'PENKA SURVIVOR',
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      _InfoSection(
                                        icon: Icons.sports_soccer,
                                        title: '🎯 OBJETIVO',
                                        content: 'Sobrevive más tiempo que otros jugadores eligiendo equipos ganadores cada jornada.',
                                      ),
                                      _InfoSection(
                                        icon: Icons.how_to_reg,
                                        title: '⚽ CÓMO JUGAR',
                                        content: '• Cada jornada elige UN equipo que crees que ganará\n• Solo puedes hacer picks en la jornada actual\n• NO puedes elegir el mismo equipo dos veces\n• Si tu equipo pierde o empata, pierdes una vida',
                                      ),
                                      _InfoSection(
                                        icon: Icons.favorite,
                                        title: '💖 VIDAS',
                                        content: 'Comienzas con ${totalLives.toInt()} vidas. Si pierdes todas, quedas eliminado de la liga.',
                                      ),
                                      _InfoSection(
                                        icon: Icons.emoji_events,
                                        title: '🏆 GANAR',
                                        content: 'El último jugador que quede con vidas se lleva todo el pozo acumulado de \$${prizePool.toStringAsFixed(0)}.',
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '📊 ESTADO ACTUAL',
                                              style: TextStyle(
                                                color: Colors.orange,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Liga: $leagueName\nTus vidas: ${userLives.toInt()}/${totalLives.toInt()}\nTu posición: #$userPosition\nSobrevivientes: $survivorsCount',
                                              style: const TextStyle(color: Colors.white70),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Entendido', style: TextStyle(color: Colors.orange)),
                                ),
                              ],
                            ),
                          );
                        }),
                      ]),
                    ],
                  ),

                  const Spacer(),

                  Text(
                    leagueName.toUpperCase(),
                    textAlign: TextAlign.left,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      shadows: const [
                        Shadow(
                          color: Colors.black45,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Center(
                    child: Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: [
                        _StatChip(
                          icon: Icons.favorite,
                          value: userLives == userLives.round()
                              ? '${userLives.toInt()}'
                              : '${userLives}',
                          label: 'VIDAS',
                          suffix: totalLives == totalLives.round()
                              ? '/${totalLives.toInt()}'
                              : '/${totalLives}',
                        ),
                        _StatChip(
                          icon: Icons.emoji_events,
                          value: userPosition.toString(),
                          label: 'POSICIÓN',
                          suffix: '/$survivorsCount',
                        ),
                        _StatChip(
                          icon: Icons.attach_money,
                          value: '\$${prizePool.toInt()}',
                          label: 'POZO ACUMULADO',
                        ),
                        _StatChip(
                          icon: Icons.groups,
                          value: survivorsCount.toString(),
                          label: 'SOBREVIVIENTES',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.only(
                              left: 25,
                              right: 12,
                              top: 6,
                              bottom: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'By ',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                Text(
                                  'PENKA',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.verified,
                                  size: 14,
                                  color: Colors.blue,
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            left: 0,
                            top: 3,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Colors.orange, Colors.amber],
                                ),
                                border: Border.all(color: Colors.black, width: 2),
                              ),
                              child: const Center(
                                child: Text(
                                  'P',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _CircIcon(this.icon, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(0.35),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String? suffix;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(
      color: Colors.white70,
      fontSize: 10,
      fontWeight: FontWeight.w500,
      letterSpacing: .2,
      height: 1.0,
    );

    final hasSuffix = suffix != null && suffix!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5.7, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 4),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                    if (hasSuffix)
                      TextSpan(
                        text: ' $suffix',
                        style: labelStyle,
                      ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(label, style: labelStyle),
          ),
        ],
      ),
    );
  }
}

class PorJugarTab extends StatefulWidget {
  final List<Match> matches;
  final int currentWeek;
  final Function(Match, String) onPickTeam;
  final List<dynamic> predictions;
  final String userId;

  const PorJugarTab({
    super.key,
    required this.matches,
    required this.currentWeek,
    required this.onPickTeam,
    required this.predictions,
    required this.userId,
  });

  @override
  State<PorJugarTab> createState() => _PorJugarTabState();
}

class _PorJugarTabState extends State<PorJugarTab> {

  @override
  Widget build(BuildContext context) {
    final matchesByWeek = <int, List<Match>>{};
    for (final match in widget.matches) {
      matchesByWeek.putIfAbsent(match.week, () => []).add(match);
    }

    final sortedWeeks = matchesByWeek.keys.toList()..sort();

    return Container(
      color: const Color(0xFF1F1B24),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sortedWeeks.length,
        itemBuilder: (context, index) {
          final week = sortedWeeks[index];
          final weekMatches = matchesByWeek[week]!;
          final isCurrentWeek = week == widget.currentWeek;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              initiallyExpanded: isCurrentWeek,
              backgroundColor: Colors.white.withOpacity(0.05),
              collapsedBackgroundColor: Colors.white.withOpacity(0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isCurrentWeek
                    ? Colors.orange.withOpacity(0.5)
                    : Colors.white.withOpacity(0.1),
                ),
              ),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isCurrentWeek
                    ? Colors.orange.withOpacity(0.5)
                    : Colors.white.withOpacity(0.1),
                ),
              ),
              iconColor: isCurrentWeek ? Colors.orange : Colors.white70,
              collapsedIconColor: isCurrentWeek ? Colors.orange : Colors.white70,
              title: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: isCurrentWeek ? Colors.orange : Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Jornada $week',
                    style: TextStyle(
                      color: isCurrentWeek ? Colors.orange : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isCurrentWeek)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'ACTUAL',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: Text(
                '${weekMatches.length} partidos',
                style: TextStyle(
                  color: isCurrentWeek ? Colors.orange.withOpacity(0.8) : Colors.white70,
                  fontSize: 12,
                ),
              ),
              children: weekMatches.map((match) {
                final userPrediction = widget.predictions.firstWhere(
                  (p) => p['matchId'] == match.matchId && p['userId'] == widget.userId,
                  orElse: () => null,
                );

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: MatchCard(
                    match: match,
                    onPickTeam: widget.onPickTeam,
                    userPrediction: userPrediction,
                    currentWeek: widget.currentWeek,
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

class ResultadosTab extends StatelessWidget {
  final Map<String, dynamic>? resultsData;

  const ResultadosTab({super.key, required this.resultsData});

  @override
  Widget build(BuildContext context) {
    if (resultsData == null) {
      return Container(
        color: const Color(0xFF1F1B24),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.orange),
        ),
      );
    }

    final matches = resultsData!['matches'] as List<dynamic>? ?? [];

    if (matches.isEmpty) {
      return Container(
        color: const Color(0xFF1F1B24),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sports_soccer, color: Colors.white54, size: 48),
              SizedBox(height: 16),
              Text(
                'No hay resultados disponibles',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    final Map<int, List<dynamic>> matchesByWeek = {};
    for (var match in matches) {
      final week = match['week'] as int;
      if (!matchesByWeek.containsKey(week)) {
        matchesByWeek[week] = [];
      }
      matchesByWeek[week]!.add(match);
    }

    final sortedWeeks = matchesByWeek.keys.toList()..sort();

    return Container(
      color: const Color(0xFF1F1B24),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sortedWeeks.length,
        itemBuilder: (context, index) {
          final week = sortedWeeks[index];
          final weekMatches = matchesByWeek[week]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Jornada $week',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              ...weekMatches.map((match) => _MatchResultCard(
                match: match,
              )).toList(),

              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _MatchResultCard extends StatelessWidget {
  final dynamic match;

  const _MatchResultCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final homeTeam = match['homeTeam'] ?? {};
    final visitorTeam = match['visitorTeam'] ?? {};

    final homeTeamName = '${homeTeam['flag'] ?? ''} ${homeTeam['name'] ?? 'Equipo Local'}';
    final visitorTeamName = '${visitorTeam['flag'] ?? ''} ${visitorTeam['name'] ?? 'Equipo Visitante'}';

    final result = match['result'] ?? 'draw';
    final finished = match['finished'] ?? false;

    Color cardColor;
    Color borderColor;
    IconData resultIcon;
    String resultText;

    if (!finished) {
      cardColor = Colors.blue.withOpacity(0.1);
      borderColor = Colors.blue.withOpacity(0.3);
      resultIcon = Icons.schedule;
      resultText = 'Pendiente';
    } else {
      switch (result) {
        case 'home':
          cardColor = Colors.green.withOpacity(0.1);
          borderColor = Colors.green.withOpacity(0.3);
          resultIcon = Icons.check_circle;
          resultText = 'Ganó Local';
          break;
        case 'visitor':
          cardColor = Colors.purple.withOpacity(0.1);
          borderColor = Colors.purple.withOpacity(0.3);
          resultIcon = Icons.check_circle;
          resultText = 'Ganó Visitante';
          break;
        case 'draw':
          cardColor = Colors.orange.withOpacity(0.1);
          borderColor = Colors.orange.withOpacity(0.3);
          resultIcon = Icons.horizontal_rule;
          resultText = 'Empate';
          break;
        default:
          cardColor = Colors.grey.withOpacity(0.1);
          borderColor = Colors.grey.withOpacity(0.3);
          resultIcon = Icons.help_outline;
          resultText = 'Desconocido';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$homeTeamName vs $visitorTeamName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(resultIcon, color: borderColor.withOpacity(0.8), size: 20),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: borderColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  resultText,
                  style: TextStyle(
                    color: borderColor.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (finished)
                Text(
                  'Finalizado',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class TablaTab extends StatelessWidget {
  final Map<String, dynamic>? leaderboardData;

  const TablaTab({super.key, required this.leaderboardData});

  @override
  Widget build(BuildContext context) {
    if (leaderboardData == null) {
      return Container(
        color: const Color(0xFF1F1B24),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.orange),
        ),
      );
    }

    final leaderboard = leaderboardData!['leaderboard'] as List<dynamic>;

    return Container(
      color: const Color(0xFF1F1B24),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: leaderboard.length,
        itemBuilder: (context, index) {
          final player = leaderboard[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    player['name'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '${(player['lives'] as num).toDouble() == (player['lives'] as num).toDouble().round() ? (player['lives'] as num).toInt() : (player['lives'] as num).toDouble()} ❤️',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class MatchCard extends StatelessWidget {
  final Match match;
  final Function(Match, String) onPickTeam;
  final dynamic userPrediction;
  final int currentWeek;

  const MatchCard({
    super.key,
    required this.match,
    required this.onPickTeam,
    this.userPrediction,
    required this.currentWeek,
  });

  @override
  Widget build(BuildContext context) {
    final hasPrediction = userPrediction != null;
    final predictedTeamId = hasPrediction ? userPrediction['predictedTeamId'] : null;
    final isCurrentWeek = match.week == currentWeek;
    final canMakePick = isCurrentWeek && !hasPrediction;

    if (match.week == 2) {
      print('🎯 Match week 2: currentWeek=$currentWeek, isCurrentWeek=$isCurrentWeek, canMakePick=$canMakePick');
    }


    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: canMakePick ? () => onPickTeam(match, match.home.id) : null,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: predictedTeamId == match.home.id
                          ? Colors.green.withOpacity(0.3)
                          : !isCurrentWeek
                              ? Colors.grey.withOpacity(0.05)
                              : hasPrediction
                                  ? Colors.grey.withOpacity(0.1)
                                  : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: predictedTeamId == match.home.id
                            ? Colors.green
                            : !isCurrentWeek
                                ? Colors.grey.withOpacity(0.2)
                                : hasPrediction
                                    ? Colors.grey.withOpacity(0.3)
                                    : Colors.orange.withOpacity(0.5),
                        width: predictedTeamId == match.home.id ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          match.home.flag,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            match.home.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              Expanded(
                child: GestureDetector(
                  onTap: canMakePick ? () => onPickTeam(match, match.visitor.id) : null,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: predictedTeamId == match.visitor.id
                          ? Colors.green.withOpacity(0.3)
                          : !isCurrentWeek
                              ? Colors.grey.withOpacity(0.05)
                              : hasPrediction
                                  ? Colors.grey.withOpacity(0.1)
                                  : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: predictedTeamId == match.visitor.id
                            ? Colors.green
                            : !isCurrentWeek
                                ? Colors.grey.withOpacity(0.2)
                                : hasPrediction
                                    ? Colors.grey.withOpacity(0.3)
                                    : Colors.orange.withOpacity(0.5),
                        width: predictedTeamId == match.visitor.id ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            match.visitor.name,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          match.visitor.flag,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (hasPrediction)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.5)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Pick realizado',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;

  const _InfoSection({
    required this.icon,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}