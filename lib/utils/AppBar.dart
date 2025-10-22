import 'dart:convert'; // 👈 for decoding cached user JSON
import 'package:flutter/material.dart';
import 'package:meubcars/Data/Models/user_model.dart';
import 'package:meubcars/utils/AppSideMenu.dart';
import 'package:meubcars/core/cache/CacheHelper.dart';
import 'package:meubcars/Data/remote/auth_remote.dart';
import 'package:meubcars/Data/repositories/auth_repository.dart';

class AppBarWithMenu extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  // Navigation
  final void Function(String route) onNavigate;
  final String homeRoute;
  final String loginRoute;

  // Optional callbacks
  final VoidCallback? onHomePressed;

  // UI
  final bool showMenuButton;
  final bool showHomeButton;

  // User
  final UserModel? currentUser;
  final String? avatarUrl;

  /// If you don’t pass this, we’ll try to read a cached name.
  final String? userName;

  // Compat
  final List<MenuSection> sections;
  final String activeRoute;

  const AppBarWithMenu({
    super.key,
    required this.title,
    required this.onNavigate,
    this.homeRoute = '/home',
    this.loginRoute = '/login',
    this.onHomePressed,
    this.showMenuButton = true,
    this.showHomeButton = true,
    this.currentUser,
    this.avatarUrl,
    this.userName,
    this.sections = const [],
    this.activeRoute = '',
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  void _openDrawer(BuildContext ctx) {
    final s = Scaffold.maybeOf(ctx);
    if (s?.hasDrawer ?? false) {
      s!.openDrawer();
    } else if (s?.hasEndDrawer ?? false) {
      s!.openEndDrawer();
    }
  }

  void _goHome(BuildContext context) {
    final s = Scaffold.maybeOf(context);
    if (s?.isDrawerOpen ?? false) Navigator.of(context).pop();
    final current = ModalRoute.of(context)?.settings.name;
    if (current == homeRoute) return;
    Navigator.of(context).pushNamedAndRemoveUntil(homeRoute, (r) => false);
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'UT';
    if (parts.length == 1) {
      final s = parts.first;
      return (s.length >= 2 ? s.substring(0, 2) : s).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Future<void> _logoutFlow(BuildContext context) async {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.kBg2,
        title: const Text('Déconnexion', style: TextStyle(color: Colors.white)),
        content: const Text('Voulez-vous vous déconnecter ?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Always clear local state even if network fails
      final repo = AuthRepository(AuthRemote());
      await repo.logout();
    } finally {
      Navigator.of(context).pop(); // close progress
    }

    Navigator.of(context).pushNamedAndRemoveUntil(loginRoute, (r) => false);
  }

  /// Try to get a display name:
  /// 1) `userName` param
  /// 2) `currentUser.nomComplet`
  /// 3) `CacheHelper('userName')`
  /// 4) `CacheHelper('user').nomComplet`
  String _resolveDisplayName() {
    if (userName != null && userName!.trim().isNotEmpty) return userName!;
    if ((currentUser?.nomComplet ?? '').trim().isNotEmpty) return currentUser!.nomComplet;

    final cachedName = CacheHelper.getData<String>(key: 'userName');
    if (cachedName != null && cachedName.trim().isNotEmpty) return cachedName;

    final raw = CacheHelper.getData<String>(key: 'user');
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final n = (map['nomComplet'] ?? '').toString().trim();
        if (n.isNotEmpty) return n;
      } catch (_) {}
    }

    return 'Utilisateur';
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _resolveDisplayName();
    final initials = _initials(displayName);

    return AppBar(
      elevation: 2,
      backgroundColor: AppColors.kBg1,
      surfaceTintColor: Colors.transparent,
      leadingWidth: (showMenuButton && showHomeButton) ? 110 : 56,
      leading: Builder(
        builder: (ctx) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 12),
            if (showMenuButton)
              Container(
                decoration: BoxDecoration(color: AppColors.kBg3, borderRadius: BorderRadius.circular(12)),
                child: IconButton(
                  icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
                  onPressed: () => _openDrawer(ctx),
                  tooltip: 'Menu',
                ),
              ),
            if (showMenuButton && showHomeButton) const SizedBox(width: 8),
            if (showHomeButton)
              Container(
                decoration: BoxDecoration(color: AppColors.kBg3, borderRadius: BorderRadius.circular(12)),
                child: IconButton(
                  icon: const Icon(Icons.home_rounded, color: Colors.white, size: 22),
                  onPressed: onHomePressed ?? () => _goHome(context),
                  tooltip: 'Accueil',
                ),
              ),
          ],
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17),
      ),
      centerTitle: true,
      actions: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.only(left: 6),
          decoration: BoxDecoration(color: AppColors.kBg3, borderRadius: BorderRadius.circular(12)),
          child: PopupMenuButton<String>(
            tooltip: 'Compte',
            color: AppColors.kBg2,
            offset: const Offset(0, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) async {
              if (value == 'profile') {
                Navigator.pushNamed(context, '/profile', arguments: currentUser);
              } else if (value == 'logout') {
                await _logoutFlow(context);
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(
                value: 'profile',
                child: _MenuRow(icon: Icons.person_outline, label: 'Profil'),
              ),
              PopupMenuDivider(height: 8),
              PopupMenuItem(
                value: 'logout',
                child: _MenuRow(icon: Icons.logout_rounded, label: 'Déconnexion'),
              ),
            ],
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFF2D8CFF),
                  backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
                      ? NetworkImage(avatarUrl!)
                      : null,
                  child: (avatarUrl == null || avatarUrl!.isEmpty)
                      ? Text(
                    initials,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  )
                      : null,
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    displayName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white70),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
