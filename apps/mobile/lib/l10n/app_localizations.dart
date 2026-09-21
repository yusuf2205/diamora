import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ru.dart';
import 'app_localizations_uz.dart';

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
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ru'),
    Locale('uz'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ru, this message translates to:
  /// **'Yusmus'**
  String get appTitle;

  /// No description provided for @iAmAdmin.
  ///
  /// In ru, this message translates to:
  /// **'Я администратор'**
  String get iAmAdmin;

  /// No description provided for @iAmWorker.
  ///
  /// In ru, this message translates to:
  /// **'Я мастерица'**
  String get iAmWorker;

  /// No description provided for @phone.
  ///
  /// In ru, this message translates to:
  /// **'Телефон'**
  String get phone;

  /// No description provided for @password.
  ///
  /// In ru, this message translates to:
  /// **'Пароль'**
  String get password;

  /// No description provided for @signIn.
  ///
  /// In ru, this message translates to:
  /// **'Войти'**
  String get signIn;

  /// No description provided for @signOut.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get signOut;

  /// No description provided for @getCode.
  ///
  /// In ru, this message translates to:
  /// **'Получить код в Telegram'**
  String get getCode;

  /// No description provided for @codeSent.
  ///
  /// In ru, this message translates to:
  /// **'Код отправлен в ваш Telegram. Введите его ниже.'**
  String get codeSent;

  /// No description provided for @codeHint.
  ///
  /// In ru, this message translates to:
  /// **'Код из Telegram (6 цифр)'**
  String get codeHint;

  /// No description provided for @workerLoginHint.
  ///
  /// In ru, this message translates to:
  /// **'Мы отправим одноразовый код в Telegram, где вы регистрировались.'**
  String get workerLoginHint;

  /// No description provided for @invalidCredentials.
  ///
  /// In ru, this message translates to:
  /// **'Неверный телефон или пароль'**
  String get invalidCredentials;

  /// No description provided for @invalidCode.
  ///
  /// In ru, this message translates to:
  /// **'Неверный или просроченный код'**
  String get invalidCode;

  /// No description provided for @tooManyAttempts.
  ///
  /// In ru, this message translates to:
  /// **'Слишком много попыток. Попробуйте позже.'**
  String get tooManyAttempts;

  /// No description provided for @noConnection.
  ///
  /// In ru, this message translates to:
  /// **'Нет связи с сервером. Проверьте интернет.'**
  String get noConnection;

  /// No description provided for @genericError.
  ///
  /// In ru, this message translates to:
  /// **'Что-то пошло не так'**
  String get genericError;

  /// No description provided for @retry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердить'**
  String get confirm;

  /// No description provided for @offlineBanner.
  ///
  /// In ru, this message translates to:
  /// **'Нет интернета — показаны сохранённые данные'**
  String get offlineBanner;

  /// No description provided for @workers.
  ///
  /// In ru, this message translates to:
  /// **'Мастерицы'**
  String get workers;

  /// No description provided for @profile.
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get profile;

  /// No description provided for @home.
  ///
  /// In ru, this message translates to:
  /// **'Главная'**
  String get home;

  /// No description provided for @search.
  ///
  /// In ru, this message translates to:
  /// **'Поиск: имя, телефон'**
  String get search;

  /// No description provided for @tabPending.
  ///
  /// In ru, this message translates to:
  /// **'Заявки'**
  String get tabPending;

  /// No description provided for @tabActive.
  ///
  /// In ru, this message translates to:
  /// **'Активные'**
  String get tabActive;

  /// No description provided for @tabAll.
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get tabAll;

  /// No description provided for @emptyPending.
  ///
  /// In ru, this message translates to:
  /// **'Новых заявок нет'**
  String get emptyPending;

  /// No description provided for @emptyPendingHint.
  ///
  /// In ru, this message translates to:
  /// **'Когда мастерица зарегистрируется в Telegram, заявка появится здесь мгновенно'**
  String get emptyPendingHint;

  /// No description provided for @emptyWorkers.
  ///
  /// In ru, this message translates to:
  /// **'Здесь пока никого нет'**
  String get emptyWorkers;

  /// No description provided for @newRegistration.
  ///
  /// In ru, this message translates to:
  /// **'Новая заявка: {name}'**
  String newRegistration(String name);

  /// No description provided for @statusPending.
  ///
  /// In ru, this message translates to:
  /// **'На рассмотрении'**
  String get statusPending;

  /// No description provided for @statusActive.
  ///
  /// In ru, this message translates to:
  /// **'Активна'**
  String get statusActive;

  /// No description provided for @statusPaused.
  ///
  /// In ru, this message translates to:
  /// **'На паузе'**
  String get statusPaused;

  /// No description provided for @statusRejected.
  ///
  /// In ru, this message translates to:
  /// **'Отклонена'**
  String get statusRejected;

  /// No description provided for @statusArchived.
  ///
  /// In ru, this message translates to:
  /// **'В архиве'**
  String get statusArchived;

  /// No description provided for @call.
  ///
  /// In ru, this message translates to:
  /// **'Позвонить'**
  String get call;

  /// No description provided for @route.
  ///
  /// In ru, this message translates to:
  /// **'Построить маршрут'**
  String get route;

  /// No description provided for @location.
  ///
  /// In ru, this message translates to:
  /// **'Геолокация'**
  String get location;

  /// No description provided for @noLocation.
  ///
  /// In ru, this message translates to:
  /// **'Геолокация не получена'**
  String get noLocation;

  /// No description provided for @secondaryPhone.
  ///
  /// In ru, this message translates to:
  /// **'Доп. телефон'**
  String get secondaryPhone;

  /// No description provided for @notes.
  ///
  /// In ru, this message translates to:
  /// **'Заметки'**
  String get notes;

  /// No description provided for @collateral.
  ///
  /// In ru, this message translates to:
  /// **'Залог'**
  String get collateral;

  /// No description provided for @collateralMoney.
  ///
  /// In ru, this message translates to:
  /// **'Деньги'**
  String get collateralMoney;

  /// No description provided for @collateralItem.
  ///
  /// In ru, this message translates to:
  /// **'Вещь'**
  String get collateralItem;

  /// No description provided for @collateralPending.
  ///
  /// In ru, this message translates to:
  /// **'Заявлен, ещё не принят'**
  String get collateralPending;

  /// No description provided for @collateralHeld.
  ///
  /// In ru, this message translates to:
  /// **'Хранится у нас'**
  String get collateralHeld;

  /// No description provided for @collateralReturned.
  ///
  /// In ru, this message translates to:
  /// **'Возвращён'**
  String get collateralReturned;

  /// No description provided for @receiveCollateral.
  ///
  /// In ru, this message translates to:
  /// **'Принять залог'**
  String get receiveCollateral;

  /// No description provided for @receivedNote.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий (необязательно)'**
  String get receivedNote;

  /// No description provided for @estimatedValue.
  ///
  /// In ru, this message translates to:
  /// **'Оценочная стоимость, сум'**
  String get estimatedValue;

  /// No description provided for @storageLocation.
  ///
  /// In ru, this message translates to:
  /// **'Где хранится'**
  String get storageLocation;

  /// No description provided for @history.
  ///
  /// In ru, this message translates to:
  /// **'История'**
  String get history;

  /// No description provided for @approve.
  ///
  /// In ru, this message translates to:
  /// **'Одобрить'**
  String get approve;

  /// No description provided for @reject.
  ///
  /// In ru, this message translates to:
  /// **'Отклонить'**
  String get reject;

  /// No description provided for @approveTitle.
  ///
  /// In ru, this message translates to:
  /// **'Одобрить мастерицу?'**
  String get approveTitle;

  /// No description provided for @collateralReceivedCheck.
  ///
  /// In ru, this message translates to:
  /// **'Залог физически получен'**
  String get collateralReceivedCheck;

  /// No description provided for @rejectTitle.
  ///
  /// In ru, this message translates to:
  /// **'Отклонить заявку'**
  String get rejectTitle;

  /// No description provided for @rejectReason.
  ///
  /// In ru, this message translates to:
  /// **'Причина (её увидит мастерица)'**
  String get rejectReason;

  /// No description provided for @required.
  ///
  /// In ru, this message translates to:
  /// **'Обязательное поле'**
  String get required;

  /// No description provided for @approvedDone.
  ///
  /// In ru, this message translates to:
  /// **'Мастерица одобрена. Ей отправлено сообщение в Telegram.'**
  String get approvedDone;

  /// No description provided for @rejectedDone.
  ///
  /// In ru, this message translates to:
  /// **'Заявка отклонена'**
  String get rejectedDone;

  /// No description provided for @myStatusPending.
  ///
  /// In ru, this message translates to:
  /// **'Ваша заявка на рассмотрении'**
  String get myStatusPending;

  /// No description provided for @myStatusActive.
  ///
  /// In ru, this message translates to:
  /// **'Вы в команде ✨'**
  String get myStatusActive;

  /// No description provided for @balanceToReceive.
  ///
  /// In ru, this message translates to:
  /// **'К получению'**
  String get balanceToReceive;

  /// No description provided for @devices.
  ///
  /// In ru, this message translates to:
  /// **'Устройства'**
  String get devices;

  /// No description provided for @thisDevice.
  ///
  /// In ru, this message translates to:
  /// **'это устройство'**
  String get thisDevice;

  /// No description provided for @revoke.
  ///
  /// In ru, this message translates to:
  /// **'Завершить сеанс'**
  String get revoke;

  /// No description provided for @logoutAll.
  ///
  /// In ru, this message translates to:
  /// **'Выйти на всех устройствах'**
  String get logoutAll;

  /// No description provided for @language.
  ///
  /// In ru, this message translates to:
  /// **'Язык'**
  String get language;

  /// No description provided for @currency.
  ///
  /// In ru, this message translates to:
  /// **'сум'**
  String get currency;

  /// No description provided for @save.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get save;

  /// No description provided for @payRateTitle.
  ///
  /// In ru, this message translates to:
  /// **'Ставка за 9 м'**
  String get payRateTitle;

  /// No description provided for @payRateSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Оплата за один комплект {meters} м'**
  String payRateSubtitle(int meters);

  /// No description provided for @payRateAppliesToAll.
  ///
  /// In ru, this message translates to:
  /// **'Ставка одна для всех. Когда вы её меняете, она сразу меняется у всех мастериц. Уже принятая работа не пересчитывается.'**
  String get payRateAppliesToAll;

  /// No description provided for @payRateChange.
  ///
  /// In ru, this message translates to:
  /// **'Изменить ставку'**
  String get payRateChange;

  /// No description provided for @payRateNew.
  ///
  /// In ru, this message translates to:
  /// **'Новая ставка за {meters} м'**
  String payRateNew(int meters);

  /// No description provided for @payRateInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Введите сумму от 1 до 10 000 000'**
  String get payRateInvalid;

  /// No description provided for @payRateSaved.
  ///
  /// In ru, this message translates to:
  /// **'Ставка обновлена: {amount} сум'**
  String payRateSaved(String amount);

  /// No description provided for @payRateHistory.
  ///
  /// In ru, this message translates to:
  /// **'История ставки'**
  String get payRateHistory;

  /// No description provided for @payRateStart.
  ///
  /// In ru, this message translates to:
  /// **'начальная'**
  String get payRateStart;

  /// No description provided for @payRatePerKit.
  ///
  /// In ru, this message translates to:
  /// **'Оплата за {meters} метров'**
  String payRatePerKit(int meters);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ru', 'uz'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ru':
      return AppLocalizationsRu();
    case 'uz':
      return AppLocalizationsUz();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
