import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/list/list_bloc.dart';
import '../../blocs/list/list_event.dart';
import '../../blocs/list/list_state.dart';
import '../../models/list_model.dart';
import '../../widgets/lists/list_item_widget.dart';
import '../../widgets/lists/create_list_dialog.dart';
import '../../widgets/lists/join_list_dialog.dart';

class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key});

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  void _loadLists() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context.read<ListBloc>().add(
        ListLoadRequested(userId: authState.user.id),
      );
    }
  }

  void _showCreateListDialog() {
    showDialog(
      context: context,
      builder: (context) => const CreateListDialog(),
    );
  }

  void _showJoinListDialog() {
    showDialog(context: context, builder: (context) => const JoinListDialog());
  }

  void _navigateToList(ListModel list) {
    if (list.type == ListType.todo) {
      context.go('/todo/${list.id}');
    } else {
      context.go('/shopping/${list.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meine Listen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateListDialog,
            tooltip: 'Liste erstellen',
          ),
          IconButton(
            icon: const Icon(Icons.join_full),
            onPressed: _showJoinListDialog,
            tooltip: 'Liste beitreten',
          ),
        ],
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          if (authState is AuthAuthenticated) {
            return BlocBuilder<ListBloc, ListState>(
              builder: (context, listState) {
                if (listState is ListLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (listState is ListLoadSuccess) {
                  final lists = listState.lists;

                  if (lists.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.list_outlined,
                            size: 80,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Keine Listen vorhanden',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Erstelle deine erste Liste oder trete einer bei',
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
                                onPressed: _showCreateListDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('Liste erstellen'),
                              ),
                              const SizedBox(width: 16),
                              OutlinedButton.icon(
                                onPressed: _showJoinListDialog,
                                icon: const Icon(Icons.join_full),
                                label: const Text('Beitreten'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }

                  // Gruppiere Listen nach Typ
                  final todoLists = lists
                      .where((list) => list.type == ListType.todo)
                      .toList();
                  final shoppingLists = lists
                      .where((list) => list.type == ListType.shopping)
                      .toList();

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (todoLists.isNotEmpty) ...[
                        _buildSectionHeader('Todo-Listen', todoLists.length),
                        const SizedBox(height: 8),
                        ...todoLists.map(
                          (list) => ListItemWidget(
                            list: list,
                            currentUserId: authState.user.id,
                            onTap: () => _navigateToList(list),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (shoppingLists.isNotEmpty) ...[
                        _buildSectionHeader(
                          'Einkaufslisten',
                          shoppingLists.length,
                        ),
                        const SizedBox(height: 8),
                        ...shoppingLists.map(
                          (list) => ListItemWidget(
                            list: list,
                            currentUserId: authState.user.id,
                            onTap: () => _navigateToList(list),
                          ),
                        ),
                      ],
                    ],
                  );
                } else if (listState is ListLoadFailure) {
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
                          listState.message,
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
                          onPressed: _loadLists,
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
        onPressed: _showCreateListDialog,
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
