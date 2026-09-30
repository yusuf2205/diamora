// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Uzbek (`uz`).
class AppLocalizationsUz extends AppLocalizations {
  AppLocalizationsUz([String locale = 'uz']) : super(locale);

  @override
  String get appTitle => 'Diamoraa';

  @override
  String get welcomeTitle => 'Xush kelibsiz';

  @override
  String get phone => 'Telefon';

  @override
  String get password => 'Parol';

  @override
  String get signIn => 'Kirish';

  @override
  String get signOut => 'Chiqish';

  @override
  String get continueAction => 'Davom etish';

  @override
  String get signInWithTelegram => 'Telegram orqali kirish';

  @override
  String get orDivider => 'yoki';

  @override
  String get openingTelegram => 'Telegram ochilmoqda…';

  @override
  String get telegramLoginFailed =>
      'Telegramni ochib bo\'lmadi. Qayta urinib ko\'ring.';

  @override
  String get workersUseTelegram =>
      'Ustalar Telegram orqali kiradi — pastdagi tugmani bosing.';

  @override
  String get pendingApprovalTitle => 'Ariza yuborildi';

  @override
  String get pendingApprovalBody =>
      'Administrator tasdiqlashini kuting. Qaror tayyor bo\'lishi bilan Telegramga yozamiz.';

  @override
  String get rejectedTitle => 'Ariza rad etildi';

  @override
  String get workerPausedTitle => 'Profil to\'xtatilgan';

  @override
  String get workerPausedBody => 'Administratorga murojaat qiling.';

  @override
  String get backToLogin => 'Kirish ekraniga';

  @override
  String get checkAgainInTelegram => 'Telegram orqali qayta urinish';

  @override
  String get invalidCredentials => 'Telefon yoki parol noto\'g\'ri';

  @override
  String get invalidCode => 'Kod noto\'g\'ri yoki muddati o\'tgan';

  @override
  String get tooManyAttempts => 'Juda ko\'p urinish. Keyinroq urinib ko\'ring.';

  @override
  String get noConnection =>
      'Serverga ulanib bo\'lmadi. Internetni tekshiring.';

  @override
  String get genericError => 'Xatolik yuz berdi';

  @override
  String get checkYourInput => 'Kiritilgan ma\'lumotlarni tekshiring';

  @override
  String get phoneRequired => 'Telefon raqamini kiriting';

  @override
  String get invalidPhoneFormat => 'To\'g\'ri telefon raqamini kiriting';

  @override
  String get userNotFound =>
      'Bu raqamli foydalanuvchi topilmadi. Administratorga murojaat qiling.';

  @override
  String get accountDisabled =>
      'Hisobingiz faol emas. Administratorga murojaat qiling.';

  @override
  String get retry => 'Qayta urinish';

  @override
  String get cancel => 'Bekor qilish';

  @override
  String get confirm => 'Tasdiqlash';

  @override
  String get offlineBanner =>
      'Internet yo\'q — saqlangan ma\'lumotlar ko\'rsatilmoqda';

  @override
  String get workers => 'Ustalar';

  @override
  String get profile => 'Profil';

  @override
  String get home => 'Asosiy';

  @override
  String get search => 'Qidiruv: ism, telefon';

  @override
  String get tabPending => 'Arizalar';

  @override
  String get tabActive => 'Faol';

  @override
  String get tabAll => 'Hammasi';

  @override
  String get emptyPending => 'Yangi arizalar yo\'q';

  @override
  String get emptyPendingHint =>
      'Usta Telegramda ro\'yxatdan o\'tganda ariza shu yerda darhol paydo bo\'ladi';

  @override
  String get emptyWorkers => 'Bu yerda hozircha hech kim yo\'q';

  @override
  String newRegistration(String name) {
    return 'Yangi ariza: $name';
  }

  @override
  String get statusPending => 'Ko\'rib chiqilmoqda';

  @override
  String get statusActive => 'Faol';

  @override
  String get statusPaused => 'To\'xtatilgan';

  @override
  String get statusRejected => 'Rad etilgan';

  @override
  String get statusArchived => 'Arxivda';

  @override
  String get call => 'Qo\'ng\'iroq qilish';

  @override
  String get route => 'Marshrut qurish';

  @override
  String get location => 'Joylashuv';

  @override
  String get noLocation => 'Joylashuv olinmagan';

  @override
  String get secondaryPhone => 'Qo\'shimcha telefon';

  @override
  String get notes => 'Izohlar';

  @override
  String get collateral => 'Garov';

  @override
  String get collateralMoney => 'Pul';

  @override
  String get collateralItem => 'Buyum';

  @override
  String get collateralPending => 'E\'lon qilingan, hali qabul qilinmagan';

  @override
  String get collateralHeld => 'Bizda saqlanmoqda';

  @override
  String get collateralReturned => 'Qaytarilgan';

  @override
  String get receiveCollateral => 'Garovni qabul qilish';

  @override
  String get receivedNote => 'Izoh (ixtiyoriy)';

  @override
  String get estimatedValue => 'Baholangan qiymat, so\'m';

  @override
  String get storageLocation => 'Saqlanadigan joy';

  @override
  String get history => 'Tarix';

  @override
  String get approve => 'Tasdiqlash';

  @override
  String get reject => 'Rad etish';

  @override
  String get approveTitle => 'Ustani tasdiqlaysizmi?';

  @override
  String get collateralReceivedCheck => 'Garov jismonan qabul qilindi';

  @override
  String get rejectTitle => 'Arizani rad etish';

  @override
  String get rejectReason => 'Sabab (usta ko\'radi)';

  @override
  String get required => 'Majburiy maydon';

  @override
  String get approvedDone =>
      'Usta tasdiqlandi. Unga Telegramda xabar yuborildi.';

  @override
  String get rejectedDone => 'Ariza rad etildi';

  @override
  String get myStatusPending => 'Arizangiz ko\'rib chiqilmoqda';

  @override
  String get myStatusActive => 'Siz jamoadasiz ✨';

  @override
  String get balanceToReceive => 'Olinadigan summa';

  @override
  String get devices => 'Qurilmalar';

  @override
  String get thisDevice => 'shu qurilma';

  @override
  String get revoke => 'Seansni tugatish';

  @override
  String get logoutAll => 'Barcha qurilmalardan chiqish';

  @override
  String get language => 'Til';

  @override
  String get currency => 'so\'m';

  @override
  String get save => 'Saqlash';

  @override
  String get payRateTitle => '9 m uchun narx';

  @override
  String payRateSubtitle(int meters) {
    return 'Bitta $meters m to\'plam uchun to\'lov';
  }

  @override
  String get payRateAppliesToAll =>
      'Narx hamma uchun bitta. Uni o\'zgartirsangiz, barcha ustalarda darhol o\'zgaradi. Qabul qilingan ish qayta hisoblanmaydi.';

  @override
  String get payRateChange => 'Narxni o\'zgartirish';

  @override
  String payRateNew(int meters) {
    return '$meters m uchun yangi narx';
  }

  @override
  String get payRateInvalid => '1 dan 10 000 000 gacha summa kiriting';

  @override
  String payRateSaved(String amount) {
    return 'Narx yangilandi: $amount so\'m';
  }

  @override
  String get payRateHistory => 'Narx tarixi';

  @override
  String get payRateStart => 'boshlang\'ich';

  @override
  String payRatePerKit(int meters) {
    return '$meters metr uchun to\'lov';
  }

  @override
  String get locationServicesOffTitle => 'Geolokatsiyani yoqing';

  @override
  String get locationServicesOffBody =>
      'Geolokatsiyasiz ilova ish qayerda ekanini ko\'rsata olmaydi. Uni telefon sozlamalarida yoqing.';

  @override
  String get locationForegroundTitle => 'Geolokatsiyaga ruxsat bering';

  @override
  String get locationForegroundBody =>
      'Ilova ochiq turganda joylashuvingiz kerak, shunda administrator uni ko\'rib turadi.';

