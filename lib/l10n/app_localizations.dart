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
  /// **'Read-only: you can view this list and tick things off. Only the owner can edit.'**
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
  /// **'New task'**
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
  /// **'Hand over your own lists to members or delete them'**
  String get deleteAccountStep2;

  /// No description provided for @deleteAccountStep3.
  ///
  /// In en, this message translates to:
  /// **'Delete todos, items, messages, profile picture and account'**
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
  /// **'How ToGetherDo handles your data:'**
  String get privacySecurityDescription;

  /// No description provided for @privacySecuritySteps.
  ///
  /// In en, this message translates to:
  /// **'In short:'**
  String get privacySecuritySteps;

  /// No description provided for @privacySecurityStep1.
  ///
  /// In en, this message translates to:
  /// **'We store your account (email, name, profile picture) and everything you create in the app: lists, todos, shopping items and chat messages. Data is stored with Google Firebase in data centres in the EU.'**
  String get privacySecurityStep1;

  /// No description provided for @privacySecurityStep2.
  ///
  /// In en, this message translates to:
  /// **'Members of a list can see its contents and chats. We do not share your data with third parties; there are no ads and no tracking.'**
  String get privacySecurityStep2;

  /// No description provided for @privacySecurityStep3.
  ///
  /// In en, this message translates to:
  /// **'Push notifications are delivered via Firebase Cloud Messaging. When you delete your account, your data is removed completely.'**
  String get privacySecurityStep3;

  /// No description provided for @privacySecurityIrreversible.
  ///
  /// In en, this message translates to:
  /// **'See the privacy policy for details.'**
  String get privacySecurityIrreversible;

  /// No description provided for @avatarChange.
  ///
  /// In en, this message translates to:
  /// **'Change profile picture'**
  String get avatarChange;

  /// No description provided for @avatarSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile picture'**
  String get avatarSheetTitle;

  /// No description provided for @avatarTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get avatarTakePhoto;

  /// No description provided for @avatarChooseFromPhotos.
  ///
  /// In en, this message translates to:
  /// **'Choose from photos'**
  String get avatarChooseFromPhotos;

  /// No description provided for @avatarChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose image …'**
  String get avatarChooseFile;

  /// No description provided for @avatarRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove profile picture'**
  String get avatarRemove;

  /// No description provided for @avatarUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile picture updated'**
  String get avatarUpdated;

  /// No description provided for @avatarRemoved.
  ///
  /// In en, this message translates to:
  /// **'Profile picture removed'**
  String get avatarRemoved;

  /// No description provided for @avatarUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'The profile picture couldn\'t be saved right now. Please try again later.'**
  String get avatarUploadFailed;

  /// No description provided for @avatarImageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This image can\'t be used. Please choose a different one.'**
  String get avatarImageUnavailable;

  /// No description provided for @avatarPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow access'**
  String get avatarPermissionTitle;

  /// No description provided for @avatarCameraPermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'TogetherDo isn\'t allowed to use the camera yet. You can allow access in Settings to take a profile photo.'**
  String get avatarCameraPermissionMessage;

  /// No description provided for @avatarPhotosPermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'TogetherDo isn\'t allowed to use your photos yet. You can allow access in Settings to choose a profile picture.'**
  String get avatarPhotosPermissionMessage;

  /// No description provided for @avatarOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get avatarOpenSettings;

  /// No description provided for @avatarNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get avatarNotNow;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @imprint.
  ///
  /// In en, this message translates to:
  /// **'Legal notice'**
  String get imprint;

  /// No description provided for @linkOpenError.
  ///
  /// In en, this message translates to:
  /// **'Could not open the link'**
  String get linkOpenError;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address. We will send you a link to set a new password.'**
  String get resetPasswordDescription;

  /// No description provided for @resetPasswordSend.
  ///
  /// In en, this message translates to:
  /// **'Send link'**
  String get resetPasswordSend;

  /// No description provided for @resetPasswordSent.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for this email address, the link is on its way. Please also check your spam folder.'**
  String get resetPasswordSent;

  /// No description provided for @resetPasswordError.
  ///
  /// In en, this message translates to:
  /// **'The link could not be sent. Please try again later.'**
  String get resetPasswordError;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @noTodos.
  ///
  /// In en, this message translates to:
  /// **'No todos yet'**
  String get noTodos;

  /// No description provided for @createFirstTodo.
  ///
  /// In en, this message translates to:
  /// **'Create your first todo'**
  String get createFirstTodo;

  /// No description provided for @listLeftSuccess.
  ///
  /// In en, this message translates to:
  /// **'Left list \"{listName}\"'**
  String listLeftSuccess(String listName);

  /// No description provided for @ownList.
  ///
  /// In en, this message translates to:
  /// **'Your list'**
  String get ownList;

  /// No description provided for @readOnly.
  ///
  /// In en, this message translates to:
  /// **'Read only'**
  String get readOnly;

  /// No description provided for @shareCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Share code'**
  String get shareCodeTitle;

  /// No description provided for @codeLabel.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get codeLabel;

  /// No description provided for @shareCodeDescription.
  ///
  /// In en, this message translates to:
  /// **'Share this code with others so they can join the list:'**
  String get shareCodeDescription;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @todoLists.
  ///
  /// In en, this message translates to:
  /// **'Todo lists'**
  String get todoLists;

  /// No description provided for @stillToBuy.
  ///
  /// In en, this message translates to:
  /// **'Still to buy'**
  String get stillToBuy;

  /// No description provided for @enterCode.
  ///
  /// In en, this message translates to:
  /// **'Please enter the code'**
  String get enterCode;

  /// No description provided for @codeMustHaveSixDigits.
  ///
  /// In en, this message translates to:
  /// **'The code must have 6 digits'**
  String get codeMustHaveSixDigits;

  /// No description provided for @tooManyCodeAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later.'**
  String get tooManyCodeAttempts;

  /// No description provided for @assignedToYou.
  ///
  /// In en, this message translates to:
  /// **'Assigned to you'**
  String get assignedToYou;

  /// No description provided for @titleRequired.
  ///
  /// In en, this message translates to:
  /// **'Title is required'**
  String get titleRequired;

  /// No description provided for @byYou.
  ///
  /// In en, this message translates to:
  /// **'you'**
  String get byYou;

  /// No description provided for @fairnessTitle.
  ///
  /// In en, this message translates to:
  /// **'Fairly shared'**
  String get fairnessTitle;

  /// No description provided for @fairnessThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get fairnessThisWeek;

  /// No description provided for @fairnessThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get fairnessThisMonth;

  /// No description provided for @fairnessWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get fairnessWeek;

  /// No description provided for @fairnessMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get fairnessMonth;

  /// No description provided for @fairnessNothingYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing done in this period yet.'**
  String get fairnessNothingYet;

  /// No description provided for @fairnessBalanced.
  ///
  /// In en, this message translates to:
  /// **'Nicely balanced – keep it up!'**
  String get fairnessBalanced;

  /// No description provided for @fairnessTopCarrier.
  ///
  /// In en, this message translates to:
  /// **'{name} has carried the most.'**
  String fairnessTopCarrier(String name);

  /// No description provided for @fairnessNextTurn.
  ///
  /// In en, this message translates to:
  /// **'{name} is up next.'**
  String fairnessNextTurn(String name);

  /// No description provided for @fairnessYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get fairnessYou;

  /// No description provided for @fairnessPoints.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 point} other{{count} points}}'**
  String fairnessPoints(int count);

  /// No description provided for @fairnessTasks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task} other{{count} tasks}}'**
  String fairnessTasks(int count);

  /// No description provided for @fairnessPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String fairnessPercent(int percent);

  /// No description provided for @fairnessShowStats.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get fairnessShowStats;

  /// No description provided for @fairnessStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Who carries how much'**
  String get fairnessStatsTitle;

  /// No description provided for @fairnessRecentlyDone.
  ///
  /// In en, this message translates to:
  /// **'Recently completed'**
  String get fairnessRecentlyDone;

  /// No description provided for @fairnessPointsLegend.
  ///
  /// In en, this message translates to:
  /// **'Points by effort: light 1, medium 2, heavy 3'**
  String get fairnessPointsLegend;

  /// No description provided for @fairnessShareList.
  ///
  /// In en, this message translates to:
  /// **'Share the list to see who carries how much.'**
  String get fairnessShareList;

  /// No description provided for @completedByAt.
  ///
  /// In en, this message translates to:
  /// **'{name} · {time}'**
  String completedByAt(String name, String time);

  /// No description provided for @effortLabel.
  ///
  /// In en, this message translates to:
  /// **'Effort'**
  String get effortLabel;

  /// No description provided for @effortLight.
  ///
  /// In en, this message translates to:
  /// **'light'**
  String get effortLight;

  /// No description provided for @effortMedium.
  ///
  /// In en, this message translates to:
  /// **'medium'**
  String get effortMedium;

  /// No description provided for @effortHeavy.
  ///
  /// In en, this message translates to:
  /// **'heavy'**
  String get effortHeavy;

  /// No description provided for @responsibleLabel.
  ///
  /// In en, this message translates to:
  /// **'Responsible'**
  String get responsibleLabel;

  /// No description provided for @nobody.
  ///
  /// In en, this message translates to:
  /// **'Nobody'**
  String get nobody;

  /// No description provided for @suggestedTurn.
  ///
  /// In en, this message translates to:
  /// **'Suggestion: it\'s {name}\'s turn'**
  String suggestedTurn(String name);

  /// No description provided for @editTodoTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit task'**
  String get editTodoTitle;

  /// No description provided for @dueLabel.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get dueLabel;

  /// No description provided for @noDueDate.
  ///
  /// In en, this message translates to:
  /// **'No date'**
  String get noDueDate;

  /// No description provided for @removeDueDate.
  ///
  /// In en, this message translates to:
  /// **'Remove date'**
  String get removeDueDate;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Saving didn\'t work. Please try again.'**
  String get saveFailed;

  /// No description provided for @rateApp.
  ///
  /// In en, this message translates to:
  /// **'Rate the app'**
  String get rateApp;

  /// No description provided for @fairnessPointsTotal.
  ///
  /// In en, this message translates to:
  /// **'points in total'**
  String get fairnessPointsTotal;

  /// No description provided for @fairnessTopCarrierYou.
  ///
  /// In en, this message translates to:
  /// **'You have carried the most.'**
  String get fairnessTopCarrierYou;

  /// No description provided for @fairnessNextTurnYou.
  ///
  /// In en, this message translates to:
  /// **'You\'re up next.'**
  String get fairnessNextTurnYou;

  /// No description provided for @suggestedTurnYou.
  ///
  /// In en, this message translates to:
  /// **'Suggestion: it\'s your turn'**
  String get suggestedTurnYou;

  /// No description provided for @scanBarcode.
  ///
  /// In en, this message translates to:
  /// **'Scan barcode'**
  String get scanBarcode;

  /// No description provided for @scanHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the barcode'**
  String get scanHint;

  /// No description provided for @scanCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing added yet} =1{1 item added} other{{count} items added}}'**
  String scanCount(int count);

  /// No description provided for @scanDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get scanDone;

  /// No description provided for @torchOn.
  ///
  /// In en, this message translates to:
  /// **'Light on'**
  String get torchOn;

  /// No description provided for @torchOff.
  ///
  /// In en, this message translates to:
  /// **'Light off'**
  String get torchOff;

  /// No description provided for @scanCameraDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera not allowed'**
  String get scanCameraDenied;

  /// No description provided for @scanCameraDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'ToGetherDo isn\'t allowed to use the camera yet. Allow access in Settings to scan barcodes.'**
  String get scanCameraDeniedMessage;

  /// No description provided for @scanCameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No camera found'**
  String get scanCameraUnavailable;

  /// No description provided for @scanCameraUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'There is no camera available on this device.'**
  String get scanCameraUnavailableMessage;

  /// No description provided for @scanLookingUp.
  ///
  /// In en, this message translates to:
  /// **'Looking up product …'**
  String get scanLookingUp;

  /// No description provided for @scanContinue.
  ///
  /// In en, this message translates to:
  /// **'Keep scanning'**
  String get scanContinue;

  /// No description provided for @scanUnknownTitle.
  ///
  /// In en, this message translates to:
  /// **'Name this item'**
  String get scanUnknownTitle;

  /// No description provided for @scanUnknownMessage.
  ///
  /// In en, this message translates to:
  /// **'This code isn\'t known yet. Enter a name – we\'ll remember it for everyone.'**
  String get scanUnknownMessage;

  /// No description provided for @scanCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Code {code}'**
  String scanCodeLabel(String code);

  /// No description provided for @scanOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get scanOfflineTitle;

  /// No description provided for @scanOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'The product couldn\'t be looked up. You can still name the item.'**
  String get scanOfflineMessage;

  /// No description provided for @scanDataAttribution.
  ///
  /// In en, this message translates to:
  /// **'Data: Open Food Facts (ODbL)'**
  String get scanDataAttribution;

  /// No description provided for @scanAdded.
  ///
  /// In en, this message translates to:
  /// **'{name} added'**
  String scanAdded(String name);

  /// No description provided for @scanIncremented.
  ///
  /// In en, this message translates to:
  /// **'{name}: quantity increased'**
  String scanIncremented(String name);

  /// No description provided for @scanDemoHit.
  ///
  /// In en, this message translates to:
  /// **'Demo hit'**
  String get scanDemoHit;

  /// No description provided for @scanBrandOptional.
  ///
  /// In en, this message translates to:
  /// **'Brand (optional)'**
  String get scanBrandOptional;

  /// No description provided for @scanPackageSizeOptional.
  ///
  /// In en, this message translates to:
  /// **'Package size (optional)'**
  String get scanPackageSizeOptional;

  /// No description provided for @scanPackageSizeExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. 500 g'**
  String get scanPackageSizeExample;

  /// No description provided for @scanAddAndRemember.
  ///
  /// In en, this message translates to:
  /// **'Add and remember'**
  String get scanAddAndRemember;

  /// No description provided for @editItem.
  ///
  /// In en, this message translates to:
  /// **'Edit item'**
  String get editItem;

  /// No description provided for @itemNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get itemNameRequired;

  /// No description provided for @quantityInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid quantity'**
  String get quantityInvalid;

  /// No description provided for @rescanProduct.
  ///
  /// In en, this message translates to:
  /// **'Rescan'**
  String get rescanProduct;

  /// No description provided for @removeProduct.
  ///
  /// In en, this message translates to:
  /// **'Remove product'**
  String get removeProduct;

  /// No description provided for @productLinked.
  ///
  /// In en, this message translates to:
  /// **'Linked product'**
  String get productLinked;

  /// No description provided for @noProductLinked.
  ///
  /// In en, this message translates to:
  /// **'No product linked'**
  String get noProductLinked;

  /// No description provided for @itemSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get itemSaved;

  /// No description provided for @decreaseQuantity.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get decreaseQuantity;

  /// No description provided for @increaseQuantity.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get increaseQuantity;

  /// No description provided for @addManually.
  ///
  /// In en, this message translates to:
  /// **'Enter manually'**
  String get addManually;

  /// No description provided for @useProduct.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get useProduct;

  /// No description provided for @voiceInput.
  ///
  /// In en, this message translates to:
  /// **'Voice input'**
  String get voiceInput;

  /// No description provided for @unit_cup.
  ///
  /// In en, this message translates to:
  /// **'Cup'**
  String get unit_cup;

  /// No description provided for @unit_jar.
  ///
  /// In en, this message translates to:
  /// **'Jar'**
  String get unit_jar;

  /// No description provided for @voiceListening.
  ///
  /// In en, this message translates to:
  /// **'Listening …'**
  String get voiceListening;

  /// No description provided for @voiceTapToSpeak.
  ///
  /// In en, this message translates to:
  /// **'Tap and speak, e.g. “2 kg tomatoes and 1 liter of milk”'**
  String get voiceTapToSpeak;

  /// No description provided for @voiceNothingUnderstood.
  ///
  /// In en, this message translates to:
  /// **'I didn\'t catch that. Please try again.'**
  String get voiceNothingUnderstood;

  /// No description provided for @voiceUseResult.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Use 1 entry} other{Use {count} entries}}'**
  String voiceUseResult(int count);

  /// No description provided for @voiceAddAll.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Add 1 item} other{Add {count} items}}'**
  String voiceAddAll(int count);

  /// No description provided for @voiceRetry.
  ///
  /// In en, this message translates to:
  /// **'Speak again'**
  String get voiceRetry;

  /// No description provided for @voiceStop.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get voiceStop;

  /// No description provided for @voiceMicDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone not allowed'**
  String get voiceMicDenied;

  /// No description provided for @voiceMicDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'ToGetherDo isn\'t allowed to use the microphone or speech recognition yet. Allow access in Settings to dictate items.'**
  String get voiceMicDeniedMessage;

  /// No description provided for @voiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice input unavailable'**
  String get voiceUnavailable;

  /// No description provided for @voiceUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition isn\'t available on this device.'**
  String get voiceUnavailableMessage;

  /// No description provided for @voiceRecognized.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get voiceRecognized;

  /// No description provided for @voiceDemoSpeak.
  ///
  /// In en, this message translates to:
  /// **'Demo sentence'**
  String get voiceDemoSpeak;

  /// No description provided for @voiceItemsAdded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item added} other{{count} items added}}'**
  String voiceItemsAdded(int count);

  /// No description provided for @voiceRemoveEntry.
  ///
  /// In en, this message translates to:
  /// **'Remove entry'**
  String get voiceRemoveEntry;

  /// No description provided for @navToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get navToday;

  /// No description provided for @navLists.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get navLists;

  /// No description provided for @navCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get navCalendar;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @calendarComingSoon.
  ///
  /// In en, this message translates to:
  /// **'The family calendar arrives with the next update.'**
  String get calendarComingSoon;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @mailReminders.
  ///
  /// In en, this message translates to:
  /// **'Email reminders'**
  String get mailReminders;

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning, {name}'**
  String greetingMorning(String name);

  /// No description provided for @greetingDay.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String greetingDay(String name);

  /// No description provided for @greetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening, {name}'**
  String greetingEvening(String name);

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Done together, shared fairly.'**
  String get tagline;

  /// No description provided for @teamCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Just you} other{{count} people}}'**
  String teamCount(int count);

  /// No description provided for @statOpen.
  ///
  /// In en, this message translates to:
  /// **'Open today'**
  String get statOpen;

  /// No description provided for @statDoneWeek.
  ///
  /// In en, this message translates to:
  /// **'Done this week'**
  String get statDoneWeek;

  /// No description provided for @statFairness.
  ///
  /// In en, this message translates to:
  /// **'Your share'**
  String get statFairness;

  /// No description provided for @sectionToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get sectionToday;

  /// No description provided for @sectionForYou.
  ///
  /// In en, this message translates to:
  /// **'For you'**
  String get sectionForYou;

  /// No description provided for @sectionShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get sectionShopping;

  /// No description provided for @sectionFairness.
  ///
  /// In en, this message translates to:
  /// **'Shared fairly'**
  String get sectionFairness;

  /// No description provided for @openToday.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task open} other{{count} tasks open}}'**
  String openToday(int count);

  /// No description provided for @allDone.
  ///
  /// In en, this message translates to:
  /// **'All done. Nice!'**
  String get allDone;

  /// No description provided for @emptyTodayTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing due today'**
  String get emptyTodayTitle;

  /// No description provided for @emptyTodayMessage.
  ///
  /// In en, this message translates to:
  /// **'No tasks due. Take a break or plan ahead.'**
  String get emptyTodayMessage;

  /// No description provided for @itemsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{all bought} =1{1 item left} other{{count} items left}}'**
  String itemsLeft(int count);

  /// No description provided for @showAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get showAll;

  /// No description provided for @chooseList.
  ///
  /// In en, this message translates to:
  /// **'Which list?'**
  String get chooseList;

  /// No description provided for @memberCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}}'**
  String memberCount(int count);

  /// No description provided for @listCountSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 list} other{{count} lists}}'**
  String listCountSummary(int count);

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @listDeleted.
  ///
  /// In en, this message translates to:
  /// **'List deleted'**
  String get listDeleted;

  /// No description provided for @todoListDescription.
  ///
  /// In en, this message translates to:
  /// **'Share tasks, tick them off, stay fair'**
  String get todoListDescription;

  /// No description provided for @shoppingListDescription.
  ///
  /// In en, this message translates to:
  /// **'Collect items, scan, shop'**
  String get shoppingListDescription;

  /// No description provided for @joinListDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code you received.'**
  String get joinListDescription;

  /// No description provided for @overdue.
  ///
  /// In en, this message translates to:
  /// **'overdue'**
  String get overdue;

  /// No description provided for @dueToday.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get dueToday;

  /// No description provided for @doneBy.
  ///
  /// In en, this message translates to:
  /// **'Done by {name}'**
  String doneBy(String name);

  /// No description provided for @onlyMembersCanComplete.
  ///
  /// In en, this message translates to:
  /// **'Only list members can tick this off.'**
  String get onlyMembersCanComplete;

  /// No description provided for @taskDeleted.
  ///
  /// In en, this message translates to:
  /// **'Task deleted'**
  String get taskDeleted;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// No description provided for @doneOf.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} done'**
  String doneOf(int done, int total);

  /// No description provided for @allDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'All done'**
  String get allDoneTitle;

  /// No description provided for @allDoneMessage.
  ///
  /// In en, this message translates to:
  /// **'No open tasks in this list.'**
  String get allDoneMessage;

  /// No description provided for @taskDetails.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get taskDetails;

  /// No description provided for @chatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Task chat'**
  String get chatSubtitle;

  /// No description provided for @chatEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Write the first message or send a photo.'**
  String get chatEmptyMessage;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @attachmentSendImage.
  ///
  /// In en, this message translates to:
  /// **'Send image'**
  String get attachmentSendImage;

  /// No description provided for @attachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get attachments;

  /// No description provided for @attachmentAdd.
  ///
  /// In en, this message translates to:
  /// **'Add attachment'**
  String get attachmentAdd;

  /// No description provided for @attachmentTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get attachmentTakePhoto;

  /// No description provided for @attachmentChooseFromPhotos.
  ///
  /// In en, this message translates to:
  /// **'Choose from photos'**
  String get attachmentChooseFromPhotos;

  /// No description provided for @attachmentChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose file (PDF)'**
  String get attachmentChooseFile;

  /// No description provided for @attachmentDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete attachment'**
  String get attachmentDelete;

  /// No description provided for @attachmentDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Really delete “{name}”?'**
  String attachmentDeleteConfirm(String name);

  /// No description provided for @attachmentOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get attachmentOpen;

  /// No description provided for @attachmentTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The file is too large (images up to 10 MB, PDF up to 20 MB).'**
  String get attachmentTooLarge;

  /// No description provided for @attachmentUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Only photos and PDF files can be attached.'**
  String get attachmentUnsupported;

  /// No description provided for @attachmentUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'The attachment could not be uploaded.'**
  String get attachmentUploadFailed;

  /// No description provided for @attachmentDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'The attachment could not be deleted.'**
  String get attachmentDeleteFailed;

  /// No description provided for @attachmentPermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'Please allow access to the camera or photos in Settings.'**
  String get attachmentPermissionMessage;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @promiseLists.
  ///
  /// In en, this message translates to:
  /// **'Tasks and shopping for everyone at home'**
  String get promiseLists;

  /// No description provided for @promiseFair.
  ///
  /// In en, this message translates to:
  /// **'Shared fairly: whose turn is it?'**
  String get promiseFair;

  /// No description provided for @promiseScan.
  ///
  /// In en, this message translates to:
  /// **'Scan barcodes, speak, attach photos'**
  String get promiseScan;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @theme_dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get theme_dark;

  /// No description provided for @theme_system.
  ///
  /// In en, this message translates to:
  /// **'Match device'**
  String get theme_system;

  /// No description provided for @aboutApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get aboutApp;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;
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
