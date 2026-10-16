/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/language/language_bloc.dart';
import '../../blocs/language/language_state.dart';
import '../../blocs/theme/theme_bloc.dart';
import '../../blocs/theme/theme_event.dart';
import '../../blocs/theme/theme_state.dart';
import '../../config/app_info.dart';
import '../../config/legal_links.dart';
import '../../design/td_design.dart';
import '../../models/user_model.dart';
import '../../services/review_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common/legal_links_row.dart';
import '../../widgets/profile/editable_profile_avatar.dart';
import '../../widgets/profile/fiberoptics25_logo.dart';
import 'notification_settings_screen.dart';

/// Profil und Einstellungen: Profilbild und Name, Darstellung (Themes,
/// Systemautomatik), Sprache, Benachrichtigungen, App, Konto.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const SizedBox.shrink();

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthProfileUpdateFailure) {
          TdToast.show(
            context,
            '${l10n.saveError}: ${state.message}',
            variant: TdToastVariant.error,
          );
          context.read<AuthBloc>().add(const AuthCheckRequested());
        }
      },
      builder: (context, state) {
        if (state is AuthProfileUpdateLoading) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: TdSpace.lg),
                  Text(l10n.profileSaving),
                ],
              ),
            ),
          );
        }
        if (state is! AuthAuthenticated) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = state.user;
        final wide = context.tdLayout == TdLayoutSize.expanded;

        final left = [
          TdFadeSlideIn(index: 0, child: _ProfileHeader(user: user)),
          const Fiberoptics25Logo(),
          const SizedBox(height: TdSpace.lg),
          TdFadeSlideIn(index: 1, child: const _AppearanceSection()),
          const SizedBox(height: TdSpace.lg),
          TdFadeSlideIn(index: 2, child: const _LanguageSection()),
        ];
        final right = [
          TdFadeSlideIn(index: 3, child: const _NotificationsSection()),
          const SizedBox(height: TdSpace.lg),
          TdFadeSlideIn(index: 4, child: const _AppSection()),
          const SizedBox(height: TdSpace.lg),
          TdFadeSlideIn(index: 5, child: _AccountSection(user: user)),
        ];

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                TdSpace.page,
                TdSpace.lg,
                TdSpace.page,
                120,
              ),
              children: [
                Text(l10n.profile, style: context.text.headlineLarge),
                const SizedBox(height: TdSpace.lg),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: left,
                        ),
                      ),
                      const SizedBox(width: TdSpace.xl),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: right,
                        ),
                      ),
                    ],
                  )
                else ...[
                  ...left,
                  const SizedBox(height: TdSpace.lg),
                  ...right,
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
    this.icon,
    this.padding = const EdgeInsets.all(TdSpace.lg),
  });

  final String title;
  final IconData? icon;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(TdSpace.xs, 0, 0, TdSpace.sm),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: context.td.muted),
                const SizedBox(width: TdSpace.xs + 2),
              ],
              Text(title, style: context.text.titleMedium),
            ],
          ),
        ),
        TdCard(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }
}

