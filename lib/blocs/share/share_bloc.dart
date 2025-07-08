import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/share_repository.dart';
import 'share_event.dart';
import 'share_state.dart';

class ShareBloc extends Bloc<ShareEvent, ShareState> {
  final ShareRepository _shareRepository;

  ShareBloc({required ShareRepository shareRepository})
    : _shareRepository = shareRepository,
      super(const ShareInitial()) {
    on<ShareLoadRequested>(_onShareLoadRequested);
    on<ShareCreateRequested>(_onShareCreateRequested);
    on<ShareJoinRequested>(_onShareJoinRequested);
    on<ShareLeaveRequested>(_onShareLeaveRequested);
    on<ShareDeleteRequested>(_onShareDeleteRequested);
    on<ShareCodeCheckRequested>(_onShareCodeCheckRequested);
  }

  Future<void> _onShareLoadRequested(
    ShareLoadRequested event,
    Emitter<ShareState> emit,
  ) async {
    emit(const ShareLoading());
    try {
      final shares = await _shareRepository.getUserShares(event.userId);
      emit(ShareLoadSuccess(shares: shares));
    } catch (e) {
      emit(ShareLoadFailure(message: e.toString()));
    }
  }

  Future<void> _onShareCreateRequested(
    ShareCreateRequested event,
    Emitter<ShareState> emit,
  ) async {
    try {
      final share = await _shareRepository.createShare(
        ownerId: event.ownerId,
        ownerName: event.ownerName,
        type: event.type,
        listName: event.listName,
      );
      emit(ShareCreateSuccess(share: share));

      // Lade die aktualisierte Liste
      final shares = await _shareRepository.getUserShares(event.ownerId);
      emit(ShareLoadSuccess(shares: shares));
    } catch (e) {
      emit(ShareCreateFailure(message: e.toString()));
    }
  }

  Future<void> _onShareJoinRequested(
    ShareJoinRequested event,
    Emitter<ShareState> emit,
  ) async {
    try {
      final share = await _shareRepository.joinShare(
        event.code,
        event.userId,
        event.userName,
      );

      if (share != null) {
        emit(ShareJoinSuccess(share: share));

        // Lade die aktualisierte Liste
        final shares = await _shareRepository.getUserShares(event.userId);
        emit(ShareLoadSuccess(shares: shares));
      } else {
        emit(
          const ShareJoinFailure(
            message: 'Ungültiger Code oder bereits Mitglied',
          ),
        );
      }
    } catch (e) {
      emit(ShareJoinFailure(message: e.toString()));
    }
  }

  Future<void> _onShareLeaveRequested(
    ShareLeaveRequested event,
    Emitter<ShareState> emit,
  ) async {
    try {
      await _shareRepository.leaveShare(event.shareId, event.userId);
      emit(ShareLeaveSuccess(shareId: event.shareId));

      // Lade die aktualisierte Liste
      final shares = await _shareRepository.getUserShares(event.userId);
      emit(ShareLoadSuccess(shares: shares));
    } catch (e) {
      emit(ShareLeaveFailure(message: e.toString()));
    }
  }

  Future<void> _onShareDeleteRequested(
    ShareDeleteRequested event,
    Emitter<ShareState> emit,
  ) async {
    try {
      await _shareRepository.deleteShare(event.shareId, event.ownerId);
      emit(ShareDeleteSuccess(shareId: event.shareId));

      // Lade die aktualisierte Liste
      final shares = await _shareRepository.getUserShares(event.ownerId);
      emit(ShareLoadSuccess(shares: shares));
    } catch (e) {
      emit(ShareDeleteFailure(message: e.toString()));
    }
  }

  Future<void> _onShareCodeCheckRequested(
    ShareCodeCheckRequested event,
    Emitter<ShareState> emit,
  ) async {
    try {
      final share = await _shareRepository.getShareByCode(event.code);

      if (share != null) {
        emit(ShareCodeCheckSuccess(share: share));
      } else {
        emit(const ShareCodeCheckFailure(message: 'Code nicht gefunden'));
      }
    } catch (e) {
      emit(ShareCodeCheckFailure(message: e.toString()));
    }
  }
}
