// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Diamoraa';

  @override
  String get welcomeTitle => 'Welcome';

  @override
  String get phone => 'Phone';

  @override
  String get password => 'Password';

  @override
  String get signIn => 'Sign in';

  @override
  String get signOut => 'Sign out';

  @override
  String get continueAction => 'Continue';

  @override
  String get signInWithTelegram => 'Sign in with Telegram';

  @override
  String get orDivider => 'or';

  @override
  String get openingTelegram => 'Opening Telegram…';

  @override
  String get telegramLoginFailed =>
      'Could not open Telegram. Please try again.';

  @override
  String get workersUseTelegram =>
      'Craftswomen sign in with Telegram — tap the button below.';

  @override
  String get pendingApprovalTitle => 'Application sent';

  @override
  String get pendingApprovalBody =>
      'Please wait for an administrator to approve you. We will message you in Telegram as soon as there is a decision.';

  @override
  String get rejectedTitle => 'Application declined';

  @override
  String get workerPausedTitle => 'Profile paused';

  @override
  String get workerPausedBody => 'Please contact the administrator.';

  @override
  String get backToLogin => 'Back to sign-in';

  @override
  String get checkAgainInTelegram => 'Try again with Telegram';

  @override
  String get invalidCredentials => 'Wrong phone or password';

  @override
  String get invalidCode => 'Wrong or expired code';

  @override
  String get tooManyAttempts => 'Too many attempts. Please try later.';

  @override
  String get noConnection => 'No connection to the server. Check the internet.';

  @override
  String get genericError => 'Something went wrong';

  @override
  String get checkYourInput => 'Please check what you entered';

  @override
  String get phoneRequired => 'Enter a phone number';

  @override
  String get invalidPhoneFormat => 'Enter a valid phone number';

  @override
  String get userNotFound =>
      'No user with this number. Please contact the administrator.';

  @override
  String get accountDisabled =>
      'Your account is disabled. Please contact the administrator.';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get offlineBanner => 'No internet — showing saved data';

  @override
  String get workers => 'Craftswomen';

  @override
  String get profile => 'Profile';

  @override
  String get home => 'Home';

  @override
  String get search => 'Search: name, phone';

  @override
  String get tabPending => 'Requests';

  @override
  String get tabActive => 'Active';

  @override
  String get tabAll => 'All';

  @override
  String get emptyPending => 'No new requests';

  @override
  String get emptyPendingHint =>
      'When a craftswoman registers in Telegram, her request appears here instantly';

  @override
  String get emptyWorkers => 'Nobody here yet';

  @override
  String newRegistration(String name) {
    return 'New request: $name';
  }

  @override
  String get statusPending => 'Under review';

  @override
  String get statusActive => 'Active';

  @override
  String get statusPaused => 'Paused';

  @override
  String get statusRejected => 'Declined';

  @override
  String get statusArchived => 'Archived';

  @override
  String get call => 'Call';

  @override
  String get route => 'Get directions';

  @override
  String get location => 'Location';

  @override
  String get noLocation => 'No location received';

  @override
  String get secondaryPhone => 'Second phone';

  @override
  String get notes => 'Notes';

  @override
  String get collateral => 'Deposit';

  @override
  String get collateralMoney => 'Money';

  @override
  String get collateralItem => 'Item';

  @override
  String get collateralPending => 'Declared, not received yet';

  @override
  String get collateralHeld => 'Kept by us';

  @override
  String get collateralReturned => 'Returned';

  @override
  String get receiveCollateral => 'Receive deposit';

  @override
  String get receivedNote => 'Comment (optional)';

  @override
  String get estimatedValue => 'Estimated value, UZS';

  @override
  String get storageLocation => 'Where it is kept';

  @override
  String get history => 'History';

  @override
  String get approve => 'Approve';

  @override
  String get reject => 'Decline';

  @override
  String get approveTitle => 'Approve this craftswoman?';

  @override
  String get collateralReceivedCheck => 'Deposit physically received';

  @override
  String get rejectTitle => 'Decline the request';

  @override
  String get rejectReason => 'Reason (she will see it)';

  @override
  String get required => 'Required';

  @override
  String get approvedDone => 'Approved. She has been notified in Telegram.';

  @override
  String get rejectedDone => 'Request declined';

  @override
  String get myStatusPending => 'Your request is under review';

  @override
  String get myStatusActive => 'You are on the team ✨';

  @override
  String get balanceToReceive => 'To receive';

  @override
  String get devices => 'Devices';

  @override
  String get thisDevice => 'this device';

  @override
  String get revoke => 'End session';

  @override
  String get logoutAll => 'Sign out on all devices';

  @override
  String get language => 'Language';

  @override
  String get currency => 'UZS';

  @override
  String get save => 'Save';

  @override
  String get payRateTitle => 'Rate per 9 m';

  @override
  String payRateSubtitle(int meters) {
    return 'Pay for one $meters m kit';
  }

  @override
  String get payRateAppliesToAll =>
      'One rate for everyone. When you change it, it changes for all craftswomen at once. Work already accepted is not recalculated.';

  @override
  String get payRateChange => 'Change rate';

  @override
  String payRateNew(int meters) {
    return 'New rate per $meters m';
  }

  @override
  String get payRateInvalid => 'Enter an amount from 1 to 10,000,000';

  @override
  String payRateSaved(String amount) {
    return 'Rate updated: $amount UZS';
  }

  @override
  String get payRateHistory => 'Rate history';

  @override
  String get payRateStart => 'initial';

  @override
  String payRatePerKit(int meters) {
    return 'Pay for $meters metres';
  }

  @override
  String get locationServicesOffTitle => 'Turn on location';

  @override
  String get locationServicesOffBody =>
      'Without location the app cannot show where the work is. Turn it on in the phone settings.';

  @override
  String get locationForegroundTitle => 'Allow location access';

  @override
  String get locationForegroundBody =>
      'The app needs your location while it is open, so the admin sees where you are.';

  @override
  String get locationBackgroundTitle => 'Allow location in the background';

  @override
  String get locationBackgroundBody =>
      'To keep the location accurate when the app is minimised, allow access «Always».';

  @override
  String get locationDeniedForeverBody =>
      'Access was denied. Open the app settings and allow location manually.';

  @override
  String get locationOpenSettings => 'Open location settings';

  @override
  String get locationAllow => 'Allow';

  @override
  String get locationOpenAppSettings => 'Open app settings';

  @override
  String get catalog => 'Our works';

  @override
  String get catalogEmpty => 'Nothing published yet';

  @override
  String get catalogEmptyHint =>
      'New works appear here as soon as the administrator publishes them';

  @override
  String get catalogNew => 'New';

  @override
  String get catalogCall => 'Call';

  @override
  String get catalogTelegram => 'Write in Telegram';

  @override
  String get catalogAvailable => 'Available';

  @override
  String get catalogOnRequest => 'On request';

  @override
  String get catalogUnavailable => 'Not now';

  @override
  String get catalogAdminTitle => 'Works catalog';

  @override
  String get catalogAddItem => 'Add a work';

  @override
  String get catalogItemName => 'Name';

  @override
  String get catalogItemDescription => 'Description';

  @override
  String get catalogStatusDraft => 'Draft';

  @override
  String get catalogStatusPublished => 'Published';

  @override
  String get catalogStatusHidden => 'Hidden';

  @override
  String get catalogPublish => 'Publish';

  @override
  String get catalogHide => 'Hide';

  @override
  String get catalogAddPhoto => 'Add photo';

  @override
  String get catalogMarkNew => 'Mark as new';

  @override
  String get catalogPublishNeedsPhoto =>
      'Add at least one photo before publishing';

  @override
  String get catalogDeleteBlocked =>
      'This work is already in use — it can only be hidden';

  @override
  String get catalogSaved => 'Saved';

  @override
  String get team => 'Team';

  @override
  String get teamUsers => 'Users';

  @override
  String get teamManagers => 'Managers';

  @override
  String get teamAddUser => 'Add user';

  @override
  String get teamFullName => 'Full name';

  @override
  String get teamRole => 'Role';

  @override
  String get roleSuperAdmin => 'Owner';

  @override
  String get roleAdmin => 'Administrator';

  @override
  String get roleManager => 'Manager';

  @override
  String get roleWorker => 'Craftswoman';

  @override
  String get teamStatusActive => 'Active';

  @override
  String get teamStatusSuspended => 'Disabled';

  @override
  String get teamDeactivate => 'Disable';

  @override
  String get teamReactivate => 'Enable';

  @override
  String get teamNoAccess => 'Not enough rights to view this';

  @override
  String get teamCreated => 'User created. The password is shown once:';

  @override
  String teamAssignedWorkers(int count) {
    return 'Craftswomen: $count';
  }

  @override
  String get teamEditUser => 'User';

  @override
  String get teamSaveChanges => 'Save';

  @override
  String get teamPhoneTaken => 'This number is already used by another user';

  @override
  String teamConfirmRoleChange(String from, String to) {
    return 'Change role from $from to $to?';
  }

  @override
  String get teamRoleChanged => 'Role changed';

  @override
  String get teamSaved => 'Changes saved';

  @override
  String get settingsCompanyContact => 'Company phone and Telegram';

  @override
  String get settingsPhone => 'Company phone';

  @override
  String get settingsTelegram => 'Telegram (without @)';

  @override
  String get settingsCompanyContactHint =>
      'Craftswomen see these on the «Call» and «Write in Telegram» buttons in the catalog';

  @override
  String get audit => 'Activity log';

  @override
  String get auditEmpty => 'No entries yet';

  @override
  String get locations => 'Team locations';

  @override
  String get locationsEmpty => 'No location data yet';

  @override
  String locationStaleMinutes(int minutes) {
    return 'Location updated $minutes min ago';
  }

  @override
  String locationRecentMinutes(int minutes) {
    return 'Location updated $minutes min ago';
  }

  @override
  String get locationJustNow => 'Location: just now';

  @override
  String get onlineNow => 'online';

  @override
  String get offlineNow => 'offline';

  @override
  String get map => 'Map';

  @override
  String get mapListView => 'List';

  @override
  String get mapMapView => 'Map';

  @override
  String get mapEmpty => 'No coordinates yet';

  @override
  String get mapOpenProfile => 'Open profile';

  @override
  String get qrScan => 'Scan QR';

  @override
  String get qrScanHint => 'Point the camera at the QR code';

  @override
  String get qrInvalid => 'QR code not found or not available';

  @override
  String get qrWorkerFound => 'Craftswoman found';

  @override
  String get qrKitFound => 'Kit found';

  @override
  String get showQr => 'Show QR code';

  @override
  String get workerQrTitle => 'Personal QR code';

  @override
  String get inventory => 'Warehouse';

  @override
  String get materials => 'Materials';

  @override
  String get materialsEmpty => 'No materials yet';

  @override
  String get materialAdd => 'New material';

  @override
  String get stockLow => 'low';

  @override
  String get stockReceipt => 'Receipt';

  @override
  String get stockReceiptHint => 'Material arriving at the warehouse';

  @override
  String get quantity => 'Quantity';

  @override
  String get kits => 'Kits';

  @override
  String get kitsEmpty => 'No kits yet';

  @override
  String get kitAssemble => 'Assemble kit';

  @override
  String get kitAssembled => 'Kit assembled, QR code ready';

  @override
  String get kitCount => 'Number of kits';

  @override
  String get kitTemplateName => 'Kit name';

  @override
  String get kitAddMaterial => 'Material';

  @override
  String get commentOptional => 'Comment (optional)';

  @override
  String get materialName => 'Material name';

  @override
  String get materialMinStock => 'Minimum stock';

  @override
  String get workMeters9 => '9 m';

  @override
  String get workMeters18 => '18 m';

  @override
  String get workMeters27 => '27 m';

  @override
  String workDoneOf(String done, String planned) {
    return 'Done $done of $planned m';
  }

  @override
  String get workDueDate => 'Due';

  @override
  String get workExpectedEarning => 'Expected pay';

  @override
  String get workMaterials => 'Materials';

  @override
  String get workUpdateProgress => 'Update progress';

  @override
  String get workReady => 'Work is ready';

  @override
  String workReadyConfirm(String planned) {
    return 'Confirm: $planned m done. After this the work will be collected.';
  }

  @override
  String get workProblem => 'There is a problem';

  @override
  String get workMetersDone => 'How many metres are done';

  @override
  String get workStatusReadyToDeliver => 'Waiting to be received';

  @override
  String get workStatusDelivered => 'Received by craftswoman';

  @override
  String get workStatusInProgress => 'In progress';

  @override
  String get workStatusReadyForPickup => 'Ready, waiting for pickup';

  @override
  String get workStatusPickedUp => 'Picked up';

  @override
  String get workStatusUnderReview => 'Being checked';

  @override
  String get workCurrentTitle => 'Current work';

  @override
  String get workNoCurrent => 'No active work right now';

  @override
  String get workNoCurrentHint => 'As soon as you get work, it appears here';

  @override
  String get workPickedUp => 'Picked up';

  @override
  String get insufficientStockGeneric =>
      'Not enough materials in the warehouse';

  @override
  String get statusChangedMeanwhile =>
      'This action is no longer available because the work status has changed.';

  @override
  String insufficientStockDetail(String material) {
    return 'Not enough material: $material';
  }

  @override
  String get back => 'Back';

  @override
  String get next => 'Next';

  @override
  String get assignCreateTitle => 'Prepare work';

  @override
  String get assignStepProduct => 'Model';

  @override
  String get assignStepVariant => 'Colour';

  @override
  String get assignStepVolume => 'Amount of work';

  @override
  String get assignStepDue => 'Deadline';

  @override
  String get assignStepComment => 'Comment';

  @override
  String get assignStepSummary => 'Confirmation';

  @override
  String get assignNoVariants =>
      'This model has no colours yet. Add a colour in the catalog first.';

  @override
  String get assignNoKitTemplate =>
      'No material kit is available for this option.';

  @override
  String get assignSelectWorker => 'Choose a craftswoman';

  @override
  String get assignSelectProduct => 'Choose a model';

  @override
  String get assignSelectVariant => 'Choose a colour';

  @override
  String get assignDueOptional => 'Deadline (optional)';

  @override
  String get assignNoDueDate => 'No deadline';

  @override
  String get assignSummaryWorker => 'Craftswoman';

  @override
  String get assignSummaryModel => 'Model';

  @override
  String get assignSummaryColor => 'Colour';

  @override
  String get assignSummaryVolume => 'Amount';

  @override
  String get assignSummaryMaterials => 'Materials';

  @override
  String get assignSummaryDue => 'Deadline';

  @override
  String get assignSummaryPayment => 'Estimated pay';

  @override
  String get assignSubmit => 'Prepare work';

  @override
  String get assignSuccess => 'Work issued';

  @override
  String get assignSuccessHint =>
      'Materials taken from the warehouse, QR code ready';

  @override
  String get assignEmptyProducts => 'No models in the catalog yet';

  @override
  String get assignEmptyWorkers => 'No active craftswomen';

  @override
  String get assignmentDetailTitle => 'Work';

  @override
  String get assignmentQr => 'Work QR code';

  @override
  String get assignmentHistory => 'History';

  @override
  String get assignmentMaterialsIssued => 'Materials issued';

  @override
  String get deliveriesTitle => 'Delivery and pickup';

  @override
  String get deliveryNeeded => 'To deliver';

  @override
  String get deliveryConfirmTitle => 'Confirm delivery';

  @override
  String get deliveryConfirmBody => 'Have the materials been handed over?';

  @override
  String get deliveryDone => 'Start handoff';

  @override
  String get pickupNeeded => 'To pick up';

  @override
  String get dashboardTab => 'Overview';

  @override
  String get dashActiveWorkers => 'Active craftswomen';

  @override
  String get dashInProgress => 'In progress';

  @override
  String get dashNeedsAcceptance => 'To inspect';

  @override
  String get dashOverdue => 'Overdue';

  @override
  String get queueEmpty => 'Nothing here yet';

  @override
  String get dueBy => 'due ';

  @override
  String get workersDueEmpty => 'All payouts are settled';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingDay => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String get dashProblems => 'Problems';

  @override
  String get dashAttention => 'Needs attention';

  @override
  String get dashAllClear => 'Everything is under control';

  @override
  String get dashToday => 'Today';

  @override
  String get dashDueToday => 'Due today';

  @override
  String get dashDeliveredToday => 'Delivered';

  @override
  String get dashPickedUpToday => 'Picked up';

  @override
  String get dashPaidToday => 'Paid';

  @override
  String get dashQuickActions => 'Quick actions';

  @override
  String get actionMap => 'Map';

  @override
  String get actionStock => 'Warehouse';

  @override
  String get more => 'More';

  @override
  String get managerLabel => 'Manager';

  @override
  String get noManager => 'No manager';

  @override
  String get historyWork => 'Works';

  @override
  String get historyMoney => 'Money';

  @override
  String get historyEmpty => 'Nothing yet';

  @override
  String attnOverdue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count overdue works',
      one: '$count overdue work',
    );
    return '$_temp0';
  }

  @override
  String attnToDeliver(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count deliveries',
      one: '$count delivery',
    );
    return '$_temp0';
  }

  @override
  String attnToPickup(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count works ready',
      one: '$count work ready',
    );
    return '$_temp0';
  }

  @override
  String attnAcceptance(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count works to inspect',
      one: '$count work to inspect',
    );
    return '$_temp0';
  }

  @override
  String attnRework(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count works in rework',
      one: '$count work in rework',
    );
    return '$_temp0';
  }

  @override
  String attnWorkersDue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count craftswomen waiting for pay',
      one: '$count craftswoman waiting for pay',
    );
    return '$_temp0';
  }

  @override
  String get acceptanceTitle => 'Inspect work';

  @override
  String get acceptanceBrought => 'Brought';

  @override
  String get acceptanceAccepted => 'Accepted';

  @override
  String get acceptanceDefective => 'Defective';

  @override
  String get acceptanceRework => 'Rework';

  @override
  String get acceptanceCalculated => 'Pay';

  @override
  String get acceptanceSubmit => 'Accept work';

  @override
  String get acceptanceSuccess => 'Work accepted';

  @override
  String get acceptanceInvalid =>
      'Accepted + defective + rework must equal brought';

  @override
  String get acceptancePhotoOptional => 'Photo (optional)';

  @override
  String get payoutTitle => 'Pay in cash';

  @override
  String get payoutDue => 'To pay';

  @override
  String get payoutFull => 'Full amount';

  @override
  String get payoutHalf => 'Half';

  @override
  String get payoutAmountLabel => 'Amount';

  @override
  String get payoutConfirmTitle => 'Confirm the payout';

  @override
  String payoutConfirmBody(String amount) {
    return 'Did you really hand over $amount in cash?';
  }

  @override
  String get payoutSubmit => 'Pay';

  @override
  String get payoutSuccess => 'Payout recorded';

  @override
  String get payoutNothingDue => 'To pay: 0 UZS';

  @override
  String get payoutExceedsBalance => 'The amount is more than she is owed';

  @override
  String get earningsEarned => 'Earned';

  @override
  String get earningsPaid => 'Paid';

  @override
  String get earningsHistory => 'History';

  @override
  String get earningsEmpty => 'No earnings yet';

  @override
  String get actionAssign => 'Prepare work';

  @override
  String get actionScanQr => 'Scan QR';

  @override
  String get actionAccept => 'Accept work';

  @override
  String get actionPayout => 'Pay in cash';

  @override
  String get actionCall => 'Call';

  @override
  String get actionRoute => 'Route';

  @override
  String get statusAccepted => 'Accepted';

  @override
  String get statusPartiallyAccepted => 'Partly accepted';

  @override
  String get statusReworkRequired => 'Rework';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get teamSearch => 'Name or phone';

  @override
  String get filterAll => 'All';

  @override
  String get filterActive => 'Active';

  @override
  String get filterDisabled => 'Disabled';

  @override
  String get lastSeenLabel => 'Last seen';

  @override
  String get createdLabel => 'Created';

  @override
  String get neverSeen => 'Has not signed in yet';

  @override
  String get changeRole => 'Change role';

  @override
  String get changeRoleHint =>
      'After a role change the user is signed out everywhere and signs in again with the new rights.';

  @override
  String get roleSuperAdminHint => 'Everything, including roles and rights';

  @override
  String get roleAdminHint => 'Craftswomen, warehouse, payouts, catalog';

  @override
  String get roleManagerHint => 'Only their own craftswomen';

  @override
  String get permissionsTitle => 'Access rights';

  @override
  String get permissionsAllSuper =>
      'The owner has every right. They cannot be limited.';

  @override
  String get permissionsSaved => 'Rights saved';

  @override
  String get permissionsDefault => 'default for the role';

  @override
  String permissionsCount(int on, int total) {
    return '$on of $total';
  }

  @override
  String get deactivateUser => 'Disable user';

  @override
  String deactivateConfirm(String name) {
    return 'Disable $name? Sign-in is blocked at once on all devices. All history is kept.';
  }

  @override
  String get restoreUser => 'Restore';

  @override
  String get userDeactivated => 'User disabled';

  @override
  String get userRestored => 'User restored';

  @override
  String get resetPassword => 'Issue a new password';

  @override
  String get resetPasswordConfirm =>
      'The old password stops working and the user is signed out everywhere.';

  @override
  String get tempPasswordTitle => 'Temporary password';

  @override
  String get tempPasswordHint =>
      'Give the password to the person yourself. It is shown only once.';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get editDetails => 'Edit details';

  @override
  String get activeImmediately => 'Active immediately';

  @override
  String get workersOfManager => 'Manager\'s craftswomen';

  @override
  String get changeManager => 'Change manager';

  @override
  String get managerChanged => 'Manager changed';

  @override
  String get archiveWorker => 'Archive craftswoman';

  @override
  String get archiveConfirm =>
      'She will not be able to sign in or get new work. History, payouts and deposit are kept.';

  @override
  String get workerArchived => 'Archived';

  @override
  String get restoreWorker => 'Restore craftswoman';

  @override
  String get workerRestored => 'Restored';

  @override
  String get workersViaTelegram =>
      'Craftswomen register themselves through the Telegram bot — only staff are added here.';

  @override
  String get usersEmpty => 'Nobody found';

  @override
  String get youLabel => 'you';

  @override
  String get permGroupUsers => 'Users';

  @override
  String get permGroupWorkers => 'Craftswomen';

  @override
  String get permGroupCollateral => 'Deposit';

  @override
  String get permGroupAssignments => 'Works';

  @override
  String get permGroupFinance => 'Payouts and money';

  @override
  String get permGroupCatalog => 'Catalog';

  @override
  String get permGroupInventory => 'Warehouse';

  @override
  String get permGroupMap => 'Map';

  @override
  String get permGroupSettings => 'Settings';

  @override
  String get permGroupAudit => 'Activity log';

  @override
  String get permUserViewAll => 'See staff';

  @override
  String get permUserCreate => 'Add staff';

  @override
  String get permUserUpdate => 'Edit staff details';

  @override
  String get permUserDeactivate => 'Disable staff';

  @override
  String get permRoleAssign => 'Change roles';

  @override
  String get permPermissionManage => 'Manage rights';

  @override
  String get permWorkerViewAll => 'See all craftswomen';

  @override
  String get permWorkerViewAssigned => 'See own craftswomen';

  @override
  String get permWorkerApprove => 'Approve requests';

  @override
  String get permWorkerUpdate => 'Edit a craftswoman\'s card';

  @override
  String get permWorkerAssignManager => 'Assign a manager';

  @override
  String get permCollateralView => 'See deposits';

  @override
  String get permCollateralManage => 'Receive and return deposits';

  @override
  String get permAssignmentViewAll => 'See all works';

  @override
  String get permAssignmentViewAssigned => 'See own craftswomen\'s works';

  @override
  String get permAssignmentCreate => 'Issue work';

  @override
  String get permAssignmentAccept => 'Accept work';

  @override
  String get permFinanceViewAll => 'See all earnings';

  @override
  String get permFinanceViewAssigned => 'See own craftswomen\'s earnings';

  @override
  String get permCashPayout => 'Pay in cash';

  @override
  String get permProfitView => 'See profit';

  @override
  String get permCatalogView => 'See the catalog';

  @override
  String get permCatalogManage => 'Edit the catalog';

  @override
  String get permInventoryView => 'See the warehouse';

  @override
  String get permInventoryManage => 'Receipts and kits';

  @override
  String get permMapViewAll => 'Map: everyone';

  @override
  String get permMapViewAssigned => 'Map: own craftswomen';

  @override
  String get permLiveLocationViewAll => 'Location: everyone';

  @override
  String get permLiveLocationViewAssigned => 'Location: own craftswomen';

  @override
  String get permPayRateManage => 'Change the price per 9 m';

  @override
  String get permSettingsManage => 'Company settings';

  @override
  String get permAuditView => 'See the activity log';

  @override
  String get auditUserCreate => 'Created';

  @override
  String get auditUserUpdate => 'Details changed';

  @override
  String get auditUserDeactivate => 'Disabled';

  @override
  String get auditUserReactivate => 'Restored';

  @override
  String get auditUserRoleChange => 'Role changed';

  @override
  String get auditUserPermissionChange => 'Rights changed';

  @override
  String get auditUserPasswordReset => 'New password issued';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get changePassword => 'Change password';

  @override
  String get currentPassword => 'Current password';

  @override
  String get newPassword => 'New password';

  @override
  String get repeatPassword => 'New password again';

  @override
  String get passwordsDontMatch => 'Passwords do not match';

  @override
  String get passwordTooShort => 'At least 8 characters';

  @override
  String get wrongCurrentPassword => 'The current password is wrong';

  @override
  String get passwordChanged =>
      'Password changed. Other devices were signed out.';

  @override
  String get setPassword => 'Set password';

  @override
  String get setPasswordHint =>
      'The user is signed out everywhere. Give the password in person.';

  @override
  String get passwordSet => 'Password set';

  @override
  String get showOnMap => 'Show on the map';

  @override
  String get showOnMapHint => 'Visible to everyone allowed to see the map';

  @override
  String get hiddenOnMapHint => 'Hidden: only you see the position';

  @override
  String locationUpdatedHours(int hours, int minutes) {
    return 'Location updated $hours h $minutes min ago';
  }

  @override
  String locationUpdatedOn(String date) {
    return 'Location from $date';
  }

  @override
  String get permPasswordSet => 'Set staff passwords';

  @override
  String get passwordForLogin => 'Sign-in password';

  @override
  String get passwordForLoginHint => 'Make one up and hand it over in person';

  @override
  String get userCreated => 'User created. Hand the password over in person.';

  @override
  String get telegramLoginHint =>
      'For craftswomen — no password, with your Telegram';

  @override
  String get staffSignIn => 'Staff sign-in';

  @override
  String get workWaitingTitle => 'New work is waiting for you';

  @override
  String get workKitReadyTitle => 'Your kit is ready to receive';

  @override
  String get workKitReadyHint =>
      'Scan the QR code on the kit the staff member brought';

  @override
  String get workWaitingHint =>
      'A staff member will bring the kit. When they scan the QR, a receive button appears here.';

  @override
  String get workScanQr => 'Scan QR';

  @override
  String get receiveTitle => 'Receive work';

  @override
  String get receiveCheckHint =>
      'Check the work and materials before confirming.';

  @override
  String get receiveConfirm => 'Confirm receipt';

  @override
  String get receiveProblem => 'There is a problem';

  @override
  String receiveKits(int count) {
    return 'Kits: $count';
  }

  @override
  String get receiveDone => 'Work received!';

  @override
  String get receiveDoneHint => 'The materials are with you now. Good luck!';

  @override
  String get receiveAlready => 'You have already received this work';

  @override
  String get receiveForeign => 'This kit is meant for another craftswoman.';

  @override
  String get receiveNotStarted => 'The staff member must scan this QR first';

  @override
  String get receiveExpired =>
      'The handoff time ran out. Ask the staff member to scan the QR again.';

  @override
  String get receiveScanHint => 'Point the camera at the kit\'s QR code';

  @override
  String get receiveGoHome => 'Go home';

  @override
  String get problemTitle => 'What is wrong?';

  @override
  String get problemShortage => 'Material is missing';

  @override
  String get problemWrongColor => 'Wrong colour';

  @override
  String get problemWrongModel => 'Wrong model';

  @override
  String get problemWrongMeters => 'Wrong length';

  @override
  String get problemDamaged => 'Damaged';

  @override
  String get problemOther => 'Other';

  @override
  String get problemComment => 'Comment (optional)';

  @override
  String get problemSend => 'Send';

  @override
  String get problemSent =>
      'The staff member got your message. The work has not been handed over yet.';

  @override
  String get handoffStart => 'Start handoff';

  @override
  String get handoffStartTitle => 'Hand the kit over?';

  @override
  String get handoffStartBody =>
      'She then scans this QR in her app and confirms receipt herself. The materials move to her only after she confirms.';

  @override
  String get handoffWaiting => 'Waiting for her confirmation';

  @override
  String get handoffWaitingHint => 'Ask her to open the app and scan this QR';

  @override
  String get handoffWorkerScanned =>
      'She scanned the QR and is checking the kit';

  @override
  String handoffReceived(String name) {
    return '$name received the kit';
  }

  @override
  String get handoffProblemTitle => 'She reported a problem';

  @override
  String get handoffRestart => 'Start handoff again';

  @override
  String get handoffExpiredLabel => 'Handoff time ran out';

  @override
  String timelineStarted(String name) {
    return 'Handoff started · $name';
  }

  @override
  String get timelineScanned => 'She scanned the QR';

  @override
  String get timelineConfirmed => 'She confirmed receipt';

  @override
  String get timelineProblem => 'She reported a problem';

  @override
  String get handoffTimelineTitle => 'Handoff';

  @override
  String get materialsAtWorker => 'Materials with the craftswoman';

  @override
  String get materialsPrepared => 'Prepared materials';

  @override
  String get workRemaining => 'Left';

  @override
  String get addWorker => 'Add';

  @override
  String get addWorkerTitle => 'Add a craftswoman';

  @override
  String get addWorkerHint =>
      'We give you a link. She opens it in Telegram and is on the team at once — no questions, no approval.';

  @override
  String get addWorkerGetLink => 'Get link';

  @override
  String get addWorkerFullName => 'Full name';

  @override
  String get addWorkerManager => 'Manager';

  @override
  String get addWorkerNoManager => 'No manager';

  @override
  String get addWorkerLinkReady =>
      'Show her the QR — she points her phone camera at it. Or send the link. It works for 7 days and opens once.';

  @override
  String get addWorkerSendTelegram => 'Send in Telegram';

  @override
  String get addWorkerCopy => 'Copy link';

  @override
  String get addWorkerCopied => 'Link copied';

  @override
  String get invitesPending => 'Invited — link not opened yet';

  @override
  String get inviteCancel => 'Cancel';

  @override
  String get deleteWorker => 'Delete craftswoman';

  @override
  String deleteWorkerConfirm(String name) {
    return '$name disappears from every list, the map and reports and can no longer sign in. Past work and payouts stay in history as «Deleted craftswoman». This cannot be undone.';
  }

  @override
  String get deleteWorkerForever => 'Delete for good';

  @override
  String get deleteWorkerBlocked =>
      'Cannot delete: she already has work, money or a received deposit — these records are needed for reports and payouts. You can archive her: she cannot sign in, history is kept.';

  @override
  String get deleteWorkerDone => 'Craftswoman deleted';

  @override
  String get permWorkerDelete => 'Delete craftswomen';

  @override
  String get chooseWork => 'Choose work';

  @override
  String get orderWork => 'Order this work';

  @override
  String get orderColor => 'Colour';

  @override
  String get orderVolume => 'How many metres';

  @override
  String get orderNote => 'Wish (optional)';

  @override
  String get orderSend => 'Send request';

  @override
  String get orderSent => 'Request sent! The manager will prepare the work.';

  @override
  String get orderAlreadyPending =>
      'You already have a request — wait for an answer or cancel it on the home screen.';

  @override
  String get myRequestPending => 'Request sent';

  @override
  String get myRequestPendingHint => 'Waiting for the manager';

  @override
  String get myRequestRejected => 'Request not accepted';

  @override
  String get myRequestCancel => 'Cancel request';

  @override
  String get jobRequestsTitle => 'Work requests';

  @override
  String get jobRequestsEmpty => 'No new requests';

  @override
  String jobRequestsCount(int count) {
    return 'Work requests: $count';
  }

  @override
  String get jobRequestRejectReason => 'Reason (she will see it)';

  @override
  String updateReady(String version) {
    return 'New version $version is ready';
  }

  @override
  String get updateInstall => 'Install';

  @override
  String get updateAllowInstall => 'Allow installs for Diamoraa and tap again';

  @override
  String get ageNow => 'now';

  @override
  String ageMinutes(int minutes) {
    return '$minutes min ago';
  }

  @override
  String ageHours(int hours, int minutes) {
    return '$hours h $minutes min ago';
  }

  @override
  String get qrRecognized => 'QR recognised';

  @override
  String get handoffStartedToast => 'Handoff started — let her scan this QR';

  @override
  String get qrPrint => 'Print QR';

  @override
  String get noticesTitle => 'Notifications';

  @override
  String get noticesReadAll => 'Mark all read';

  @override
  String get noticesEmpty => 'No notifications yet';

  @override
  String get reportsTitle => 'Reports';

  @override
  String get reportDay => 'Day';

  @override
  String get reportWeek => 'Week';

  @override
  String get reportMonth => 'Month';

  @override
  String get reportIssued => 'Issued';

  @override
  String get reportAccepted => 'Accepted';

  @override
  String get reportOverdue => 'Overdue';

  @override
  String get reportDefective => 'Defective';

  @override
  String get reportByWorker => 'By craftswoman';

  @override
  String get reportEmpty => 'Nothing happened in this period';

  @override
  String get reportLowStock => 'Running low in the warehouse';

  @override
  String get reportExcelHint =>
      'Excel export is in the web panel: Reports → «Download for Excel».';

  @override
  String get myMonthsTitle => 'My earnings by month';

  @override
  String get m1 => 'January';

  @override
  String get m2 => 'February';

  @override
  String get m3 => 'March';

  @override
  String get m4 => 'April';

  @override
  String get m5 => 'May';

  @override
  String get m6 => 'June';

  @override
  String get m7 => 'July';

  @override
  String get m8 => 'August';

  @override
  String get m9 => 'September';

  @override
  String get m10 => 'October';

  @override
  String get m11 => 'November';

  @override
  String get m12 => 'December';

  @override
  String get qaAssign => 'Work';

  @override
  String get qaScan => 'QR';

  @override
  String get qaMap => 'Map';

  @override
  String get qaStock => 'Stock';

  @override
  String get qaPay => 'Pay';

  @override
  String get assignCancel => 'Cancel work';

  @override
  String get assignCancelReason => 'Reason';

  @override
  String get assignCancelReturned => 'Materials returned to the warehouse';

  @override
  String get assignCancelled => 'Work cancelled';

  @override
  String get assignChangeDue => 'Change deadline';

  @override
  String get userDelete => 'Delete staff member';

  @override
  String userDeleteConfirm(String name) {
    return '$name will be deleted for good.';
  }

  @override
  String get userDeleteBlocked =>
      'Cannot delete: this person has history (works, payouts, warehouse). You can disable them.';

  @override
  String get userDeleted => 'Staff member deleted';

  @override
  String get qrNotYours =>
      'This craftswoman belongs to another manager. Ask the administrator to assign her to you.';

  @override
  String get qrRevoked =>
      'This QR no longer works: the work is finished or cancelled, or the craftswoman was deleted.';

  @override
  String get errOpenWork =>
      'First finish or cancel her works and return the deposit — then you can delete.';

  @override
  String get errInUse =>
      'The material is in use: a craftswoman has it or it is in a kit. Remove it from there first.';

  @override
  String errInUseKits(String kits) {
    return 'The material is in kits: $kits. Delete or change those kits first.';
  }

  @override
  String get deleteAction => 'Delete';

  @override
  String get deleteDone => 'Deleted';

  @override
  String catalogDeleteConfirm(String name) {
    return '«$name» disappears from the catalog for everyone. Work already issued stays in history. This cannot be undone.';
  }

  @override
  String materialDeleteConfirm(String name, String left) {
    return '«$name» disappears from the warehouse. The remaining stock ($left) is written off. This cannot be undone.';
  }

  @override
  String kitDeleteConfirm(String name) {
    return 'Kit «$name» disappears from the warehouse. Work already issued stays in history. This cannot be undone.';
  }

  @override
  String get permCatalogDelete => 'Delete from the catalog';

  @override
  String get permInventoryDelete => 'Delete materials and kits';

  @override
  String get assignManagerTitle => 'Assign a manager';

  @override
  String get assignManagerSave => 'Assign';

  @override
  String assignManagerDone(int count) {
    return 'Done: $count craftswomen';
  }

  @override
  String get assignWorkersToManager => 'Assign craftswomen';

  @override
  String get auditClear => 'Clear the log';

  @override
  String get auditClearConfirm =>
      'The log starts over — the first line will be «Log cleared» with your name. Old entries are no longer shown here but are not erased from the database (so nobody can hide what they did).';

  @override
  String get collateralsTitle => 'Deposits';

  @override
  String get collateralsWithUs => 'With us now';

  @override
  String collateralsItems(int count) {
    return '$count items';
  }

  @override
  String get collateralsTabHeld => 'With us';

  @override
  String get collateralsTabPending => 'Not received';

  @override
  String get collateralsTabReturned => 'Returned';

  @override
  String get collateralsEmpty => 'Nothing here';

  @override
  String get collateralReturnTitle => 'Return deposit';

  @override
  String get collateralReturnNote => 'How it was returned';

  @override
  String get collateralReturnConfirm => 'She got the deposit back';

  @override
  String get collateralReturnedToast => 'Deposit returned';

  @override
  String get mapFilterAll => 'All';

  @override
  String get mapFilterToDeliver => 'To deliver';

  @override
  String get mapFilterToPickup => 'Ready to collect';

  @override
  String get mapFilterOverdue => 'Overdue';

  @override
  String get mapFilterAllManagers => 'All managers';

  @override
  String get mapAtHome =>
      'At home — the address she registered with (her phone is not sharing a location now)';

  @override
  String get ratingTitle => 'Craftswomen rating';

  @override
  String get ratingThreeMonths => '3 months';

  @override
  String get ratingHalfYear => 'Half a year';

  @override
  String ratingLine(String meters, String defect, int late, int total) {
    return '$meters m · defects $defect% · late $late of $total';
  }

  @override
  String get ratingHowScored =>
      'Score out of 100: 40% volume (≈54 m a month = full marks), 35% no defects, 25% on time.';

  @override
  String get profitTitle => 'Profit';

  @override
  String get profitAdd => 'Sale or expense';

  @override
  String get profitSale => 'Sale';

  @override
  String get profitExpense => 'Expense';

  @override
  String get profitSales => 'Sales';

  @override
  String get profitLabor => 'Craftswomen';

  @override
  String get profitMaterials => 'Materials';

  @override
  String get profitExpenses => 'Expenses';

  @override
  String get profitCustomer => 'Customer (optional)';

  @override
  String get profitNoPriceHint =>
      '* Some materials have no purchase price and are not counted. Set the price in the web panel\'s warehouse.';

  @override
  String get profitDeleteConfirm =>
      'Delete this entry? The month\'s profit is recalculated.';

  @override
  String get expenseFuel => 'Fuel / delivery';

  @override
  String get expensePackaging => 'Packaging';

  @override
  String get expenseOther => 'Other';

  @override
  String get stockValueTitle => 'Warehouse value (purchase price)';

  @override
  String stockValueSplit(String shelf, String homes) {
    return 'on the shelf $shelf · with craftswomen $homes';
  }

  @override
  String stockValueNoPrice(String names) {
    return 'No price: $names';
  }

  @override
  String get systemTitle => 'System status';

  @override
  String get systemServer => 'Server';

  @override
  String get systemDatabase => 'Database';

  @override
  String systemUptime(int hours) {
    return 'up $hours h';
  }

  @override
  String get systemOk => 'OK';

  @override
  String get systemDown => 'not responding';

  @override
  String get systemBackups => 'Backups';

  @override
  String get systemBackupsHidden =>
      'The server cannot see the backup status folder.';

  @override
  String get systemBackupFailed => 'failed';

  @override
  String get systemBackupLate => 'overdue';

  @override
  String get backupDaily => 'Database (daily)';

  @override
  String get backupWeekly => 'Full database copy (weekly)';

  @override
  String get backupFiles => 'Photos and files';

  @override
  String get backupConfig => 'Settings';

  @override
  String get backupVerify => 'Restore check';

  @override
  String get backupRestore => 'Restore';

  @override
  String get editName => 'Change name';

  @override
  String get firstName => 'First name';

  @override
  String get lastName => 'Surname';

  @override
  String get nameSaved => 'Name saved';

  @override
  String get nameTooShort => 'The first name needs at least 2 letters';

  @override
  String get chat => 'Chat';

  @override
  String get chatCompany => 'Company chat';

  @override
  String get chatNew => 'New chat';

  @override
  String get chatNewGroup => 'New group';

  @override
  String get chatGroupName => 'Group name';

  @override
  String chatMembers(int count) {
    return 'Members: $count';
  }

  @override
  String get chatSearchPeople => 'Search by name';

  @override
  String get chatEmpty => 'No messages yet — say hello';

  @override
  String get chatNoChats => 'Your conversations will be here';

  @override
  String get chatTypeMessage => 'Message';

  @override
  String get chatPhoto => 'Photo';

  @override
  String get chatCamera => 'Camera';

  @override
  String get chatVideo => 'Video';

  @override
  String get chatRecordVideo => 'Record video';

  @override
  String get chatFile => 'File';

  @override
  String get chatVoice => 'Voice message';

  @override
  String get chatAudio => 'Audio';

  @override
  String get chatHoldToRecord => 'Hold the microphone button to record';

  @override
  String get chatRecording => 'Recording… release to send';

  @override
  String get chatMessageDeleted => 'Message deleted';

  @override
  String get chatDeleteMessage => 'Delete message';

  @override
  String get chatDeleteMessageBody =>
      'The message will disappear for everyone.';

  @override
  String get chatCopy => 'Copy';

  @override
  String get chatCopied => 'Copied';

  @override
  String get chatFileTooLarge =>
      'The file is larger than 50 MB and cannot be sent';

  @override
  String chatSendingProgress(int percent) {
    return 'Sending… $percent%';
  }

  @override
  String get chatSendFailed => 'Not sent — tap to retry';

  @override
  String get chatRead => 'Read';

  @override
  String get chatLeaveGroup => 'Leave group';

  @override
  String get chatLeaveGroupBody => 'You will no longer see this group.';

  @override
  String get chatAddMembers => 'Add members';

  @override
  String get chatRemoveMember => 'Remove from group';

  @override
  String get chatRename => 'Rename';

  @override
  String get chatOwner => 'owner';

  @override
  String get chatMicPermission =>
      'Allow the microphone to record voice messages';

  @override
  String get chatYou => 'You';

  @override
  String get chatDownloading => 'Downloading…';

  @override
  String get chatFileFailed => 'Could not load the file';

  @override
  String get chatCreate => 'Create';

  @override
  String get chatGroupInfo => 'Group info';

  @override
  String get chatToday => 'Today';

  @override
  String get chatYesterday => 'Yesterday';

  @override
  String get chatCompanyHint => 'All staff and workers';

  @override
  String get chatAttach => 'Attach';

  @override
  String get chatSend => 'Send';

  @override
  String get chatReply => 'Reply';

  @override
  String get chatEdit => 'Edit';

  @override
  String get chatEdited => 'edited';

  @override
  String get chatEditing => 'Editing';

  @override
  String get chatForward => 'Forward';

  @override
  String get chatForwardTo => 'Forward to…';

  @override
  String get chatForwarded => 'Forwarded';

  @override
  String chatForwardedFrom(String name) {
    return 'Forwarded from $name';
  }

  @override
  String get chatPin => 'Pin';

  @override
  String get chatUnpin => 'Unpin';

  @override
  String get chatPinned => 'Pinned message';

  @override
  String get chatPinChat => 'Pin chat';

  @override
  String get chatUnpinChat => 'Unpin chat';

  @override
  String get chatMute => 'Mute';

  @override
  String get chatUnmute => 'Unmute';

  @override
  String get chatSearch => 'Search';

  @override
  String get chatSearchHint => 'Chats, people, messages';

  @override
  String get chatSectionChats => 'Chats';

  @override
  String get chatSectionPeople => 'People';

  @override
  String get chatSectionMessages => 'Messages';

  @override
  String get chatNothingFound => 'Nothing found';

  @override
  String get chatTyping => 'typing…';

  @override
  String chatTypingName(String name) {
    return '$name is typing…';
  }

  @override
  String get chatRecordingVoice => 'recording a voice message…';

  @override
  String chatRecordingVoiceName(String name) {
    return '$name is recording a voice message…';
  }

  @override
  String chatLastSeen(String time) {
    return 'last seen $time';
  }

  @override
  String chatReplyTo(String name) {
    return 'Reply to $name';
  }

  @override
  String get chatEmoji => 'Emoji';

  @override
  String get chatNewChannel => 'New channel';

  @override
  String get chatChannelName => 'Channel name';

  @override
  String get chatDescription => 'Description';

  @override
  String get chatAudience => 'Who reads it';

  @override
  String get chatAudienceAll => 'All staff and workers';

  @override
  String get chatAudienceStaff => 'Staff only';

  @override
  String get chatAudienceWorkers => 'Workers only';

  @override
  String get chatAudienceCustom => 'Chosen people';

  @override
  String chatChoosePeople(int count) {
    return 'Choose people ($count)';
  }

  @override
  String get chatChannelHint =>
      'Only the channel admins post; readers see the announcements and get notified.';

  @override
  String get chatChannelReadOnly => 'This is a channel: only its admins post';

  @override
  String get chatGroupReadOnly => 'Only the group admins can write';

  @override
  String get chatOnlyAdminsWrite => 'Only admins can write';

  @override
  String get chatMakeAdmin => 'Make admin';

  @override
  String get chatRemoveAdmin => 'Remove admin';

  @override
  String get chatAddAdmin => 'Add an admin';

  @override
  String get chatAdmin => 'admin';

  @override
  String get chatChangePhoto => 'Change photo';

  @override
  String get chatInfo => 'Chat info';

  @override
  String get chatChannelInfo => 'Channel info';

  @override
  String get chatTabMembers => 'Members';

  @override
  String get chatTabMedia => 'Media';

  @override
  String get chatTabFiles => 'Files';

  @override
  String get chatTabVoice => 'Voice';

  @override
  String get chatTabLinks => 'Links';

  @override
  String get chatNothingYet => 'Nothing yet';

  @override
  String chatSubscribers(int count) {
    return 'Channel · subscribers: $count';
  }

  @override
  String get chatLeaveChannel => 'Leave channel';

  @override
  String get chatVideoTooLarge =>
      'The video is larger than 150 MB and cannot be sent';

  @override
  String get chatMyProfile => 'My profile';

  @override
  String get chatBio => 'Bio';

  @override
  String get chatBioHint => 'Any details: your role, area or working hours.';

  @override
  String get chatUsername => 'Username';

  @override
  String get chatUsernameHint => 'Latin letters, digits and _, 5+ characters.';

  @override
  String get chatUsernameTaken => 'This username is taken';

  @override
  String get chatPhone => 'Phone';

  @override
  String get chatRole => 'Role';

  @override
  String get chatChangeAvatar => 'Change profile photo';

  @override
  String get chatRemoveAvatar => 'Remove photo';

  @override
  String chatReadAt(String time) {
    return 'read at $time';
  }

  @override
  String get chatNotReadYet => 'not read yet';

  @override
  String get chatWhoRead => 'Who read it';

  @override
  String get chatNobodyYet => 'Nobody yet';

  @override
  String get chatClearHistory => 'Clear history';

  @override
  String get chatClearHistoryBody => 'Messages disappear only for you.';

  @override
  String get chatDeleteChat => 'Delete chat';

  @override
  String get chatDeleteChatBody => 'The conversation disappears only for you.';

  @override
  String get chatProtectOn => 'Restrict saving content';

  @override
  String get chatProtectOff => 'Allow saving content';

  @override
  String get chatProtected => 'Copying and forwarding are off in this chat';

  @override
  String get chatExport => 'Export chat history';

  @override
  String get chatSearchInChat => 'Search in this chat';

  @override
  String get chatOlderMessage => 'This message is further up — scroll up';

  @override
  String get chatCancelUpload => 'Cancel sending';

  @override
  String chatCountPhotos(int count) {
    return 'Photos: $count';
  }

  @override
  String chatCountVideos(int count) {
    return 'Videos: $count';
  }

  @override
  String chatCountFiles(int count) {
    return 'Files: $count';
  }

  @override
  String chatCountVoice(int count) {
    return 'Voice messages: $count';
  }

  @override
  String chatCountLinks(int count) {
    return 'Links: $count';
  }

  @override
  String get chatShowProfile => 'View profile';

  @override
  String chatTodayAt(String time) {
    return 'today at $time';
  }

  @override
  String chatYesterdayAt(String time) {
    return 'yesterday at $time';
  }

  @override
  String chatDateAt(String date, String time) {
    return '$date at $time';
  }

  @override
  String get chatAudioPrev => 'Previous';

  @override
  String get chatAudioNext => 'Next';

  @override
  String get chatAudioPlay => 'Play';

  @override
  String get chatAudioPause => 'Pause';

  @override
  String get chatAudioSpeed => 'Speed';

  @override
  String get chatAudioMute => 'Sound';

  @override
  String get chatAudioClose => 'Close player';

  @override
  String updateDownloading(String version, int percent) {
    return 'Downloading version $version — $percent%';
  }

  @override
  String get mapZoomIn => 'Zoom in';

  @override
  String get mapZoomOut => 'Zoom out';

  @override
  String get mapMyPlace => 'My location';

  @override
  String get mapNoMyPlace => 'Could not find your location. Turn on location.';

  @override
  String get mapNorth => 'North up';

  @override
  String get mapTraffic => 'Traffic';

  @override
  String get mapShowAll => 'Everyone in view';

  @override
  String get map3d => '3D view';

  @override
  String get updateAppVersion => 'App version';

  @override
  String get updateCheck => 'Check';

  @override
  String get updateLatest => 'You have the latest version';

  @override
  String stockLasts(int days) {
    return 'lasts ≈ $days d';
  }

  @override
  String get goalTitle => 'Goal of the month';

  @override
  String goalPlace(int place, int of) {
    return 'Place $place of $of';
  }

  @override
  String goalProgress(String done, int goal) {
    return '$done of $goal m';
  }

  @override
  String goalLeft(String left, int days) {
    return '$left m to go · $days days left';
  }

  @override
  String get goalDone => 'Goal reached! Thank you 🎉';

  @override
  String goalNoGoal(String done) {
    return 'Accepted this month: $done m';
  }

  @override
  String get routeTitle => 'Route';

  @override
  String routeReady(int count, String km) {
    return 'Route: $count stops, ≈ $km km';
  }

  @override
  String routeBuild(int count) {
    return 'Plan the route ($count)';
  }

  @override
  String get routeOpenYandex => 'Open in Yandex Maps';

  @override
  String get routeChange => 'Change the list';

  @override
  String get routeToPickup => 'collect work';

  @override
  String get routeToDeliver => 'deliver materials';

  @override
  String get routeOverdue => 'overdue';

  @override
  String get routeNobody => 'No workers on the map yet.';

  @override
  String get routeNoStart =>
      'Your location is unknown - the route starts at the first stop.';
}
