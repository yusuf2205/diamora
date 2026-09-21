// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Yusmus';

  @override
  String get iAmAdmin => 'Я администратор';

  @override
  String get iAmWorker => 'Я мастерица';

  @override
  String get phone => 'Телефон';

  @override
  String get password => 'Пароль';

  @override
  String get signIn => 'Войти';

  @override
  String get signOut => 'Выйти';

  @override
  String get getCode => 'Получить код в Telegram';

  @override
  String get codeSent => 'Код отправлен в ваш Telegram. Введите его ниже.';

  @override
  String get codeHint => 'Код из Telegram (6 цифр)';

  @override
  String get workerLoginHint =>
      'Мы отправим одноразовый код в Telegram, где вы регистрировались.';

  @override
  String get invalidCredentials => 'Неверный телефон или пароль';

  @override
  String get invalidCode => 'Неверный или просроченный код';

  @override
  String get tooManyAttempts => 'Слишком много попыток. Попробуйте позже.';

  @override
  String get noConnection => 'Нет связи с сервером. Проверьте интернет.';

  @override
  String get genericError => 'Что-то пошло не так';

  @override
  String get retry => 'Повторить';

  @override
  String get cancel => 'Отмена';

  @override
  String get confirm => 'Подтвердить';

  @override
  String get offlineBanner => 'Нет интернета — показаны сохранённые данные';

  @override
  String get workers => 'Мастерицы';

  @override
  String get profile => 'Профиль';

  @override
  String get home => 'Главная';

  @override
  String get search => 'Поиск: имя, телефон';

  @override
  String get tabPending => 'Заявки';

  @override
  String get tabActive => 'Активные';

  @override
  String get tabAll => 'Все';

  @override
  String get emptyPending => 'Новых заявок нет';

  @override
  String get emptyPendingHint =>
      'Когда мастерица зарегистрируется в Telegram, заявка появится здесь мгновенно';

  @override
  String get emptyWorkers => 'Здесь пока никого нет';

  @override
  String newRegistration(String name) {
    return 'Новая заявка: $name';
  }

  @override
  String get statusPending => 'На рассмотрении';

  @override
  String get statusActive => 'Активна';

  @override
  String get statusPaused => 'На паузе';

  @override
  String get statusRejected => 'Отклонена';

  @override
  String get statusArchived => 'В архиве';

  @override
  String get call => 'Позвонить';

  @override
  String get route => 'Построить маршрут';

  @override
  String get location => 'Геолокация';

  @override
  String get noLocation => 'Геолокация не получена';

  @override
  String get secondaryPhone => 'Доп. телефон';

  @override
  String get notes => 'Заметки';

  @override
  String get collateral => 'Залог';

  @override
  String get collateralMoney => 'Деньги';

  @override
  String get collateralItem => 'Вещь';

  @override
  String get collateralPending => 'Заявлен, ещё не принят';

  @override
  String get collateralHeld => 'Хранится у нас';

  @override
  String get collateralReturned => 'Возвращён';

  @override
  String get receiveCollateral => 'Принять залог';

  @override
  String get receivedNote => 'Комментарий (необязательно)';

  @override
  String get estimatedValue => 'Оценочная стоимость, сум';

  @override
  String get storageLocation => 'Где хранится';

  @override
  String get history => 'История';

  @override
  String get approve => 'Одобрить';

  @override
  String get reject => 'Отклонить';

  @override
  String get approveTitle => 'Одобрить мастерицу?';

  @override
  String get collateralReceivedCheck => 'Залог физически получен';

  @override
  String get rejectTitle => 'Отклонить заявку';

  @override
  String get rejectReason => 'Причина (её увидит мастерица)';

  @override
  String get required => 'Обязательное поле';

  @override
  String get approvedDone =>
      'Мастерица одобрена. Ей отправлено сообщение в Telegram.';

  @override
  String get rejectedDone => 'Заявка отклонена';

  @override
  String get myStatusPending => 'Ваша заявка на рассмотрении';

  @override
  String get myStatusActive => 'Вы в команде ✨';

  @override
  String get balanceToReceive => 'К получению';

  @override
  String get devices => 'Устройства';

  @override
  String get thisDevice => 'это устройство';

  @override
  String get revoke => 'Завершить сеанс';

  @override
  String get logoutAll => 'Выйти на всех устройствах';

  @override
  String get language => 'Язык';

  @override
  String get currency => 'сум';

  @override
  String get save => 'Сохранить';

  @override
  String get payRateTitle => 'Ставка за 9 м';

  @override
  String payRateSubtitle(int meters) {
    return 'Оплата за один комплект $meters м';
  }

  @override
  String get payRateAppliesToAll =>
      'Ставка одна для всех. Когда вы её меняете, она сразу меняется у всех мастериц. Уже принятая работа не пересчитывается.';

  @override
  String get payRateChange => 'Изменить ставку';

  @override
  String payRateNew(int meters) {
    return 'Новая ставка за $meters м';
  }

  @override
  String get payRateInvalid => 'Введите сумму от 1 до 10 000 000';

  @override
  String payRateSaved(String amount) {
    return 'Ставка обновлена: $amount сум';
  }

  @override
  String get payRateHistory => 'История ставки';

  @override
  String get payRateStart => 'начальная';

  @override
  String payRatePerKit(int meters) {
    return 'Оплата за $meters метров';
  }
}
