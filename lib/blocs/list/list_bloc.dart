/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:togetherdo/l10n/app_localizations.dart';
import '../../models/list_preview.dart';
import '../../repositories/list_repository.dart';
import 'list_event.dart';
import 'list_state.dart';
import '../../utils/global_navigator.dart';
import 'dart:developer';

class ListBloc extends Bloc<ListEvent, ListState> {
  final ListRepository _listRepository;

  ListBloc({required ListRepository listRepository})
    : _listRepository = listRepository,
      super(const ListInitial()) {
    on<ListLoadRequested>(_onListLoadRequested);
    on<ListCreateRequested>(_onListCreateRequested);
    on<ListUpdateRequested>(_onListUpdateRequested);
    on<ListDeleteRequested>(_onListDeleteRequested);
    on<ListCodeCheckRequested>(_onListCodeCheckRequested);
    on<ListJoinRequested>(_onListJoinRequested);
    on<ListLeaveRequested>(_onListLeaveRequested);
  }

  Future<void> _onListLoadRequested(
    ListLoadRequested event,
    Emitter<ListState> emit,
  ) async {
    emit(const ListLoading());
    try {
      final lists = await _listRepository.getUserLists(event.userId);
      emit(ListLoadSuccess(lists: lists));
    } catch (e) {
      emit(ListLoadFailure(message: e.toString()));
    }
  }

  Future<void> _onListCreateRequested(
    ListCreateRequested event,
    Emitter<ListState> emit,
  ) async {
    try {
      final list = await _listRepository.createList(
        name: event.name,
        ownerId: event.ownerId,
        ownerName: event.ownerName,
        type: event.type,
        allowEdit: event.allowEdit,
      );
      emit(ListCreateSuccess(list: list));

      // Lade die aktualisierte Liste
      final lists = await _listRepository.getUserLists(event.ownerId);
      emit(ListLoadSuccess(lists: lists));
    } catch (e) {
      emit(ListCreateFailure(message: e.toString()));
    }
  }

  Future<void> _onListUpdateRequested(
    ListUpdateRequested event,
    Emitter<ListState> emit,
  ) async {
    try {
      final updatedList = await _listRepository.updateList(event.list);
      emit(ListUpdateSuccess(list: updatedList));

      // Lade die aktualisierte Liste
      final lists = await _listRepository.getUserLists(event.list.ownerId);
      emit(ListLoadSuccess(lists: lists));
    } catch (e) {
      emit(ListUpdateFailure(message: e.toString()));
    }
  }

  Future<void> _onListDeleteRequested(
    ListDeleteRequested event,
    Emitter<ListState> emit,
  ) async {
    try {
      await _listRepository.deleteList(event.listId, event.ownerId);
      emit(ListDeleteSuccess(listId: event.listId));

      // Lade die aktualisierte Liste
      final lists = await _listRepository.getUserLists(event.ownerId);
      emit(ListLoadSuccess(lists: lists));
    } catch (e) {
      emit(ListDeleteFailure(message: e.toString()));
    }
  }

  /// Fehlermeldung beim Verlassen in der aktuellen Sprache.
  String _leaveErrorMessage(Object e) {
    final context = GlobalNavigator.navigatorKey.currentContext;
    final l10n = context != null ? AppLocalizations.of(context) : null;
    final text = e.toString();
    if (text.contains('owner_cannot_leave')) {
      return l10n?.ownerCannotLeave ??
          'Der Besitzer kann die Liste nicht verlassen';
    }
    if (text.contains('owner_cannot_delete')) {
      return l10n?.onlyOwnerCanDelete ?? 'Nur der Besitzer kann löschen';
    }
    return text;
  }

  /// Fehlermeldung zu einem Code-Fehler in der aktuellen Sprache.
  String _codeErrorMessage(Object e) {
    final context = GlobalNavigator.navigatorKey.currentContext;
    final l10n = context != null ? AppLocalizations.of(context) : null;
    if (e is ListCodeException) {
      switch (e.error) {
        case ListCodeError.notFound:
          return l10n?.codeNotFound ?? 'Code nicht gefunden';
        case ListCodeError.alreadyMember:
          return l10n?.alreadyMember ?? 'Du bist bereits Mitglied';
        case ListCodeError.tooManyAttempts:
          return l10n?.tooManyCodeAttempts ??
              'Zu viele Versuche. Bitte später erneut probieren.';
        case ListCodeError.invalid:
          return l10n?.codeMustHaveSixDigits ?? 'Der Code muss 6 Ziffern haben';
      }
    }
    return e.toString();
  }

  Future<void> _onListCodeCheckRequested(
    ListCodeCheckRequested event,
    Emitter<ListState> emit,
  ) async {
    try {
      final preview = await _listRepository.previewListByCode(event.code);
      emit(ListCodeCheckSuccess(preview: preview));
    } catch (e) {
      emit(ListCodeCheckFailure(message: _codeErrorMessage(e)));
    }
  }

  Future<void> _onListJoinRequested(
    ListJoinRequested event,
    Emitter<ListState> emit,
  ) async {
    try {
      // Beitritt läuft serverseitig (Function joinListByCode, gedrosselt).
      final list = await _listRepository.joinListByCode(
        code: event.code,
        userName: event.userName,
      );
      emit(ListJoinSuccess(list: list));

      final lists = await _listRepository.getUserLists(event.userId);
      emit(ListLoadSuccess(lists: lists));
    } catch (e) {
      emit(ListJoinFailure(message: _codeErrorMessage(e)));
    }
  }

  Future<void> _onListLeaveRequested(
    ListLeaveRequested event,
    Emitter<ListState> emit,
  ) async {
    try {
      if (event.listId.isEmpty || event.userId.isEmpty) {
        emit(
          const ListLeaveFailure(
            message: 'Listen-ID oder User-ID ist nicht gesetzt!',
          ),
        );
        return;
      }
      log(
        '[ListBloc] leaveList: listId=${event.listId}, userId=${event.userId}',
      );
      // Lokalisierung vor async holen
      await _listRepository.leaveList(event.listId, event.userId);
      emit(ListLeaveSuccess(listId: event.listId));

      // Lade die aktualisierte Liste
      final lists = await _listRepository.getUserLists(event.userId);
      emit(ListLoadSuccess(lists: lists));
    } catch (e, stack) {
      log(
        '[ListBloc] Fehler beim Verlassen der Liste: $e\n$stack',
        level: 1000,
        stackTrace: stack,
      );
      emit(ListLeaveFailure(message: _leaveErrorMessage(e)));
    }
  }
}
