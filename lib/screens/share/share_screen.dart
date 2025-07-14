import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/share/share_bloc.dart';
import '../../blocs/share/share_event.dart';
import '../../blocs/share/share_state.dart';
import '../../models/share_model.dart';
import '../../widgets/share/share_item_widget.dart';
import '../../widgets/share/create_share_dialog.dart';
import '../../widgets/share/join_share_dialog.dart';

class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  @override
  void initState() {
    super.initState();
    _loadShares();
  }

  void _loadShares() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context.read<ShareBloc>().add(
        ShareLoadRequested(userId: authState.user.id),
      );
    }
  }

  void _showCreateShareDialog() {
    showDialog(
      context: context,
      builder: (context) => const CreateShareDialog(),
    );
  }

  void _showJoinShareDialog() {
    showDialog(context: context, builder: (context) => const JoinShareDialog());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sharedLists),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateShareDialog,
            tooltip: 'Liste erstellen',
          ),
          IconButton(
            icon: const Icon(Icons.join_full),
            onPressed: _showJoinShareDialog,
            tooltip: 'Liste beitreten',
          ),
        ],
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          if (authState is AuthAuthenticated) {
            return BlocBuilder<ShareBloc, ShareState>(
              builder: (context, shareState) {
                if (shareState is ShareLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (shareState is ShareLoadSuccess) {
                  final shares = shareState.shares;

                  if (shares.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.share_outlined,
                            size: 80,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.noSharedLists,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.createOrJoinList,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _showCreateShareDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('Liste erstellen'),
                              ),
                              const SizedBox(width: 16),
                              OutlinedButton.icon(
                                onPressed: _showJoinShareDialog,
                                icon: const Icon(Icons.join_full),
                                label: const Text('Beitreten'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }

                  // Gruppiere Shares nach Typ
                  final todoShares = shares
                      .where((share) => share.type == ShareType.todo)
                      .toList();
                  final shoppingShares = shares
                      .where((share) => share.type == ShareType.shopping)
                      .toList();

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (todoShares.isNotEmpty) ...[
                        _buildSectionHeader('Todo-Listen', todoShares.length),
                        const SizedBox(height: 8),
                        ...todoShares.map(
                          (share) => ShareItemWidget(
                            share: share,
                            currentUserId: authState.user.id,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (shoppingShares.isNotEmpty) ...[
                        _buildSectionHeader(
                          'Einkaufslisten',
                          shoppingShares.length,
                        ),
                        const SizedBox(height: 8),
                        ...shoppingShares.map(
                          (share) => ShareItemWidget(
                            share: share,
                            currentUserId: authState.user.id,
                          ),
                        ),
                      ],
                    ],
                  );
                } else if (shareState is ShareLoadFailure) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 80,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Fehler beim Laden',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          shareState.message,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadShares,
                          child: const Text('Erneut versuchen'),
                        ),
                      ],
                    ),
                  );
                }

                return const Center(child: CircularProgressIndicator());
              },
            );
          }

          return const Center(child: CircularProgressIndicator());
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateShareDialog,
        icon: const Icon(Icons.add),
        label: const Text('Liste erstellen'),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