  @override
  String get locationBackgroundTitle => 'Fonda geolokatsiyaga ruxsat bering';

  @override
  String get locationBackgroundBody =>
      'Ilova yopiq bo\'lganda ham joylashuv aniq bo\'lishi uchun \"Doim\" ruxsatini bering.';

  @override
  String get locationDeniedForeverBody =>
      'Ruxsat rad etildi. Ilova sozlamalarini oching va geolokatsiyaga qo\'lda ruxsat bering.';

  @override
  String get locationOpenSettings => 'Geolokatsiya sozlamalarini ochish';

  @override
  String get locationAllow => 'Ruxsat berish';

  @override
  String get locationOpenAppSettings => 'Ilova sozlamalarini ochish';

  @override
  String get catalog => 'Bizning ishlarimiz';

  @override
  String get catalogEmpty => 'Hozircha hech narsa e\'lon qilinmagan';

  @override
  String get catalogEmptyHint =>
      'Administrator e\'lon qilishi bilan yangi ishlar shu yerda paydo bo\'ladi';

  @override
  String get catalogNew => 'Yangi';

  @override
  String get catalogCall => 'Qo\'ng\'iroq qilish';

  @override
  String get catalogTelegram => 'Telegramga yozish';

  @override
  String get catalogAvailable => 'Mavjud';

  @override
  String get catalogOnRequest => 'Buyurtma bilan';

  @override
  String get catalogUnavailable => 'Hozircha yo\'q';

  @override
  String get catalogAdminTitle => 'Ishlar katalogi';

  @override
  String get catalogAddItem => 'Ish qo\'shish';

  @override
  String get catalogItemName => 'Nomi';

  @override
  String get catalogItemDescription => 'Tavsif';

  @override
  String get catalogStatusDraft => 'Qoralama';

  @override
  String get catalogStatusPublished => 'E\'lon qilingan';

  @override
  String get catalogStatusHidden => 'Yashirilgan';

  @override
  String get catalogPublish => 'E\'lon qilish';

  @override
  String get catalogHide => 'Yashirish';

  @override
  String get catalogAddPhoto => 'Rasm qo\'shish';

  @override
  String get catalogMarkNew => 'Yangi deb belgilash';

  @override
  String get catalogPublishNeedsPhoto =>
      'E\'lon qilishdan oldin kamida bitta rasm qo\'shing';

  @override
  String get catalogDeleteBlocked =>
      'Bu ish allaqachon ishlatilgan — faqat yashirish mumkin';

  @override
  String get catalogSaved => 'Saqlandi';

  @override
  String get team => 'Jamoa';

  @override
  String get teamUsers => 'Foydalanuvchilar';

  @override
  String get teamManagers => 'Menejerlar';

  @override
  String get teamAddUser => 'Foydalanuvchi qo\'shish';

  @override
  String get teamFullName => 'F.I.Sh.';

  @override
  String get teamRole => 'Rol';

  @override
  String get roleSuperAdmin => 'Bosh administrator';

  @override
  String get roleAdmin => 'Administrator';

  @override
  String get roleManager => 'Menejer';

  @override
  String get roleWorker => 'Usta';

  @override
  String get teamStatusActive => 'Faol';

  @override
  String get teamStatusSuspended => 'O\'chirilgan';

  @override
  String get teamDeactivate => 'O\'chirish';

  @override
  String get teamReactivate => 'Yoqish';

  @override
  String get teamNoAccess => 'Jamoani ko\'rish uchun huquq yetarli emas';

  @override
  String get teamCreated =>
      'Foydalanuvchi yaratildi. Parol bir marta ko\'rsatiladi:';

  @override
  String teamAssignedWorkers(int count) {
    return 'Ustalar: $count';
  }

  @override
  String get teamEditUser => 'Foydalanuvchi';

  @override
  String get teamSaveChanges => 'Saqlash';

  @override
  String get teamPhoneTaken => 'Bu raqam boshqa foydalanuvchida band';

  @override
  String teamConfirmRoleChange(String from, String to) {
    return 'Rolni $from dan $to ga o\'zgartirasizmi?';
  }

  @override
  String get teamRoleChanged => 'Rol o\'zgartirildi';

  @override
  String get teamSaved => 'O\'zgarishlar saqlandi';

  @override
  String get settingsCompanyContact => 'Kompaniya telefoni va Telegram';

  @override
  String get settingsPhone => 'Kompaniya telefoni';

  @override
  String get settingsTelegram => 'Telegram (@ siz)';

  @override
  String get settingsCompanyContactHint =>
      'Bu ma\'lumotlarni ustalar katalogda \"Qo\'ng\'iroq qilish\" va \"Telegramga yozish\" tugmalarida ko\'radi';

  @override
  String get audit => 'Amallar jurnali';

  @override
  String get auditEmpty => 'Hozircha yozuvlar yo\'q';

  @override
  String get locations => 'Jamoa geolokatsiyasi';

  @override
  String get locationsEmpty => 'Joylashuv ma\'lumotlari hali yo\'q';

  @override
  String locationStaleMinutes(int minutes) {
    return 'Joylashuv $minutes daqiqa oldin yangilangan';
  }

  @override
  String locationRecentMinutes(int minutes) {
    return 'Joylashuv $minutes daqiqa oldin yangilangan';
  }

  @override
  String get locationJustNow => 'Joylashuv: hozir';

  @override
  String get onlineNow => 'onlayn';

  @override
  String get offlineNow => 'oflayn';

  @override
  String get map => 'Xarita';

  @override
  String get mapListView => 'Roʻyxat';

  @override
  String get mapMapView => 'Xarita';

  @override
  String get mapEmpty => 'Hozircha koordinata yo\'q';

  @override
  String get mapOpenProfile => 'Profilni ochish';

  @override
  String get qrScan => 'QR skanerlash';

  @override
  String get qrScanHint => 'Kamerani QR-kodga qarating';

  @override
  String get qrInvalid => 'QR-kod topilmadi yoki mavjud emas';

  @override
  String get qrWorkerFound => 'Usta topildi';

  @override
  String get qrKitFound => 'Toʻplam topildi';

  @override
  String get showQr => 'QR-kodni koʻrsatish';

  @override
  String get workerQrTitle => 'Shaxsiy QR-kod';

  @override
  String get inventory => 'Ombor';

  @override
  String get materials => 'Materiallar';

  @override
  String get materialsEmpty => 'Hozircha material yoʻq';

  @override
  String get materialAdd => 'Yangi material';

  @override
  String get stockLow => 'kam';

  @override
  String get stockReceipt => 'Kirim';

  @override
  String get stockReceiptHint => 'Omborga material kelib tushishi';

  @override
  String get quantity => 'Miqdor';

  @override
  String get kits => 'Toʻplamlar';

  @override
  String get kitsEmpty => 'Hozircha toʻplam yoʻq';

  @override
  String get kitAssemble => 'Toʻplamni yigʻish';

  @override
  String get kitAssembled => 'Toʻplam yigʻildi, QR-kod tayyor';

  @override
  String get kitCount => 'Toʻplamlar soni';

  @override
  String get kitTemplateName => 'Toʻplam nomi';

  @override
  String get kitAddMaterial => 'Material';

  @override
  String get commentOptional => 'Izoh (ixtiyoriy)';

  @override
  String get materialName => 'Material nomi';

  @override
  String get materialMinStock => 'Minimal qoldiq';

  @override
  String get workMeters9 => '9 m';

  @override
  String get workMeters18 => '18 m';

  @override
  String get workMeters27 => '27 m';

  @override
  String workDoneOf(String done, String planned) {
    return 'Bajarildi $done / $planned m';
  }

  @override
  String get workDueDate => 'Muddat';

  @override
  String get workExpectedEarning => 'Kutilayotgan toʻlov';

  @override
  String get workMaterials => 'Materiallar';

  @override
  String get workUpdateProgress => 'Jarayonni yangilash';

  @override
  String get workReady => 'Ish tayyor';

