// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Diamoraa';

  @override
  String get welcomeTitle => 'Добро пожаловать';

  @override
  String get phone => 'Телефон';

  @override
  String get password => 'Пароль';

  @override
  String get signIn => 'Войти';

  @override
  String get signOut => 'Выйти';

  @override
  String get continueAction => 'Продолжить';

  @override
  String get signInWithTelegram => 'Войти через Telegram';

  @override
  String get orDivider => 'или';

  @override
  String get openingTelegram => 'Открываем Telegram…';

  @override
  String get telegramLoginFailed =>
      'Не удалось открыть Telegram. Попробуйте ещё раз.';

  @override
  String get workersUseTelegram =>
      'Мастерицы входят через Telegram — нажмите кнопку ниже.';

  @override
  String get pendingApprovalTitle => 'Заявка отправлена';

  @override
  String get pendingApprovalBody =>
      'Ожидайте подтверждения администратора. Мы напишем в Telegram, как только решение будет готово.';

  @override
  String get rejectedTitle => 'Заявка отклонена';

  @override
  String get workerPausedTitle => 'Профиль приостановлен';

  @override
  String get workerPausedBody => 'Свяжитесь с администратором.';

  @override
  String get backToLogin => 'На экран входа';

  @override
  String get checkAgainInTelegram => 'Попробовать снова через Telegram';

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
  String get checkYourInput => 'Проверьте введённые данные';

  @override
  String get phoneRequired => 'Введите номер телефона';

  @override
  String get invalidPhoneFormat => 'Введите правильный номер телефона';

  @override
  String get userNotFound =>
      'Пользователь с таким номером не найден. Обратитесь к администратору.';

  @override
  String get accountDisabled =>
      'Ваш аккаунт отключён. Обратитесь к администратору.';

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

  @override
  String get locationServicesOffTitle => 'Включите геолокацию';

  @override
  String get locationServicesOffBody =>
      'Без геолокации приложение не может показывать, где сейчас находится работа. Включите её в настройках телефона.';

  @override
  String get locationForegroundTitle => 'Разрешите доступ к геолокации';

  @override
  String get locationForegroundBody =>
      'Приложению нужна ваша геолокация, пока оно открыто, чтобы админ видел актуальное местоположение.';

  @override
  String get locationBackgroundTitle => 'Разрешите геолокацию в фоне';

  @override
  String get locationBackgroundBody =>
      'Чтобы местоположение оставалось точным и когда приложение свёрнуто, разрешите доступ «Всегда».';

  @override
  String get locationDeniedForeverBody =>
      'Доступ отклонён. Откройте настройки приложения и разрешите геолокацию вручную.';

  @override
  String get locationOpenSettings => 'Открыть настройки геолокации';

  @override
  String get locationAllow => 'Разрешить';

  @override
  String get locationOpenAppSettings => 'Открыть настройки приложения';

  @override
  String get catalog => 'Наши работы';

  @override
  String get catalogEmpty => 'Пока ничего не опубликовано';

  @override
  String get catalogEmptyHint =>
      'Новые работы появятся здесь, как только их опубликует администратор';

  @override
  String get catalogNew => 'Новинка';

  @override
  String get catalogCall => 'Позвонить';

  @override
  String get catalogTelegram => 'Написать в Telegram';

  @override
  String get catalogAvailable => 'Есть в наличии';

  @override
  String get catalogOnRequest => 'Под заказ';

  @override
  String get catalogUnavailable => 'Сейчас нет';

  @override
  String get catalogAdminTitle => 'Каталог работ';

  @override
  String get catalogAddItem => 'Добавить работу';

  @override
  String get catalogItemName => 'Название';

  @override
  String get catalogItemDescription => 'Описание';

  @override
  String get catalogStatusDraft => 'Черновик';

  @override
  String get catalogStatusPublished => 'Опубликовано';

  @override
  String get catalogStatusHidden => 'Скрыто';

  @override
  String get catalogPublish => 'Опубликовать';

  @override
  String get catalogHide => 'Скрыть';

  @override
  String get catalogAddPhoto => 'Добавить фото';

  @override
  String get catalogMarkNew => 'Отметить как новинку';

  @override
  String get catalogPublishNeedsPhoto =>
      'Перед публикацией добавьте хотя бы одно фото';

  @override
  String get catalogDeleteBlocked =>
      'Эта работа уже использована — можно только скрыть';

  @override
  String get catalogSaved => 'Сохранено';

  @override
  String get team => 'Команда';

  @override
  String get teamUsers => 'Пользователи';

  @override
  String get teamManagers => 'Менеджеры';

  @override
  String get teamAddUser => 'Добавить пользователя';

  @override
  String get teamFullName => 'ФИО';

  @override
  String get teamRole => 'Роль';

  @override
  String get roleSuperAdmin => 'Главный администратор';

  @override
  String get roleAdmin => 'Администратор';

  @override
  String get roleManager => 'Менеджер';

  @override
  String get roleWorker => 'Мастерица';

  @override
  String get teamStatusActive => 'Активен';

  @override
  String get teamStatusSuspended => 'Отключён';

  @override
  String get teamDeactivate => 'Отключить';

  @override
  String get teamReactivate => 'Включить';

  @override
  String get teamNoAccess => 'Недостаточно прав для просмотра команды';

  @override
  String get teamCreated => 'Пользователь создан. Пароль показан один раз:';

  @override
  String teamAssignedWorkers(int count) {
    return 'Мастериц: $count';
  }

  @override
  String get teamEditUser => 'Пользователь';

  @override
  String get teamSaveChanges => 'Сохранить';

  @override
  String get teamPhoneTaken =>
      'Этот номер уже используется другим пользователем';

  @override
  String teamConfirmRoleChange(String from, String to) {
    return 'Изменить роль с $from на $to?';
  }

  @override
  String get teamRoleChanged => 'Роль изменена';

  @override
  String get teamSaved => 'Изменения сохранены';

  @override
  String get settingsCompanyContact => 'Телефон и Telegram компании';

  @override
  String get settingsPhone => 'Телефон компании';

  @override
  String get settingsTelegram => 'Telegram (без @)';

  @override
  String get settingsCompanyContactHint =>
      'Эти данные видят мастерицы в каталоге на кнопках «Позвонить» и «Написать в Telegram»';

  @override
  String get audit => 'Журнал действий';

  @override
  String get auditEmpty => 'Записей пока нет';

  @override
  String get locations => 'Геолокация команды';

  @override
  String get locationsEmpty => 'Пока нет данных о местоположении';

  @override
  String locationStaleMinutes(int minutes) {
    return 'Местоположение обновлено $minutes мин назад';
  }

  @override
  String locationRecentMinutes(int minutes) {
    return 'Местоположение обновлено $minutes мин назад';
  }

  @override
  String get locationJustNow => 'Местоположение: сейчас';

  @override
  String get onlineNow => 'в сети';

  @override
  String get offlineNow => 'не в сети';

  @override
  String get map => 'Карта';

  @override
  String get mapListView => 'Список';

  @override
  String get mapMapView => 'Карта';

  @override
  String get mapEmpty => 'Пока нет координат';

  @override
  String get mapOpenProfile => 'Открыть профиль';

  @override
  String get qrScan => 'Сканировать QR';

  @override
  String get qrScanHint => 'Наведите камеру на QR-код';

  @override
  String get qrInvalid => 'QR-код не найден или недоступен';

  @override
  String get qrWorkerFound => 'Мастерица найдена';

  @override
  String get qrKitFound => 'Комплект найден';

  @override
  String get showQr => 'Показать QR-код';

  @override
  String get workerQrTitle => 'Личный QR-код';

  @override
  String get inventory => 'Склад';

  @override
  String get materials => 'Материалы';

  @override
  String get materialsEmpty => 'Материалов пока нет';

  @override
  String get materialAdd => 'Новый материал';

  @override
  String get stockLow => 'мало';

  @override
  String get stockReceipt => 'Приход';

  @override
  String get stockReceiptHint => 'Поступление материала на склад';

  @override
  String get quantity => 'Количество';

  @override
  String get kits => 'Комплекты';

  @override
  String get kitsEmpty => 'Комплектов пока нет';

  @override
  String get kitAssemble => 'Собрать комплект';

  @override
  String get kitAssembled => 'Комплект собран, QR-код готов';

  @override
  String get kitCount => 'Количество комплектов';

  @override
  String get kitTemplateName => 'Название комплекта';

  @override
  String get kitAddMaterial => 'Материал';

  @override
  String get commentOptional => 'Комментарий (необязательно)';

  @override
  String get materialName => 'Название материала';

  @override
  String get materialMinStock => 'Минимальный остаток';

  @override
  String get workMeters9 => '9 м';

  @override
  String get workMeters18 => '18 м';

  @override
  String get workMeters27 => '27 м';

  @override
  String workDoneOf(String done, String planned) {
    return 'Готово $done из $planned м';
  }

  @override
  String get workDueDate => 'Срок';

  @override
  String get workExpectedEarning => 'Ожидаемая оплата';

  @override
  String get workMaterials => 'Материалы';

  @override
  String get workUpdateProgress => 'Обновить прогресс';

  @override
  String get workReady => 'Работа готова';

  @override
  String workReadyConfirm(String planned) {
    return 'Подтвердите: готово $planned м. После этого работу заберут.';
  }

  @override
  String get workProblem => 'Есть проблема';

  @override
  String get workMetersDone => 'Сколько метров готово';

  @override
  String get workStatusReadyToDeliver => 'Ожидает получения';

  @override
  String get workStatusDelivered => 'Получено мастерицей';

  @override
  String get workStatusInProgress => 'В работе';

  @override
  String get workStatusReadyForPickup => 'Готово, ждём забора';

  @override
  String get workStatusPickedUp => 'Забрано';

  @override
  String get workStatusUnderReview => 'На проверке';

  @override
  String get workCurrentTitle => 'Текущая работа';

  @override
  String get workNoCurrent => 'Сейчас нет активной работы';

  @override
  String get workNoCurrentHint =>
      'Как только вам назначат задание, оно появится здесь';

  @override
  String get workPickedUp => 'Забрал';

  @override
  String get insufficientStockGeneric => 'Не хватает материалов на складе';

  @override
  String get statusChangedMeanwhile =>
      'Это действие уже недоступно, потому что статус задания изменился.';

  @override
  String insufficientStockDetail(String material) {
    return 'Не хватает материала: $material';
  }

  @override
  String get back => 'Назад';

  @override
  String get next => 'Далее';

  @override
  String get assignCreateTitle => 'Подготовить работу';

  @override
  String get assignStepProduct => 'Модель';

  @override
  String get assignStepVariant => 'Цвет';

  @override
  String get assignStepVolume => 'Объём работы';

  @override
  String get assignStepDue => 'Срок';

  @override
  String get assignStepComment => 'Комментарий';

  @override
  String get assignStepSummary => 'Подтверждение';

  @override
  String get assignNoVariants =>
      'У этой модели ещё нет цветов. Сначала добавьте цвет в каталоге.';

  @override
  String get assignNoKitTemplate =>
      'Нет доступного комплекта материалов для этого варианта.';

  @override
  String get assignSelectWorker => 'Выберите мастерицу';

  @override
  String get assignSelectProduct => 'Выберите модель';

  @override
  String get assignSelectVariant => 'Выберите цвет';

  @override
  String get assignDueOptional => 'Срок (необязательно)';

  @override
  String get assignNoDueDate => 'Без срока';

  @override
  String get assignSummaryWorker => 'Мастерица';

  @override
  String get assignSummaryModel => 'Модель';

  @override
  String get assignSummaryColor => 'Цвет';

  @override
  String get assignSummaryVolume => 'Объём';

  @override
  String get assignSummaryMaterials => 'Материалы';

  @override
  String get assignSummaryDue => 'Срок';

  @override
  String get assignSummaryPayment => 'Расчётная оплата';

  @override
  String get assignSubmit => 'Подготовить работу';

  @override
  String get assignSuccess => 'Работа выдана';

  @override
  String get assignSuccessHint => 'Материалы списаны со склада, QR-код готов';

  @override
  String get assignEmptyProducts => 'В каталоге пока нет моделей';

  @override
  String get assignEmptyWorkers => 'Нет активных мастериц';

  @override
  String get assignmentDetailTitle => 'Задание';

  @override
  String get assignmentQr => 'QR-код задания';

  @override
  String get assignmentHistory => 'История';

  @override
  String get assignmentMaterialsIssued => 'Выданные материалы';

  @override
  String get deliveriesTitle => 'Доставка и забор';

  @override
  String get deliveryNeeded => 'Нужно доставить';

  @override
  String get deliveryConfirmTitle => 'Подтвердите доставку';

  @override
  String get deliveryConfirmBody => 'Материалы переданы мастерице?';

  @override
  String get deliveryDone => 'Начать передачу';

  @override
  String get pickupNeeded => 'Есть что забрать';

  @override
  String get dashboardTab => 'Обзор';

  @override
  String get dashActiveWorkers => 'Активные мастерицы';

  @override
  String get dashInProgress => 'В работе';

  @override
  String get dashNeedsAcceptance => 'На приёмке';

  @override
  String get dashOverdue => 'Просрочено';

  @override
  String get queueEmpty => 'Здесь пока пусто';

  @override
  String get dueBy => 'срок ';

  @override
  String get workersDueEmpty => 'Все выплаты закрыты';

  @override
  String get greetingMorning => 'Доброе утро';

  @override
  String get greetingDay => 'Добрый день';

  @override
  String get greetingEvening => 'Добрый вечер';

  @override
  String get dashProblems => 'Есть проблемы';

  @override
  String get dashAttention => 'Требует внимания';

  @override
  String get dashAllClear => 'Всё под контролем';

  @override
  String get dashToday => 'Сегодня';

  @override
  String get dashDueToday => 'Срок сегодня';

  @override
  String get dashDeliveredToday => 'Доставлено';

  @override
  String get dashPickedUpToday => 'Забрано';

  @override
  String get dashPaidToday => 'Выплачено';

  @override
  String get dashQuickActions => 'Быстрые действия';

  @override
  String get actionMap => 'Карта';

  @override
  String get actionStock => 'Склад';

  @override
  String get more => 'Ещё';

  @override
  String get managerLabel => 'Менеджер';

  @override
  String get noManager => 'Без менеджера';

  @override
  String get historyWork => 'Задания';

  @override
  String get historyMoney => 'Деньги';

  @override
  String get historyEmpty => 'Пока ничего не было';

  @override
  String attnOverdue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count просроченных работ',
      few: '$count просроченные работы',
      one: '$count просроченная работа',
    );
    return '$_temp0';
  }

  @override
  String attnToDeliver(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count доставок',
      few: '$count доставки',
      one: '$count доставка',
    );
    return '$_temp0';
  }

  @override
  String attnToPickup(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count работ готово',
      few: '$count работы готовы',
      one: '$count работа готова',
    );
    return '$_temp0';
  }

  @override
  String attnAcceptance(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count работ ждут приёмки',
      few: '$count работы ждут приёмки',
      one: '$count работа ждёт приёмки',
    );
    return '$_temp0';
  }

  @override
  String attnRework(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count работ на доработке',
      few: '$count работы на доработке',
      one: '$count работа на доработке',
    );
    return '$_temp0';
  }

  @override
  String attnWorkersDue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count мастериц ждут выплату',
      few: '$count мастерицы ждут выплату',
      one: '$count мастерица ждёт выплату',
    );
    return '$_temp0';
  }

  @override
  String get acceptanceTitle => 'Приёмка работы';

  @override
  String get acceptanceBrought => 'Принесено';

  @override
  String get acceptanceAccepted => 'Принято';

  @override
  String get acceptanceDefective => 'Брак';

  @override
  String get acceptanceRework => 'На доработку';

  @override
  String get acceptanceCalculated => 'Начисление';

  @override
  String get acceptanceSubmit => 'Принять работу';

  @override
  String get acceptanceSuccess => 'Работа принята';

  @override
  String get acceptanceInvalid =>
      'Принято + брак + доработка должно равняться принесено';

  @override
  String get acceptancePhotoOptional => 'Фото (необязательно)';

  @override
  String get payoutTitle => 'Выплатить наличными';

  @override
  String get payoutDue => 'К выплате';

  @override
  String get payoutFull => 'Вся сумма';

  @override
  String get payoutHalf => 'Половина';

  @override
  String get payoutAmountLabel => 'Сумма';

  @override
  String get payoutConfirmTitle => 'Подтвердите выплату';

  @override
  String payoutConfirmBody(String amount) {
    return 'Вы действительно выдали $amount наличными?';
  }

  @override
  String get payoutSubmit => 'Выплатить';

  @override
  String get payoutSuccess => 'Выплата записана';

  @override
  String get payoutNothingDue => 'К выплате: 0 сум';

  @override
  String get payoutExceedsBalance => 'Сумма больше, чем причитается мастерице';

  @override
  String get earningsEarned => 'Заработано';

  @override
  String get earningsPaid => 'Выплачено';

  @override
  String get earningsHistory => 'История';

  @override
  String get earningsEmpty => 'Пока нет начислений';

  @override
  String get actionAssign => 'Подготовить работу';

  @override
  String get actionScanQr => 'Сканировать QR';

  @override
  String get actionAccept => 'Принять работу';

  @override
  String get actionPayout => 'Выплатить наличными';

  @override
  String get actionCall => 'Позвонить';

  @override
  String get actionRoute => 'Маршрут';

  @override
  String get statusAccepted => 'Принято';

  @override
  String get statusPartiallyAccepted => 'Частично принято';

  @override
  String get statusReworkRequired => 'На доработку';

  @override
  String get statusCompleted => 'Завершено';

  @override
  String get statusCancelled => 'Отменено';

  @override
  String get teamSearch => 'Имя или телефон';

  @override
  String get filterAll => 'Все';

  @override
  String get filterActive => 'Активные';

  @override
  String get filterDisabled => 'Отключённые';

  @override
  String get lastSeenLabel => 'Был(а) в сети';

  @override
  String get createdLabel => 'Создан(а)';

  @override
  String get neverSeen => 'Ещё не входил(а)';

  @override
  String get changeRole => 'Изменить роль';

  @override
  String get changeRoleHint =>
      'После смены роли пользователь выйдет со всех устройств и войдёт заново уже с новыми правами.';

  @override
  String get roleSuperAdminHint => 'Всё, включая роли и права';

  @override
  String get roleAdminHint => 'Мастерицы, склад, выплаты, каталог';

  @override
  String get roleManagerHint => 'Только свои мастерицы';

  @override
  String get permissionsTitle => 'Права доступа';

  @override
  String get permissionsAllSuper =>
      'У главного администратора есть все права. Их нельзя ограничить.';

  @override
  String get permissionsSaved => 'Права сохранены';

  @override
  String get permissionsDefault => 'по умолчанию для роли';

  @override
  String permissionsCount(int on, int total) {
    return '$on из $total';
  }

  @override
  String get deactivateUser => 'Отключить пользователя';

  @override
  String deactivateConfirm(String name) {
    return 'Отключить $name? Вход будет запрещён сразу на всех устройствах. Вся история сохранится.';
  }

  @override
  String get restoreUser => 'Восстановить';

  @override
  String get userDeactivated => 'Пользователь отключён';

  @override
  String get userRestored => 'Пользователь восстановлен';

  @override
  String get resetPassword => 'Выдать новый пароль';

  @override
  String get resetPasswordConfirm =>
      'Старый пароль перестанет работать, пользователь выйдет со всех устройств.';

  @override
  String get tempPasswordTitle => 'Временный пароль';

  @override
  String get tempPasswordHint =>
      'Передайте пароль сотруднику лично. Он показывается только один раз.';

  @override
  String get copy => 'Копировать';

  @override
  String get copied => 'Скопировано';

  @override
  String get editDetails => 'Изменить данные';

  @override
  String get activeImmediately => 'Сразу активен';

  @override
  String get workersOfManager => 'Мастерицы менеджера';

  @override
  String get changeManager => 'Сменить менеджера';

  @override
  String get managerChanged => 'Менеджер изменён';

  @override
  String get archiveWorker => 'Архивировать мастерицу';

  @override
  String get archiveConfirm =>
      'Мастерица не сможет войти и не получит новую работу. История, выплаты и залог сохранятся.';

  @override
  String get workerArchived => 'Мастерица в архиве';

  @override
  String get restoreWorker => 'Восстановить мастерицу';

  @override
  String get workerRestored => 'Мастерица восстановлена';

  @override
  String get workersViaTelegram =>
      'Мастерицы регистрируются сами через Telegram-бота — здесь добавляются только сотрудники.';

  @override
  String get usersEmpty => 'Никого не найдено';

  @override
  String get youLabel => 'это вы';

  @override
  String get permGroupUsers => 'Пользователи';

  @override
  String get permGroupWorkers => 'Мастерицы';

  @override
  String get permGroupCollateral => 'Залог';

  @override
  String get permGroupAssignments => 'Задания';

  @override
  String get permGroupFinance => 'Выплаты и деньги';

  @override
  String get permGroupCatalog => 'Каталог';

  @override
  String get permGroupInventory => 'Склад';

  @override
  String get permGroupMap => 'Карта';

  @override
  String get permGroupSettings => 'Настройки';

  @override
  String get permGroupAudit => 'Журнал действий';

  @override
  String get permUserViewAll => 'Видеть сотрудников';

  @override
  String get permUserCreate => 'Добавлять сотрудников';

  @override
  String get permUserUpdate => 'Изменять данные сотрудников';

  @override
  String get permUserDeactivate => 'Отключать сотрудников';

  @override
  String get permRoleAssign => 'Менять роли';

  @override
  String get permPermissionManage => 'Настраивать права';

  @override
  String get permWorkerViewAll => 'Видеть всех мастериц';

  @override
  String get permWorkerViewAssigned => 'Видеть своих мастериц';

  @override
  String get permWorkerApprove => 'Одобрять заявки';

  @override
  String get permWorkerUpdate => 'Изменять карточку мастерицы';

  @override
  String get permWorkerAssignManager => 'Назначать менеджера';

  @override
  String get permCollateralView => 'Видеть залог';

  @override
  String get permCollateralManage => 'Принимать и возвращать залог';

  @override
  String get permAssignmentViewAll => 'Видеть все задания';

  @override
  String get permAssignmentViewAssigned => 'Видеть задания своих мастериц';

  @override
  String get permAssignmentCreate => 'Выдавать работу';

  @override
  String get permAssignmentAccept => 'Принимать работу';

  @override
  String get permFinanceViewAll => 'Видеть все начисления';

  @override
  String get permFinanceViewAssigned => 'Видеть начисления своих мастериц';

  @override
  String get permCashPayout => 'Выплачивать наличными';

  @override
  String get permProfitView => 'Видеть прибыль';

  @override
  String get permCatalogView => 'Видеть каталог';

  @override
  String get permCatalogManage => 'Изменять каталог';

  @override
  String get permInventoryView => 'Видеть склад';

  @override
  String get permInventoryManage => 'Приход и комплекты';

  @override
  String get permMapViewAll => 'Карта: все';

  @override
  String get permMapViewAssigned => 'Карта: свои мастерицы';

  @override
  String get permLiveLocationViewAll => 'Геолокация: все';

  @override
  String get permLiveLocationViewAssigned => 'Геолокация: свои мастерицы';

  @override
  String get permPayRateManage => 'Менять цену за 9 м';

  @override
  String get permSettingsManage => 'Настройки компании';

  @override
  String get permAuditView => 'Видеть журнал действий';

  @override
  String get auditUserCreate => 'Создан(а)';

  @override
  String get auditUserUpdate => 'Изменены данные';

  @override
  String get auditUserDeactivate => 'Отключён(а)';

  @override
  String get auditUserReactivate => 'Восстановлен(а)';

  @override
  String get auditUserRoleChange => 'Изменена роль';

  @override
  String get auditUserPermissionChange => 'Изменены права';

  @override
  String get auditUserPasswordReset => 'Выдан новый пароль';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get changePassword => 'Сменить пароль';

  @override
  String get currentPassword => 'Текущий пароль';

  @override
  String get newPassword => 'Новый пароль';

  @override
  String get repeatPassword => 'Новый пароль ещё раз';

  @override
  String get passwordsDontMatch => 'Пароли не совпадают';

  @override
  String get passwordTooShort => 'Не меньше 8 символов';

  @override
  String get wrongCurrentPassword => 'Текущий пароль неверный';

  @override
  String get passwordChanged =>
      'Пароль изменён. Другие устройства вышли из аккаунта.';

  @override
  String get setPassword => 'Задать пароль';

  @override
  String get setPasswordHint =>
      'Пользователь выйдет со всех устройств. Передайте пароль лично.';

  @override
  String get passwordSet => 'Пароль установлен';

  @override
  String get showOnMap => 'Показывать на карте';

  @override
  String get showOnMapHint => 'Видят все, кому разрешена карта';

  @override
  String get hiddenOnMapHint => 'Скрыт: позицию видите только вы';

  @override
  String locationUpdatedHours(int hours, int minutes) {
    return 'Местоположение обновлено $hours ч $minutes мин назад';
  }

  @override
  String locationUpdatedOn(String date) {
    return 'Местоположение от $date';
  }

  @override
  String get permPasswordSet => 'Задавать пароли сотрудникам';

  @override
  String get passwordForLogin => 'Пароль для входа';

  @override
  String get passwordForLoginHint => 'Придумайте сами и передайте лично';

  @override
  String get userCreated => 'Пользователь создан. Передайте ему пароль лично.';

  @override
  String get telegramLoginHint =>
      'Для мастериц — без пароля, через ваш Telegram';

  @override
  String get staffSignIn => 'Вход для сотрудников';

  @override
  String get workWaitingTitle => 'Вас ожидает новая работа';

  @override
  String get workKitReadyTitle => 'Ваш комплект готов к получению';

  @override
  String get workKitReadyHint =>
      'Отсканируйте QR-код на комплекте, который привёз сотрудник';

  @override
  String get workWaitingHint =>
      'Сотрудник привезёт комплект. Когда он отсканирует QR, здесь появится кнопка получения.';

  @override
  String get workScanQr => 'Сканировать QR';

  @override
  String get receiveTitle => 'Получение работы';

  @override
  String get receiveCheckHint =>
      'Проверьте работу и материалы перед подтверждением.';

  @override
  String get receiveConfirm => 'Подтвердить получение';

  @override
  String get receiveProblem => 'Есть проблема';

  @override
  String receiveKits(int count) {
    return 'Комплектов: $count';
  }

  @override
  String get receiveDone => 'Работа получена!';

  @override
  String get receiveDoneHint => 'Материалы теперь у вас. Удачной работы!';

  @override
  String get receiveAlready => 'Вы уже получили эту работу';

  @override
  String get receiveForeign => 'Этот комплект предназначен другой мастерице.';

  @override
  String get receiveNotStarted =>
      'Сначала сотрудник должен отсканировать этот QR';

  @override
  String get receiveExpired =>
      'Время передачи истекло. Попросите сотрудника отсканировать QR ещё раз.';

  @override
  String get receiveScanHint => 'Наведите камеру на QR-код комплекта';

  @override
  String get receiveGoHome => 'На главную';

  @override
  String get problemTitle => 'Что не так?';

  @override
  String get problemShortage => 'Не хватает материала';

  @override
  String get problemWrongColor => 'Неправильный цвет';

  @override
  String get problemWrongModel => 'Неправильная модель';

  @override
  String get problemWrongMeters => 'Неправильный метраж';

  @override
  String get problemDamaged => 'Повреждение';

  @override
  String get problemOther => 'Другое';

  @override
  String get problemComment => 'Комментарий (необязательно)';

  @override
  String get problemSend => 'Отправить';

  @override
  String get problemSent =>
      'Сотрудник получил ваше сообщение. Работа пока не передана.';

  @override
  String get handoffStart => 'Начать передачу';

  @override
  String get handoffStartTitle => 'Передать комплект мастерице?';

  @override
  String get handoffStartBody =>
      'После этого мастерица сама отсканирует этот QR в своём приложении и подтвердит получение. Материалы перейдут к ней только после её подтверждения.';

  @override
  String get handoffWaiting => 'Ожидаем подтверждения мастерицы';

  @override
  String get handoffWaitingHint =>
      'Попросите мастерицу открыть приложение и отсканировать этот QR';

  @override
  String get handoffWorkerScanned =>
      'Мастерица отсканировала QR и проверяет комплект';

  @override
  String handoffReceived(String name) {
    return '$name получила комплект';
  }

  @override
  String get handoffProblemTitle => 'Мастерица сообщила о проблеме';

  @override
  String get handoffRestart => 'Начать передачу снова';

  @override
  String get handoffExpiredLabel => 'Время передачи истекло';

  @override
  String timelineStarted(String name) {
    return 'Передача начата · $name';
  }

  @override
  String get timelineScanned => 'Мастерица отсканировала QR';

  @override
  String get timelineConfirmed => 'Мастерица подтвердила получение';

  @override
  String get timelineProblem => 'Мастерица сообщила о проблеме';

  @override
  String get handoffTimelineTitle => 'Передача';

  @override
  String get materialsAtWorker => 'Материалы у мастерицы';

  @override
  String get materialsPrepared => 'Подготовленные материалы';

  @override
  String get workRemaining => 'Осталось';

  @override
  String get addWorker => 'Добавить';

  @override
  String get addWorkerTitle => 'Добавить мастерицу';

  @override
  String get addWorkerHint =>
      'Мы дадим ссылку. Мастерица открывает её в Telegram — и сразу в команде, без анкеты и без одобрения.';

  @override
  String get addWorkerGetLink => 'Получить ссылку';

  @override
  String get addWorkerFullName => 'Фамилия и имя';

  @override
  String get addWorkerManager => 'Менеджер';

  @override
  String get addWorkerNoManager => 'Без менеджера';

  @override
  String get addWorkerLinkReady =>
      'Покажите QR мастерице — она наведёт камеру телефона. Или отправьте ссылку. Ссылка действует 7 дней и открывается один раз.';

  @override
  String get addWorkerSendTelegram => 'Отправить в Telegram';

  @override
  String get addWorkerCopy => 'Скопировать ссылку';

  @override
  String get addWorkerCopied => 'Ссылка скопирована';

  @override
  String get invitesPending => 'Приглашены — ещё не открыли ссылку';

  @override
  String get inviteCancel => 'Отменить';

  @override
  String get deleteWorker => 'Удалить мастерицу';

  @override
  String deleteWorkerConfirm(String name) {
    return '$name исчезнет из всех списков, с карты и из отчётов и больше не сможет войти. Прошлые работы и выплаты останутся в истории как «Удалённая мастерица». Это нельзя отменить.';
  }

  @override
  String get deleteWorkerForever => 'Удалить навсегда';

  @override
  String get deleteWorkerBlocked =>
      'Удалить нельзя: у мастерицы уже есть работа, деньги или принятый залог — эти записи нужны для отчётов и выплат. Её можно архивировать: она не сможет войти, а история сохранится.';

  @override
  String get deleteWorkerDone => 'Мастерица удалена';

  @override
  String get permWorkerDelete => 'Удалять мастериц';

  @override
  String get chooseWork => 'Выбрать работу';

  @override
  String get orderWork => 'Заказать эту работу';

  @override
  String get orderColor => 'Цвет';

  @override
  String get orderVolume => 'Сколько метров';

  @override
  String get orderNote => 'Пожелание (необязательно)';

  @override
  String get orderSend => 'Отправить заявку';

  @override
  String get orderSent => 'Заявка отправлена! Менеджер подготовит работу.';

  @override
  String get orderAlreadyPending =>
      'У вас уже есть заявка — дождитесь ответа или отмените её на главной.';

  @override
  String get myRequestPending => 'Заявка отправлена';

  @override
  String get myRequestPendingHint => 'Ждём ответа менеджера';

  @override
  String get myRequestRejected => 'Заявка не принята';

  @override
  String get myRequestCancel => 'Отменить заявку';

  @override
  String get jobRequestsTitle => 'Заявки на работу';

  @override
  String get jobRequestsEmpty => 'Новых заявок нет';

  @override
  String jobRequestsCount(int count) {
    return 'Заявки на работу: $count';
  }

  @override
  String get jobRequestRejectReason => 'Причина (мастерица её увидит)';

  @override
  String updateReady(String version) {
    return 'Новая версия $version готова';
  }

  @override
  String get updateInstall => 'Установить';

  @override
  String get updateAllowInstall =>
      'Разрешите установку для Diamoraa и нажмите ещё раз';

  @override
  String get ageNow => 'сейчас';

  @override
  String ageMinutes(int minutes) {
    return '$minutes мин назад';
  }

  @override
  String ageHours(int hours, int minutes) {
    return '$hours ч $minutes мин назад';
  }

  @override
  String get qrRecognized => 'QR распознан';

  @override
  String get handoffStartedToast =>
      'Передача начата — пусть мастерица отсканирует этот QR';

  @override
  String get qrPrint => 'Печать QR';

  @override
  String get noticesTitle => 'Уведомления';

  @override
  String get noticesReadAll => 'Прочитать все';

  @override
  String get noticesEmpty => 'Пока уведомлений нет';

  @override
  String get reportsTitle => 'Отчёты';

  @override
  String get reportDay => 'День';

  @override
  String get reportWeek => 'Неделя';

  @override
  String get reportMonth => 'Месяц';

  @override
  String get reportIssued => 'Выдано';

  @override
  String get reportAccepted => 'Принято';

  @override
  String get reportOverdue => 'Просрочено';

  @override
  String get reportDefective => 'Брак';

  @override
  String get reportByWorker => 'По мастерицам';

  @override
  String get reportEmpty => 'За этот период ничего не было';

  @override
  String get reportLowStock => 'Заканчивается на складе';

  @override
  String get reportExcelHint =>
      'Выгрузка в Excel — в веб-панели: Отчёты → «Скачать для Excel».';

  @override
  String get myMonthsTitle => 'Мои заработки по месяцам';

  @override
  String get m1 => 'Январь';

  @override
  String get m2 => 'Февраль';

  @override
  String get m3 => 'Март';

  @override
  String get m4 => 'Апрель';

  @override
  String get m5 => 'Май';

  @override
  String get m6 => 'Июнь';

  @override
  String get m7 => 'Июль';

  @override
  String get m8 => 'Август';

  @override
  String get m9 => 'Сентябрь';

  @override
  String get m10 => 'Октябрь';

  @override
  String get m11 => 'Ноябрь';

  @override
  String get m12 => 'Декабрь';

  @override
  String get qaAssign => 'Работа';

  @override
  String get qaScan => 'QR';

  @override
  String get qaMap => 'Карта';

  @override
  String get qaStock => 'Склад';

  @override
  String get qaPay => 'Выплата';

  @override
  String get assignCancel => 'Отменить работу';

  @override
  String get assignCancelReason => 'Причина';

  @override
  String get assignCancelReturned => 'Материалы вернулись на склад';

  @override
  String get assignCancelled => 'Работа отменена';

  @override
  String get assignChangeDue => 'Изменить срок';

  @override
  String get userDelete => 'Удалить сотрудника';

  @override
  String userDeleteConfirm(String name) {
    return '$name будет удалён(а) навсегда.';
  }

  @override
  String get userDeleteBlocked =>
      'Удалить нельзя: за сотрудником есть история (работы, выплаты, склад). Его можно отключить.';

  @override
  String get userDeleted => 'Сотрудник удалён';

  @override
  String get qrNotYours =>
      'Эта мастерица закреплена за другим менеджером. Попросите администратора закрепить её за вами.';

  @override
  String get qrRevoked =>
      'Этот QR больше не действует: работа завершена или отменена, либо мастерица удалена.';

  @override
  String get errOpenWork =>
      'Сначала завершите или отмените её работы и верните залог — потом можно удалить.';

  @override
  String get errInUse =>
      'Материал сейчас используется: он у мастерицы или в комплекте. Сначала уберите его оттуда.';

  @override
  String errInUseKits(String kits) {
    return 'Материал есть в комплектах: $kits. Сначала удалите или измените эти комплекты.';
  }

  @override
  String get deleteAction => 'Удалить';

  @override
  String get deleteDone => 'Удалено';

  @override
  String catalogDeleteConfirm(String name) {
    return '«$name» исчезнет из каталога у всех. Уже выданные работы останутся в истории. Это нельзя отменить.';
  }

  @override
  String materialDeleteConfirm(String name, String left) {
    return '«$name» исчезнет со склада. Остаток ($left) будет списан. Это нельзя отменить.';
  }

  @override
  String kitDeleteConfirm(String name) {
    return 'Комплект «$name» исчезнет со склада. Уже выданные работы останутся в истории. Это нельзя отменить.';
  }

  @override
  String get permCatalogDelete => 'Удалять из каталога';

  @override
  String get permInventoryDelete => 'Удалять материалы и комплекты';

  @override
  String get assignManagerTitle => 'Назначить менеджера';

  @override
  String get assignManagerSave => 'Назначить';

  @override
  String assignManagerDone(int count) {
    return 'Готово: $count мастериц';
  }

  @override
  String get assignWorkersToManager => 'Назначить мастериц';

  @override
  String get auditClear => 'Очистить журнал';

  @override
  String get auditClearConfirm =>
      'Журнал начнётся с чистого листа — первой строкой будет «Журнал очищен» с вашим именем. Старые записи здесь больше не показываются, но из базы не стираются (так никто не может скрыть свои действия).';

  @override
  String get collateralsTitle => 'Залоги';

  @override
  String get collateralsWithUs => 'Сейчас у нас';

  @override
  String collateralsItems(int count) {
    return '$count вещей';
  }

  @override
  String get collateralsTabHeld => 'У нас';

  @override
  String get collateralsTabPending => 'Не получены';

  @override
  String get collateralsTabReturned => 'Возвращены';

  @override
  String get collateralsEmpty => 'Здесь пусто';

  @override
  String get collateralReturnTitle => 'Вернуть залог';

  @override
  String get collateralReturnNote => 'Как вернули';

  @override
  String get collateralReturnConfirm => 'Мастерица получила залог обратно';

  @override
  String get collateralReturnedToast => 'Залог возвращён';

  @override
  String get mapFilterAll => 'Все';

  @override
  String get mapFilterToDeliver => 'Ждут доставку';

  @override
  String get mapFilterToPickup => 'Готово к забору';

  @override
  String get mapFilterOverdue => 'Просрочено';

  @override
  String get mapFilterAllManagers => 'Все менеджеры';

  @override
  String get mapAtHome =>
      'Дома — адрес при регистрации (телефон сейчас не передаёт геопозицию)';

  @override
  String get ratingTitle => 'Рейтинг мастериц';

  @override
  String get ratingThreeMonths => '3 месяца';

  @override
  String get ratingHalfYear => 'Полгода';

  @override
  String ratingLine(String meters, String defect, int late, int total) {
    return '$meters м · брак $defect% · опоздала $late из $total';
  }

  @override
  String get ratingHowScored =>
      'Балл из 100: 40% — объём (≈54 м в месяц = максимум), 35% — без брака, 25% — вовремя.';

  @override
  String get profitTitle => 'Прибыль';

  @override
  String get profitAdd => 'Продажа или расход';

  @override
  String get profitSale => 'Продажа';

  @override
  String get profitExpense => 'Расход';

  @override
  String get profitSales => 'Продажи';

  @override
  String get profitLabor => 'Мастерицам';

  @override
  String get profitMaterials => 'Материалы';

  @override
  String get profitExpenses => 'Расходы';

  @override
  String get profitCustomer => 'Покупатель (необязательно)';

  @override
  String get profitNoPriceHint =>
      '* У части материалов не указана цена закупки — они не посчитаны. Укажите цену в веб-панели на складе.';

  @override
  String get profitDeleteConfirm =>
      'Удалить эту запись? Прибыль за месяц пересчитается.';

  @override
  String get expenseFuel => 'Бензин / доставка';

  @override
  String get expensePackaging => 'Упаковка';

  @override
  String get expenseOther => 'Другое';

  @override
  String get stockValueTitle => 'Стоимость склада (по цене закупки)';

  @override
  String stockValueSplit(String shelf, String homes) {
    return 'на складе $shelf · у мастериц $homes';
  }

  @override
  String stockValueNoPrice(String names) {
    return 'Без цены: $names';
  }

  @override
  String get systemTitle => 'Состояние системы';

  @override
  String get systemServer => 'Сервер';

  @override
  String get systemDatabase => 'База данных';

  @override
  String systemUptime(int hours) {
    return 'работает $hours ч';
  }

  @override
  String get systemOk => 'в порядке';

  @override
  String get systemDown => 'не отвечает';

  @override
  String get systemBackups => 'Резервные копии';

  @override
  String get systemBackupsHidden =>
      'Сервер не видит папку с отметками резервных копий.';

  @override
  String get systemBackupFailed => 'ошибка';

  @override
  String get systemBackupLate => 'давно не было';

  @override
  String get backupDaily => 'База данных (каждый день)';

  @override
  String get backupWeekly => 'Полная копия базы (раз в неделю)';

  @override
  String get backupFiles => 'Фото и файлы';

  @override
  String get backupConfig => 'Настройки';

  @override
  String get backupVerify => 'Проверка восстановления';

  @override
  String get backupRestore => 'Восстановление';

  @override
  String get editName => 'Изменить имя';

  @override
  String get firstName => 'Имя';

  @override
  String get lastName => 'Фамилия';

  @override
  String get nameSaved => 'Имя сохранено';

  @override
  String get nameTooShort => 'Имя — не меньше 2 букв';

  @override
  String get chat => 'Чат';

  @override
  String get chatCompany => 'Общий чат';

  @override
  String get chatNew => 'Новый чат';

  @override
  String get chatNewGroup => 'Новая группа';

  @override
  String get chatGroupName => 'Название группы';

  @override
  String chatMembers(int count) {
    return 'Участников: $count';
  }

  @override
  String get chatSearchPeople => 'Поиск по имени';

  @override
  String get chatEmpty => 'Сообщений пока нет — напишите первым';

  @override
  String get chatNoChats => 'Здесь будут ваши переписки';

  @override
  String get chatTypeMessage => 'Сообщение';

  @override
  String get chatPhoto => 'Фото';

  @override
  String get chatCamera => 'Камера';

  @override
  String get chatVideo => 'Видео';

  @override
  String get chatRecordVideo => 'Снять видео';

  @override
  String get chatFile => 'Файл';

  @override
  String get chatVoice => 'Голосовое сообщение';

  @override
  String get chatAudio => 'Аудио';

  @override
  String get chatHoldToRecord => 'Удерживайте кнопку микрофона, чтобы записать';

  @override
  String get chatRecording => 'Запись… отпустите — отправится';

  @override
  String get chatMessageDeleted => 'Сообщение удалено';

  @override
  String get chatDeleteMessage => 'Удалить сообщение';

  @override
  String get chatDeleteMessageBody => 'Сообщение исчезнет у всех участников.';

  @override
  String get chatCopy => 'Копировать';

  @override
  String get chatCopied => 'Скопировано';

  @override
  String get chatFileTooLarge => 'Файл больше 50 МБ — его нельзя отправить';

  @override
  String chatSendingProgress(int percent) {
    return 'Отправка… $percent%';
  }

  @override
  String get chatSendFailed => 'Не отправлено — нажмите, чтобы повторить';

  @override
  String get chatRead => 'Прочитано';

  @override
  String get chatLeaveGroup => 'Выйти из группы';

  @override
  String get chatLeaveGroupBody =>
      'Вы больше не будете видеть сообщения этой группы.';

  @override
  String get chatAddMembers => 'Добавить участников';

  @override
  String get chatRemoveMember => 'Убрать из группы';

  @override
  String get chatRename => 'Переименовать';

  @override
  String get chatOwner => 'создатель';

  @override
  String get chatMicPermission =>
      'Разрешите доступ к микрофону, чтобы записывать голосовые';

  @override
  String get chatYou => 'Вы';

  @override
  String get chatDownloading => 'Загрузка…';

  @override
  String get chatFileFailed => 'Не удалось загрузить файл';

  @override
  String get chatCreate => 'Создать';

  @override
  String get chatGroupInfo => 'О группе';

  @override
  String get chatToday => 'Сегодня';

  @override
  String get chatYesterday => 'Вчера';

  @override
  String get chatCompanyHint => 'Все сотрудники и мастерицы';

  @override
  String get chatAttach => 'Прикрепить';

  @override
  String get chatSend => 'Отправить';

  @override
  String get chatReply => 'Ответить';

  @override
  String get chatEdit => 'Изменить';

  @override
  String get chatEdited => 'изменено';

  @override
  String get chatEditing => 'Редактирование';

  @override
  String get chatForward => 'Переслать';

  @override
  String get chatForwardTo => 'Переслать в…';

  @override
  String get chatForwarded => 'Переслано';

  @override
  String chatForwardedFrom(String name) {
    return 'Переслано от $name';
  }

  @override
  String get chatPin => 'Закрепить';

  @override
  String get chatUnpin => 'Открепить';

  @override
  String get chatPinned => 'Закреплённое сообщение';

  @override
  String get chatPinChat => 'Закрепить чат';

  @override
  String get chatUnpinChat => 'Открепить чат';

  @override
  String get chatMute => 'Без уведомлений';

  @override
  String get chatUnmute => 'Включить уведомления';

  @override
  String get chatSearch => 'Поиск';

  @override
  String get chatSearchHint => 'Чаты, люди, сообщения';

  @override
  String get chatSectionChats => 'Чаты';

  @override
  String get chatSectionPeople => 'Люди';

  @override
  String get chatSectionMessages => 'Сообщения';

  @override
  String get chatNothingFound => 'Ничего не найдено';

  @override
  String get chatTyping => 'печатает…';

  @override
  String chatTypingName(String name) {
    return '$name печатает…';
  }

  @override
  String get chatRecordingVoice => 'записывает голосовое…';

  @override
  String chatRecordingVoiceName(String name) {
    return '$name записывает голосовое…';
  }

  @override
  String chatLastSeen(String time) {
    return 'был(а) в сети $time';
  }

  @override
  String chatReplyTo(String name) {
    return 'Ответ: $name';
  }

  @override
  String get chatEmoji => 'Эмодзи';

  @override
  String get chatNewChannel => 'Новый канал';

  @override
  String get chatChannelName => 'Название канала';

  @override
  String get chatDescription => 'Описание';

  @override
  String get chatAudience => 'Кто читает';

  @override
  String get chatAudienceAll => 'Все сотрудники и мастерицы';

  @override
  String get chatAudienceStaff => 'Только сотрудники';

  @override
  String get chatAudienceWorkers => 'Только мастерицы';

  @override
  String get chatAudienceCustom => 'Выбранные люди';

  @override
  String chatChoosePeople(int count) {
    return 'Выбрать людей ($count)';
  }

  @override
  String get chatChannelHint =>
      'Публикуют только администраторы канала; читатели видят объявления и получают уведомления.';

  @override
  String get chatChannelReadOnly =>
      'Это канал: публикуют только его администраторы';

  @override
  String get chatGroupReadOnly => 'Писать могут только администраторы группы';

  @override
  String get chatOnlyAdminsWrite => 'Писать могут только администраторы';

  @override
  String get chatMakeAdmin => 'Сделать администратором';

  @override
  String get chatRemoveAdmin => 'Снять администратора';

  @override
  String get chatAddAdmin => 'Добавить администратора';

  @override
  String get chatAdmin => 'администратор';

  @override
  String get chatChangePhoto => 'Сменить фото';

  @override
  String get chatInfo => 'Информация о чате';

  @override
  String get chatChannelInfo => 'О канале';

  @override
  String get chatTabMembers => 'Участники';

  @override
  String get chatTabMedia => 'Медиа';

  @override
  String get chatTabFiles => 'Файлы';

  @override
  String get chatTabVoice => 'Голосовые';

  @override
  String get chatTabLinks => 'Ссылки';

  @override
  String get chatNothingYet => 'Пока ничего нет';

  @override
  String chatSubscribers(int count) {
    return 'Канал · подписчиков: $count';
  }

  @override
  String get chatLeaveChannel => 'Выйти из канала';

  @override
  String get chatVideoTooLarge => 'Видео больше 150 МБ — его нельзя отправить';

  @override
  String get chatMyProfile => 'Мой профиль';

  @override
  String get chatBio => 'О себе';

  @override
  String get chatBioHint =>
      'Любые подробности, например: должность, район или график работы.';

  @override
  String get chatUsername => 'Имя пользователя';

  @override
  String get chatUsernameHint =>
      'Латиница, цифры и _, от 5 символов. По нему вас найдут в чате.';

  @override
  String get chatUsernameTaken => 'Это имя пользователя уже занято';

  @override
  String get chatPhone => 'Телефон';

  @override
  String get chatRole => 'Роль';

  @override
  String get chatChangeAvatar => 'Сменить фото профиля';

  @override
  String get chatRemoveAvatar => 'Удалить фото';

  @override
  String chatReadAt(String time) {
    return 'прочитано в $time';
  }

  @override
  String get chatNotReadYet => 'ещё не прочитано';

  @override
  String get chatWhoRead => 'Кто прочитал';

  @override
  String get chatNobodyYet => 'Пока никто';

  @override
  String get chatClearHistory => 'Очистить историю';

  @override
  String get chatClearHistoryBody => 'Сообщения исчезнут только у вас.';

  @override
  String get chatDeleteChat => 'Удалить чат';

  @override
  String get chatDeleteChatBody => 'Переписка исчезнет только у вас.';

  @override
  String get chatProtectOn => 'Запретить копирование';

  @override
  String get chatProtectOff => 'Разрешить копирование';

  @override
  String get chatProtected => 'Копирование и пересылка в этом чате запрещены';

  @override
  String get chatExport => 'Экспорт истории чата';

  @override
  String get chatSearchInChat => 'Поиск в этом чате';

  @override
  String get chatOlderMessage => 'Это сообщение выше — прокрутите вверх';

  @override
  String get chatCancelUpload => 'Отменить отправку';

  @override
  String chatCountPhotos(int count) {
    return 'Фото: $count';
  }

  @override
  String chatCountVideos(int count) {
    return 'Видео: $count';
  }

  @override
  String chatCountFiles(int count) {
    return 'Файлы: $count';
  }

  @override
  String chatCountVoice(int count) {
    return 'Голосовые: $count';
  }

  @override
  String chatCountLinks(int count) {
    return 'Ссылки: $count';
  }

  @override
  String get chatShowProfile => 'Показать профиль';

  @override
  String chatTodayAt(String time) {
    return 'сегодня в $time';
  }

  @override
  String chatYesterdayAt(String time) {
    return 'вчера в $time';
  }

  @override
  String chatDateAt(String date, String time) {
    return '$date в $time';
  }

  @override
  String get chatAudioPrev => 'Предыдущее';

  @override
  String get chatAudioNext => 'Следующее';

  @override
  String get chatAudioPlay => 'Слушать';

  @override
  String get chatAudioPause => 'Пауза';

  @override
  String get chatAudioSpeed => 'Скорость';

  @override
  String get chatAudioMute => 'Звук';

  @override
  String get chatAudioClose => 'Закрыть проигрыватель';
}
