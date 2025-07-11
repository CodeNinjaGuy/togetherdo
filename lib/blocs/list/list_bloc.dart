import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/list_repository.dart';
import 'list_event.dart';
import 'list_state.dart';

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

  Future<void> _onListCodeCheckRequested(
    ListCodeCheckRequested event,
    Emitter<ListState> emit,
  ) async {
    try {
      final list = await _listRepository.getListByCode(event.code);

      if (list != null) {
        emit(ListCodeCheckSuccess(list: list));
      } else {
        emit(const ListCodeCheckFailure(message: 'Code nicht gefunden'));
      }
    } catch (e) {
      emit(ListCodeCheckFailure(message: e.toString()));
    }
  }

  Future<void> _onListJoinRequested(
    ListJoinRequested event,
    Emitter<ListState> emit,
  ) async {
    try {
      final list = await _listRepository.getListByCode(event.code);

      if (list != null) {
        // Prüfe ob Benutzer bereits Mitglied ist oder der Owner
        if (list.ownerId == event.userId ||
            list.memberIds.contains(event.userId)) {
          emit(const ListJoinFailure(message: 'Bereits Mitglied dieser Liste'));
          return;
        }

        // Füge Benutzer zur Liste hinzu
        final updatedList = list.copyWith(
          memberIds: [...list.memberIds, event.userId],
          memberNames: [...list.memberNames, event.userName],
        );

        await _listRepository.updateList(updatedList);
        emit(ListJoinSuccess(list: updatedList));

        // Lade die aktualisierte Liste
        final lists = await _listRepository.getUserLists(event.userId);
        emit(ListLoadSuccess(lists: lists));
      } else {
        emit(const ListJoinFailure(message: 'Code nicht gefunden'));
      }
    } catch (e) {
      emit(ListJoinFailure(message: e.toString()));
    }
  }

  Future<void> _onListLeaveRequested(
    ListLeaveRequested event,
    Emitter<ListState> emit,
  ) async {
    try {
      await _listRepository.leaveList(event.listId, event.userId);
      emit(ListLeaveSuccess(listId: event.listId));

      // Lade die aktualisierte Liste
      final lists = await _listRepository.getUserLists(event.userId);
      emit(ListLoadSuccess(lists: lists));
    } catch (e) {
      emit(ListLeaveFailure(message: e.toString()));
    }
  }
}
