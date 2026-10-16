/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Einstieg der Cloud Functions für ToGetherDo (Region europe-west3).
// `common` zuerst: initialisiert firebase-admin.

import './common';

export {
  onTodoCreated,
  onTodoCompleted,
  onTodoDeleted,
  onListMemberAdded,
  onListMemberRemoved,
  onChatMessageCreated,
  onShoppingItemCreated,
  onShoppingItemPurchased,
  onShoppingItemDeleted,
  onShoppingListMemberAdded,
  onShoppingListMemberRemoved,
  sendTestNotification,
} from './notifications';
export { createList, previewListByCode, joinListByCode, onListDeleted } from './lists';
export { deleteAccount, onUserDeleted } from './account';
export { onTerminCreated, onTerminDeleted, onListDeletedTermine } from './termine';
export { erinnerungenSenden, wochenueberblickSenden } from './erinnerungen';
export { monatsueberblickSenden } from './monatsueberblick';
export { inviteByEmail } from './einladungen';
export { mailEinstellungen } from './mail_einstellungen';