  @override
  String workReadyConfirm(String planned) {
    return 'Tasdiqlang: $planned m tayyor. Shundan keyin ish olib ketiladi.';
  }

  @override
  String get workProblem => 'Muammo bor';

  @override
  String get workMetersDone => 'Necha metr tayyor';

  @override
  String get workStatusReadyToDeliver => 'Qabul qilinishi kutilmoqda';

  @override
  String get workStatusDelivered => 'Usta qabul qildi';

  @override
  String get workStatusInProgress => 'Ishlanmoqda';

  @override
  String get workStatusReadyForPickup => 'Tayyor, olib ketishni kutmoqda';

  @override
  String get workStatusPickedUp => 'Olib ketildi';

  @override
  String get workStatusUnderReview => 'Tekshiruvda';

  @override
  String get workCurrentTitle => 'Joriy ish';

  @override
  String get workNoCurrent => 'Hozircha faol ish yoʻq';

  @override
  String get workNoCurrentHint =>
      'Sizga topshiriq berilishi bilan u shu yerda paydo boʻladi';

  @override
  String get workPickedUp => 'Oldim';

  @override
  String get insufficientStockGeneric => 'Omborda material yetarli emas';

  @override
  String get statusChangedMeanwhile =>
      'Bu amal endi mavjud emas, chunki topshiriq holati o\'zgardi.';

  @override
  String insufficientStockDetail(String material) {
    return 'Material yetarli emas: $material';
  }

  @override
  String get back => 'Orqaga';

  @override
  String get next => 'Keyingisi';

  @override
  String get assignCreateTitle => 'Ishni tayyorlash';

  @override
  String get assignStepProduct => 'Model';

  @override
  String get assignStepVariant => 'Rang';

  @override
  String get assignStepVolume => 'Ish hajmi';

  @override
  String get assignStepDue => 'Muddat';

  @override
  String get assignStepComment => 'Izoh';

  @override
  String get assignStepSummary => 'Tasdiqlash';

  @override
  String get assignNoVariants =>
      'Bu modelda hali ranglar yoʻq. Avval katalogga rang qoʻshing.';

  @override
  String get assignNoKitTemplate =>
      'Bu variant uchun material toʻplami mavjud emas.';

  @override
  String get assignSelectWorker => 'Mastaricani tanlang';

  @override
  String get assignSelectProduct => 'Modelni tanlang';

  @override
  String get assignSelectVariant => 'Rangni tanlang';

  @override
  String get assignDueOptional => 'Muddat (ixtiyoriy)';

  @override
  String get assignNoDueDate => 'Muddatsiz';

  @override
  String get assignSummaryWorker => 'Mastarica';

  @override
  String get assignSummaryModel => 'Model';

  @override
  String get assignSummaryColor => 'Rang';

  @override
  String get assignSummaryVolume => 'Hajm';

  @override
  String get assignSummaryMaterials => 'Materiallar';

  @override
  String get assignSummaryDue => 'Muddat';

  @override
  String get assignSummaryPayment => 'Hisoblangan toʻlov';

  @override
  String get assignSubmit => 'Ishni tayyorlash';

  @override
  String get assignSuccess => 'Ish berildi';

  @override
  String get assignSuccessHint =>
      'Materiallar ombordan yechildi, QR-kod tayyor';

  @override
  String get assignEmptyProducts => 'Katalogda hali model yoʻq';

  @override
  String get assignEmptyWorkers => 'Faol mastaricalar yoʻq';

  @override
  String get assignmentDetailTitle => 'Topshiriq';

  @override
  String get assignmentQr => 'Topshiriq QR-kodi';

  @override
  String get assignmentHistory => 'Tarix';

  @override
  String get assignmentMaterialsIssued => 'Berilgan materiallar';

  @override
  String get deliveriesTitle => 'Yetkazish va olib ketish';

  @override
  String get deliveryNeeded => 'Yetkazish kerak';

  @override
  String get deliveryConfirmTitle => 'Yetkazishni tasdiqlang';

  @override
  String get deliveryConfirmBody => 'Materiallar mastaricaga topshirildimi?';

  @override
  String get deliveryDone => 'Topshirishni boshlash';

  @override
  String get pickupNeeded => 'Olib ketish kerak';

  @override
  String get dashboardTab => 'Umumiy koʻrinish';

  @override
  String get dashActiveWorkers => 'Faol mastaricalar';

  @override
  String get dashInProgress => 'Ishda';

  @override
  String get dashNeedsAcceptance => 'Qabulda';

  @override
  String get dashOverdue => 'Muddati oʻtgan';

  @override
  String get queueEmpty => 'Hozircha boʻsh';

  @override
  String get dueBy => 'muddat ';

  @override
  String get workersDueEmpty => 'Barcha toʻlovlar yopilgan';

  @override
  String get greetingMorning => 'Xayrli tong';

  @override
  String get greetingDay => 'Xayrli kun';

  @override
  String get greetingEvening => 'Xayrli kech';

  @override
  String get dashProblems => 'Muammolar bor';

  @override
  String get dashAttention => 'Diqqat talab qiladi';

  @override
  String get dashAllClear => 'Hammasi nazoratda';

  @override
  String get dashToday => 'Bugun';

  @override
  String get dashDueToday => 'Muddati bugun';

  @override
  String get dashDeliveredToday => 'Yetkazildi';

  @override
  String get dashPickedUpToday => 'Olib ketildi';

  @override
  String get dashPaidToday => 'Toʻlandi';

  @override
  String get dashQuickActions => 'Tezkor amallar';

  @override
  String get actionMap => 'Xarita';

  @override
  String get actionStock => 'Ombor';

  @override
  String get more => 'Yana';

  @override
  String get managerLabel => 'Menejer';

  @override
  String get noManager => 'Menejersiz';

  @override
  String get historyWork => 'Ishlar';

  @override
  String get historyMoney => 'Pul';

  @override
  String get historyEmpty => 'Hozircha hech narsa yoʻq';

  @override
  String attnOverdue(int count) {
    return '$count ta ish muddati oʻtgan';
  }

  @override
  String attnToDeliver(int count) {
    return '$count ta yetkazish';
  }

  @override
  String attnToPickup(int count) {
    return '$count ta ish tayyor';
  }

  @override
  String attnAcceptance(int count) {
    return '$count ta ish qabulni kutmoqda';
  }

  @override
  String attnRework(int count) {
    return '$count ta ish qayta ishlashda';
  }

  @override
  String attnWorkersDue(int count) {
    return '$count ta mastarica toʻlovni kutmoqda';
  }

  @override
  String get acceptanceTitle => 'Ishni qabul qilish';

  @override
  String get acceptanceBrought => 'Keltirildi';

  @override
  String get acceptanceAccepted => 'Qabul qilindi';

  @override
  String get acceptanceDefective => 'Brak';

  @override
  String get acceptanceRework => 'Qayta ishlash';

  @override
  String get acceptanceCalculated => 'Hisoblanadi';

  @override
  String get acceptanceSubmit => 'Ishni qabul qilish';

  @override
  String get acceptanceSuccess => 'Ish qabul qilindi';

  @override
  String get acceptanceInvalid =>
      'Qabul + brak + qayta ishlash keltirilganiga teng boʻlishi kerak';

  @override
  String get acceptancePhotoOptional => 'Foto (ixtiyoriy)';

  @override
  String get payoutTitle => 'Naqd toʻlash';

  @override
  String get payoutDue => 'Toʻlanadigan';

  @override
  String get payoutFull => 'Butun summa';

  @override
  String get payoutHalf => 'Yarmi';

  @override
  String get payoutAmountLabel => 'Summa';

  @override
  String get payoutConfirmTitle => 'Toʻlovni tasdiqlang';

  @override
  String payoutConfirmBody(String amount) {
    return 'Haqiqatan ham $amount naqd berdingizmi?';
  }

  @override
  String get payoutSubmit => 'Toʻlash';

  @override
  String get payoutSuccess => 'Toʻlov yozildi';