/// Zeile mit Symbol, Text, optionalem Wert und Pfeil.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
    this.danger = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final bool danger;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = danger ? context.td.danger : context.colors.onSurface;
    return TdPressable(
      onTap: onTap,
      scale: 0.985,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TdSpace.lg,
          vertical: TdSpace.md + 2,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: danger ? color : context.td.muted),
            const SizedBox(width: TdSpace.md),
            Expanded(
              child: Text(
                label,
                style: context.text.bodyLarge?.copyWith(color: color),
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: context.text.bodyMedium?.copyWith(color: context.td.muted),
              ),
            if (trailing != null) trailing!,
            if (onTap != null && trailing == null) ...[
              const SizedBox(width: TdSpace.xs),
              Icon(Icons.chevron_right_rounded, color: context.td.muted),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final UserModel user;

  Future<void> _editName(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final bloc = context.read<AuthBloc>();
    final controller = TextEditingController(text: user.displayName);
    final name = await showTdSheet<String>(
      context,
      title: l10n.editProfile,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TdTextField(
            controller: controller,
            label: l10n.displayName,
            hint: l10n.yourName,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
          ),
          const SizedBox(height: TdSpace.xl),
          Row(
            children: [
              Expanded(
                child: TdButton.secondary(
                  label: l10n.cancel,
                  onPressed: () => Navigator.of(ctx).maybePop(),
                ),
              ),
              const SizedBox(width: TdSpace.md),
              Expanded(
                flex: 2,
                child: ValueListenableBuilder(
                  valueListenable: controller,
                  builder: (ctx, v, _) => TdButton.primary(
                    label: l10n.save,
                    icon: Icons.check_rounded,
                    expanded: true,
                    onPressed: v.text.trim().length < 2
                        ? null
                        : () => Navigator.of(ctx).pop(v.text.trim()),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name == user.displayName) return;
    bloc.add(AuthUpdateProfileRequested(displayName: name));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return TdCard(
      variant: TdCardVariant.gradient,
      padding: const EdgeInsets.all(TdSpace.xl),
      child: Row(
        children: [
          EditableProfileAvatar(user: user, radius: 42),
          const SizedBox(width: TdSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.displayName,
                        style: context.text.headlineSmall?.copyWith(
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: TdSpace.xs),
                    IconButton(
                      tooltip: l10n.editProfile,
                      onPressed: () => _editName(context),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                Text(
                  user.email,
                  style: context.text.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: TdSpace.xs),
                Text(
                  '${l10n.memberSince} ${DateFormat.yMMMd(locale).format(user.createdAt)}',
                  style: context.text.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.75),
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

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  static String themeLabel(AppLocalizations l10n, String id) => switch (id) {
    'System' => l10n.theme_system,
    'Light' => l10n.theme_light,
    'Dark' => l10n.theme_dark,
    'Matrix' => l10n.theme_matrix,
    'Neo' => l10n.theme_neo,
    'Summer' => l10n.theme_summer,
    'Aurora' => l10n.theme_aurora,
    'Sunset' => l10n.theme_sunset,
    'Ocean' => l10n.theme_ocean,
    'Forest' => l10n.theme_forest,
    'Galaxy' => l10n.theme_galaxy,
    'Fiberoptics25' => l10n.theme_fiberoptics25,
    _ => id,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, state) {
        final current = switch (state) {
          ThemeLoadSuccess(:final themeName) => themeName,
          ThemeChangedSuccess(:final themeName) => themeName,
          _ => AppTheme.defaultTheme,
        };
        return _SectionCard(
          title: l10n.appearance,
          icon: Icons.palette_outlined,
          padding: const EdgeInsets.symmetric(vertical: TdSpace.lg),
          children: [
            SizedBox(
              height: 118,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: TdSpace.lg),
                clipBehavior: Clip.none,
                children: [
                  _ThemeSwatch(
                    id: AppTheme.systemTheme,
                    label: themeLabel(l10n, AppTheme.systemTheme),
                    colors: const [
                      TdPalettes.light,
                      TdPalettes.dark,
                    ],
                    selected: current == AppTheme.systemTheme,
                    system: true,
                  ),
                  for (final p in TdPalettes.all)
                    _ThemeSwatch(
                      id: p.id,
                      label: themeLabel(l10n, p.id),
                      colors: [p],
                      selected: current == p.id,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.id,
    required this.label,
    required this.colors,
    required this.selected,
    this.system = false,
  });

  final String id;
  final String label;
  final List<TdPalette> colors;
  final bool selected;
  final bool system;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final p = colors.first;
    return Padding(
      padding: const EdgeInsets.only(right: TdSpace.md),
      child: TdPressable(
        onTap: () => context.read<ThemeBloc>().add(ThemeChanged(id)),
        haptic: true,
        semanticLabel: label,
        child: SizedBox(
          width: 84,
          child: Column(
            children: [
              AnimatedContainer(
                duration: TdMotion.of(context, TdMotion.base),
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(TdRadius.lg),
                  border: Border.all(
                    color: selected ? scheme.primary : scheme.outlineVariant,
                    width: selected ? 3 : 1,
                  ),
                  boxShadow: selected ? TdShadows.glow(scheme.primary) : null,
                ),
                clipBehavior: Clip.antiAlias,
                child: system
                    ? Row(
                        children: [
                          Expanded(child: _Preview(colors[0])),
                          Expanded(child: _Preview(colors[1])),
                        ],
                      )
                    : _Preview(p),
              ),
              const SizedBox(height: TdSpace.sm),
              Text(
                label,
                style: context.text.labelSmall?.copyWith(
                  color: selected ? scheme.primary : null,
                  fontWeight: selected ? FontWeight.w700 : null,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview(this.p);

  final TdPalette p;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: p.background,
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 12,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: p.resolvedHeroGradient),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 8,
            width: 30,
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: p.outline ?? p.onSurfaceMuted, width: 0.5),
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              for (final c in [p.primary, p.secondary, p.tertiary])
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 2),
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LanguageSection extends StatelessWidget {
  const _LanguageSection();

  static const options = [
    ('de', 'DE', 'Deutsch (Deutschland)'),
    ('de', 'AT', 'Deutsch (Österreich)'),
    ('en', 'GB', 'English (United Kingdom)'),
    ('en', 'US', 'English (United States)'),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<LanguageBloc, LanguageState>(
      builder: (context, state) {
        final (lang, country) = switch (state) {
          LanguageLoadSuccess(:final languageCode, :final countryCode) => (
            languageCode,
            countryCode,
          ),
          LanguageChangedSuccess(:final languageCode, :final countryCode) => (
            languageCode,
            countryCode,
          ),
          _ => ('de', 'DE'),
        };
        return _SectionCard(
          title: l10n.language,
          icon: Icons.language_rounded,
          padding: const EdgeInsets.symmetric(vertical: TdSpace.xs),
          children: [
            for (final (code, region, name) in options)
              _Row(
                icon: code == 'de'
                    ? Icons.text_fields_rounded
                    : Icons.translate_rounded,
                label: name,
                trailing: AnimatedSwitcher(
                  duration: TdMotion.of(context, TdMotion.fast),
                  child: lang == code && country == region
                      ? Icon(
                          Icons.check_circle_rounded,
                          key: const ValueKey('on'),
                          color: context.colors.primary,
                        )
                      : Icon(
                          Icons.circle_outlined,
                          key: const ValueKey('off'),
                          color: context.colors.outlineVariant,
                        ),
                ),
                onTap: () => context.read<AuthBloc>().add(
                  AuthUpdateLanguageRequested(
                    languageCode: code,
                    countryCode: region,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _NotificationsSection extends StatelessWidget {
  const _NotificationsSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _SectionCard(
      title: l10n.notifications,
      icon: Icons.notifications_outlined,
      padding: const EdgeInsets.symmetric(vertical: TdSpace.xs),
      children: [
        _Row(
          icon: Icons.notifications_active_outlined,
          label: l10n.pushNotifications,
          onTap: () => Navigator.of(context).push(
            TdPageRoute(builder: (_) => const NotificationSettingsScreen()),
          ),
        ),
      ],
    );
  }
}

class _AppSection extends StatelessWidget {
  const _AppSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _SectionCard(
      title: l10n.aboutApp,
      icon: Icons.info_outline_rounded,
      padding: const EdgeInsets.symmetric(vertical: TdSpace.xs),
      children: [
        _Row(
          icon: Icons.star_rate_rounded,
          label: l10n.rateApp,
          onTap: ReviewService.instance.openStoreListing,
        ),
        _Row(
          icon: Icons.privacy_tip_outlined,
          label: l10n.privacyPolicy,
          onTap: () => openLegalLink(context, LegalLinks.privacyPolicy),
        ),
        _Row(
          icon: Icons.article_outlined,
          label: l10n.imprint,
          onTap: () => openLegalLink(context, LegalLinks.imprint),
        ),
        _Row(
          icon: Icons.tag_rounded,
          label: l10n.version,
          value: appVersion,
        ),
      ],
    );
  }
}

class _AccountSection extends StatefulWidget {
  const _AccountSection({required this.user});

  final UserModel user;

  @override
  State<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<_AccountSection> {
  StreamSubscription<AuthState>? _deletion;

  @override
  void dispose() {
    _deletion?.cancel();
    super.dispose();
  }

  Future<void> _logout() async {
    final l10n = AppLocalizations.of(context)!;
    final bloc = context.read<AuthBloc>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.logout),
        content: Text(l10n.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.logout),
          ),
        ],
      ),
    );
    if (ok == true) bloc.add(const AuthLogoutRequested());
  }

  Future<void> _deleteAccount() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showTdSheet<bool>(
      context,
      title: l10n.deleteAccount,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.deleteAccountWarning, style: ctx.text.bodyMedium),
          const SizedBox(height: TdSpace.lg),
          for (final step in [
            (Icons.logout_rounded, l10n.deleteAccountStep1),
            (Icons.delete_sweep_outlined, l10n.deleteAccountStep2),
            (Icons.person_remove_outlined, l10n.deleteAccountStep3),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: TdSpace.sm),
              child: Row(
                children: [
                  Icon(step.$1, size: 20, color: ctx.td.muted),
                  const SizedBox(width: TdSpace.md),
                  Expanded(child: Text(step.$2, style: ctx.text.bodyMedium)),
                ],
              ),
            ),
          const SizedBox(height: TdSpace.md),
          Container(
            padding: const EdgeInsets.all(TdSpace.md),
            decoration: BoxDecoration(
              color: ctx.td.danger.withValues(alpha: ctx.td.isDark ? 0.2 : 0.08),
              borderRadius: TdRadius.control,
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: ctx.td.danger, size: 20),
                const SizedBox(width: TdSpace.sm),
                Expanded(
                  child: Text(
                    l10n.deleteAccountIrreversible,
                    style: ctx.text.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: TdSpace.xl),
          Row(
            children: [
              Expanded(
                child: TdButton.secondary(
                  label: l10n.cancel,
                  onPressed: () => Navigator.of(ctx).pop(false),
                ),
              ),
              const SizedBox(width: TdSpace.md),
              Expanded(
                flex: 2,
                child: TdButton.danger(
                  label: l10n.deleteAccount,
                  icon: Icons.delete_forever_rounded,
                  expanded: true,
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _startDeletion(l10n);
  }

  void _startDeletion(AppLocalizations l10n) {
    final bloc = context.read<AuthBloc>();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deletingAccount),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: TdSpace.lg),
            Text(l10n.deletingAccountProgress),
          ],
        ),
      ),
    );
    bloc.add(const AuthDeleteAccountRequested());
    _deletion?.cancel();
    _deletion = bloc.stream.listen((state) {
      if (!mounted) return;
      if (state is AuthFailure) {
        Navigator.of(context, rootNavigator: true).pop();
        _deletion?.cancel();
        if (state.message.contains('Re-Authentifizierung')) {
          _showInfo(
            l10n.reAuthRequired,
            l10n.reAuthRequiredMessage,
            icon: Icons.security_rounded,
          );
        } else {
          _showInfo(l10n.deletionError, state.message, icon: Icons.error_outline);
        }
      } else if (state is AuthUnauthenticated) {
        Navigator.of(context, rootNavigator: true).pop();
        _deletion?.cancel();
        _showInfo(
          l10n.accountDeleted,
          l10n.accountDeletedMessage,
          icon: Icons.check_circle_rounded,
        );
      }
    });
  }

  void _showInfo(String title, String message, {required IconData icon}) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(icon),
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _SectionCard(
      title: l10n.account,
      icon: Icons.manage_accounts_outlined,
      padding: const EdgeInsets.symmetric(vertical: TdSpace.xs),
      children: [
        _Row(icon: Icons.logout_rounded, label: l10n.logout, onTap: _logout),
        _Row(
          icon: Icons.delete_forever_outlined,
          label: l10n.deleteAccount,
          danger: true,
          onTap: _deleteAccount,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TdSpace.lg,
            TdSpace.sm,
            TdSpace.lg,
            TdSpace.md,
          ),
          child: Text(l10n.privacySecurityDescription, style: context.text.bodySmall),
        ),
        const LegalLinksRow(),
      ],
    );
  }
}
