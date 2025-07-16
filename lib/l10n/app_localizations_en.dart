// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'TogetherDo';

  @override
  String get login => 'Login';

  @override
  String get register => 'Register';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get email => 'Email';

  @override
  String get onlyOwnerCanEditItems => 'Only the owner can edit items';

  @override
  String get password => 'Password';

  @override
  String get listCreatedSubtitle => 'The list will automatically receive a';

  @override
  String get listCreatedSubtitle2 => 'to share.';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get displayName => 'Display Name';

  @override
  String get confirmPasswordRequired => 'Confirm Password is required';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get alreadyHaveAccount => 'Already have an account? ';

  @override
  String get createAccount => 'Create Account';

  @override
  String get createAccountSubtitle => 'Create an account to manage your tasks';

  @override
  String get logout => 'Logout';

  @override
  String get profile => 'Profile';

  @override
  String get pleaseEnterName => 'Please enter a name';

  @override
  String get listNameMinLength => 'The name must be at least 3 characters long';

  @override
  String get onlyOwnerCanDelete => 'Only the owner can delete';

  @override
  String get ownerCannotLeave => 'The owner cannot leave the list';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get readOnlyMode => 'Read-Only Mode: You can only view this list. Only the owner can edit items.';

  @override
  String get delete => 'Delete';

  @override
  String get noLists => 'No Lists';

  @override
  String get createOrJoinList => 'Create your first list or join a list';

  @override
  String get noSharedLists => 'No Shared Lists';

  @override
  String get edit => 'Edit';

  @override
  String get addFirstItem => 'Add your first item';

  @override
  String get listIsEmpty => 'The list is still empty';

  @override
  String get shoppingListEmpty => 'Shopping list is empty';

  @override
  String get enterMessage => 'Enter message...';

  @override
  String get add => 'Add';

  @override
  String get create => 'Create';

  @override
  String get join => 'Join';

  @override
  String get leave => 'Leave';

  @override
  String get copy => 'Copy';

  @override
  String get share => 'Share';

  @override
  String get notifications => 'Notifications';

  @override
  String get settings => 'Settings';

  @override
  String get theme => 'Theme';

  @override
  String get language => 'Language';

  @override
  String get todo => 'Todo';

  @override
  String get todos => 'Todos';

  @override
  String get shopping => 'Shopping';

  @override
  String get shoppingList => 'Shopping List';

  @override
  String get shoppingLists => 'Shopping Lists';

  @override
  String get lists => 'Lists';

  @override
  String get chat => 'Chat';

  @override
  String get messages => 'Messages';

  @override
  String get newTodo => 'New Todo';

  @override
  String get newList => 'New List';

  @override
  String get newShoppingList => 'New Shopping List';

  @override
  String get newSharedList => 'New Shared List';

  @override
  String get joinList => 'Join List';

  @override
  String get listName => 'List Name';

  @override
  String get listType => 'List Type';

  @override
  String get todoList => 'Todo List';

  @override
  String get shoppingListType => 'Shopping List';

  @override
  String get itemName => 'Item Name';

  @override
  String get itemQuantity => 'Quantity';

  @override
  String get itemUnit => 'Unit';

  @override
  String get itemNotes => 'Notes';

  @override
  String get priority => 'Priority';

  @override
  String get priorityLow => 'Low';

  @override
  String get priorityMedium => 'Medium';

  @override
  String get priorityHigh => 'High';

  @override
  String get category => 'Category';

  @override
  String get categoryWork => 'Work';

  @override
  String get categoryPersonal => 'Personal';

  @override
  String get categoryShopping => 'Shopping';

  @override
  String get categoryHousehold => 'Household';

  @override
  String get categoryHealth => 'Health';

  @override
  String get categoryLearning => 'Learning';

  @override
  String get categoryOther => 'Other';

  @override
  String get categoryCustom => 'Custom';

  @override
  String get dueDate => 'Due Date';

  @override
  String get dueTime => 'Due Time';

  @override
  String get assignedTo => 'Assigned To';

  @override
  String get noAssignment => 'No Assignment';

  @override
  String get completedBy => 'Completed By';

  @override
  String get completedAt => 'Completed At';

  @override
  String get pending => 'Pending';

  @override
  String get completed => 'Completed';

  @override
  String get bought => 'Bought';

  @override
  String get notBought => 'Not Bought';

  @override
  String get boughtBy => 'Bought By';

  @override
  String get boughtAt => 'Bought At';

  @override
  String get shareCode => 'Share Code';

  @override
  String get shareCodeCopied => 'Code copied';

  @override
  String get allowEdit => 'Members can edit';

  @override
  String get allowEditDescription => 'Other members can edit todos and shopping lists';

  @override
  String get members => 'Members';

  @override
  String get owner => 'Owner';

  @override
  String get createdAt => 'Created At';

  @override
  String get updatedAt => 'Updated At';

  @override
  String get lastMessage => 'Last Message';

  @override
  String get unreadMessages => 'Unread Messages';

  @override
  String get noMessages => 'No Messages';

  @override
  String get typeMessage => 'Type message...';

  @override
  String get send => 'Send';

  @override
  String get avatarUpload => 'Avatar upload will be implemented later';

  @override
  String get profileSaving => 'Profile is being saved...';

  @override
  String get saveError => 'Error saving';

  @override
  String get logoutConfirm => 'Do you really want to logout?';

  @override
  String deleteConfirm(Object itemName) {
    return 'Do you really want to delete \"$itemName\"?';
  }

  @override
  String get leaveListConfirm => 'Do you really want to leave this list?';

  @override
  String listCreated(Object listName) {
    return 'List \"$listName\" created';
  }

  @override
  String get listJoined => 'Successfully joined list';

  @override
  String get listLeft => 'Left list';

  @override
  String get error => 'Error';

  @override
  String get success => 'Success';

  @override
  String get warning => 'Warning';

  @override
  String get info => 'Information';

  @override
  String get loading => 'Loading...';

  @override
  String get noData => 'No Data';

  @override
  String get search => 'Search';

  @override
  String get filter => 'Filter';

  @override
  String get sort => 'Sort';

  @override
  String get groupBy => 'Group By';

  @override
  String get groupByStatus => 'Status';

  @override
  String get groupByUser => 'User';

  @override
  String get sortByDueDate => 'Due Date';

  @override
  String get sortByPriority => 'Priority';

  @override
  String get sortByCreated => 'Created Date';

  @override
  String get general => 'General';

  @override
  String get testNotification => 'Test Notification';

  @override
  String get testNotificationSuccess => '🎉 Test successful!';

  @override
  String get testNotificationMessage => 'Your push notifications are working!';

  @override
  String get notificationSettings => 'Notification Settings';

  @override
  String get notificationTodoCreated => 'Todo created';

  @override
  String get notificationTodoCompleted => 'Todo completed';

  @override
  String get notificationTodoDeleted => 'Todo deleted';

  @override
  String get notificationMemberAdded => 'Member added';

  @override
  String get notificationMemberRemoved => 'Member removed';

  @override
  String get notificationChatMessage => 'Chat message';

  @override
  String get unit_piece => 'Piece';

  @override
  String get unit_kg => 'kg';

  @override
  String get unit_g => 'g';

  @override
  String get unit_l => 'l';

  @override
  String get unit_ml => 'ml';

  @override
  String get unit_pack => 'Pack';

  @override
  String get unit_can => 'Can';

  @override
  String get unit_bottle => 'Bottle';

  @override
  String get unit_bag => 'Bag';

  @override
  String get unit_bunch => 'Bunch';

  @override
  String get unit_head => 'Head';

  @override
  String get theme_light => 'Light';

  @override
  String get theme_matrix => 'Matrix';

  @override
  String get theme_neo => 'Neo';

  @override
  String get theme_summer => 'Summer';

  @override
  String get theme_aurora => 'Aurora';

  @override
  String get theme_sunset => 'Sunset';

  @override
  String get theme_ocean => 'Ocean';

  @override
  String get theme_forest => 'Forest';

  @override
  String get theme_galaxy => 'Galaxy';

  @override
  String get theme_fiberoptics25 => 'Fiberoptics25';

  @override
  String get language_de => 'German';

  @override
  String get language_en => 'English';

  @override
  String get region_de => 'Germany';

  @override
  String get region_at => 'Austria';

  @override
  String get region_us => 'United States';

  @override
  String get region_en => 'England';

  @override
  String get yourName => 'Your Name';

  @override
  String get displayNameRequired => 'Display name is required';

  @override
  String get displayNameMinLength => 'Display name must be at least 2 characters long';

  @override
  String get memberSince => 'Member since';

  @override
  String get lastLogin => 'Last Login';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get myLists => 'My Lists';

  @override
  String get myTodos => 'My Todos';

  @override
  String get sharedLists => 'Shared Lists';

  @override
  String get createList => 'Create List';

  @override
  String get retry => 'Retry';

  @override
  String get listNotFound => 'List not found';

  @override
  String get loadError => 'Error loading';

  @override
  String get noMessagesYet => 'No messages yet.';

  @override
  String chatWith(Object todoTitle) {
    return 'Chat: $todoTitle';
  }

  @override
  String get addItem => 'Add Item';

  @override
  String get itemLabel => 'Label';

  @override
  String get quantity => 'Quantity';

  @override
  String get unit => 'Unit';

  @override
  String get notesOptional => 'Notes (optional)';

  @override
  String get exampleShoppingList => 'e.g. Shopping list for party';

  @override
  String get exampleItem => 'e.g. Milk, Bread, Apples';

  @override
  String get exampleQuantity => '1';

  @override
  String get exampleNotes => 'e.g. Organic, Brand, Size';

  @override
  String get sixDigitCode => '6-digit code';

  @override
  String get exampleCode => '123456';

  @override
  String get listDeleteTitle => 'Delete List';

  @override
  String listDeleteContent(Object listName) {
    return 'Do you really want to delete \"$listName\"?';
  }

  @override
  String get listLeaveTitle => 'Leave List';

  @override
  String listLeaveContent(Object listName) {
    return 'Do you really want to leave \"$listName\"?';
  }

  @override
  String get codeCopied => 'Code copied';

  @override
  String listJoinedSuccess(Object listName) {
    return 'Successfully joined \"$listName\"';
  }

  @override
  String get newSharedListTitle => 'Create New Shared List';

  @override
  String get listTypeLabel => 'List Type';

  @override
  String get todoListLabel => 'Todo List';

  @override
  String get shoppingListLabel => 'Shopping List';

  @override
  String listCreatedSuccess(Object listName) {
    return 'List \"$listName\" created';
  }

  @override
  String get newListTitle => 'Create New List';

  @override
  String get membersCanEditTitle => 'Members can edit';

  @override
  String get membersCanEditSubtitle => 'Other members can edit todos and shopping lists';

  @override
  String get newTodoTitle => 'New Todo';

  @override
  String get todoTitle => 'Title';

  @override
  String get todoDescription => 'Description (optional)';

  @override
  String get todoCategory => 'Category (optional)';

  @override
  String get customCategory => 'Custom Category';

  @override
  String get assignment => 'Assignment (optional)';

  @override
  String get priorityLabel => 'Priority';

  @override
  String get dueDateOptional => 'Due Date (optional)';

  @override
  String get timeOptional => 'Time (optional)';

  @override
  String get exampleTodo => 'What needs to be done?';

  @override
  String get exampleDescription => 'More details...';

  @override
  String get selectCategory => 'Select Category';

  @override
  String get exampleCustomCategory => 'e.g. Hobby, Project ...';

  @override
  String get assignTo => 'Who should this todo be assigned to?';

  @override
  String get exampleDate => 'e.g. 12/31/2024';

  @override
  String get exampleTime => 'e.g. 2:30 PM';

  @override
  String get deleteTodoTitle => 'Delete Todo';

  @override
  String deleteTodoContent(Object todoTitle) {
    return 'Do you really want to delete \"$todoTitle\"?';
  }

  @override
  String get deleteItemTitle => 'Delete Item';

  @override
  String deleteItemContent(Object itemName) {
    return 'Do you really want to delete \"$itemName\"?';
  }

  @override
  String get pushNotifications => 'Push Notifications';

  @override
  String get pushNotificationsDescription => 'Choose which notifications you want to receive:';

  @override
  String get todoNotifications => 'Todo Notifications';

  @override
  String get newTodoCreated => 'New Todo Created';

  @override
  String get newTodoCreatedSubtitle => 'Notification when a new todo is added to the list';

  @override
  String get todoCompleted => 'Todo Completed';

  @override
  String get todoCompletedSubtitle => 'Notification when a todo is marked as completed';

  @override
  String get todoDeleted => 'Todo Deleted';

  @override
  String get todoDeletedSubtitle => 'Notification when a todo is removed from the list';

  @override
  String get memberNotifications => 'Member Notifications';

  @override
  String get newMember => 'New Member';

  @override
  String get newMemberSubtitle => 'Notification when a new member joins the list';

  @override
  String get memberLeft => 'Member Left';

  @override
  String get memberLeftSubtitle => 'Notification when a member leaves the list';

  @override
  String get chatNotifications => 'Chat Notifications';

  @override
  String get newChatMessage => 'New Chat Message';

  @override
  String get newChatMessageSubtitle => 'Notification when a new message is sent in the todo chat';

  @override
  String get shoppingNotifications => 'Shopping List Notifications';

  @override
  String get newShoppingItem => 'New Shopping Item';

  @override
  String get newShoppingItemSubtitle => 'Notification when a new item is added to the shopping list';

  @override
  String get shoppingItemCompleted => 'Shopping Item Completed';

  @override
  String get shoppingItemCompletedSubtitle => 'Notification when an item is marked as completed/purchased';

  @override
  String get shoppingItemDeleted => 'Shopping Item Deleted';

  @override
  String get shoppingItemDeletedSubtitle => 'Notification when an item is removed from the shopping list';

  @override
  String get newShoppingMember => 'New Member in Shopping List';

  @override
  String get newShoppingMemberSubtitle => 'Notification when someone joins the shopping list';

  @override
  String get shoppingMemberLeft => 'Member Leaves Shopping List';

  @override
  String get shoppingMemberLeftSubtitle => 'Notification when someone leaves the shopping list';

  @override
  String get note => 'Note';

  @override
  String get notificationNote => 'Notifications are only sent to other members of the list. You will not receive notifications for your own actions.';

  @override
  String get grouping => 'Grouping';

  @override
  String get sorting => 'Sorting';

  @override
  String get emailHint => 'your@email.com';

  @override
  String get passwordHint => 'Your Password';

  @override
  String get nameHint => 'Your Name';

  @override
  String get passwordMinLength => 'At least 6 characters';

  @override
  String get passwordConfirmHint => 'Confirm Password';

  @override
  String get codeNotFound => 'Code not found';

  @override
  String get alreadyMember => 'You are already a member';

  @override
  String get member => 'Member';

  @override
  String get welcomeBack => 'Welcome Back';

  @override
  String get loginSubtitle => 'Sign in to manage your tasks';

  @override
  String get emailRequired => 'Email is required';

  @override
  String get invalidEmail => 'Invalid email address';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get noAccountYet => 'Don\'t have an account yet? ';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountWarning => 'This action cannot be undone. All your data, lists and settings will be permanently deleted.';

  @override
  String get deleteAccountConfirm => 'Are you sure you want to delete your account?';

  @override
  String get deleteAccountSteps => 'The following steps will be performed:';

  @override
  String get deleteAccountStep1 => 'Leave all joined lists';

  @override
  String get deleteAccountStep2 => 'Delete all created lists';

  @override
  String get deleteAccountStep3 => 'Permanently delete account and all data';

  @override
  String get deleteAccountIrreversible => 'This action is irreversible. All your data will be permanently deleted.';

  @override
  String get deletingAccount => 'Deleting account...';

  @override
  String get deletingAccountProgress => 'Please wait while your account and all data are being deleted...';

  @override
  String get reAuthRequired => 'Re-authentication required';

  @override
  String get reAuthRequiredMessage => 'To delete your account, you need to sign in again. This is a security measure by Firebase.';

  @override
  String get pleaseLoginAgain => 'Please sign in again';

  @override
  String get loginAgain => 'Sign in again';

  @override
  String get deletionError => 'Deletion error';

  @override
  String get ok => 'OK';

  @override
  String get accountDeleted => 'Account deleted';

  @override
  String get accountDeletedMessage => 'Your account and all data have been successfully deleted.';

  @override
  String get privacySecurity => 'Privacy & Security';

  @override
  String get privacySecurityDescription => 'TogetherDo respects your privacy and protects your data. Here\'s how we handle your information:';

  @override
  String get privacySecuritySteps => 'Our privacy policy:';

  @override
  String get privacySecurityStep1 => 'No chat storage: Messages are not permanently stored';

  @override
  String get privacySecurityStep2 => 'No data sharing: We don\'t share your data with third parties';

  @override
  String get privacySecurityStep3 => 'No liability: We don\'t assume liability for data loss';

  @override
  String get privacySecurityIrreversible => 'Note: Deleting lists removes all associated data irreversibly.';
}