  @override
  String get payoutNothingDue => 'Toʻlanadigan: 0 soʻm';

  @override
  String get payoutExceedsBalance => 'Summa ustaga tegishli miqdordan katta';

  @override
  String get earningsEarned => 'Ishlab topildi';

  @override
  String get earningsPaid => 'Toʻlandi';

  @override
  String get earningsHistory => 'Tarix';

  @override
  String get earningsEmpty => 'Hozircha hisoblanganlar yoʻq';

  @override
  String get actionAssign => 'Ishni tayyorlash';

  @override
  String get actionScanQr => 'QR skanerlash';

  @override
  String get actionAccept => 'Ishni qabul qilish';

  @override
  String get actionPayout => 'Naqd toʻlash';

  @override
  String get actionCall => 'Qoʻngʻiroq';

  @override
  String get actionRoute => 'Yoʻnalish';

  @override
  String get statusAccepted => 'Qabul qilindi';

  @override
  String get statusPartiallyAccepted => 'Qisman qabul qilindi';

  @override
  String get statusReworkRequired => 'Qayta ishlash kerak';

  @override
  String get statusCompleted => 'Yakunlandi';

  @override
  String get statusCancelled => 'Bekor qilindi';

  @override
  String get teamSearch => 'Ism yoki telefon';

  @override
  String get filterAll => 'Hammasi';

  @override
  String get filterActive => 'Faollar';

  @override
  String get filterDisabled => 'O\'chirilganlar';

  @override
  String get lastSeenLabel => 'Oxirgi marta onlayn';

  @override
  String get createdLabel => 'Yaratilgan';

  @override
  String get neverSeen => 'Hali kirmagan';

  @override
  String get changeRole => 'Rolni o\'zgartirish';

  @override
  String get changeRoleHint =>
      'Rol o\'zgargach, foydalanuvchi barcha qurilmalardan chiqadi va yangi huquqlar bilan qayta kiradi.';

  @override
  String get roleSuperAdminHint => 'Hammasi, rollar va huquqlar ham';

  @override
  String get roleAdminHint => 'Ustalar, ombor, to\'lovlar, katalog';

  @override
  String get roleManagerHint => 'Faqat o\'z ustalari';

  @override
  String get permissionsTitle => 'Kirish huquqlari';

  @override
  String get permissionsAllSuper =>
      'Bosh administratorda barcha huquqlar bor. Ularni cheklab bo\'lmaydi.';

  @override
  String get permissionsSaved => 'Huquqlar saqlandi';

  @override
  String get permissionsDefault => 'rol uchun standart';

  @override
  String permissionsCount(int on, int total) {
    return '$on / $total';
  }

  @override
  String get deactivateUser => 'Foydalanuvchini o\'chirish';

  @override
  String deactivateConfirm(String name) {
    return '$name o\'chirilsinmi? Kirish barcha qurilmalarda darhol taqiqlanadi. Butun tarix saqlanadi.';
  }

  @override
  String get restoreUser => 'Tiklash';

  @override
  String get userDeactivated => 'Foydalanuvchi o\'chirildi';

  @override
  String get userRestored => 'Foydalanuvchi tiklandi';

  @override
  String get resetPassword => 'Yangi parol berish';

  @override
  String get resetPasswordConfirm =>
      'Eski parol ishlamay qoladi, foydalanuvchi barcha qurilmalardan chiqadi.';

  @override
  String get tempPasswordTitle => 'Vaqtinchalik parol';

  @override
  String get tempPasswordHint =>
      'Parolni xodimga shaxsan bering. U faqat bir marta ko\'rsatiladi.';

  @override
  String get copy => 'Nusxalash';

  @override
  String get copied => 'Nusxa olindi';

  @override
  String get editDetails => 'Ma\'lumotlarni o\'zgartirish';

  @override
  String get activeImmediately => 'Darhol faol';

  @override
  String get workersOfManager => 'Menejer ustalari';

  @override
  String get changeManager => 'Menejerni almashtirish';

  @override
  String get managerChanged => 'Menejer o\'zgartirildi';

  @override
  String get archiveWorker => 'Ustani arxivlash';

  @override
  String get archiveConfirm =>
      'Usta kira olmaydi va yangi ish olmaydi. Tarix, to\'lovlar va garov saqlanadi.';

  @override
  String get workerArchived => 'Usta arxivda';

  @override
  String get restoreWorker => 'Ustani tiklash';

  @override
  String get workerRestored => 'Usta tiklandi';

  @override
  String get workersViaTelegram =>
      'Ustalar Telegram-bot orqali o\'zlari ro\'yxatdan o\'tadi — bu yerda faqat xodimlar qo\'shiladi.';

  @override
  String get usersEmpty => 'Hech kim topilmadi';

  @override
  String get youLabel => 'siz';

  @override
  String get permGroupUsers => 'Foydalanuvchilar';

  @override
  String get permGroupWorkers => 'Ustalar';

  @override
  String get permGroupCollateral => 'Garov';

  @override
  String get permGroupAssignments => 'Topshiriqlar';

  @override
  String get permGroupFinance => 'To\'lovlar va pul';

  @override
  String get permGroupCatalog => 'Katalog';

  @override
  String get permGroupInventory => 'Ombor';

  @override
  String get permGroupMap => 'Xarita';

  @override
  String get permGroupSettings => 'Sozlamalar';

  @override
  String get permGroupAudit => 'Amallar jurnali';

  @override
  String get permUserViewAll => 'Xodimlarni ko\'rish';

  @override
  String get permUserCreate => 'Xodim qo\'shish';

  @override
  String get permUserUpdate => 'Xodim ma\'lumotlarini o\'zgartirish';

  @override
  String get permUserDeactivate => 'Xodimlarni o\'chirish';

  @override
  String get permRoleAssign => 'Rollarni o\'zgartirish';

  @override
  String get permPermissionManage => 'Huquqlarni sozlash';

  @override
  String get permWorkerViewAll => 'Barcha ustalarni ko\'rish';

  @override
  String get permWorkerViewAssigned => 'O\'z ustalarini ko\'rish';

  @override
  String get permWorkerApprove => 'Arizalarni tasdiqlash';

  @override
  String get permWorkerUpdate => 'Usta kartasini o\'zgartirish';

  @override
  String get permWorkerAssignManager => 'Menejer tayinlash';

  @override
  String get permCollateralView => 'Garovni ko\'rish';

  @override
  String get permCollateralManage => 'Garovni qabul qilish va qaytarish';

  @override
  String get permAssignmentViewAll => 'Barcha topshiriqlarni ko\'rish';

  @override
  String get permAssignmentViewAssigned => 'O\'z ustalari topshiriqlari';

  @override
  String get permAssignmentCreate => 'Ish berish';

  @override
  String get permAssignmentAccept => 'Ishni qabul qilish';

  @override
  String get permFinanceViewAll => 'Barcha hisob-kitoblar';

  @override
  String get permFinanceViewAssigned => 'O\'z ustalari hisob-kitobi';

  @override
  String get permCashPayout => 'Naqd to\'lash';

  @override
  String get permProfitView => 'Foydani ko\'rish';

  @override
  String get permCatalogView => 'Katalogni ko\'rish';

  @override
  String get permCatalogManage => 'Katalogni o\'zgartirish';

  @override
  String get permInventoryView => 'Omborni ko\'rish';

  @override
  String get permInventoryManage => 'Kirim va to\'plamlar';

  @override
  String get permMapViewAll => 'Xarita: hammasi';

  @override
  String get permMapViewAssigned => 'Xarita: o\'z ustalari';

  @override
  String get permLiveLocationViewAll => 'Geolokatsiya: hammasi';

  @override
  String get permLiveLocationViewAssigned => 'Geolokatsiya: o\'z ustalari';

  @override
  String get permPayRateManage => '9 m narxini o\'zgartirish';

  @override
  String get permSettingsManage => 'Kompaniya sozlamalari';

  @override
  String get permAuditView => 'Amallar jurnalini ko\'rish';

