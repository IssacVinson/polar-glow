import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/services/account_deletion_service.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_widgets.dart';
import '../providers/auth_provider.dart';
import 'privacy_policy_screen.dart';
import 'profile_screen.dart';
import 'terms_of_service_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    final name =
        context.watch<AuthProvider>().appUser?.displayName ?? 'Account';

    return Scaffold(
      appBar: AppBar(
        title: Text(embedded ? 'Account' : 'Settings'),
        automaticallyImplyLeading: !embedded,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          GlowCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.cyan.withValues(alpha: 0.16),
                  child: const Icon(Icons.person, color: AppColors.cyan),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          )),
                      const SizedBox(height: 2),
                      Text(email,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const GlowSectionLabel('Account'),
          const SizedBox(height: 10),
          GlowCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit profile'),
                  subtitle: const Text('Name, username, phone, password'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: const Text('Call Polar Glow'),
                  subtitle: const Text(AppConstants.phoneDisplay),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: launchAppPhone,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language_outlined),
                  title: const Text('Website'),
                  subtitle: const Text(AppConstants.websiteUrl),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => launchAppUrl(AppConstants.websiteUrl),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const GlowSectionLabel('Hours & area'),
          const SizedBox(height: 10),
          const GlowCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppConstants.hoursWeekday,
                    style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text(AppConstants.hoursSunday,
                    style: TextStyle(color: AppColors.textSecondary)),
                SizedBox(height: 10),
                Text(AppConstants.locationLine),
                SizedBox(height: 4),
                Text(
                  AppConstants.serviceAreaCopy,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const GlowSectionLabel('Legal'),
          const SizedBox(height: 10),
          GlowCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => launchAppUrl(AppConstants.privacyPolicyUrl),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Terms of Service'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => launchAppUrl(AppConstants.termsOfServiceUrl),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: const Text('Privacy Policy (in app)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.gavel_outlined),
                  title: const Text('Terms of Service (in app)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TermsOfServiceScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const GlowSectionLabel('Danger zone'),
          const SizedBox(height: 10),
          GlowCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.warning),
                  title: const Text('Sign out',
                      style: TextStyle(color: AppColors.warning)),
                  onTap: () async {
                    await context.read<AuthProvider>().signOut();
                    if (context.mounted) {
                      Navigator.popUntil(context, (route) => route.isFirst);
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      const Icon(Icons.delete_forever, color: AppColors.danger),
                  title: const Text('Delete account',
                      style: TextStyle(color: AppColors.danger)),
                  subtitle: const Text(
                    'Permanently delete your login and personal data',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  onTap: () => _confirmDelete(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final passwordController = TextEditingController();
    var loading = false;
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (context, setModal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GlowSectionLabel('Delete account'),
                  const SizedBox(height: 12),
                  Text(
                    'This cannot be undone',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We will delete your Polar Glow login, profile, reviews, and personal booking details. Completed paid jobs are kept for business records with your personal information removed.',
                    style:
                        TextStyle(color: AppColors.textSecondary, height: 1.45),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm with your password',
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!,
                        style: const TextStyle(color: AppColors.danger)),
                  ],
                  const SizedBox(height: 16),
                  GlowPrimaryButton(
                    label: loading ? 'Deleting…' : 'Delete my account',
                    loading: loading,
                    onPressed: () async {
                      final password = passwordController.text;
                      if (password.isEmpty) {
                        setModal(() => error = 'Password is required');
                        return;
                      }
                      setModal(() {
                        loading = true;
                        error = null;
                      });
                      try {
                        await AccountDeletionService()
                            .deleteCurrentAccount(password: password);
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      } catch (e) {
                        setModal(() {
                          loading = false;
                          error = e.toString();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  GlowOutlineButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
