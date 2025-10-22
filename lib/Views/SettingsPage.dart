import 'package:flutter/material.dart';
import 'package:meubcars/utils/AppBar.dart';
import 'package:meubcars/utils/AppSideMenu.dart';
import 'package:meubcars/core/cache/CacheHelper.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notif = CacheHelper.getData<bool>(key: 'notif') ?? true;
  String _lang = CacheHelper.getData<String>(key: 'lang') ?? 'fr';

  @override
  Widget build(BuildContext context) {
    final routeNow = ModalRoute.of(context)?.settings.name ?? '/settings';


    void go(String r) {
      if (routeNow == r) return;
      Navigator.of(context).pushReplacementNamed(r);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBarWithMenu(
        title: 'Paramètres',
        onNavigate: go,
        activeRoute: routeNow,
      ),
      drawer: AppSideMenu(
        activeRoute: routeNow,
        onNavigate: go, sections: [],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720),
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF121214).withOpacity(.4),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile.adaptive(
                value: _notif,
                title: const Text('Notifications', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Recevoir des alertes',
                    style: TextStyle(color: Colors.white70)),
                onChanged: (v) {
                  setState(() => _notif = v);
                  CacheHelper.saveData(key: 'notif', value: v);
                },
              ),
              const Divider(),
              const SizedBox(height: 8),
              const Text('Langue',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _lang,
                dropdownColor: const Color(0xFF1E1F22),
                items: const [
                  DropdownMenuItem(value: 'fr', child: Text('Français')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _lang = v);
                  CacheHelper.saveData(key: 'lang', value: v);
                },
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Color(0xFF222327),
                  border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              // Add more settings here...
            ],
          ),
        ),
      ),
    );
  }
}
