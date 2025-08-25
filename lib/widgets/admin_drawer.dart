import 'package:flutter/material.dart';
import '../core/auth_utils.dart';
import '../pages/admin/admin_users_page.dart';
import '../pages/admin/admin_stats_page.dart';
import '../pages/admin/admin_user_mgmt.dart';

class AdminDrawer extends StatelessWidget {
  const AdminDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: <Widget>[
            const ListTile(
              leading: Icon(Icons.admin_panel_settings),
              title: Text('Admin'),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Nutzer & Notizen'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (BuildContext c) => const AdminUsersPage()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Statistiken'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (BuildContext c) => const AdminStatsPage()));
              },
            ),
            // ListTile(
            //   leading: const Icon(Icons.manage_accounts),
            //   title: const Text('Nutzerverwaltung'),
            //   onTap: () {
            //     Navigator.of(context).pop();
            //     Navigator.of(context).push(MaterialPageRoute(builder: (BuildContext c) => const AdminUserMgmtPage()));
            //   },
            // ),
          ],
        ),
      ),
    );
  }
}