  @override
  String get auditUserCreate => 'Yaratildi';

  @override
  String get auditUserUpdate => 'Ma’lumotlar o‘zgartirildi';

  @override
  String get auditUserDeactivate => 'O‘chirildi';

  @override
  String get auditUserReactivate => 'Tiklandi';

  @override
  String get auditUserRoleChange => 'Rol o‘zgartirildi';

  @override
  String get auditUserPermissionChange => 'Huquqlar o‘zgartirildi';

  @override
  String get auditUserPasswordReset => 'Yangi parol berildi';

  @override
  String get settingsTitle => 'Sozlamalar';

  @override
  String get changePassword => 'Parolni o\'zgartirish';

  @override
  String get currentPassword => 'Joriy parol';

  @override
  String get newPassword => 'Yangi parol';

  @override
  String get repeatPassword => 'Yangi parolni takrorlang';

  @override
  String get passwordsDontMatch => 'Parollar mos emas';

  @override
  String get passwordTooShort => 'Kamida 8 ta belgi';

  @override
  String get wrongCurrentPassword => 'Joriy parol noto\'g\'ri';

  @override
  String get passwordChanged =>
      'Parol o\'zgartirildi. Boshqa qurilmalar hisobdan chiqdi.';

  @override
  String get setPassword => 'Parol o\'rnatish';

  @override
  String get setPasswordHint =>
      'Foydalanuvchi barcha qurilmalardan chiqadi. Parolni shaxsan bering.';

  @override
  String get passwordSet => 'Parol o\'rnatildi';

  @override
  String get showOnMap => 'Xaritada ko\'rsatish';

  @override
  String get showOnMapHint => 'Xaritaga ruxsati borlar ko\'radi';

  @override
  String get hiddenOnMapHint => 'Yashirilgan: joylashuvni faqat siz ko\'rasiz';

  @override
  String locationUpdatedHours(int hours, int minutes) {
    return 'Joylashuv $hours soat $minutes daqiqa oldin yangilangan';
  }

  @override
  String locationUpdatedOn(String date) {
    return 'Joylashuv: $date';
  }

  @override
  String get permPasswordSet => 'Xodimlarga parol o\'rnatish';

  @override
  String get passwordForLogin => 'Kirish paroli';

  @override
  String get passwordForLoginHint =>
      'O\'zingiz o\'ylab toping va shaxsan bering';

  @override
  String get userCreated => 'Foydalanuvchi yaratildi. Parolni shaxsan bering.';

  @override
  String get telegramLoginHint => 'Ustalar uchun — parolsiz, Telegram orqali';

  @override
  String get staffSignIn => 'Xodimlar uchun kirish';

  @override
  String get workWaitingTitle => 'Sizni yangi ish kutmoqda';

  @override
  String get workKitReadyTitle => 'To\'plamingiz qabul qilishga tayyor';

  @override
  String get workKitReadyHint =>
      'Xodim olib kelgan to\'plamdagi QR-kodni skanerlang';

  @override
  String get workWaitingHint =>
      'Xodim to\'plamni olib keladi. U QR-kodni skanerlaganda, shu yerda qabul qilish tugmasi chiqadi.';

  @override
  String get workScanQr => 'QR-ni skanerlash';

  @override
  String get receiveTitle => 'Ishni qabul qilish';

  @override
  String get receiveCheckHint =>
      'Tasdiqlashdan oldin ish va materiallarni tekshiring.';

  @override
  String get receiveConfirm => 'Qabul qilishni tasdiqlash';

  @override
  String get receiveProblem => 'Muammo bor';

  @override
  String receiveKits(int count) {
    return 'To\'plamlar: $count';
  }

  @override
  String get receiveDone => 'Ish qabul qilindi!';

  @override
  String get receiveDoneHint => 'Materiallar endi sizda. Ishingizga omad!';

  @override
  String get receiveAlready => 'Siz bu ishni allaqachon qabul qilgansiz';

  @override
  String get receiveForeign => 'Bu to\'plam boshqa ustaga mo\'ljallangan.';

  @override
  String get receiveNotStarted => 'Avval xodim bu QR-ni skanerlashi kerak';

  @override
  String get receiveExpired =>
      'Topshirish vaqti tugadi. Xodimdan QR-ni qayta skanerlashni so\'rang.';

  @override
  String get receiveScanHint => 'Kamerani to\'plamdagi QR-kodga qarating';

  @override
  String get receiveGoHome => 'Bosh sahifaga';

  @override
  String get problemTitle => 'Nima noto\'g\'ri?';

  @override
  String get problemShortage => 'Material yetarli emas';

  @override
  String get problemWrongColor => 'Rang noto\'g\'ri';

  @override
  String get problemWrongModel => 'Model noto\'g\'ri';

  @override
  String get problemWrongMeters => 'Metraj noto\'g\'ri';

  @override
  String get problemDamaged => 'Shikastlangan';

  @override
  String get problemOther => 'Boshqa';

  @override
  String get problemComment => 'Izoh (ixtiyoriy)';

  @override
  String get problemSend => 'Yuborish';

  @override
  String get problemSent => 'Xodim xabaringizni oldi. Ish hali topshirilmagan.';

  @override
  String get handoffStart => 'Topshirishni boshlash';

  @override
  String get handoffStartTitle => 'To\'plamni ustaga topshirasizmi?';

  @override
  String get handoffStartBody =>
      'Shundan so\'ng usta o\'z ilovasida ushbu QR-ni skanerlaydi va qabul qilishni tasdiqlaydi. Materiallar faqat uning tasdig\'idan keyin unga o\'tadi.';

  @override
  String get handoffWaiting => 'Usta tasdig\'i kutilmoqda';

  @override
  String get handoffWaitingHint =>
      'Ustadan ilovani ochib, ushbu QR-ni skanerlashini so\'rang';

  @override
  String get handoffWorkerScanned =>
      'Usta QR-ni skanerladi va to\'plamni tekshirmoqda';

  @override
  String handoffReceived(String name) {
    return '$name to\'plamni oldi';
  }

  @override
  String get handoffProblemTitle => 'Usta muammo haqida xabar berdi';

  @override
  String get handoffRestart => 'Topshirishni qaytadan boshlash';

  @override
  String get handoffExpiredLabel => 'Topshirish vaqti tugadi';

  @override
  String timelineStarted(String name) {
    return 'Topshirish boshlandi · $name';
  }

  @override
  String get timelineScanned => 'Usta QR-ni skanerladi';

  @override
  String get timelineConfirmed => 'Usta qabul qilishni tasdiqladi';

  @override
  String get timelineProblem => 'Usta muammo haqida xabar berdi';

  @override
  String get handoffTimelineTitle => 'Topshirish';

  @override
  String get materialsAtWorker => 'Materiallar ustada';

  @override
  String get materialsPrepared => 'Tayyorlangan materiallar';

  @override
  String get workRemaining => 'Qoldi';

  @override
  String get addWorker => 'Qo\'shish';

  @override
  String get addWorkerTitle => 'Usta qo\'shish';

  @override
  String get addWorkerHint =>
      'Biz havola beramiz. Usta uni Telegramda ochadi — va darhol jamoada, anketasiz va tasdiqsiz.';

  @override
  String get addWorkerGetLink => 'Havola olish';

  @override
  String get addWorkerFullName => 'Familiya va ism';

  @override
  String get addWorkerManager => 'Menejer';

  @override
  String get addWorkerNoManager => 'Menejersiz';

  @override
  String get addWorkerLinkReady =>
      'QR-ni ustaga ko\'rsating — u telefon kamerasini qaratadi. Yoki havolani yuboring. Havola 7 kun amal qiladi va bir marta ochiladi.';

  @override
  String get addWorkerSendTelegram => 'Telegramda yuborish';

  @override
  String get addWorkerCopy => 'Havolani nusxalash';

  @override
  String get addWorkerCopied => 'Havola nusxalandi';

  @override
  String get invitesPending => 'Taklif qilingan — havolani hali ochmagan';

