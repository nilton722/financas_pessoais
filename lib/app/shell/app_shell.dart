import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const List<({String path, IconData icon, String label})> tabs = [
    (path: '/', icon: Icons.dashboard_outlined, label: 'Painel'),
    (path: '/movements', icon: Icons.swap_vert, label: 'Movimentos'),
    (
      path: '/accounts',
      icon: Icons.account_balance_wallet_outlined,
      label: 'Contas',
    ),
    (path: '/categories', icon: Icons.category_outlined, label: 'Categorias'),
    (path: '/planning', icon: Icons.event_note_outlined, label: 'Planeamento'),
  ];

  int _indexFor(String location) {
    if (location == '/') {
      return 0;
    }
    for (var index = 1; index < tabs.length; index++) {
      if (location.startsWith(tabs[index].path)) {
        return index;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indexFor(location),
        onDestinationSelected: (index) => context.go(tabs[index].path),
        destinations: [
          for (final tab in tabs)
            NavigationDestination(icon: Icon(tab.icon), label: tab.label),
        ],
      ),
    );
  }
}