/// The translations for English, as used in the United Kingdom (`en_GB`).
class AppLocalizationsEnGb extends AppLocalizationsEn {
  AppLocalizationsEnGb(): super('en_GB');

  @override
  String get shoppingListEmpty => 'Shopping list is empty';

  @override
  String get shoppingList => 'Shopping List';

  @override
  String get shoppingLists => 'Shopping Lists';

  @override
  String get newShoppingList => 'New Shopping List';

  @override
  String get newSharedList => 'New Shared Shopping List';

  @override
  String get shoppingListType => 'Shopping List';

  @override
  String get allowEditDescription => 'Other members can edit todos and shopping lists';

  @override
  String get exampleShoppingList => 'e.g. Shopping list for party';

  @override
  String get membersCanEditSubtitle => 'Other members can edit todos and shopping lists';

  @override
  String get shoppingNotifications => 'Shopping List Notifications';

  @override
  String get newShoppingItem => 'New Shopping Item';

  @override
  String get newShoppingItemSubtitle => 'Notification when a new item is added to the shopping list';

  @override
  String get shoppingItemCompleted => 'Shopping Item Completed';

  @override
  String get shoppingItemCompletedSubtitle => 'Notification when an item is marked as purchased';

  @override
  String get shoppingItemDeleted => 'Shopping Item Deleted';