  @override
  String get inviteCancel => 'Bekor qilish';

  @override
  String get deleteWorker => 'Ustani o\'chirish';

  @override
  String deleteWorkerConfirm(String name) {
    return '$name barcha roʻyxatlardan, xaritadan va hisobotlardan yoʻqoladi va boshqa kira olmaydi. Oldingi ishlar va toʻlovlar tarixda «Oʻchirilgan usta» sifatida qoladi. Buni qaytarib boʻlmaydi.';
  }

  @override
  String get deleteWorkerForever => 'Butunlay o\'chirish';

  @override
  String get deleteWorkerBlocked =>
      'O\'chirib bo\'lmaydi: ustada ish, pul yoki qabul qilingan garov bor — bu yozuvlar hisobot va to\'lovlar uchun kerak. Uni arxivlash mumkin: u kira olmaydi, tarix saqlanadi.';

  @override
  String get deleteWorkerDone => 'Usta o\'chirildi';

  @override
  String get permWorkerDelete => 'Ustalarni o\'chirish';

  @override
  String get chooseWork => 'Ish tanlash';

  @override
  String get orderWork => 'Bu ishga buyurtma berish';

  @override
  String get orderColor => 'Rang';

  @override
  String get orderVolume => 'Necha metr';

  @override
  String get orderNote => 'Istak (ixtiyoriy)';

  @override
  String get orderSend => 'Arizani yuborish';

  @override
  String get orderSent => 'Ariza yuborildi! Menejer ishni tayyorlaydi.';

  @override
  String get orderAlreadyPending =>
      'Sizda allaqachon ariza bor — javobni kuting yoki bosh sahifada bekor qiling.';

  @override
  String get myRequestPending => 'Ariza yuborildi';

  @override
  String get myRequestPendingHint => 'Menejer javobini kutyapmiz';

  @override
  String get myRequestRejected => 'Ariza qabul qilinmadi';

  @override
  String get myRequestCancel => 'Arizani bekor qilish';

  @override
  String get jobRequestsTitle => 'Ishga arizalar';

  @override
  String get jobRequestsEmpty => 'Yangi arizalar yo\'q';

  @override
  String jobRequestsCount(int count) {
    return 'Ishga arizalar: $count';
  }

  @override
  String get jobRequestRejectReason => 'Sabab (usta ko\'radi)';

  @override
  String updateReady(String version) {
    return 'Yangi versiya $version tayyor';
  }

  @override
  String get updateInstall => 'O\'rnatish';

  @override
  String get updateAllowInstall =>
      'Diamoraa uchun o\'rnatishga ruxsat bering va yana bosing';

  @override
  String get ageNow => 'hozir';

  @override
  String ageMinutes(int minutes) {
    return '$minutes daqiqa oldin';
  }

  @override
  String ageHours(int hours, int minutes) {
    return '$hours soat $minutes daqiqa oldin';
  }

  @override
  String get qrRecognized => 'QR aniqlandi';

  @override
  String get handoffStartedToast =>
      'Topshirish boshlandi — usta shu QR-ni skanerlasin';

  @override
  String get qrPrint => 'QR-ni chop etish';

  @override
  String get noticesTitle => 'Bildirishnomalar';

  @override
  String get noticesReadAll => 'Hammasini o\'qilgan deb belgilash';

  @override
  String get noticesEmpty => 'Hozircha bildirishnomalar yo\'q';

  @override
  String get reportsTitle => 'Hisobotlar';

  @override
  String get reportDay => 'Kun';

  @override
  String get reportWeek => 'Hafta';

  @override
  String get reportMonth => 'Oy';

  @override
  String get reportIssued => 'Berildi';

  @override
  String get reportAccepted => 'Qabul qilindi';

  @override
  String get reportOverdue => 'Muddati o\'tgan';

  @override
  String get reportDefective => 'Brak';

  @override
  String get reportByWorker => 'Ustalar bo\'yicha';

  @override
  String get reportEmpty => 'Bu davrda hech narsa bo\'lmagan';

  @override
  String get reportLowStock => 'Omborda tugayapti';

  @override
  String get reportExcelHint =>
      'Excel uchun yuklab olish — veb-panelda: Hisobotlar → «Excel uchun yuklab olish».';

  @override
  String get myMonthsTitle => 'Oylar bo\'yicha daromadim';

  @override
  String get m1 => 'Yanvar';

  @override
  String get m2 => 'Fevral';

  @override
  String get m3 => 'Mart';

  @override
  String get m4 => 'Aprel';

  @override
  String get m5 => 'May';

  @override
  String get m6 => 'Iyun';

  @override
  String get m7 => 'Iyul';

  @override
  String get m8 => 'Avgust';

  @override
  String get m9 => 'Sentyabr';

  @override
  String get m10 => 'Oktyabr';

  @override
  String get m11 => 'Noyabr';

  @override
  String get m12 => 'Dekabr';

  @override
  String get qaAssign => 'Ish';

  @override
  String get qaScan => 'QR';

  @override
  String get qaMap => 'Xarita';

  @override
  String get qaStock => 'Ombor';

  @override
  String get qaPay => 'To\'lov';

  @override
  String get assignCancel => 'Ishni bekor qilish';

  @override
  String get assignCancelReason => 'Sabab';

  @override
  String get assignCancelReturned => 'Materiallar omborga qaytdi';

  @override
  String get assignCancelled => 'Ish bekor qilindi';

  @override
  String get assignChangeDue => 'Muddatni o\'zgartirish';

  @override
  String get userDelete => 'Xodimni o\'chirish';

  @override
  String userDeleteConfirm(String name) {
    return '$name butunlay o\'chiriladi.';
  }

  @override
  String get userDeleteBlocked =>
      'O\'chirib bo\'lmaydi: xodimda tarix bor (ishlar, to\'lovlar, ombor). Uni o\'chirib qo\'yish mumkin.';

  @override
  String get userDeleted => 'Xodim o\'chirildi';

  @override
  String get qrNotYours =>
      'Bu usta boshqa menejerga biriktirilgan. Administratordan uni sizga biriktirishni soʻrang.';

  @override
  String get qrRevoked =>
      'Bu QR endi ishlamaydi: ish tugagan yoki bekor qilingan, yoki usta oʻchirilgan.';

  @override
  String get errOpenWork =>
      'Avval uning ishlarini tugating yoki bekor qiling va garovni qaytaring — keyin oʻchirish mumkin.';

  @override
  String get errInUse =>
      'Material hozir ishlatilmoqda: ustada yoki toʻplamda. Avval uni u yerdan olib tashlang.';

  @override
  String errInUseKits(String kits) {
    return 'Material toʻplamlarda bor: $kits. Avval shu toʻplamlarni oʻchiring yoki oʻzgartiring.';
  }

  @override
  String get deleteAction => 'Oʻchirish';

  @override
  String get deleteDone => 'Oʻchirildi';

  @override
  String catalogDeleteConfirm(String name) {
    return '«$name» hammadan katalogdan yoʻqoladi. Berilgan ishlar tarixda qoladi. Buni qaytarib boʻlmaydi.';
  }

  @override
  String materialDeleteConfirm(String name, String left) {
    return '«$name» ombordan yoʻqoladi. Qoldiq ($left) hisobdan chiqariladi. Buni qaytarib boʻlmaydi.';
  }

  @override
  String kitDeleteConfirm(String name) {
    return '«$name» toʻplami ombordan yoʻqoladi. Berilgan ishlar tarixda qoladi. Buni qaytarib boʻlmaydi.';
  }

  @override
  String get permCatalogDelete => 'Katalogdan oʻchirish';

  @override
  String get permInventoryDelete => 'Material va toʻplamlarni oʻchirish';

  @override
  String get assignManagerTitle => 'Menejer biriktirish';

  @override
  String get assignManagerSave => 'Biriktirish';

  @override
  String assignManagerDone(int count) {
    return 'Tayyor: $count usta';
  }

