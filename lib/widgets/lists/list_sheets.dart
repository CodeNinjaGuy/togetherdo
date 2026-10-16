/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/list/list_bloc.dart';
import '../../blocs/list/list_event.dart';
import '../../blocs/list/list_state.dart';
import '../../design/td_design.dart';
import '../../models/list_model.dart';
import '../../models/list_preview.dart';

/// Sheet „Neue Liste“: Name, Art (Aufgaben/Einkauf), Mitglieder dürfen
/// bearbeiten.
Future<void> showCreateListSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final bloc = context.read<ListBloc>();
  final auth = context.read<AuthBloc>();
  return showTdSheet<void>(
    context,
    title: l10n.newListTitle,
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: bloc),
        BlocProvider.value(value: auth),
      ],
      child: const CreateListForm(),
    ),
  );
}

class CreateListForm extends StatefulWidget {
  const CreateListForm({super.key});

  @override
  State<CreateListForm> createState() => _CreateListFormState();
}

class _CreateListFormState extends State<CreateListForm> {
  final _name = TextEditingController();
  ListType _type = ListType.todo;
  bool _allowEdit = true;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _create() {
    final name = _name.text.trim();
    if (name.length < 3 || _saving) return;
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    setState(() => _saving = true);
    context.read<ListBloc>().add(
      ListCreateRequested(
        name: name,
        ownerId: auth.user.id,
        ownerName: auth.user.displayName,
        type: _type,
        allowEdit: _allowEdit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocListener<ListBloc, ListState>(
      listener: (context, state) {
        if (state is ListCreateSuccess) {
          Navigator.of(context).maybePop();
          TdToast.show(
            context,
            l10n.listCreatedSuccess(state.list.name),
            variant: TdToastVariant.success,
          );
        } else if (state is ListCreateFailure) {
          setState(() => _saving = false);
          TdToast.show(context, state.message, variant: TdToastVariant.error);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TdTextField(
            controller: _name,
            label: l10n.listName,
            hint: l10n.exampleShoppingList,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _create(),
          ),
          const SizedBox(height: TdSpace.xl),
          Text(l10n.listTypeLabel, style: context.text.labelMedium),
          const SizedBox(height: TdSpace.sm),
          Row(
            children: [
              Expanded(
                child: _TypeCard(
                  icon: Icons.checklist_rounded,
                  label: l10n.todoListLabel,
                  description: l10n.todoListDescription,
                  selected: _type == ListType.todo,
                  onTap: () => setState(() => _type = ListType.todo),
                ),
              ),
              const SizedBox(width: TdSpace.md),
              Expanded(
                child: _TypeCard(
                  icon: Icons.shopping_basket_rounded,
                  label: l10n.shoppingListLabel,
                  description: l10n.shoppingListDescription,
                  selected: _type == ListType.shopping,
                  onTap: () => setState(() => _type = ListType.shopping),
                ),
              ),
            ],
          ),
          const SizedBox(height: TdSpace.xl),
          SwitchListTile.adaptive(
            value: _allowEdit,
            onChanged: (v) => setState(() => _allowEdit = v),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.membersCanEditTitle, style: context.text.titleSmall),
            subtitle: Text(
              _allowEdit
                  ? l10n.membersCanEditSubtitle
                  : l10n.onlyOwnerCanEditItems,
              style: context.text.bodySmall,
            ),
          ),
          const SizedBox(height: TdSpace.xxl),
          Row(
            children: [
              Expanded(
                child: TdButton.secondary(
                  label: l10n.cancel,
                  onPressed: _saving
                      ? null
                      : () => Navigator.of(context).maybePop(),
                ),
              ),
              const SizedBox(width: TdSpace.md),
              Expanded(
                flex: 2,
                child: ValueListenableBuilder(
                  valueListenable: _name,
                  builder: (context, v, _) => TdButton.primary(
                    label: l10n.create,
                    icon: Icons.add_rounded,
                    expanded: true,
                    loading: _saving,
                    onPressed: v.text.trim().length < 3 ? null : _create,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return TdPressable(
      onTap: onTap,
      haptic: true,
      child: AnimatedContainer(
        duration: TdMotion.of(context, TdMotion.base),
        curve: TdMotion.standard,
        padding: const EdgeInsets.all(TdSpace.lg),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : scheme.surface,
          borderRadius: TdRadius.card,
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(height: TdSpace.sm),
            Text(label, style: context.text.titleSmall),
            const SizedBox(height: 2),
            Text(description, style: context.text.bodySmall, maxLines: 2),
          ],
        ),
      ),
    );
  }
}

/// Sheet „Liste beitreten“: 6-stelliger Code, Vorschau, Beitreten.
Future<void> showJoinListSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final bloc = context.read<ListBloc>();
  final auth = context.read<AuthBloc>();
  return showTdSheet<void>(
    context,
    title: l10n.joinList,
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: bloc),
        BlocProvider.value(value: auth),
      ],
      child: const JoinListForm(),
    ),
  );
}

class JoinListForm extends StatefulWidget {
  const JoinListForm({super.key});

  @override
  State<JoinListForm> createState() => _JoinListFormState();
}

class _JoinListFormState extends State<JoinListForm> {
  final _code = TextEditingController();
  bool _checking = false;
  bool _joining = false;
  ListPreview? _preview;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {
      _preview = null;
      _error = null;
    });
    if (value.length == 6) {
      setState(() => _checking = true);
      context.read<ListBloc>().add(ListCodeCheckRequested(code: value));
    }
  }

  void _join() {
    final p = _preview;
    final auth = context.read<AuthBloc>().state;
    if (p == null || auth is! AuthAuthenticated || _joining) return;
    setState(() => _joining = true);
    context.read<ListBloc>().add(
      ListJoinRequested(
        code: p.shareCode,
        userId: auth.user.id,
        userName: auth.user.displayName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = _preview;
    return BlocListener<ListBloc, ListState>(
      listener: (context, state) {
        if (state is ListCodeCheckSuccess) {
          setState(() {
            _checking = false;
            _preview = state.preview;
          });
        } else if (state is ListCodeCheckFailure) {
          setState(() {
            _checking = false;
            _error = state.message;
          });
        } else if (state is ListJoinSuccess) {
          Navigator.of(context).maybePop();
          TdToast.show(
            context,
            l10n.listJoinedSuccess(state.list.name),
            variant: TdToastVariant.success,
          );
        } else if (state is ListJoinFailure) {
          setState(() {
            _joining = false;
            _error = state.message;
          });
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.joinListDescription, style: context.text.bodyMedium),
          const SizedBox(height: TdSpace.xl),
          TextField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: context.text.displaySmall?.copyWith(
              letterSpacing: 8,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              hintText: '••••••',
              hintStyle: context.text.displaySmall?.copyWith(
                letterSpacing: 8,
                color: context.colors.outlineVariant,
              ),
            ),
            onChanged: _onChanged,
          ),
          const SizedBox(height: TdSpace.lg),
          AnimatedSwitcher(
            duration: TdMotion.of(context, TdMotion.base),
            child: _checking
                ? const Padding(
                    key: ValueKey('checking'),
                    padding: EdgeInsets.all(TdSpace.lg),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : p != null
                ? _PreviewCard(key: const ValueKey('preview'), preview: p)
                : _error != null
                ? TdCard(
                    key: const ValueKey('error'),
                    variant: TdCardVariant.outlined,
                    padding: const EdgeInsets.all(TdSpace.md),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded, color: context.td.danger),
                        const SizedBox(width: TdSpace.sm),
                        Expanded(
                          child: Text(_error!, style: context.text.bodySmall),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(key: ValueKey('none'), height: 0),
          ),
          const SizedBox(height: TdSpace.xxl),
          Row(
            children: [
              Expanded(
                child: TdButton.secondary(
                  label: l10n.cancel,
                  onPressed: _joining
                      ? null
                      : () => Navigator.of(context).maybePop(),
                ),
              ),
              const SizedBox(width: TdSpace.md),
              Expanded(
                flex: 2,
                child: TdButton.primary(
                  label: l10n.join,
                  icon: Icons.group_add_rounded,
                  expanded: true,
                  loading: _joining,
                  onPressed: p == null || p.isMember ? null : _join,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({super.key, required this.preview});

  final ListPreview preview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = TdAvatarData(name: preview.name, id: preview.shareCode)
        .resolveColor();
    return TdCard(
      variant: TdCardVariant.elevated,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, Color.lerp(color, Colors.white, 0.3)!],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              preview.type == ListType.todo
                  ? Icons.checklist_rounded
                  : Icons.shopping_basket_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: TdSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(preview.name, style: context.text.titleMedium),
                Text(
                  '${l10n.owner}: ${preview.ownerName} · ${l10n.memberCount(preview.memberCount)}',
                  style: context.text.bodySmall,
                ),
                if (preview.isMember)
                  Text(
                    l10n.alreadyMember,
                    style: context.text.labelSmall?.copyWith(
                      color: context.td.warning,
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
