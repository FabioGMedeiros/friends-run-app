import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:friends_run/core/services/location_service.dart';
import 'package:friends_run/core/services/race_service.dart';
import 'package:friends_run/models/race/race_model.dart';
import 'package:friends_run/core/utils/colors.dart';
import 'package:friends_run/core/services/auth_service.dart';
import 'package:friends_run/models/user/app_user.dart';
import 'package:friends_run/views/auth/auth_main_view.dart';
import 'package:friends_run/views/profile/profile_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final RaceService _raceService = RaceService();
  final LocationService _locationService = LocationService();
  final AuthService _authService = AuthService();
  late Future<List<Race>> _racesFuture;
  late final Future<AppUser?> _userFuture;
  bool _isLoadingLocation = true;
  double? _userLatitude;
  double? _userLongitude;

  @override
  void initState() {
    super.initState();
    _getUserLocationAndRaces();
    _userFuture = _loadUser();
  }

  Future<void> _getUserLocationAndRaces() async {
    try {
      final location = await _locationService.getCurrentLocation();
      setState(() {
        _userLatitude = location.latitude;
        _userLongitude = location.longitude;
        _isLoadingLocation = false;
      });

      _racesFuture = _raceService.getNearbyRaces(
        userLatitude: _userLatitude!,
        userLongitude: _userLongitude!,
      );
    } catch (e) {
      debugPrint('Erro ao obter localização: $e');
      setState(() => _isLoadingLocation = false);
      _racesFuture = _raceService.getNearbyRaces(
        userLatitude: -23.5505, // Fallback para São Paulo
        userLongitude: -46.6333,
      );
    }
  }

  Future<AppUser?> _loadUser() async {
    try {
      return await _authService.getCurrentUser();
    } catch (e) {
      debugPrint("Erro ao carregar usuário: $e");
      return null;
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await _authService.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthMainView()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao fazer logout: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: _buildDrawer(context),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          'Corridas Próximas',
          style: TextStyle(color: AppColors.white),
        ),
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.white),
            onPressed: () {
              setState(() {
                _isLoadingLocation = true;
                _getUserLocationAndRaces();
              });
            },
          ),
        ],
      ),
      body: _isLoadingLocation
          ? const Center(child: CircularProgressIndicator())
          : _buildRaceList(),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return FutureBuilder<AppUser?>(
      future: _userFuture,
      builder: (context, snapshot) {
        final user = snapshot.data;
        
        return Drawer(
          backgroundColor: AppColors.background,
          child: Column(
            children: [
              // Cabeçalho do Drawer com dados do usuário
              UserAccountsDrawerHeader(
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withOpacity(0.8),
                ),
                accountName: Text(
                  user?.name ?? 'Nome do Usuário',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                accountEmail: Text(user?.email ?? 'usuario@email.com'),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: AppColors.white,
                  child: user?.profileImageUrl != null
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: user!.profileImageUrl!,
                            placeholder: (context, url) => const CircularProgressIndicator(),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.person,
                              color: AppColors.primaryRed,
                              size: 40,
                            ),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          color: AppColors.primaryRed,
                          size: 40,
                        ),
                ),
              ),

              // Opções do menu
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildDrawerItem(
                      icon: Icons.home,
                      title: 'Início',
                      onTap: () {
                        Navigator.pop(context);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.person,
                      title: 'Meu Perfil',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfileView(),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.flag,
                      title: 'Minhas Corridas',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/my-races');
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.group,
                      title: 'Meus Grupos',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/groups');
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.leaderboard,
                      title: 'Estatísticas',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/stats');
                      },
                    ),
                    const Divider(color: AppColors.white),
                    _buildDrawerItem(
                      icon: Icons.settings,
                      title: 'Configurações',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/settings');
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.help,
                      title: 'Ajuda',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/help');
                      },
                    ),
                    const Divider(color: AppColors.white),
                    _buildDrawerItem(
                      icon: Icons.logout,
                      title: 'Sair',
                      onTap: () => _logout(context),
                    ),
                  ],
                ),
              ),

              // Rodapé do Drawer
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Friends Run v1.0',
                  style: TextStyle(color: AppColors.white.withOpacity(0.6)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.white),
      title: Text(title, style: const TextStyle(color: AppColors.white)),
      onTap: onTap,
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      backgroundColor: AppColors.primaryRed,
      onPressed: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: AppColors.background,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (context) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.add_location,
                      color: AppColors.primaryRed,
                    ),
                    title: const Text(
                      'Criar Corrida',
                      style: TextStyle(color: AppColors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/create-race');
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.group_add,
                      color: AppColors.primaryRed,
                    ),
                    title: const Text(
                      'Criar Grupo',
                      style: TextStyle(color: AppColors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/create-group');
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
      child: const Icon(Icons.add, color: AppColors.white),
    );
  }

  Widget _buildRaceList() {
    return FutureBuilder<List<Race>>(
      future: _racesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 50),
                const SizedBox(height: 16),
                const Text(
                  'Erro ao carregar corridas',
                  style: TextStyle(color: AppColors.white, fontSize: 18),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _getUserLocationAndRaces(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: AppColors.white,
                  ),
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          );
        }

        final races = snapshot.data ?? [];

        if (races.isEmpty) {
          return Center(
            child: Text(
              'Nenhuma corrida próxima encontrada',
              style: TextStyle(
                color: AppColors.white.withOpacity(0.8),
                fontSize: 18,
              ),
            ),
          );
        }

        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: races.length,
          itemBuilder: (context, index) => _buildRaceCard(races[index]),
          separatorBuilder: (_, __) => const SizedBox(height: 4),
        );
      },
    );
  }

  Widget _buildRaceCard(Race race) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.white.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (race.imageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Image.network(
                race.imageUrl!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return SizedBox(
                    height: 180,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 180,
                  color: Colors.grey[800],
                  child: const Center(
                    child: Icon(
                      Icons.map,
                      color: AppColors.primaryRed,
                      size: 50,
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        race.title,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        race.formattedDistance,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildRaceInfoRow(Icons.calendar_today, race.formattedDate),
                _buildRaceInfoRow(
                  Icons.location_on,
                  '${race.startAddress} → ${race.endAddress}',
                ),
                _buildRaceInfoRow(
                  Icons.people,
                  '${race.participants} participantes confirmados',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _joinRace(race),
                    child: const Text('Participar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRaceInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryRed),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.white.withOpacity(0.9),
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _joinRace(Race race) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        title: const Text(
          'Confirmar participação',
          style: TextStyle(color: AppColors.black),
        ),
        content: Text(
          'Deseja participar da corrida "${race.title}"?',
          style: TextStyle(color: AppColors.black),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.primaryRed),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: AppColors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Você está participando de "${race.title}"'),
                  backgroundColor: AppColors.primaryRed,
                ),
              );
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}