  @override
  String get assignWorkersToManager => 'Ustalarni biriktirish';

  @override
  String get auditClear => 'Jurnalni tozalash';

  @override
  String get auditClearConfirm =>
      'Jurnal boshidan boshlanadi — birinchi qatorda sizning ismingiz bilan «Jurnal tozalandi» boʻladi. Eski yozuvlar bu yerda koʻrinmaydi, lekin bazadan oʻchirilmaydi.';

  @override
  String get collateralsTitle => 'Garovlar';

  @override
  String get collateralsWithUs => 'Hozir bizda';

  @override
  String collateralsItems(int count) {
    return '$count ta buyum';
  }

  @override
  String get collateralsTabHeld => 'Bizda';

  @override
  String get collateralsTabPending => 'Olinmagan';

  @override
  String get collateralsTabReturned => 'Qaytarilgan';

  @override
  String get collateralsEmpty => 'Bu yerda boʻsh';

  @override
  String get collateralReturnTitle => 'Garovni qaytarish';

  @override
  String get collateralReturnNote => 'Qanday qaytarildi';

  @override
  String get collateralReturnConfirm => 'Usta garovni qaytarib oldi';

  @override
  String get collateralReturnedToast => 'Garov qaytarildi';

  @override
  String get mapFilterAll => 'Hammasi';

  @override
  String get mapFilterToDeliver => 'Yetkazish kerak';

  @override
  String get mapFilterToPickup => 'Olib ketishga tayyor';

  @override
  String get mapFilterOverdue => 'Muddati oʻtgan';

  @override
  String get mapFilterAllManagers => 'Barcha menejerlar';

  @override
  String get mapAtHome =>
      'Uyda — roʻyxatdan oʻtgandagi manzil (telefon hozir joylashuvni yubormayapti)';

  @override
  String get ratingTitle => 'Ustalar reytingi';

  @override
  String get ratingThreeMonths => '3 oy';

  @override
  String get ratingHalfYear => 'Yarim yil';

  @override
  String ratingLine(String meters, String defect, int late, int total) {
    return '$meters m · brak $defect% · kechikdi $late/$total';
  }

  @override
  String get ratingHowScored =>
      '100 balldan: 40% — hajm (oyiga ≈54 m = maksimum), 35% — braksiz, 25% — oʻz vaqtida.';

  @override
  String get profitTitle => 'Foyda';

  @override
  String get profitAdd => 'Sotuv yoki xarajat';

  @override
  String get profitSale => 'Sotuv';

  @override
  String get profitExpense => 'Xarajat';

  @override
  String get profitSales => 'Sotuvlar';

  @override
  String get profitLabor => 'Ustalarga';

  @override
  String get profitMaterials => 'Materiallar';

  @override
  String get profitExpenses => 'Xarajatlar';

  @override
  String get profitCustomer => 'Xaridor (ixtiyoriy)';

  @override
  String get profitNoPriceHint =>
      '* Ayrim materiallarning xarid narxi koʻrsatilmagan — ular hisoblanmadi. Narxni veb-paneldagi omborda kiriting.';

  @override
  String get profitDeleteConfirm =>
      'Bu yozuv oʻchirilsinmi? Oylik foyda qayta hisoblanadi.';

  @override
  String get expenseFuel => 'Benzin / yetkazish';

  @override
  String get expensePackaging => 'Qadoqlash';

  @override
  String get expenseOther => 'Boshqa';

  @override
  String get stockValueTitle => 'Ombor qiymati (xarid narxida)';

  @override
  String stockValueSplit(String shelf, String homes) {
    return 'omborda $shelf · ustalarda $homes';
  }

  @override
  String stockValueNoPrice(String names) {
    return 'Narxsiz: $names';
  }

  @override
  String get systemTitle => 'Tizim holati';

  @override
  String get systemServer => 'Server';

  @override
  String get systemDatabase => 'Maʼlumotlar bazasi';

  @override
  String systemUptime(int hours) {
    return '$hours soat ishlayapti';
  }

  @override
  String get systemOk => 'joyida';

  @override
  String get systemDown => 'javob bermayapti';

  @override
  String get systemBackups => 'Zaxira nusxalar';

  @override
  String get systemBackupsHidden =>
      'Server zaxira belgilari papkasini koʻrmayapti.';

  @override
  String get systemBackupFailed => 'xato';

  @override
  String get systemBackupLate => 'ancha boʻlmadi';

  @override
  String get backupDaily => 'Baza (har kuni)';

  @override
  String get backupWeekly => 'Bazaning toʻliq nusxasi (haftada bir)';

  @override
  String get backupFiles => 'Rasmlar va fayllar';

  @override
  String get backupConfig => 'Sozlamalar';

  @override
  String get backupVerify => 'Tiklashni tekshirish';

  @override
  String get backupRestore => 'Tiklash';

  @override
  String get editName => 'Ismni o\'zgartirish';

  @override
  String get firstName => 'Ism';

  @override
  String get lastName => 'Familiya';

  @override
  String get nameSaved => 'Ism saqlandi';

  @override
  String get nameTooShort => 'Ism kamida 2 harf bo\'lsin';

  @override
  String get chat => 'Chat';

  @override
  String get chatCompany => 'Umumiy chat';

  @override
  String get chatNew => 'Yangi chat';

  @override
  String get chatNewGroup => 'Yangi guruh';

  @override
  String get chatGroupName => 'Guruh nomi';

  @override
  String chatMembers(int count) {
    return 'A\'zolar: $count';
  }

  @override
  String get chatSearchPeople => 'Ism bo\'yicha qidirish';

  @override
  String get chatEmpty => 'Hozircha xabar yo\'q — birinchi bo\'lib yozing';

  @override
  String get chatNoChats => 'Bu yerda yozishmalaringiz bo\'ladi';

  @override
  String get chatTypeMessage => 'Xabar';

  @override
  String get chatPhoto => 'Rasm';

  @override
  String get chatCamera => 'Kamera';

  @override
  String get chatVideo => 'Video';

  @override
  String get chatRecordVideo => 'Video olish';

  @override
  String get chatFile => 'Fayl';

  @override
  String get chatVoice => 'Ovozli xabar';

  @override
  String get chatAudio => 'Audio';

  @override
  String get chatHoldToRecord => 'Yozish uchun mikrofon tugmasini bosib turing';

  @override
  String get chatRecording => 'Yozilmoqda… qo\'yib yuboring — yuboriladi';

  @override
  String get chatMessageDeleted => 'Xabar o\'chirildi';

  @override
  String get chatDeleteMessage => 'Xabarni o\'chirish';

  @override
  String get chatDeleteMessageBody => 'Xabar barcha a\'zolarda o\'chadi.';

  @override
  String get chatCopy => 'Nusxa olish';

  @override
  String get chatCopied => 'Nusxa olindi';

  @override
  String get chatFileTooLarge => 'Fayl 50 MB dan katta — yuborib bo\'lmaydi';

  @override
  String chatSendingProgress(int percent) {
    return 'Yuborilmoqda… $percent%';
  }

  @override
  String get chatSendFailed => 'Yuborilmadi — qayta urinish uchun bosing';

  @override
  String get chatRead => 'O\'qildi';

  @override
  String get chatLeaveGroup => 'Guruhdan chiqish';

  @override
  String get chatLeaveGroupBody =>
      'Siz bu guruh xabarlarini boshqa ko\'rmaysiz.';

  @override
  String get chatAddMembers => 'A\'zo qo\'shish';

  @override
  String get chatRemoveMember => 'Guruhdan chiqarish';

  @override
  String get chatRename => 'Nomini o\'zgartirish';

  @override
  String get chatOwner => 'yaratuvchi';

  @override
  String get chatMicPermission =>
      'Ovozli xabar yozish uchun mikrofonga ruxsat bering';

  @override
  String get chatYou => 'Siz';

  @override
  String get chatDownloading => 'Yuklanmoqda…';

  @override
  String get chatFileFailed => 'Faylni yuklab bo\'lmadi';