  @override
  String get shoppingItemDeletedSubtitle => 'Notification when an item is removed from the shopping list';

  @override
  String get newShoppingMember => 'New Member in Shopping List';

  @override
  String get newShoppingMemberSubtitle => 'Notification when someone joins the shopping list';

  @override
  String get shoppingMemberLeft => 'Member Leaves Shopping List';

  @override
  String get shoppingMemberLeftSubtitle => 'Notification when someone leaves the shopping list';
}

/// The translations for English, as used in the United States (`en_US`).
class AppLocalizationsEnUs extends AppLocalizationsEn {
  AppLocalizationsEnUs(): super('en_US');

  @override
  String get shoppingListEmpty => 'Grocery list is empty';

  @override
  String get shoppingList => 'Grocery List';

  @override
  String get shoppingLists => 'Grocery Lists';

  @override
  String get newShoppingList => 'New Grocery List';

  @override
  String get newSharedList => 'New Shared Grocery List';

  @override
  String get shoppingListType => 'Grocery List';

  @override
  String get allowEditDescription => 'Other members can edit todos and grocery lists';

  @override
  String get exampleShoppingList => 'e.g. Grocery list for party';

  @override
  String get membersCanEditSubtitle => 'Other members can edit todos and grocery lists';

  @override
  String get shoppingNotifications => 'Grocery List Notifications';

  @override
  String get newShoppingItem => 'New Grocery Item';

  @override
  String get newShoppingItemSubtitle => 'Notification when a new item is added to the grocery list';

  @override
  String get shoppingItemCompleted => 'Grocery Item Completed';

  @override
  String get shoppingItemCompletedSubtitle => 'Notification when an item is marked as purchased';

  @override
  String get shoppingItemDeleted => 'Grocery Item Deleted';

  @override
  String get shoppingItemDeletedSubtitle => 'Notification when an item is removed from the grocery list';

  @override
  String get newShoppingMember => 'New Member in Grocery List';

  @override
  String get newShoppingMemberSubtitle => 'Notification when someone joins the grocery list';

  @override
  String get shoppingMemberLeft => 'Member Leaves Grocery List';

  @override
  String get shoppingMemberLeftSubtitle => 'Notification when someone leaves the grocery list';
}
