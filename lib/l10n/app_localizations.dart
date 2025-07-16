import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('de', 'AT'),
    Locale('en'),
    Locale('en', 'GB'),
    Locale('en', 'US')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'TogetherDo'**
  String get appTitle;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @onlyOwnerCanEditItems.
  ///
  /// In en, this message translates to:
  /// **'Only the owner can edit items'**
  String get onlyOwnerCanEditItems;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @listCreatedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The list will automatically receive a'**
  String get listCreatedSubtitle;

  /// No description provided for @listCreatedSubtitle2.
  ///
  /// In en, this message translates to:
  /// **'to share.'**
  String get listCreatedSubtitle2;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get displayName;

  /// No description provided for @confirmPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password is required'**
  String get confirmPasswordRequired;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get alreadyHaveAccount;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @createAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create an account to manage your tasks'**
  String get createAccountSubtitle;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @pleaseEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get pleaseEnterName;

  /// No description provided for @listNameMinLength.
  ///
  /// In en, this message translates to:
  /// **'The name must be at least 3 characters long'**
  String get listNameMinLength;

  /// No description provided for @onlyOwnerCanDelete.
  ///
  /// In en, this message translates to:
  /// **'Only the owner can delete'**
  String get onlyOwnerCanDelete;

  /// No description provided for @ownerCannotLeave.
  ///
  /// In en, this message translates to:
  /// **'The owner cannot leave the list'**
  String get ownerCannotLeave;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @readOnlyMode.
  ///
  /// In en, this message translates to:
  /// **'Read-Only Mode: You can only view this list. Only the owner can edit items.'**
  String get readOnlyMode;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @noLists.
  ///
  /// In en, this message translates to:
  /// **'No Lists'**
  String get noLists;

  /// No description provided for @createOrJoinList.
  ///
  /// In en, this message translates to:
  /// **'Create your first list or join a list'**
  String get createOrJoinList;

  /// No description provided for @noSharedLists.
  ///
  /// In en, this message translates to:
  /// **'No Shared Lists'**
  String get noSharedLists;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @addFirstItem.
  ///
  /// In en, this message translates to:
  /// **'Add your first item'**
  String get addFirstItem;

  /// No description provided for @listIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'The list is still empty'**
  String get listIsEmpty;

  /// No description provided for @shoppingListEmpty.
  ///
  /// In en, this message translates to:
  /// **'Shopping list is empty'**
  String get shoppingListEmpty;

  /// No description provided for @enterMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter message...'**
  String get enterMessage;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @todo.
  ///
  /// In en, this message translates to:
  /// **'Todo'**
  String get todo;

  /// No description provided for @todos.
  ///
  /// In en, this message translates to:
  /// **'Todos'**
  String get todos;

  /// No description provided for @shopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get shopping;

  /// No description provided for @shoppingList.
  ///
  /// In en, this message translates to:
  /// **'Shopping List'**
  String get shoppingList;

  /// No description provided for @shoppingLists.
  ///
  /// In en, this message translates to:
  /// **'Shopping Lists'**
  String get shoppingLists;

  /// No description provided for @lists.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get lists;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @newTodo.
  ///
  /// In en, this message translates to:
  /// **'New Todo'**
  String get newTodo;

  /// No description provided for @newList.
  ///
  /// In en, this message translates to:
  /// **'New List'**
  String get newList;

  /// No description provided for @newShoppingList.
  ///
  /// In en, this message translates to:
  /// **'New Shopping List'**
  String get newShoppingList;

  /// No description provided for @newSharedList.
  ///
  /// In en, this message translates to:
  /// **'New Shared List'**
  String get newSharedList;

  /// No description provided for @joinList.
  ///
  /// In en, this message translates to:
  /// **'Join List'**
  String get joinList;

  /// No description provided for @listName.
  ///
  /// In en, this message translates to:
  /// **'List Name'**
  String get listName;

  /// No description provided for @listType.
  ///
  /// In en, this message translates to:
  /// **'List Type'**
  String get listType;

  /// No description provided for @todoList.
  ///
  /// In en, this message translates to:
  /// **'Todo List'**
  String get todoList;

  /// No description provided for @shoppingListType.
  ///
  /// In en, this message translates to:
  /// **'Shopping List'**
  String get shoppingListType;

  /// No description provided for @itemName.
  ///
  /// In en, this message translates to:
  /// **'Item Name'**
  String get itemName;

  /// No description provided for @itemQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get itemQuantity;

  /// No description provided for @itemUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get itemUnit;

  /// No description provided for @itemNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get itemNotes;

  /// No description provided for @priority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priority;

  /// No description provided for @priorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get priorityLow;

  /// No description provided for @priorityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get priorityMedium;

  /// No description provided for @priorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get priorityHigh;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @categoryWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get categoryWork;

  /// No description provided for @categoryPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get categoryPersonal;

  /// No description provided for @categoryShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get categoryShopping;

  /// No description provided for @categoryHousehold.
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get categoryHousehold;

  /// No description provided for @categoryHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get categoryHealth;

  /// No description provided for @categoryLearning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get categoryLearning;

  /// No description provided for @categoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get categoryOther;

  /// No description provided for @categoryCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get categoryCustom;

  /// No description provided for @dueDate.
  ///
  /// In en, this message translates to:
  /// **'Due Date'**
  String get dueDate;

  /// No description provided for @dueTime.
  ///
  /// In en, this message translates to:
  /// **'Due Time'**
  String get dueTime;

  /// No description provided for @assignedTo.
  ///
  /// In en, this message translates to:
  /// **'Assigned To'**
  String get assignedTo;

  /// No description provided for @noAssignment.
  ///
  /// In en, this message translates to:
  /// **'No Assignment'**
  String get noAssignment;

  /// No description provided for @completedBy.
  ///
  /// In en, this message translates to:
  /// **'Completed By'**
  String get completedBy;

  /// No description provided for @completedAt.
  ///
  /// In en, this message translates to:
  /// **'Completed At'**
  String get completedAt;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @bought.
  ///
  /// In en, this message translates to:
  /// **'Bought'**
  String get bought;

  /// No description provided for @notBought.
  ///
  /// In en, this message translates to:
  /// **'Not Bought'**
  String get notBought;

  /// No description provided for @boughtBy.
  ///
  /// In en, this message translates to:
  /// **'Bought By'**
  String get boughtBy;

  /// No description provided for @boughtAt.
  ///
  /// In en, this message translates to:
  /// **'Bought At'**
  String get boughtAt;

  /// No description provided for @shareCode.
  ///
  /// In en, this message translates to:
  /// **'Share Code'**
  String get shareCode;

  /// No description provided for @shareCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get shareCodeCopied;

  /// No description provided for @allowEdit.
  ///
  /// In en, this message translates to:
  /// **'Members can edit'**
  String get allowEdit;

  /// No description provided for @allowEditDescription.
  ///
  /// In en, this message translates to:
  /// **'Other members can edit todos and shopping lists'**
  String get allowEditDescription;

  /// No description provided for @members.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get members;

  /// No description provided for @owner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get owner;

  /// No description provided for @createdAt.
  ///
  /// In en, this message translates to:
  /// **'Created At'**
  String get createdAt;

  /// No description provided for @updatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated At'**
  String get updatedAt;

  /// No description provided for @lastMessage.
  ///
  /// In en, this message translates to:
  /// **'Last Message'**
  String get lastMessage;

  /// No description provided for @unreadMessages.
  ///
  /// In en, this message translates to:
  /// **'Unread Messages'**
  String get unreadMessages;

  /// No description provided for @noMessages.
  ///
  /// In en, this message translates to:
  /// **'No Messages'**
  String get noMessages;

  /// No description provided for @typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type message...'**
  String get typeMessage;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @avatarUpload.
  ///
  /// In en, this message translates to:
  /// **'Avatar upload will be implemented later'**
  String get avatarUpload;

  /// No description provided for @profileSaving.
  ///
  /// In en, this message translates to:
  /// **'Profile is being saved...'**
  String get profileSaving;

  /// No description provided for @saveError.
  ///
  /// In en, this message translates to:
  /// **'Error saving'**
  String get saveError;

  /// No description provided for @logoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Do you really want to logout?'**
  String get logoutConfirm;

  /// No description provided for @deleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Do you really want to delete \"{itemName}\"?'**
  String deleteConfirm(Object itemName);

  /// No description provided for @leaveListConfirm.
  ///
  /// In en, this message translates to:
  /// **'Do you really want to leave this list?'**
  String get leaveListConfirm;

  /// No description provided for @listCreated.
  ///
  /// In en, this message translates to:
  /// **'List \"{listName}\" created'**
  String listCreated(Object listName);

  /// No description provided for @listJoined.
  ///
  /// In en, this message translates to:
  /// **'Successfully joined list'**
  String get listJoined;

  /// No description provided for @listLeft.
  ///
  /// In en, this message translates to:
  /// **'Left list'**
  String get listLeft;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// No description provided for @info.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get info;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No Data'**
  String get noData;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @groupBy.
  ///
  /// In en, this message translates to:
  /// **'Group By'**
  String get groupBy;

  /// No description provided for @groupByStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get groupByStatus;

  /// No description provided for @groupByUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get groupByUser;

  /// No description provided for @sortByDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due Date'**
  String get sortByDueDate;

  /// No description provided for @sortByPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get sortByPriority;

  /// No description provided for @sortByCreated.
  ///
  /// In en, this message translates to:
  /// **'Created Date'**
  String get sortByCreated;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @testNotification.
  ///
  /// In en, this message translates to:
  /// **'Test Notification'**
  String get testNotification;

  /// No description provided for @testNotificationSuccess.
  ///
  /// In en, this message translates to:
  /// **'🎉 Test successful!'**
  String get testNotificationSuccess;

  /// No description provided for @testNotificationMessage.
  ///
  /// In en, this message translates to:
  /// **'Your push notifications are working!'**
  String get testNotificationMessage;

  /// No description provided for @notificationSettings.
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get notificationSettings;

  /// No description provided for @notificationTodoCreated.
  ///
  /// In en, this message translates to:
  /// **'Todo created'**
  String get notificationTodoCreated;

  /// No description provided for @notificationTodoCompleted.
  ///
  /// In en, this message translates to:
  /// **'Todo completed'**
  String get notificationTodoCompleted;

  /// No description provided for @notificationTodoDeleted.
  ///
  /// In en, this message translates to:
  /// **'Todo deleted'**
  String get notificationTodoDeleted;

  /// No description provided for @notificationMemberAdded.
  ///
  /// In en, this message translates to:
  /// **'Member added'**
  String get notificationMemberAdded;

  /// No description provided for @notificationMemberRemoved.
  ///
  /// In en, this message translates to:
  /// **'Member removed'**
  String get notificationMemberRemoved;

  /// No description provided for @notificationChatMessage.
  ///
  /// In en, this message translates to:
  /// **'Chat message'**
  String get notificationChatMessage;

  /// No description provided for @unit_piece.
  ///
  /// In en, this message translates to:
  /// **'Piece'**
  String get unit_piece;

  /// No description provided for @unit_kg.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get unit_kg;

  /// No description provided for @unit_g.
  ///
  /// In en, this message translates to:
  /// **'g'**
  String get unit_g;

  /// No description provided for @unit_l.
  ///
  /// In en, this message translates to:
  /// **'l'**
  String get unit_l;

  /// No description provided for @unit_ml.
  ///
  /// In en, this message translates to:
  /// **'ml'**
  String get unit_ml;

  /// No description provided for @unit_pack.
  ///
  /// In en, this message translates to:
  /// **'Pack'**
  String get unit_pack;

  /// No description provided for @unit_can.
  ///
  /// In en, this message translates to:
  /// **'Can'**
  String get unit_can;

  /// No description provided for @unit_bottle.
  ///
  /// In en, this message translates to:
  /// **'Bottle'**
  String get unit_bottle;

  /// No description provided for @unit_bag.
  ///
  /// In en, this message translates to:
  /// **'Bag'**
  String get unit_bag;

  /// No description provided for @unit_bunch.
  ///
  /// In en, this message translates to:
  /// **'Bunch'**
  String get unit_bunch;

  /// No description provided for @unit_head.
  ///
  /// In en, this message translates to:
  /// **'Head'**
  String get unit_head;

  /// No description provided for @theme_light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get theme_light;

  /// No description provided for @theme_matrix.
  ///
  /// In en, this message translates to:
  /// **'Matrix'**
  String get theme_matrix;

  /// No description provided for @theme_neo.
  ///
  /// In en, this message translates to:
  /// **'Neo'**
  String get theme_neo;

  /// No description provided for @theme_summer.
  ///
  /// In en, this message translates to:
  /// **'Summer'**
  String get theme_summer;

  /// No description provided for @theme_aurora.
  ///
  /// In en, this message translates to:
  /// **'Aurora'**
  String get theme_aurora;

  /// No description provided for @theme_sunset.
  ///
  /// In en, this message translates to:
  /// **'Sunset'**
  String get theme_sunset;

  /// No description provided for @theme_ocean.
  ///
  /// In en, this message translates to:
  /// **'Ocean'**
  String get theme_ocean;

  /// No description provided for @theme_forest.
  ///
  /// In en, this message translates to:
  /// **'Forest'**
  String get theme_forest;

  /// No description provided for @theme_galaxy.
  ///
  /// In en, this message translates to:
  /// **'Galaxy'**
  String get theme_galaxy;

  /// No description provided for @theme_fiberoptics25.
  ///
  /// In en, this message translates to:
  /// **'Fiberoptics25'**
  String get theme_fiberoptics25;

  /// No description provided for @language_de.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get language_de;

  /// No description provided for @language_en.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get language_en;

  /// No description provided for @region_de.
  ///
  /// In en, this message translates to:
  /// **'Germany'**
  String get region_de;

  /// No description provided for @region_at.
  ///
  /// In en, this message translates to:
  /// **'Austria'**
  String get region_at;

  /// No description provided for @region_us.
  ///
  /// In en, this message translates to:
  /// **'United States'**
  String get region_us;

  /// No description provided for @region_en.
  ///
  /// In en, this message translates to:
  /// **'England'**
  String get region_en;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your Name'**
  String get yourName;

  /// No description provided for @displayNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Display name is required'**
  String get displayNameRequired;

  /// No description provided for @displayNameMinLength.
  ///
  /// In en, this message translates to:
  /// **'Display name must be at least 2 characters long'**
  String get displayNameMinLength;

  /// No description provided for @memberSince.
  ///
  /// In en, this message translates to:
  /// **'Member since'**
  String get memberSince;

  /// No description provided for @lastLogin.
  ///
  /// In en, this message translates to:
  /// **'Last Login'**
  String get lastLogin;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @myLists.
  ///
  /// In en, this message translates to:
  /// **'My Lists'**
  String get myLists;

  /// No description provided for @myTodos.
  ///
  /// In en, this message translates to:
  /// **'My Todos'**
  String get myTodos;

  /// No description provided for @sharedLists.
  ///
  /// In en, this message translates to:
  /// **'Shared Lists'**
  String get sharedLists;

  /// No description provided for @createList.
  ///
  /// In en, this message translates to:
  /// **'Create List'**
  String get createList;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @listNotFound.
  ///
  /// In en, this message translates to:
  /// **'List not found'**
  String get listNotFound;

  /// No description provided for @loadError.
  ///
  /// In en, this message translates to:
  /// **'Error loading'**
  String get loadError;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet.'**
  String get noMessagesYet;

  /// No description provided for @chatWith.
  ///
  /// In en, this message translates to:
  /// **'Chat: {todoTitle}'**
  String chatWith(Object todoTitle);

  /// No description provided for @addItem.
  ///
  /// In en, this message translates to:
  /// **'Add Item'**
  String get addItem;

  /// No description provided for @itemLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get itemLabel;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @unit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unit;

  /// No description provided for @notesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notesOptional;

  /// No description provided for @exampleShoppingList.
  ///
  /// In en, this message translates to:
  /// **'e.g. Shopping list for party'**
  String get exampleShoppingList;

  /// No description provided for @exampleItem.
  ///
  /// In en, this message translates to:
  /// **'e.g. Milk, Bread, Apples'**
  String get exampleItem;

  /// No description provided for @exampleQuantity.
  ///
  /// In en, this message translates to:
  /// **'1'**
  String get exampleQuantity;

  /// No description provided for @exampleNotes.
  ///
  /// In en, this message translates to:
  /// **'e.g. Organic, Brand, Size'**
  String get exampleNotes;

  /// No description provided for @sixDigitCode.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get sixDigitCode;

  /// No description provided for @exampleCode.
  ///
  /// In en, this message translates to:
  /// **'123456'**
  String get exampleCode;

  /// No description provided for @listDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete List'**
  String get listDeleteTitle;

  /// No description provided for @listDeleteContent.
  ///
  /// In en, this message translates to:
  /// **'Do you really want to delete \"{listName}\"?'**
  String listDeleteContent(Object listName);

  /// No description provided for @listLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave List'**
  String get listLeaveTitle;

  /// No description provided for @listLeaveContent.
  ///
  /// In en, this message translates to:
  /// **'Do you really want to leave \"{listName}\"?'**
  String listLeaveContent(Object listName);

  /// No description provided for @codeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get codeCopied;

  /// No description provided for @listJoinedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Successfully joined \"{listName}\"'**
  String listJoinedSuccess(Object listName);

  /// No description provided for @newSharedListTitle.
  ///
  /// In en, this message translates to:
  /// **'Create New Shared List'**
  String get newSharedListTitle;

  /// No description provided for @listTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'List Type'**
  String get listTypeLabel;

  /// No description provided for @todoListLabel.
  ///
  /// In en, this message translates to:
  /// **'Todo List'**
  String get todoListLabel;

  /// No description provided for @shoppingListLabel.
  ///
  /// In en, this message translates to:
  /// **'Shopping List'**
  String get shoppingListLabel;

  /// No description provided for @listCreatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'List \"{listName}\" created'**
  String listCreatedSuccess(Object listName);

  /// No description provided for @newListTitle.
  ///
  /// In en, this message translates to:
  /// **'Create New List'**
  String get newListTitle;

  /// No description provided for @membersCanEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Members can edit'**
  String get membersCanEditTitle;

  /// No description provided for @membersCanEditSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Other members can edit todos and shopping lists'**
  String get membersCanEditSubtitle;

  /// No description provided for @newTodoTitle.
  ///
  /// In en, this message translates to:
  /// **'New Todo'**
  String get newTodoTitle;

  /// No description provided for @todoTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get todoTitle;

  /// No description provided for @todoDescription.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get todoDescription;

  /// No description provided for @todoCategory.
  ///
  /// In en, this message translates to:
  /// **'Category (optional)'**
  String get todoCategory;

  /// No description provided for @customCategory.
  ///
  /// In en, this message translates to:
  /// **'Custom Category'**
  String get customCategory;

  /// No description provided for @assignment.
  ///
  /// In en, this message translates to:
  /// **'Assignment (optional)'**
  String get assignment;

  /// No description provided for @priorityLabel.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priorityLabel;

  /// No description provided for @dueDateOptional.
  ///
  /// In en, this message translates to:
  /// **'Due Date (optional)'**
  String get dueDateOptional;

  /// No description provided for @timeOptional.
  ///
  /// In en, this message translates to:
  /// **'Time (optional)'**
  String get timeOptional;

  /// No description provided for @exampleTodo.
  ///
  /// In en, this message translates to:
  /// **'What needs to be done?'**
  String get exampleTodo;

  /// No description provided for @exampleDescription.
  ///
  /// In en, this message translates to:
  /// **'More details...'**
  String get exampleDescription;

  /// No description provided for @selectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select Category'**
  String get selectCategory;

  /// No description provided for @exampleCustomCategory.
  ///
  /// In en, this message translates to:
  /// **'e.g. Hobby, Project ...'**
  String get exampleCustomCategory;

  /// No description provided for @assignTo.
  ///
  /// In en, this message translates to:
  /// **'Who should this todo be assigned to?'**
  String get assignTo;

  /// No description provided for @exampleDate.
  ///
  /// In en, this message translates to:
  /// **'e.g. 12/31/2024'**
  String get exampleDate;

  /// No description provided for @exampleTime.
  ///
  /// In en, this message translates to:
  /// **'e.g. 2:30 PM'**
  String get exampleTime;

  /// No description provided for @deleteTodoTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Todo'**
  String get deleteTodoTitle;

  /// No description provided for @deleteTodoContent.
  ///
  /// In en, this message translates to:
  /// **'Do you really want to delete \"{todoTitle}\"?'**
  String deleteTodoContent(Object todoTitle);

  /// No description provided for @deleteItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Item'**
  String get deleteItemTitle;

  /// No description provided for @deleteItemContent.
  ///
  /// In en, this message translates to:
  /// **'Do you really want to delete \"{itemName}\"?'**
  String deleteItemContent(Object itemName);

  /// No description provided for @pushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get pushNotifications;

  /// No description provided for @pushNotificationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose which notifications you want to receive:'**
  String get pushNotificationsDescription;

  /// No description provided for @todoNotifications.
  ///
  /// In en, this message translates to:
  /// **'Todo Notifications'**
  String get todoNotifications;

  /// No description provided for @newTodoCreated.
  ///
  /// In en, this message translates to:
  /// **'New Todo Created'**
  String get newTodoCreated;

  /// No description provided for @newTodoCreatedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notification when a new todo is added to the list'**
  String get newTodoCreatedSubtitle;

  /// No description provided for @todoCompleted.
  ///
  /// In en, this message translates to:
  /// **'Todo Completed'**
  String get todoCompleted;

  /// No description provided for @todoCompletedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notification when a todo is marked as completed'**
  String get todoCompletedSubtitle;

  /// No description provided for @todoDeleted.
  ///
  /// In en, this message translates to:
  /// **'Todo Deleted'**
  String get todoDeleted;

  /// No description provided for @todoDeletedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notification when a todo is removed from the list'**
  String get todoDeletedSubtitle;

  /// No description provided for @memberNotifications.
  ///
  /// In en, this message translates to:
  /// **'Member Notifications'**
  String get memberNotifications;

  /// No description provided for @newMember.
  ///
  /// In en, this message translates to:
  /// **'New Member'**
  String get newMember;

  /// No description provided for @newMemberSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notification when a new member joins the list'**
  String get newMemberSubtitle;

  /// No description provided for @memberLeft.
  ///
  /// In en, this message translates to:
  /// **'Member Left'**
  String get memberLeft;

  /// No description provided for @memberLeftSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notification when a member leaves the list'**
  String get memberLeftSubtitle;

  /// No description provided for @chatNotifications.
  ///
  /// In en, this message translates to:
  /// **'Chat Notifications'**
  String get chatNotifications;

  /// No description provided for @newChatMessage.
  ///
  /// In en, this message translates to:
  /// **'New Chat Message'**
  String get newChatMessage;

  /// No description provided for @newChatMessageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notification when a new message is sent in the todo chat'**
  String get newChatMessageSubtitle;

  /// No description provided for @shoppingNotifications.
  ///
  /// In en, this message translates to:
  /// **'Shopping List Notifications'**
  String get shoppingNotifications;

  /// No description provided for @newShoppingItem.
  ///
  /// In en, this message translates to:
  /// **'New Shopping Item'**
  String get newShoppingItem;

  /// No description provided for @newShoppingItemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notification when a new item is added to the shopping list'**
  String get newShoppingItemSubtitle;

  /// No description provided for @shoppingItemCompleted.
  ///
  /// In en, this message translates to:
  /// **'Shopping Item Completed'**
  String get shoppingItemCompleted;

  /// No description provided for @shoppingItemCompletedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notification when an item is marked as completed/purchased'**
  String get shoppingItemCompletedSubtitle;

  /// No description provided for @shoppingItemDeleted.
  ///
  /// In en, this message translates to:
  /// **'Shopping Item Deleted'**
  String get shoppingItemDeleted;

  /// No description provided for @shoppingItemDeletedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notification when an item is removed from the shopping list'**
  String get shoppingItemDeletedSubtitle;

  /// No description provided for @newShoppingMember.
  ///
  /// In en, this message translates to:
  /// **'New Member in Shopping List'**
  String get newShoppingMember;

  /// No description provided for @newShoppingMemberSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notification when someone joins the shopping list'**
  String get newShoppingMemberSubtitle;

  /// No description provided for @shoppingMemberLeft.
  ///
  /// In en, this message translates to:
  /// **'Member Leaves Shopping List'**
  String get shoppingMemberLeft;

  /// No description provided for @shoppingMemberLeftSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notification when someone leaves the shopping list'**
  String get shoppingMemberLeftSubtitle;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @notificationNote.
  ///
  /// In en, this message translates to:
  /// **'Notifications are only sent to other members of the list. You will not receive notifications for your own actions.'**
  String get notificationNote;

  /// No description provided for @grouping.
  ///
  /// In en, this message translates to:
  /// **'Grouping'**
  String get grouping;

  /// No description provided for @sorting.
  ///
  /// In en, this message translates to:
  /// **'Sorting'**
  String get sorting;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'your@email.com'**
  String get emailHint;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Your Password'**
  String get passwordHint;

  /// No description provided for @nameHint.
  ///
  /// In en, this message translates to:
  /// **'Your Name'**
  String get nameHint;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get passwordMinLength;

  /// No description provided for @passwordConfirmHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get passwordConfirmHint;

  /// No description provided for @codeNotFound.
  ///
  /// In en, this message translates to:
  /// **'Code not found'**
  String get codeNotFound;

  /// No description provided for @alreadyMember.
  ///
  /// In en, this message translates to:
  /// **'You are already a member'**
  String get alreadyMember;

  /// No description provided for @member.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get member;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBack;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to manage your tasks'**
  String get loginSubtitle;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailRequired;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email address'**
  String get invalidEmail;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// No description provided for @noAccountYet.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account yet? '**
  String get noAccountYet;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone. All your data, lists and settings will be permanently deleted.'**
  String get deleteAccountWarning;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your account?'**
  String get deleteAccountConfirm;

  /// No description provided for @deleteAccountSteps.
  ///
  /// In en, this message translates to:
  /// **'The following steps will be performed:'**
  String get deleteAccountSteps;

  /// No description provided for @deleteAccountStep1.
  ///
  /// In en, this message translates to:
  /// **'Leave all joined lists'**
  String get deleteAccountStep1;

  /// No description provided for @deleteAccountStep2.
  ///
  /// In en, this message translates to:
  /// **'Delete all created lists'**
  String get deleteAccountStep2;

  /// No description provided for @deleteAccountStep3.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete account and all data'**
  String get deleteAccountStep3;

  /// No description provided for @deleteAccountIrreversible.
  ///
  /// In en, this message translates to:
  /// **'This action is irreversible. All your data will be permanently deleted.'**
  String get deleteAccountIrreversible;

  /// No description provided for @deletingAccount.
  ///
  /// In en, this message translates to:
  /// **'Deleting account...'**
  String get deletingAccount;

  /// No description provided for @deletingAccountProgress.
  ///
  /// In en, this message translates to:
  /// **'Please wait while your account and all data are being deleted...'**
  String get deletingAccountProgress;

  /// No description provided for @reAuthRequired.
  ///
  /// In en, this message translates to:
  /// **'Re-authentication required'**
  String get reAuthRequired;

  /// No description provided for @reAuthRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'To delete your account, you need to sign in again. This is a security measure by Firebase.'**
  String get reAuthRequiredMessage;

  /// No description provided for @pleaseLoginAgain.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again'**
  String get pleaseLoginAgain;

  /// No description provided for @loginAgain.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get loginAgain;

  /// No description provided for @deletionError.
  ///
  /// In en, this message translates to:
  /// **'Deletion error'**
  String get deletionError;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted'**
  String get accountDeleted;

  /// No description provided for @accountDeletedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your account and all data have been successfully deleted.'**
  String get accountDeletedMessage;

  /// No description provided for @privacySecurity.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Security'**
  String get privacySecurity;

  /// No description provided for @privacySecurityDescription.
  ///
  /// In en, this message translates to:
  /// **'TogetherDo respects your privacy and protects your data. Here\'s how we handle your information:'**
  String get privacySecurityDescription;

  /// No description provided for @privacySecuritySteps.
  ///
  /// In en, this message translates to:
  /// **'Our privacy policy:'**
  String get privacySecuritySteps;

  /// No description provided for @privacySecurityStep1.
  ///
  /// In en, this message translates to:
  /// **'No chat storage: Messages are not permanently stored'**
  String get privacySecurityStep1;

  /// No description provided for @privacySecurityStep2.
  ///
  /// In en, this message translates to:
  /// **'No data sharing: We don\'t share your data with third parties'**
  String get privacySecurityStep2;

  /// No description provided for @privacySecurityStep3.
  ///
  /// In en, this message translates to:
  /// **'No liability: We don\'t assume liability for data loss'**
  String get privacySecurityStep3;

  /// No description provided for @privacySecurityIrreversible.
  ///
  /// In en, this message translates to:
  /// **'Note: Deleting lists removes all associated data irreversibly.'**
  String get privacySecurityIrreversible;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {

  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'de': {
  switch (locale.countryCode) {
    case 'AT': return AppLocalizationsDeAt();
   }
  break;
   }
    case 'en': {
  switch (locale.countryCode) {
    case 'GB': return AppLocalizationsEnGb();
case 'US': return AppLocalizationsEnUs();
   }
  break;
   }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de': return AppLocalizationsDe();
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