  @override
  String get chatCreate => 'Yaratish';

  @override
  String get chatGroupInfo => 'Guruh haqida';

  @override
  String get chatToday => 'Bugun';

  @override
  String get chatYesterday => 'Kecha';

  @override
  String get chatCompanyHint => 'Barcha xodimlar va ustalar';

  @override
  String get chatAttach => 'Biriktirish';

  @override
  String get chatSend => 'Yuborish';

  @override
  String get chatReply => 'Javob berish';

  @override
  String get chatEdit => 'O\'zgartirish';

  @override
  String get chatEdited => 'o\'zgartirildi';

  @override
  String get chatEditing => 'Tahrirlash';

  @override
  String get chatForward => 'Uzatish';

  @override
  String get chatForwardTo => 'Qayerga uzatish…';

  @override
  String get chatForwarded => 'Uzatildi';

  @override
  String chatForwardedFrom(String name) {
    return '$name dan uzatilgan';
  }

  @override
  String get chatPin => 'Qadash';

  @override
  String get chatUnpin => 'Qadashni olish';

  @override
  String get chatPinned => 'Qadalgan xabar';

  @override
  String get chatPinChat => 'Chatni qadash';

  @override
  String get chatUnpinChat => 'Chatni qadashdan olish';

  @override
  String get chatMute => 'Bildirishnomasiz';

  @override
  String get chatUnmute => 'Bildirishnomalarni yoqish';

  @override
  String get chatSearch => 'Qidiruv';

  @override
  String get chatSearchHint => 'Chatlar, odamlar, xabarlar';

  @override
  String get chatSectionChats => 'Chatlar';

  @override
  String get chatSectionPeople => 'Odamlar';

  @override
  String get chatSectionMessages => 'Xabarlar';

  @override
  String get chatNothingFound => 'Hech narsa topilmadi';

  @override
  String get chatTyping => 'yozmoqda…';

  @override
  String chatTypingName(String name) {
    return '$name yozmoqda…';
  }

  @override
  String get chatRecordingVoice => 'ovozli xabar yozmoqda…';

  @override
  String chatRecordingVoiceName(String name) {
    return '$name ovozli xabar yozmoqda…';
  }

  @override
  String chatLastSeen(String time) {
    return '$time da tarmoqda edi';
  }

  @override
  String chatReplyTo(String name) {
    return 'Javob: $name';
  }

  @override
  String get chatEmoji => 'Emoji';

  @override
  String get chatNewChannel => 'Yangi kanal';

  @override
  String get chatChannelName => 'Kanal nomi';

  @override
  String get chatDescription => 'Tavsif';

  @override
  String get chatAudience => 'Kim o\'qiydi';

  @override
  String get chatAudienceAll => 'Barcha xodimlar va ustalar';

  @override
  String get chatAudienceStaff => 'Faqat xodimlar';

  @override
  String get chatAudienceWorkers => 'Faqat ustalar';

  @override
  String get chatAudienceCustom => 'Tanlangan odamlar';

  @override
  String chatChoosePeople(int count) {
    return 'Odamlarni tanlash ($count)';
  }

  @override
  String get chatChannelHint =>
      'Faqat kanal adminlari e\'lon qiladi; o\'quvchilar e\'lonlarni ko\'radi va bildirishnoma oladi.';

  @override
  String get chatChannelReadOnly =>
      'Bu kanal: faqat uning adminlari e\'lon qiladi';

  @override
  String get chatGroupReadOnly => 'Faqat guruh adminlari yoza oladi';

  @override
  String get chatOnlyAdminsWrite => 'Faqat adminlar yoza oladi';

  @override
  String get chatMakeAdmin => 'Admin qilish';

  @override
  String get chatRemoveAdmin => 'Adminlikdan olish';

  @override
  String get chatAddAdmin => 'Admin qo\'shish';

  @override
  String get chatAdmin => 'admin';

  @override
  String get chatChangePhoto => 'Rasmni o\'zgartirish';

  @override
  String get chatInfo => 'Chat haqida ma\'lumot';

  @override
  String get chatChannelInfo => 'Kanal haqida';

  @override
  String get chatTabMembers => 'A\'zolar';

  @override
  String get chatTabMedia => 'Media';

  @override
  String get chatTabFiles => 'Fayllar';

  @override
  String get chatTabVoice => 'Ovozli';

  @override
  String get chatTabLinks => 'Havolalar';

  @override
  String get chatNothingYet => 'Hozircha hech narsa yo\'q';

  @override
  String chatSubscribers(int count) {
    return 'Kanal · obunachilar: $count';
  }

  @override
  String get chatLeaveChannel => 'Kanaldan chiqish';

  @override
  String get chatVideoTooLarge => 'Video 150 MB dan katta — yuborib bo\'lmaydi';

  @override
  String get chatMyProfile => 'Mening profilim';

  @override
  String get chatBio => 'O\'zim haqimda';

  @override
  String get chatBioHint => 'Istalgan tafsilot: lavozim, tuman yoki ish vaqti.';

  @override
  String get chatUsername => 'Foydalanuvchi nomi';

  @override
  String get chatUsernameHint =>
      'Lotin harflari, raqamlar va _, kamida 5 belgi.';

  @override
  String get chatUsernameTaken => 'Bu nom band';

  @override
  String get chatPhone => 'Telefon';

  @override
  String get chatRole => 'Rol';

  @override
  String get chatChangeAvatar => 'Profil rasmini o\'zgartirish';

  @override
  String get chatRemoveAvatar => 'Rasmni o\'chirish';

  @override
  String chatReadAt(String time) {
    return '$time da o\'qildi';
  }

  @override
  String get chatNotReadYet => 'hali o\'qilmagan';

  @override
  String get chatWhoRead => 'Kim o\'qidi';

  @override
  String get chatNobodyYet => 'Hali hech kim';

  @override
  String get chatClearHistory => 'Tarixni tozalash';

  @override
  String get chatClearHistoryBody => 'Xabarlar faqat sizda o\'chadi.';

  @override
  String get chatDeleteChat => 'Chatni o\'chirish';

  @override
  String get chatDeleteChatBody => 'Yozishma faqat sizda o\'chadi.';

  @override
  String get chatProtectOn => 'Nusxalashni taqiqlash';

  @override
  String get chatProtectOff => 'Nusxalashga ruxsat berish';

  @override
  String get chatProtected => 'Bu chatda nusxalash va uzatish taqiqlangan';

  @override
  String get chatExport => 'Chat tarixini eksport qilish';

  @override
  String get chatSearchInChat => 'Shu chatda qidirish';

  @override
  String get chatOlderMessage => 'Bu xabar yuqorida — yuqoriga suring';

  @override
  String get chatCancelUpload => 'Yuborishni bekor qilish';

  @override
  String chatCountPhotos(int count) {
    return 'Rasmlar: $count';
  }

  @override
  String chatCountVideos(int count) {
    return 'Videolar: $count';
  }

  @override
  String chatCountFiles(int count) {
    return 'Fayllar: $count';
  }

  @override
  String chatCountVoice(int count) {
    return 'Ovozli: $count';
  }

  @override
  String chatCountLinks(int count) {
    return 'Havolalar: $count';
  }

  @override
  String get chatShowProfile => 'Profilni ko\'rsatish';

  @override
  String chatTodayAt(String time) {
    return 'bugun $time da';
  }

  @override
  String chatYesterdayAt(String time) {
    return 'kecha $time da';
  }

  @override
  String chatDateAt(String date, String time) {
    return '$date $time da';
  }

  @override
  String get chatAudioPrev => 'Oldingi';

  @override
  String get chatAudioNext => 'Keyingi';

  @override
  String get chatAudioPlay => 'Tinglash';

  @override
  String get chatAudioPause => 'Pauza';

  @override
  String get chatAudioSpeed => 'Tezlik';

  @override
  String get chatAudioMute => 'Ovoz';

  @override
  String get chatAudioClose => 'Pleyerni yopish';
}
