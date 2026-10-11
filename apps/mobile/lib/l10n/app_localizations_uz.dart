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
  String get telegramLoginHint => 'Hamma uchun — parolsiz, Telegram orqali';

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

  @override
  String updateDownloading(String version, int percent) {
    return 'Yangi versiya $version yuklanmoqda — $percent%';
  }

  @override
  String get mapZoomIn => 'Yaqinlashtirish';

  @override
  String get mapZoomOut => 'Uzoqlashtirish';

  @override
  String get mapMyPlace => 'Men qayerdaman';

  @override
  String get mapNoMyPlace =>
      'Joylashuvingiz aniqlanmadi. Geolokatsiyani yoqing.';

  @override
  String get mapNorth => 'Shimolga';

  @override
  String get mapTraffic => 'Tirbandlik';

  @override
  String get mapShowAll => 'Hammasi xaritada';

  @override
  String get map3d => 'Hajmli ko\'rinish';

  @override
  String get updateAppVersion => 'Ilova versiyasi';

  @override
  String get updateCheck => 'Tekshirish';

  @override
  String get updateLatest => 'Sizda eng so\'nggi versiya';

  @override
  String stockLasts(int days) {
    return '≈ $days kunga yetadi';
  }

  @override
  String get goalTitle => 'Oy maqsadi';

  @override
  String goalPlace(int place, int of) {
    return '$of tadan $place-o‘rin';
  }

  @override
  String goalProgress(String done, int goal) {
    return '$goal m dan $done m';
  }

  @override
  String goalLeft(String left, int days) {
    return 'Yana $left m · oy oxirigacha $days kun';
  }

  @override
  String get goalDone => 'Maqsad bajarildi! Rahmat 🎉';

  @override
  String goalNoGoal(String done) {
    return 'Bu oy qabul qilindi: $done m';
  }

  @override
  String get routeTitle => 'Marshrut';

  @override
  String routeReady(int count, String km) {
    return 'Marshrut: $count ta bekat, ≈ $km km';
  }

  @override
  String routeBuild(int count) {
    return 'Marshrut tuzish ($count)';
  }

  @override
  String get routeOpenYandex => 'Yandex Xaritada ochish';

  @override
  String get routeChange => 'Ro\'yxatni o\'zgartirish';

  @override
  String get routeToPickup => 'ishni olib ketish';

  @override
  String get routeToDeliver => 'materiallarni olib borish';

  @override
  String get routeOverdue => 'muddati o\'tgan';

  @override
  String get routeNobody => 'Xaritada hali ustalar yo\'q.';

  @override
  String get routeNoStart =>
      'Joylashuvingiz aniqlanmadi — marshrut birinchi nuqtadan boshlanadi.';

  @override
  String get offlineSaved =>
      'Internet yo\'q — telefonda saqlandi, aloqa paydo bo\'lganda o\'zi yuboriladi';

  @override
  String offlineSent(int count) {
    return 'Internetsiz qilinganlar yuborildi: $count';
  }

  @override
  String offlineWaiting(int count) {
    return 'Yuborilmagan: $count';
  }

  @override
  String get offlineWillSend => 'internet bo\'lganda o\'zi yuboriladi';

  @override
  String get offlineSendNow => 'Hozir yuborish';

  @override
  String offlineRefused(String what) {
    return 'Qabul qilinmadi: $what';
  }

  @override
  String get offlineRefusedHint =>
      'Server bu amalni qabul qilmadi. Qayta bajaring yoki menejerga qo\'ng\'iroq qiling.';

  @override
  String get offlineKindProgress => 'qancha qilindi';

  @override
  String get offlineKindReady => 'ish tayyor';

  @override
  String get offlineKindReceive => 'ishni qabul qilish';

  @override
  String get offlineScanNoInternet =>
      'Internet yo\'q. Saqlash mumkin — aloqa paydo bo\'lganda ish qabul qilinadi.';

  @override
  String get offlineScanSave => 'Saqlash va keyinroq qabul qilish';

  @override
  String get assignSuggestTitle =>
      'Avval — kimga berish yaxshiroq (bo\'sh, tez, nuqsonsiz, o\'z vaqtida)';

  @override
  String get visitTimeTitle => 'Qachon kelishlari qulay';

  @override
  String get visitTimeShort => 'Qulay';

  @override
  String get visitTimeNotSet => 'Ko\'rsatilmagan — kun va soatlarni tanlang';

  @override
  String get visitTimeHint =>
      'Menejer bu vaqtni ko\'radi va materiallarni sizga qulay vaqtda olib keladi.';

  @override
  String get visitFrom => 'dan';

  @override
  String get visitTo => 'gacha';

  @override
  String get visitTimeOrder =>
      'Boshlanish vaqti tugashdan oldin bo\'lishi kerak';

  @override
  String get visitTimeNote => 'Izoh (ixtiyoriy)';

  @override
  String get visitTimeNoteHint => 'masalan: oldindan qo\'ng\'iroq qiling';

  @override
  String get visitTimeClear => 'Vaqtni olib tashlash';

  @override
  String get dayMon => 'Du';

  @override
  String get dayTue => 'Se';

  @override
  String get dayWed => 'Ch';

  @override
  String get dayThu => 'Pa';

  @override
  String get dayFri => 'Ju';

  @override
  String get daySat => 'Sh';

  @override
  String get daySun => 'Ya';

  @override
  String get ordersTitle => 'Mijozlar buyurtmalari';

  @override
  String get ordersEmpty => 'Hozircha bo\'sh';

  @override
  String get ordersNew => 'Yangi';

  @override
  String get ordersConfirmed => 'Tasdiqlangan';

  @override
  String get ordersInWork => 'Ishda';

  @override
  String get ordersDone => 'Bajarilgan';

  @override
  String get ordersCancelled => 'Bekor qilingan';

  @override
  String get ordersAll => 'Hammasi';

  @override
  String get ordersAccept => 'Buyurtmani qabul qilish';

  @override
  String get ordersStart => 'Ishni boshlash';

  @override
  String get ordersFinish => 'Tayyor';

  @override
  String get ordersCancel => 'Bekor qilish';

  @override
  String get ordersCancelAsk => 'Bu buyurtmani bekor qilasizmi?';

  @override
  String get ordersFromSite => 'saytdan';

  @override
  String get ordersFromBot => 'Telegramdan';

  @override
  String get ordersFromPanel => 'xodim yozgan';

  @override
  String get ordersNoItem => 'Mahsulot tanlanmagan';

  @override
  String ordersTotal(String m) {
    return 'Jami: $m m';
  }

  @override
  String get badgeFirstKit => 'Birinchi komplekt';

  @override
  String get badge100 => '100 metr';

  @override
  String get badge500 => '500 metr';

  @override
  String get badgeGoal => 'Oy maqsadi';

  @override
  String get badgeNoDefects => 'Braksiz';

  @override
  String get badgeOnTime => 'Hammasi o\'z vaqtida';

  @override
  String get visitEveryDay => 'Har kuni';

  @override
  String get learnTitle => 'O\'qitish';

  @override
  String get learnSubtitle => 'Qisqa videolar: Diamoraa\'da qanday ishlash';

  @override
  String get learnNone => 'Hozircha video yo\'q. Keyinroq qarang.';

  @override
  String learnMinutes(int n) {
    return '$n daq';
  }

  @override
  String get signInWithPassword => 'Parol bilan kirish (xodimlar uchun)';

  @override
  String get waitingForTelegram =>
      'Telegramda kutyapmiz… Keyin shu yerga qayting.';

  @override
  String get progressTitle => 'Mening yutuqlarim';

  @override
  String get progressOpenHint =>
      'Qancha topshirdingiz, sifat, bonus va daromad kalkulyatori';

  @override
  String get progressThisMonth => 'Shu oy';

  @override
  String get progressAccepted => 'Topshirildi';

  @override
  String get progressQuality => 'Braksiz';

  @override
  String get progressEarned => 'Ishlab topildi';

  @override
  String get progressRecord => '🏆 Yangi shaxsiy rekord!';

  @override
  String progressBest(String month, String meters) {
    return 'Eng yaxshi oy: $month — $meters m';
  }

  @override
  String get progressAllTime => 'Barcha vaqt';

  @override
  String progressChecksCount(String count) {
    return 'Tekshirilgan ishlar: $count';
  }

  @override
  String get progressChecks => 'Ishlar tekshiruvi';

  @override
  String get progressNoChecks =>
      'Ishingiz qabul qilinganda, bu yerda tekshiruv chiqadi: nima qabul qilindi va nima noto‘g‘ri';

  @override
  String get bonusQuality => 'Sifat uchun bonus';

  @override
  String bonusRule(String percent, String maxDefect, String minMeters) {
    return 'Oylik daromadga +$percent%, agar brak $maxDefect% dan oshmasa va kamida $minMeters m topshirilsa';
  }

  @override
  String bonusYes(String amount) {
    return 'Hozir sizga bonus ≈ $amount so‘m. Shunday davom eting!';
  }

  @override
  String bonusTooManyDefects(String defect) {
    return 'Bu oy brak $defect% — me’yordan ko‘p. Keyingi oyda albatta bo‘ladi!';
  }

  @override
  String bonusNeedMeters(String meters) {
    return 'Yana $meters m braksiz topshiring — bonus sizniki';
  }

  @override
  String get bonusPaidOn1st =>
      'Bonus har oyning 1-sanasida o‘tgan oy uchun beriladi';

  @override
  String get calcTitle => 'Daromad kalkulyatori';

  @override
  String get calcHint => 'Necha metr topshirasiz?';

  @override
  String calcResult(String amount) {
    return '≈ $amount so‘m';
  }

  @override
  String calcWithBonus(String amount) {
    return '+ sifat bonusi ≈ $amount so‘m';
  }

  @override
  String calcRate(String rate) {
    return '9 m uchun $rate so‘m stavka bo‘yicha';
  }

  @override
  String get checkAccepted => 'Qabul qilindi';

  @override
  String get checkDefective => 'Brak';

  @override
  String get checkRework => 'Qayta ishlashga';

  @override
  String get workHowToSew => 'Qanday tikish (video)';

  @override
  String get acceptanceDefectPhoto => 'Brak rasmi';

  @override
  String get acceptanceWhatsWrong => 'Nima noto‘g‘ri? Usta buni ko‘radi';

  @override
  String get idleTitle => 'Ishsiz turganlar';

  @override
  String get idleHint =>
      'Ishsiz ustalaringiz: avval ish so‘raganlar, keyin uzoq kutayotganlar.';

  @override
  String get idleNone => 'Barcha ustalar ish bilan band 🎉';

  @override
  String idleDays(String days) {
    return '$days kundan beri ishsiz';
  }

  @override
  String get idleNeverWorked => 'Hali ish olmagan';

  @override
  String idleQuality(String percent) {
    return 'braksiz $percent%';
  }

  @override
  String get idleWantsWork => 'Ish so‘ramoqda';

  @override
  String get idleGiveWork => 'Ish berish';

  @override
  String idleBanner(String count) {
    return 'Ishsiz: $count';
  }

  @override
  String get remindersTitle => 'Eslatmalar';

  @override
  String get reminderAdd => 'Eslatish';

  @override
  String get remindersEmpty => 'Eslatmalar yo‘q';

  @override
  String get remindersEmptyHint =>
      'Masalan: «Juma kuni Nigoraga qo‘ng‘iroq qilish». «Eslatish» tugmasini bosing.';

  @override
  String get reminderWhat => 'Nima haqida eslatish';

  @override
  String get reminderWhatHint => 'Masalan: tayyor ishni olib ketish';

  @override
  String get reminderTomorrow => 'Ertaga 9:00';

  @override
  String get reminderIn3Days => '3 kundan keyin';

  @override
  String get reminderNextMonday => 'Dushanba kuni';

  @override
  String reminderSaved(String when) {
    return '$when da eslataman';
  }

  @override
  String get awayTitle => 'Ta’til';

  @override
  String awayHint(String count) {
    return 'Ta’tilga ketyapsizmi? Ustalaringiz ($count) shu vaqtga boshqa menejerga o‘tadi va belgilangan kuni o‘zi sizga qaytadi.';
  }

  @override
  String get awaySubstitute => 'Kim almashtiradi';

  @override
  String get awayUntilPick => 'Qaysi kungacha';

  @override
  String awayUntil(String date) {
    return '$date gacha';
  }

  @override
  String get awayGo => 'Ustalarni topshirish';

  @override
  String awayNow(String date, String name) {
    return 'Siz $date gacha ta’tildasiz. Ustalaringizni $name olib bormoqda.';
  }

  @override
  String get awayBack => 'Qaytdim — ustalarni olish';

  @override
  String get awayCovering => 'Siz almashtiryapsiz';

  @override
  String awayCoveringLine(String count, String date) {
    return 'Ustalar: $count · $date gacha';
  }

  @override
  String get myQrTitle => 'Mening QR-kodim';

  @override
  String get myQrHint =>
      'Menejerga ko‘rsating — u skanerlab, kartangizni darhol ko‘radi';

  @override
  String get widgetToday => 'Bugun';

  @override
  String widgetDeliver(String count) {
    return 'Olib borish: $count';
  }

  @override
  String widgetPickup(String count) {
    return 'Olib ketish: $count';
  }

  @override
  String widgetOverdue(String count) {
    return 'Muddati o‘tgan: $count';
  }

  @override
  String get acceptAllAction => 'Hammasini qabul qilish';

  @override
  String get acceptWithDefects => 'Brak bor';

  @override
  String acceptAllConfirm(String name, String meters, String sum) {
    return '$name: hammasini braksiz qabul qilish — $meters m? ≈ $sum so‘m hisoblanadi.';
  }

  @override
  String get visitTitle => 'Tashrif';

  @override
  String get visitOpenCard => 'Usta kartasi';

  @override
  String get visitNothing =>
      'Hozir undan hech narsa olish yoki berish kerak emas';

  @override
  String visitPickup(String count) {
    return 'Olib ketish: $count';
  }

  @override
  String visitPickupAll(String count) {
    return 'Hammasini olish ($count)';
  }

  @override
  String visitPickedAll(String count) {
    return 'Olingan ishlar: $count';
  }

  @override
  String visitDeliver(String count) {
    return 'Berish: $count';
  }

  @override
  String get visitDeliverHint => 'U olganini o‘z ilovasida tasdiqlaydi';

  @override
  String get visitInProgress => 'Ishda';

  @override
  String get visitPay => 'To‘lov';

  @override
  String get payManyTitle => 'Bir nechtasiga to‘lash';

  @override
  String payManyConfirm(String count, String sum) {
    return '$count ta ustaga jami $sum so‘m naqd to‘lansinmi? Har biriga — to‘liq summasi.';
  }

  @override
  String payManyButton(String count, String sum) {
    return 'Tanlanganlarga: $count · $sum so‘m';
  }

  @override
  String payManyDone(String count) {
    return 'To‘landi: $count';
  }

  @override
  String payManyFailed(String names) {
    return 'bo‘lmadi: $names';
  }

  @override
  String get payManyComment => 'Bir nechtasiga to‘lov';

  @override
  String get permPresets => 'Tayyor to‘plamlar';

  @override
  String get presetManagerBasic => 'Yetkazish va olib ketish';

  @override
  String get presetManagerCash => 'To‘lovlar bilan';

  @override
  String get presetManagerStock => 'Omborchi';

  @override
  String get presetManagerFull => 'O‘z ustalari uchun hammasi';

  @override
  String get presetAdminStandard => 'Standart';

  @override
  String get presetAdminStock => 'Ombor va katalog';

  @override
  String get presetAdminMoney => 'Pul';

  @override
  String get searchHint => 'Qidiruv';

  @override
  String get searchExplain =>
      'Ustalar, ishlar, buyurtmalar, materiallar, modellar, xodimlar — ism, telefon yoki kod bo‘yicha';

  @override
  String get searchNothing => 'Hech narsa topilmadi';

  @override
  String get searchWorks => 'Ishlar';

  @override
  String get searchMaterials => 'Materiallar';

  @override
  String get moneyTitle => 'Pul';

  @override
  String get moneyOwed => 'Ustalarga qarzdorlik';

  @override
  String moneyOwedWorkers(String count) {
    return 'Ustalar: $count';
  }

  @override
  String get moneyEarned => 'Ish uchun hisoblangan';

  @override
  String get moneyPaid => 'To‘langan';

  @override
  String get moneySales => 'Sotuvlar';

  @override
  String get moneyMaterials => 'Materiallar';

  @override
  String get moneyExpenses => 'Xarajatlar';

  @override
  String get moneyProfit => 'Foyda';

  @override
  String get chatSlideToCancel => 'Chapga — bekor qilish';

  @override
  String get chatPoll => 'So‘rovnoma';

  @override
  String get chatPollQuestion => 'Savol';

  @override
  String get chatPollQuestionHint => 'Masalan: shanba kuni kim ish ola oladi?';

  @override
  String chatPollOption(String n) {
    return '$n-variant';
  }

  @override
  String get chatPollAddOption => 'Variant qo‘shish';

  @override
  String get chatPollMultiple => 'Bir nechtasini tanlash mumkin';

  @override
  String get chatPollSingle => 'Bitta javob';

  @override
  String get chatPollAnswer => 'Javob berish';

  @override
  String chatPollVotes(String n) {
    return 'Javob berganlar: $n';
  }

  @override
  String get chatPollWho => 'Kim javob berdi';

  @override
  String get chatPollVoters => 'Kim qanday javob berdi';

  @override
  String get chatLocation => 'Joylashuv';

  @override
  String get chatMyLocation => 'Mening joylashuvim';

  @override
  String get chatOpenMap => 'Xaritada ochish';

  @override
  String get chatLocationDenied =>
      'Telefon sozlamalarida joylashuvga ruxsat bering';

  @override
  String get chatLocationFailed =>
      'Joylashuv aniqlanmadi. Geolokatsiyani yoqib, qayta urinib ko‘ring';

  @override
  String get chatContact => 'Kontakt';

  @override
  String get chatCardAttach => 'Ish / buyurtma / usta';

  @override
  String get chatCardSearch => 'Ish, usta yoki buyurtmani toping';

  @override
  String get chatOpenCard => 'Ochish';

  @override
  String get chatVideoNote => 'Video xabar';

  @override
  String get chatSaved => 'Saqlanganlar';

  @override
  String get chatSaveToSaved => 'Saqlanganlarga';

  @override
  String get chatSavedDone => 'Saqlanganlarga qo‘shildi';

  @override
  String get chatSendSilent => 'Ovozsiz yuborish';

  @override
  String get chatSendLater => 'Keyinroq yuborish';

  @override
  String get chatLaterInPast => 'Kelajakdagi vaqtni tanlang';

  @override
  String chatLaterSaved(String when) {
    return '$when da yuboriladi';
  }

  @override
  String get chatScheduled => 'Rejalashtirilgan xabarlar';

  @override
  String get chatScheduledNone => 'Rejalashtirilgan xabarlar yo‘q';

  @override
  String get quickReplies => 'Tezkor javoblar';

  @override
  String get quickReplyAdd => 'Javob qo‘shish';

  @override
  String get quickReply1 => 'Sizga kelyapman';

  @override
  String get quickReply2 => '30 daqiqada boraman';

  @override
  String get quickReply3 => 'Ish tayyormi? Bugun olib keta olaman';

  @override
  String get quickReply4 => 'Rahmat, hammasini oldim';

  @override
  String get chatArchive => 'Arxiv';

  @override
  String get chatArchiveAction => 'Arxivlash';

  @override
  String get chatUnarchive => 'Arxivdan qaytarish';

  @override
  String get chatMarkUnread => 'O‘qilmagan deb belgilash';

  @override
  String get chatMarkRead => 'O‘qilgan deb belgilash';

  @override
  String get chatMuteFor => 'Ovozsiz…';

  @override
  String get chatMute1h => '1 soatga';

  @override
  String get chatMute8h => '8 soatga';

  @override
  String get chatMute2d => '2 kunga';

  @override
  String get chatMuteForever => 'Butunlay';

  @override
  String get chatFolders => 'Papkalar';

  @override
  String get chatTranscribe => 'Matn';

  @override
  String get chatTranscribeEmpty => 'Soʻzlarni aniqlab boʻlmadi';

  @override
  String get chatTranslate => 'Tarjima qilish';

  @override
  String get chatTranslateBy => 'Tarjima: Yandex';

  @override
  String get chatCameraFailed =>
      'Kamerani yoqib boʻlmadi. Sozlamalarda kamera va mikrofonga ruxsat bering';

  @override
  String get chatVideoNoteHint =>
      'Yozish uchun qizil tugmani bosing (60 soniyagacha)';

  @override
  String get chatVideoNoteReady => 'Tayyor — yuboring yoki qayta yozing';

  @override
  String get chatSwitchCamera => 'Kamerani almashtirish';

  @override
  String get chatFolderAll => 'Hammasi';

  @override
  String get chatFolderNew => 'Papka';

  @override
  String get chatFolderEdit => 'Papkani oʻzgartirish';

  @override
  String get chatFolderName => 'Nomi';

  @override
  String get chatFolderNameHint => 'Masalan: Ish';

  @override
  String get chatFolderChats => 'Papkadagi chatlar';

  @override
  String get chatAddToFolder => 'Papkaga qoʻshish';
}

/// The translations for Uzbek, using the Cyrillic script (`uz_Cyrl`).
class AppLocalizationsUzCyrl extends AppLocalizationsUz {
  AppLocalizationsUzCyrl() : super('uz_Cyrl');

  @override
  String get appTitle => 'Diamoraa';

  @override
  String get welcomeTitle => 'Хуш келибсиз';

  @override
  String get phone => 'Телефон';

  @override
  String get password => 'Парол';

  @override
  String get signIn => 'Кириш';

  @override
  String get signOut => 'Чиқиш';

  @override
  String get continueAction => 'Давом этиш';

  @override
  String get signInWithTelegram => 'Телеграм орқали кириш';

  @override
  String get orDivider => 'ёки';

  @override
  String get openingTelegram => 'Телеграм очилмоқда…';

  @override
  String get telegramLoginFailed =>
      'Телеграмни очиб бўлмади. Қайта уриниб кўринг.';

  @override
  String get workersUseTelegram =>
      'Усталар Телеграм орқали киради — пастдаги тугмани босинг.';

  @override
  String get pendingApprovalTitle => 'Ариза юборилди';

  @override
  String get pendingApprovalBody =>
      'Администратор тасдиқлашини кутинг. Қарор тайёр бўлиши билан Телеграмга ёзамиз.';

  @override
  String get rejectedTitle => 'Ариза рад этилди';

  @override
  String get workerPausedTitle => 'Профил тўхтатилган';

  @override
  String get workerPausedBody => 'Администраторга мурожаат қилинг.';

  @override
  String get backToLogin => 'Кириш экранига';

  @override
  String get checkAgainInTelegram => 'Телеграм орқали қайта уриниш';

  @override
  String get invalidCredentials => 'Телефон ёки парол нотўғри';

  @override
  String get invalidCode => 'Код нотўғри ёки муддати ўтган';

  @override
  String get tooManyAttempts => 'Жуда кўп уриниш. Кейинроқ уриниб кўринг.';

  @override
  String get noConnection => 'Серверга уланиб бўлмади. Интернетни текширинг.';

  @override
  String get genericError => 'Хатолик юз берди';

  @override
  String get checkYourInput => 'Киритилган маълумотларни текширинғ';

  @override
  String get phoneRequired => 'Телефон рақамини киритинғ';

  @override
  String get invalidPhoneFormat => 'Тўғри телефон рақамини киритинғ';

  @override
  String get userNotFound =>
      'Бу рақамли фойдаланувчи топилмади. Администраторга мурожаат қилинг.';

  @override
  String get accountDisabled =>
      'Ҳисобингиз фаол эмас. Администраторга мурожаат қилинг.';

  @override
  String get retry => 'Қайта уриниш';

  @override
  String get cancel => 'Бекор қилиш';

  @override
  String get confirm => 'Тасдиқлаш';

  @override
  String get offlineBanner =>
      'Интернет ёъқ — сақланган маълумотлар кўрсатилмоқда';

  @override
  String get workers => 'Усталар';

  @override
  String get profile => 'Профил';

  @override
  String get home => 'Асосий';

  @override
  String get search => 'Қидирув: исм, телефон';

  @override
  String get tabPending => 'Аризалар';

  @override
  String get tabActive => 'Фаол';

  @override
  String get tabAll => 'Ҳаммаси';

  @override
  String get emptyPending => 'Янги аризалар ёъқ';

  @override
  String get emptyPendingHint =>
      'Уста Телеграмда рўйхатдан ўтганда ариза шу ерда дарҳол пайдо бўлади';

  @override
  String get emptyWorkers => 'Бу ерда ҳозирча ҳеч ким ёъқ';

  @override
  String newRegistration(String name) {
    return 'Янги ариза: $name';
  }

  @override
  String get statusPending => 'Кўриб чиқилмоқда';

  @override
  String get statusActive => 'Фаол';

  @override
  String get statusPaused => 'Тўхтатилган';

  @override
  String get statusRejected => 'Рад этилган';

  @override
  String get statusArchived => 'Архивда';

  @override
  String get call => 'Қўнғироқ қилиш';

  @override
  String get route => 'Маршрут қуриш';

  @override
  String get location => 'Жойлашув';

  @override
  String get noLocation => 'Жойлашув олинмаган';

  @override
  String get secondaryPhone => 'Қўшимча телефон';

  @override
  String get notes => 'Изоҳлар';

  @override
  String get collateral => 'Гаров';

  @override
  String get collateralMoney => 'Пул';

  @override
  String get collateralItem => 'Буюм';

  @override
  String get collateralPending => 'Еълон қилинган, ҳали қабул қилинмаган';

  @override
  String get collateralHeld => 'Бизда сақланмоқда';

  @override
  String get collateralReturned => 'Қайтарилган';

  @override
  String get receiveCollateral => 'Гаровни қабул қилиш';

  @override
  String get receivedNote => 'Изоҳ (ихтиёрий)';

  @override
  String get estimatedValue => 'Баҳоланган қиймат, сўм';

  @override
  String get storageLocation => 'Сақланадиган жой';

  @override
  String get history => 'Тарих';

  @override
  String get approve => 'Тасдиқлаш';

  @override
  String get reject => 'Рад этиш';

  @override
  String get approveTitle => 'Устани тасдиқлайсизми?';

  @override
  String get collateralReceivedCheck => 'Гаров жисмонан қабул қилинди';

  @override
  String get rejectTitle => 'Аризани рад этиш';

  @override
  String get rejectReason => 'Сабаб (уста кўради)';

  @override
  String get required => 'Мажбурий майдон';

  @override
  String get approvedDone =>
      'Уста тасдиқланди. Унга Телеграмда хабар юборилди.';

  @override
  String get rejectedDone => 'Ариза рад этилди';

  @override
  String get myStatusPending => 'Аризангиз кўриб чиқилмоқда';

  @override
  String get myStatusActive => 'Сиз жамоадасиз ✨';

  @override
  String get balanceToReceive => 'Олинадиган сумма';

  @override
  String get devices => 'Қурилмалар';

  @override
  String get thisDevice => 'шу қурилма';

  @override
  String get revoke => 'Сеансни тугатиш';

  @override
  String get logoutAll => 'Барча қурилмалардан чиқиш';

  @override
  String get language => 'Тил';

  @override
  String get currency => 'сўм';

  @override
  String get save => 'Сақлаш';

  @override
  String get payRateTitle => '9 м учун нарх';

  @override
  String payRateSubtitle(int meters) {
    return 'Битта $meters м тўплам учун тўлов';
  }

  @override
  String get payRateAppliesToAll =>
      'Нарх ҳамма учун битта. Уни ўзгартирсангиз, барча усталарда дарҳол ўзгаради. Қабул қилинган иш қайта ҳисобланмайди.';

  @override
  String get payRateChange => 'Нархни ўзгартириш';

  @override
  String payRateNew(int meters) {
    return '$meters м учун янги нарх';
  }

  @override
  String get payRateInvalid => '1 дан 10 000 000 гача сумма киритинғ';

  @override
  String payRateSaved(String amount) {
    return 'Нарх янгиланди: $amount сўм';
  }

  @override
  String get payRateHistory => 'Нарх тарихи';

  @override
  String get payRateStart => 'бошланғич';

  @override
  String payRatePerKit(int meters) {
    return '$meters метр учун тўлов';
  }

  @override
  String get locationServicesOffTitle => 'Геолокатсияни ёқинғ';

  @override
  String get locationServicesOffBody =>
      'Геолокатсиясиз илова иш қаерда эканини кўрсата олмайди. Уни телефон созламаларида ёқинг.';

  @override
  String get locationForegroundTitle => 'Геолокатсияга рухсат беринғ';

  @override
  String get locationForegroundBody =>
      'Илова очиқ турганда жойлашувингиз керак, шунда администратор уни кўриб туради.';

  @override
  String get locationBackgroundTitle => 'Фонда геолокатсияга рухсат беринғ';

  @override
  String get locationBackgroundBody =>
      'Илова ёпиқ бўлганда ҳам жойлашув аниқ бўлиши учун \"Доим\" рухсатини беринг.';

  @override
  String get locationDeniedForeverBody =>
      'Рухсат рад этилди. Илова созламаларини очинг ва геолокатсияга қўлда рухсат беринг.';

  @override
  String get locationOpenSettings => 'Геолокатсия созламаларини очиш';

  @override
  String get locationAllow => 'Рухсат бериш';

  @override
  String get locationOpenAppSettings => 'Илова созламаларини очиш';

  @override
  String get catalog => 'Бизнинг ишларимиз';

  @override
  String get catalogEmpty => 'Ҳозирча ҳеч нарса эълон қилинмаган';

  @override
  String get catalogEmptyHint =>
      'Администратор эълон қилиши билан янги ишлар шу ерда пайдо бўлади';

  @override
  String get catalogNew => 'Янги';

  @override
  String get catalogCall => 'Қўнғироқ қилиш';

  @override
  String get catalogTelegram => 'Телеграмга ёзиш';

  @override
  String get catalogAvailable => 'Мавжуд';

  @override
  String get catalogOnRequest => 'Буюртма билан';

  @override
  String get catalogUnavailable => 'Ҳозирча ёъқ';

  @override
  String get catalogAdminTitle => 'Ишлар каталоги';

  @override
  String get catalogAddItem => 'Иш қўшиш';

  @override
  String get catalogItemName => 'Номи';

  @override
  String get catalogItemDescription => 'Тавсиф';

  @override
  String get catalogStatusDraft => 'Қоралама';

  @override
  String get catalogStatusPublished => 'Еълон қилинган';

  @override
  String get catalogStatusHidden => 'Яширилган';

  @override
  String get catalogPublish => 'Еълон қилиш';

  @override
  String get catalogHide => 'Яшириш';

  @override
  String get catalogAddPhoto => 'Расм қўшиш';

  @override
  String get catalogMarkNew => 'Янги деб белгилаш';

  @override
  String get catalogPublishNeedsPhoto =>
      'Еълон қилишдан олдин камида битта расм қўшинғ';

  @override
  String get catalogDeleteBlocked =>
      'Бу иш аллақачон ишлатилган — фақат яшириш мумкин';

  @override
  String get catalogSaved => 'Сақланди';

  @override
  String get team => 'Жамоа';

  @override
  String get teamUsers => 'Фойдаланувчилар';

  @override
  String get teamManagers => 'Менежерлар';

  @override
  String get teamAddUser => 'Фойдаланувчи қўшиш';

  @override
  String get teamFullName => 'Ф.И.Ш.';

  @override
  String get teamRole => 'Рол';

  @override
  String get roleSuperAdmin => 'Бош администратор';

  @override
  String get roleAdmin => 'Администратор';

  @override
  String get roleManager => 'Менежер';

  @override
  String get roleWorker => 'Уста';

  @override
  String get teamStatusActive => 'Фаол';

  @override
  String get teamStatusSuspended => 'Ўчирилган';

  @override
  String get teamDeactivate => 'Ўчириш';

  @override
  String get teamReactivate => 'Ёқиш';

  @override
  String get teamNoAccess => 'Жамоани кўриш учун ҳуқуқ етарли эмас';

  @override
  String get teamCreated =>
      'Фойдаланувчи яратилди. Парол бир марта кўрсатилади:';

  @override
  String teamAssignedWorkers(int count) {
    return 'Усталар: $count';
  }

  @override
  String get teamEditUser => 'Фойдаланувчи';

  @override
  String get teamSaveChanges => 'Сақлаш';

  @override
  String get teamPhoneTaken => 'Бу рақам бошқа фойдаланувчида банд';

  @override
  String teamConfirmRoleChange(String from, String to) {
    return 'Ролни $from дан $to га ўзгартирасизми?';
  }

  @override
  String get teamRoleChanged => 'Рол ўзгартирилди';

  @override
  String get teamSaved => 'Ўзгаришлар сақланди';

  @override
  String get settingsCompanyContact => 'Компания телефони ва Телеграм';

  @override
  String get settingsPhone => 'Компания телефони';

  @override
  String get settingsTelegram => 'Телеграм (@ сиз)';

  @override
  String get settingsCompanyContactHint =>
      'Бу маълумотларни усталар каталогда \"Қўнғироқ қилиш\" ва \"Телеграмга ёзиш\" тугмаларида кўради';

  @override
  String get audit => 'Амаллар журнали';

  @override
  String get auditEmpty => 'Ҳозирча ёзувлар ёъқ';

  @override
  String get locations => 'Жамоа геолокатсияси';

  @override
  String get locationsEmpty => 'Жойлашув маълумотлари ҳали ёъқ';

  @override
  String locationStaleMinutes(int minutes) {
    return 'Жойлашув $minutes дақиқа олдин янгиланган';
  }

  @override
  String locationRecentMinutes(int minutes) {
    return 'Жойлашув $minutes дақиқа олдин янгиланган';
  }

  @override
  String get locationJustNow => 'Жойлашув: ҳозир';

  @override
  String get onlineNow => 'онлайн';

  @override
  String get offlineNow => 'офлайн';

  @override
  String get map => 'Харита';

  @override
  String get mapListView => 'Рўйхат';

  @override
  String get mapMapView => 'Харита';

  @override
  String get mapEmpty => 'Ҳозирча координата ёъқ';

  @override
  String get mapOpenProfile => 'Профилни очиш';

  @override
  String get qrScan => 'QR сканерлаш';

  @override
  String get qrScanHint => 'Камерани QR-кодга қаратинғ';

  @override
  String get qrInvalid => 'QR-код топилмади ёки мавжуд эмас';

  @override
  String get qrWorkerFound => 'Уста топилди';

  @override
  String get qrKitFound => 'Тўплам топилди';

  @override
  String get showQr => 'QR-кодни кўрсатиш';

  @override
  String get workerQrTitle => 'Шахсий QR-код';

  @override
  String get inventory => 'Омбор';

  @override
  String get materials => 'Материаллар';

  @override
  String get materialsEmpty => 'Ҳозирча материал ёъқ';

  @override
  String get materialAdd => 'Янги материал';

  @override
  String get stockLow => 'кам';

  @override
  String get stockReceipt => 'Кирим';

  @override
  String get stockReceiptHint => 'Омборга материал келиб тушиши';

  @override
  String get quantity => 'Миқдор';

  @override
  String get kits => 'Тўпламлар';

  @override
  String get kitsEmpty => 'Ҳозирча тўплам ёъқ';

  @override
  String get kitAssemble => 'Тўпламни йиғиш';

  @override
  String get kitAssembled => 'Тўплам йиғилди, QR-код тайёр';

  @override
  String get kitCount => 'Тўпламлар сони';

  @override
  String get kitTemplateName => 'Тўплам номи';

  @override
  String get kitAddMaterial => 'Материал';

  @override
  String get commentOptional => 'Изоҳ (ихтиёрий)';

  @override
  String get materialName => 'Материал номи';

  @override
  String get materialMinStock => 'Минимал қолдиқ';

  @override
  String get workMeters9 => '9 м';

  @override
  String get workMeters18 => '18 м';

  @override
  String get workMeters27 => '27 м';

  @override
  String workDoneOf(String done, String planned) {
    return 'Бажарилди $done / $planned м';
  }

  @override
  String get workDueDate => 'Муддат';

  @override
  String get workExpectedEarning => 'Кутилаётган тўлов';

  @override
  String get workMaterials => 'Материаллар';

  @override
  String get workUpdateProgress => 'Жараённи янгилаш';

  @override
  String get workReady => 'Иш тайёр';

  @override
  String workReadyConfirm(String planned) {
    return 'Тасдиқланг: $planned м тайёр. Шундан кейин иш олиб кетилади.';
  }

  @override
  String get workProblem => 'Муаммо бор';

  @override
  String get workMetersDone => 'Неча метр тайёр';

  @override
  String get workStatusReadyToDeliver => 'Қабул қилиниши кутилмоқда';

  @override
  String get workStatusDelivered => 'Уста қабул қилди';

  @override
  String get workStatusInProgress => 'Ишланмоқда';

  @override
  String get workStatusReadyForPickup => 'Тайёр, олиб кетишни кутмоқда';

  @override
  String get workStatusPickedUp => 'Олиб кетилди';

  @override
  String get workStatusUnderReview => 'Текширувда';

  @override
  String get workCurrentTitle => 'Жорий иш';

  @override
  String get workNoCurrent => 'Ҳозирча фаол иш ёъқ';

  @override
  String get workNoCurrentHint =>
      'Сизга топшириқ берилиши билан у шу ерда пайдо бўлади';

  @override
  String get workPickedUp => 'Олдим';

  @override
  String get insufficientStockGeneric => 'Омборда материал етарли эмас';

  @override
  String get statusChangedMeanwhile =>
      'Бу амал энди мавжуд эмас, чунки топшириқ ҳолати ўзгарди.';

  @override
  String insufficientStockDetail(String material) {
    return 'Материал етарли эмас: $material';
  }

  @override
  String get back => 'Орқага';

  @override
  String get next => 'Кейингиси';

  @override
  String get assignCreateTitle => 'Ишни тайёрлаш';

  @override
  String get assignStepProduct => 'Модел';

  @override
  String get assignStepVariant => 'Ранғ';

  @override
  String get assignStepVolume => 'Иш ҳажми';

  @override
  String get assignStepDue => 'Муддат';

  @override
  String get assignStepComment => 'Изоҳ';

  @override
  String get assignStepSummary => 'Тасдиқлаш';

  @override
  String get assignNoVariants =>
      'Бу моделда ҳали ранглар ёъқ. Аввал каталогга ранг қўшинг.';

  @override
  String get assignNoKitTemplate =>
      'Бу вариант учун материал тўплами мавжуд эмас.';

  @override
  String get assignSelectWorker => 'Мастарицани танланғ';

  @override
  String get assignSelectProduct => 'Моделни танланғ';

  @override
  String get assignSelectVariant => 'Рангни танланғ';

  @override
  String get assignDueOptional => 'Муддат (ихтиёрий)';

  @override
  String get assignNoDueDate => 'Муддатсиз';

  @override
  String get assignSummaryWorker => 'Мастарица';

  @override
  String get assignSummaryModel => 'Модел';

  @override
  String get assignSummaryColor => 'Ранғ';

  @override
  String get assignSummaryVolume => 'Ҳажм';

  @override
  String get assignSummaryMaterials => 'Материаллар';

  @override
  String get assignSummaryDue => 'Муддат';

  @override
  String get assignSummaryPayment => 'Ҳисобланган тўлов';

  @override
  String get assignSubmit => 'Ишни тайёрлаш';

  @override
  String get assignSuccess => 'Иш берилди';

  @override
  String get assignSuccessHint => 'Материаллар омбордан ечилди, QR-код тайёр';

  @override
  String get assignEmptyProducts => 'Каталогда ҳали модел ёъқ';

  @override
  String get assignEmptyWorkers => 'Фаол мастарицалар ёъқ';

  @override
  String get assignmentDetailTitle => 'Топшириқ';

  @override
  String get assignmentQr => 'Топшириқ QR-коди';

  @override
  String get assignmentHistory => 'Тарих';

  @override
  String get assignmentMaterialsIssued => 'Берилган материаллар';

  @override
  String get deliveriesTitle => 'Етказиш ва олиб кетиш';

  @override
  String get deliveryNeeded => 'Етказиш керак';

  @override
  String get deliveryConfirmTitle => 'Етказишни тасдиқланғ';

  @override
  String get deliveryConfirmBody => 'Материаллар мастарицага топширилдими?';

  @override
  String get deliveryDone => 'Топширишни бошлаш';

  @override
  String get pickupNeeded => 'Олиб кетиш керак';

  @override
  String get dashboardTab => 'Умумий кўриниш';

  @override
  String get dashActiveWorkers => 'Фаол мастарицалар';

  @override
  String get dashInProgress => 'Ишда';

  @override
  String get dashNeedsAcceptance => 'Қабулда';

  @override
  String get dashOverdue => 'Муддати ўтган';

  @override
  String get queueEmpty => 'Ҳозирча бўш';

  @override
  String get dueBy => 'муддат ';

  @override
  String get workersDueEmpty => 'Барча тўловлар ёпилган';

  @override
  String get greetingMorning => 'Хайрли тонғ';

  @override
  String get greetingDay => 'Хайрли кун';

  @override
  String get greetingEvening => 'Хайрли кеч';

  @override
  String get dashProblems => 'Муаммолар бор';

  @override
  String get dashAttention => 'Диққат талаб қилади';

  @override
  String get dashAllClear => 'Ҳаммаси назоратда';

  @override
  String get dashToday => 'Бугун';

  @override
  String get dashDueToday => 'Муддати бугун';

  @override
  String get dashDeliveredToday => 'Етказилди';

  @override
  String get dashPickedUpToday => 'Олиб кетилди';

  @override
  String get dashPaidToday => 'Тўланди';

  @override
  String get dashQuickActions => 'Тезкор амаллар';

  @override
  String get actionMap => 'Харита';

  @override
  String get actionStock => 'Омбор';

  @override
  String get more => 'Яна';

  @override
  String get managerLabel => 'Менежер';

  @override
  String get noManager => 'Менежерсиз';

  @override
  String get historyWork => 'Ишлар';

  @override
  String get historyMoney => 'Пул';

  @override
  String get historyEmpty => 'Ҳозирча ҳеч нарса ёъқ';

  @override
  String attnOverdue(int count) {
    return '$count та иш муддати ўтган';
  }

  @override
  String attnToDeliver(int count) {
    return '$count та етказиш';
  }

  @override
  String attnToPickup(int count) {
    return '$count та иш тайёр';
  }

  @override
  String attnAcceptance(int count) {
    return '$count та иш қабулни кутмоқда';
  }

  @override
  String attnRework(int count) {
    return '$count та иш қайта ишлашда';
  }

  @override
  String attnWorkersDue(int count) {
    return '$count та мастарица тўловни кутмоқда';
  }

  @override
  String get acceptanceTitle => 'Ишни қабул қилиш';

  @override
  String get acceptanceBrought => 'Келтирилди';

  @override
  String get acceptanceAccepted => 'Қабул қилинди';

  @override
  String get acceptanceDefective => 'Брак';

  @override
  String get acceptanceRework => 'Қайта ишлаш';

  @override
  String get acceptanceCalculated => 'Ҳисобланади';

  @override
  String get acceptanceSubmit => 'Ишни қабул қилиш';

  @override
  String get acceptanceSuccess => 'Иш қабул қилинди';

  @override
  String get acceptanceInvalid =>
      'Қабул + брак + қайта ишлаш келтирилганига тенг бўлиши керак';

  @override
  String get acceptancePhotoOptional => 'Фото (ихтиёрий)';

  @override
  String get payoutTitle => 'Нақд тўлаш';

  @override
  String get payoutDue => 'Тўланадиган';

  @override
  String get payoutFull => 'Бутун сумма';

  @override
  String get payoutHalf => 'Ярми';

  @override
  String get payoutAmountLabel => 'Сумма';

  @override
  String get payoutConfirmTitle => 'Тўловни тасдиқланғ';

  @override
  String payoutConfirmBody(String amount) {
    return 'Ҳақиқатан ҳам $amount нақд бердингизми?';
  }

  @override
  String get payoutSubmit => 'Тўлаш';

  @override
  String get payoutSuccess => 'Тўлов ёзилди';

  @override
  String get payoutNothingDue => 'Тўланадиган: 0 сўм';

  @override
  String get payoutExceedsBalance => 'Сумма устага тегишли миқдордан катта';

  @override
  String get earningsEarned => 'Ишлаб топилди';

  @override
  String get earningsPaid => 'Тўланди';

  @override
  String get earningsHistory => 'Тарих';

  @override
  String get earningsEmpty => 'Ҳозирча ҳисобланганлар ёъқ';

  @override
  String get actionAssign => 'Ишни тайёрлаш';

  @override
  String get actionScanQr => 'QR сканерлаш';

  @override
  String get actionAccept => 'Ишни қабул қилиш';

  @override
  String get actionPayout => 'Нақд тўлаш';

  @override
  String get actionCall => 'Қўнғироқ';

  @override
  String get actionRoute => 'Ёъналиш';

  @override
  String get statusAccepted => 'Қабул қилинди';

  @override
  String get statusPartiallyAccepted => 'Қисман қабул қилинди';

  @override
  String get statusReworkRequired => 'Қайта ишлаш керак';

  @override
  String get statusCompleted => 'Якунланди';

  @override
  String get statusCancelled => 'Бекор қилинди';

  @override
  String get teamSearch => 'Исм ёки телефон';

  @override
  String get filterAll => 'Ҳаммаси';

  @override
  String get filterActive => 'Фаоллар';

  @override
  String get filterDisabled => 'Ўчирилганлар';

  @override
  String get lastSeenLabel => 'Охирги марта онлайн';

  @override
  String get createdLabel => 'Яратилган';

  @override
  String get neverSeen => 'Ҳали кирмаган';

  @override
  String get changeRole => 'Ролни ўзгартириш';

  @override
  String get changeRoleHint =>
      'Рол ўзгаргач, фойдаланувчи барча қурилмалардан чиқади ва янги ҳуқуқлар билан қайта киради.';

  @override
  String get roleSuperAdminHint => 'Ҳаммаси, роллар ва ҳуқуқлар ҳам';

  @override
  String get roleAdminHint => 'Усталар, омбор, тўловлар, каталоғ';

  @override
  String get roleManagerHint => 'Фақат ўз усталари';

  @override
  String get permissionsTitle => 'Кириш ҳуқуқлари';

  @override
  String get permissionsAllSuper =>
      'Бош администраторда барча ҳуқуқлар бор. Уларни чеклаб бўлмайди.';

  @override
  String get permissionsSaved => 'Ҳуқуқлар сақланди';

  @override
  String get permissionsDefault => 'рол учун стандарт';

  @override
  String permissionsCount(int on, int total) {
    return '$on / $total';
  }

  @override
  String get deactivateUser => 'Фойдаланувчини ўчириш';

  @override
  String deactivateConfirm(String name) {
    return '$name ўчирилсинми? Кириш барча қурилмаларда дарҳол тақиқланади. Бутун тарих сақланади.';
  }

  @override
  String get restoreUser => 'Тиклаш';

  @override
  String get userDeactivated => 'Фойдаланувчи ўчирилди';

  @override
  String get userRestored => 'Фойдаланувчи тикланди';

  @override
  String get resetPassword => 'Янги парол бериш';

  @override
  String get resetPasswordConfirm =>
      'Ески парол ишламай қолади, фойдаланувчи барча қурилмалардан чиқади.';

  @override
  String get tempPasswordTitle => 'Вақтинчалик парол';

  @override
  String get tempPasswordHint =>
      'Паролни ходимга шахсан беринг. У фақат бир марта кўрсатилади.';

  @override
  String get copy => 'Нусхалаш';

  @override
  String get copied => 'Нусха олинди';

  @override
  String get editDetails => 'Маълумотларни ўзгартириш';

  @override
  String get activeImmediately => 'Дарҳол фаол';

  @override
  String get workersOfManager => 'Менежер усталари';

  @override
  String get changeManager => 'Менежерни алмаштириш';

  @override
  String get managerChanged => 'Менежер ўзгартирилди';

  @override
  String get archiveWorker => 'Устани архивлаш';

  @override
  String get archiveConfirm =>
      'Уста кира олмайди ва янги иш олмайди. Тарих, тўловлар ва гаров сақланади.';

  @override
  String get workerArchived => 'Уста архивда';

  @override
  String get restoreWorker => 'Устани тиклаш';

  @override
  String get workerRestored => 'Уста тикланди';

  @override
  String get workersViaTelegram =>
      'Усталар Телеграм-бот орқали ўзлари рўйхатдан ўтади — бу ерда фақат ходимлар қўшилади.';

  @override
  String get usersEmpty => 'Ҳеч ким топилмади';

  @override
  String get youLabel => 'сиз';

  @override
  String get permGroupUsers => 'Фойдаланувчилар';

  @override
  String get permGroupWorkers => 'Усталар';

  @override
  String get permGroupCollateral => 'Гаров';

  @override
  String get permGroupAssignments => 'Топшириқлар';

  @override
  String get permGroupFinance => 'Тўловлар ва пул';

  @override
  String get permGroupCatalog => 'Каталоғ';

  @override
  String get permGroupInventory => 'Омбор';

  @override
  String get permGroupMap => 'Харита';

  @override
  String get permGroupSettings => 'Созламалар';

  @override
  String get permGroupAudit => 'Амаллар журнали';

  @override
  String get permUserViewAll => 'Ходимларни кўриш';

  @override
  String get permUserCreate => 'Ходим қўшиш';

  @override
  String get permUserUpdate => 'Ходим маълумотларини ўзгартириш';

  @override
  String get permUserDeactivate => 'Ходимларни ўчириш';

  @override
  String get permRoleAssign => 'Ролларни ўзгартириш';

  @override
  String get permPermissionManage => 'Ҳуқуқларни созлаш';

  @override
  String get permWorkerViewAll => 'Барча усталарни кўриш';

  @override
  String get permWorkerViewAssigned => 'Ўз усталарини кўриш';

  @override
  String get permWorkerApprove => 'Аризаларни тасдиқлаш';

  @override
  String get permWorkerUpdate => 'Уста картасини ўзгартириш';

  @override
  String get permWorkerAssignManager => 'Менежер тайинлаш';

  @override
  String get permCollateralView => 'Гаровни кўриш';

  @override
  String get permCollateralManage => 'Гаровни қабул қилиш ва қайтариш';

  @override
  String get permAssignmentViewAll => 'Барча топшириқларни кўриш';

  @override
  String get permAssignmentViewAssigned => 'Ўз усталари топшириқлари';

  @override
  String get permAssignmentCreate => 'Иш бериш';

  @override
  String get permAssignmentAccept => 'Ишни қабул қилиш';

  @override
  String get permFinanceViewAll => 'Барча ҳисоб-китоблар';

  @override
  String get permFinanceViewAssigned => 'Ўз усталари ҳисоб-китоби';

  @override
  String get permCashPayout => 'Нақд тўлаш';

  @override
  String get permProfitView => 'Фойдани кўриш';

  @override
  String get permCatalogView => 'Каталогни кўриш';

  @override
  String get permCatalogManage => 'Каталогни ўзгартириш';

  @override
  String get permInventoryView => 'Омборни кўриш';

  @override
  String get permInventoryManage => 'Кирим ва тўпламлар';

  @override
  String get permMapViewAll => 'Харита: ҳаммаси';

  @override
  String get permMapViewAssigned => 'Харита: ўз усталари';

  @override
  String get permLiveLocationViewAll => 'Геолокатсия: ҳаммаси';

  @override
  String get permLiveLocationViewAssigned => 'Геолокатсия: ўз усталари';

  @override
  String get permPayRateManage => '9 м нархини ўзгартириш';

  @override
  String get permSettingsManage => 'Компания созламалари';

  @override
  String get permAuditView => 'Амаллар журналини кўриш';

  @override
  String get auditUserCreate => 'Яратилди';

  @override
  String get auditUserUpdate => 'Маълумотлар ўзгартирилди';

  @override
  String get auditUserDeactivate => 'Ўчирилди';

  @override
  String get auditUserReactivate => 'Тикланди';

  @override
  String get auditUserRoleChange => 'Рол ўзгартирилди';

  @override
  String get auditUserPermissionChange => 'Ҳуқуқлар ўзгартирилди';

  @override
  String get auditUserPasswordReset => 'Янги парол берилди';

  @override
  String get settingsTitle => 'Созламалар';

  @override
  String get changePassword => 'Паролни ўзгартириш';

  @override
  String get currentPassword => 'Жорий парол';

  @override
  String get newPassword => 'Янги парол';

  @override
  String get repeatPassword => 'Янги паролни такрорланғ';

  @override
  String get passwordsDontMatch => 'Пароллар мос эмас';

  @override
  String get passwordTooShort => 'Камида 8 та белги';

  @override
  String get wrongCurrentPassword => 'Жорий парол нотўғри';

  @override
  String get passwordChanged =>
      'Парол ўзгартирилди. Бошқа қурилмалар ҳисобдан чиқди.';

  @override
  String get setPassword => 'Парол ўрнатиш';

  @override
  String get setPasswordHint =>
      'Фойдаланувчи барча қурилмалардан чиқади. Паролни шахсан беринг.';

  @override
  String get passwordSet => 'Парол ўрнатилди';

  @override
  String get showOnMap => 'Харитада кўрсатиш';

  @override
  String get showOnMapHint => 'Харитага рухсати борлар кўради';

  @override
  String get hiddenOnMapHint => 'Яширилган: жойлашувни фақат сиз кўрасиз';

  @override
  String locationUpdatedHours(int hours, int minutes) {
    return 'Жойлашув $hours соат $minutes дақиқа олдин янгиланган';
  }

  @override
  String locationUpdatedOn(String date) {
    return 'Жойлашув: $date';
  }

  @override
  String get permPasswordSet => 'Ходимларга парол ўрнатиш';

  @override
  String get passwordForLogin => 'Кириш пароли';

  @override
  String get passwordForLoginHint => 'Ўзингиз ўйлаб топинг ва шахсан беринғ';

  @override
  String get userCreated => 'Фойдаланувчи яратилди. Паролни шахсан беринг.';

  @override
  String get telegramLoginHint => 'Ҳамма учун — паролсиз, Телеграм орқали';

  @override
  String get staffSignIn => 'Ходимлар учун кириш';

  @override
  String get workWaitingTitle => 'Сизни янги иш кутмоқда';

  @override
  String get workKitReadyTitle => 'Тўпламингиз қабул қилишга тайёр';

  @override
  String get workKitReadyHint =>
      'Ходим олиб келган тўпламдаги QR-кодни сканерланғ';

  @override
  String get workWaitingHint =>
      'Ходим тўпламни олиб келади. У QR-кодни сканерлаганда, шу ерда қабул қилиш тугмаси чиқади.';

  @override
  String get workScanQr => 'QR-ни сканерлаш';

  @override
  String get receiveTitle => 'Ишни қабул қилиш';

  @override
  String get receiveCheckHint =>
      'Тасдиқлашдан олдин иш ва материалларни текширинг.';

  @override
  String get receiveConfirm => 'Қабул қилишни тасдиқлаш';

  @override
  String get receiveProblem => 'Муаммо бор';

  @override
  String receiveKits(int count) {
    return 'Тўпламлар: $count';
  }

  @override
  String get receiveDone => 'Иш қабул қилинди!';

  @override
  String get receiveDoneHint => 'Материаллар энди сизда. Ишингизга омад!';

  @override
  String get receiveAlready => 'Сиз бу ишни аллақачон қабул қилгансиз';

  @override
  String get receiveForeign => 'Бу тўплам бошқа устага мўлжалланган.';

  @override
  String get receiveNotStarted => 'Аввал ходим бу QR-ни сканерлаши керак';

  @override
  String get receiveExpired =>
      'Топшириш вақти тугади. Ходимдан QR-ни қайта сканерлашни сўранг.';

  @override
  String get receiveScanHint => 'Камерани тўпламдаги QR-кодга қаратинғ';

  @override
  String get receiveGoHome => 'Бош саҳифага';

  @override
  String get problemTitle => 'Нима нотўғри?';

  @override
  String get problemShortage => 'Материал етарли эмас';

  @override
  String get problemWrongColor => 'Ранг нотўғри';

  @override
  String get problemWrongModel => 'Модел нотўғри';

  @override
  String get problemWrongMeters => 'Метраж нотўғри';

  @override
  String get problemDamaged => 'Шикастланган';

  @override
  String get problemOther => 'Бошқа';

  @override
  String get problemComment => 'Изоҳ (ихтиёрий)';

  @override
  String get problemSend => 'Юбориш';

  @override
  String get problemSent => 'Ходим хабарингизни олди. Иш ҳали топширилмаган.';

  @override
  String get handoffStart => 'Топширишни бошлаш';

  @override
  String get handoffStartTitle => 'Тўпламни устага топширасизми?';

  @override
  String get handoffStartBody =>
      'Шундан сўнг уста ўз иловасида ушбу QR-ни сканерлайди ва қабул қилишни тасдиқлайди. Материаллар фақат унинг тасдиғидан кейин унга ўтади.';

  @override
  String get handoffWaiting => 'Уста тасдиғи кутилмоқда';

  @override
  String get handoffWaitingHint =>
      'Устадан иловани очиб, ушбу QR-ни сканерлашини сўранғ';

  @override
  String get handoffWorkerScanned =>
      'Уста QR-ни сканерлади ва тўпламни текширмоқда';

  @override
  String handoffReceived(String name) {
    return '$name тўпламни олди';
  }

  @override
  String get handoffProblemTitle => 'Уста муаммо ҳақида хабар берди';

  @override
  String get handoffRestart => 'Топширишни қайтадан бошлаш';

  @override
  String get handoffExpiredLabel => 'Топшириш вақти тугади';

  @override
  String timelineStarted(String name) {
    return 'Топшириш бошланди · $name';
  }

  @override
  String get timelineScanned => 'Уста QR-ни сканерлади';

  @override
  String get timelineConfirmed => 'Уста қабул қилишни тасдиқлади';

  @override
  String get timelineProblem => 'Уста муаммо ҳақида хабар берди';

  @override
  String get handoffTimelineTitle => 'Топшириш';

  @override
  String get materialsAtWorker => 'Материаллар устада';

  @override
  String get materialsPrepared => 'Тайёрланган материаллар';

  @override
  String get workRemaining => 'Қолди';

  @override
  String get addWorker => 'Қўшиш';

  @override
  String get addWorkerTitle => 'Уста қўшиш';

  @override
  String get addWorkerHint =>
      'Биз ҳавола берамиз. Уста уни Телеграмда очади — ва дарҳол жамоада, анкетасиз ва тасдиқсиз.';

  @override
  String get addWorkerGetLink => 'Ҳавола олиш';

  @override
  String get addWorkerFullName => 'Фамилия ва исм';

  @override
  String get addWorkerManager => 'Менежер';

  @override
  String get addWorkerNoManager => 'Менежерсиз';

  @override
  String get addWorkerLinkReady =>
      'QR-ни устага кўрсатинг — у телефон камерасини қаратади. Ёки ҳаволани юборинг. Ҳавола 7 кун амал қилади ва бир марта очилади.';

  @override
  String get addWorkerSendTelegram => 'Телеграмда юбориш';

  @override
  String get addWorkerCopy => 'Ҳаволани нусхалаш';

  @override
  String get addWorkerCopied => 'Ҳавола нусхаланди';

  @override
  String get invitesPending => 'Таклиф қилинган — ҳаволани ҳали очмаган';

  @override
  String get inviteCancel => 'Бекор қилиш';

  @override
  String get deleteWorker => 'Устани ўчириш';

  @override
  String deleteWorkerConfirm(String name) {
    return '$name барча рўйхатлардан, харитадан ва ҳисоботлардан ёъқолади ва бошқа кира олмайди. Олдинги ишлар ва тўловлар тарихда «Ўчирилган уста» сифатида қолади. Буни қайтариб бўлмайди.';
  }

  @override
  String get deleteWorkerForever => 'Бутунлай ўчириш';

  @override
  String get deleteWorkerBlocked =>
      'Ўчириб бўлмайди: устада иш, пул ёки қабул қилинган гаров бор — бу ёзувлар ҳисобот ва тўловлар учун керак. Уни архивлаш мумкин: у кира олмайди, тарих сақланади.';

  @override
  String get deleteWorkerDone => 'Уста ўчирилди';

  @override
  String get permWorkerDelete => 'Усталарни ўчириш';

  @override
  String get chooseWork => 'Иш танлаш';

  @override
  String get orderWork => 'Бу ишга буюртма бериш';

  @override
  String get orderColor => 'Ранғ';

  @override
  String get orderVolume => 'Неча метр';

  @override
  String get orderNote => 'Истак (ихтиёрий)';

  @override
  String get orderSend => 'Аризани юбориш';

  @override
  String get orderSent => 'Ариза юборилди! Менежер ишни тайёрлайди.';

  @override
  String get orderAlreadyPending =>
      'Сизда аллақачон ариза бор — жавобни кутинг ёки бош саҳифада бекор қилинг.';

  @override
  String get myRequestPending => 'Ариза юборилди';

  @override
  String get myRequestPendingHint => 'Менежер жавобини кутяпмиз';

  @override
  String get myRequestRejected => 'Ариза қабул қилинмади';

  @override
  String get myRequestCancel => 'Аризани бекор қилиш';

  @override
  String get jobRequestsTitle => 'Ишга аризалар';

  @override
  String get jobRequestsEmpty => 'Янги аризалар ёъқ';

  @override
  String jobRequestsCount(int count) {
    return 'Ишга аризалар: $count';
  }

  @override
  String get jobRequestRejectReason => 'Сабаб (уста кўради)';

  @override
  String updateReady(String version) {
    return 'Янги версия $version тайёр';
  }

  @override
  String get updateInstall => 'Ўрнатиш';

  @override
  String get updateAllowInstall =>
      'Diamoraa учун ўрнатишга рухсат беринг ва яна босинғ';

  @override
  String get ageNow => 'ҳозир';

  @override
  String ageMinutes(int minutes) {
    return '$minutes дақиқа олдин';
  }

  @override
  String ageHours(int hours, int minutes) {
    return '$hours соат $minutes дақиқа олдин';
  }

  @override
  String get qrRecognized => 'QR аниқланди';

  @override
  String get handoffStartedToast =>
      'Топшириш бошланди — уста шу QR-ни сканерласин';

  @override
  String get qrPrint => 'QR-ни чоп этиш';

  @override
  String get noticesTitle => 'Билдиришномалар';

  @override
  String get noticesReadAll => 'Ҳаммасини ўқилган деб белгилаш';

  @override
  String get noticesEmpty => 'Ҳозирча билдиришномалар ёъқ';

  @override
  String get reportsTitle => 'Ҳисоботлар';

  @override
  String get reportDay => 'Кун';

  @override
  String get reportWeek => 'Ҳафта';

  @override
  String get reportMonth => 'Ой';

  @override
  String get reportIssued => 'Берилди';

  @override
  String get reportAccepted => 'Қабул қилинди';

  @override
  String get reportOverdue => 'Муддати ўтган';

  @override
  String get reportDefective => 'Брак';

  @override
  String get reportByWorker => 'Усталар бўйича';

  @override
  String get reportEmpty => 'Бу даврда ҳеч нарса бўлмаган';

  @override
  String get reportLowStock => 'Омборда тугаяпти';

  @override
  String get reportExcelHint =>
      'Excel учун юклаб олиш — веб-панелда: Ҳисоботлар → «Excel учун юклаб олиш».';

  @override
  String get myMonthsTitle => 'Ойлар бўйича даромадим';

  @override
  String get m1 => 'Январ';

  @override
  String get m2 => 'Феврал';

  @override
  String get m3 => 'Март';

  @override
  String get m4 => 'Апрел';

  @override
  String get m5 => 'Май';

  @override
  String get m6 => 'Июн';

  @override
  String get m7 => 'Июл';

  @override
  String get m8 => 'Август';

  @override
  String get m9 => 'Сентябр';

  @override
  String get m10 => 'Октябр';

  @override
  String get m11 => 'Ноябр';

  @override
  String get m12 => 'Декабр';

  @override
  String get qaAssign => 'Иш';

  @override
  String get qaScan => 'QR';

  @override
  String get qaMap => 'Харита';

  @override
  String get qaStock => 'Омбор';

  @override
  String get qaPay => 'Тўлов';

  @override
  String get assignCancel => 'Ишни бекор қилиш';

  @override
  String get assignCancelReason => 'Сабаб';

  @override
  String get assignCancelReturned => 'Материаллар омборга қайтди';

  @override
  String get assignCancelled => 'Иш бекор қилинди';

  @override
  String get assignChangeDue => 'Муддатни ўзгартириш';

  @override
  String get userDelete => 'Ходимни ўчириш';

  @override
  String userDeleteConfirm(String name) {
    return '$name бутунлай ўчирилади.';
  }

  @override
  String get userDeleteBlocked =>
      'Ўчириб бўлмайди: ходимда тарих бор (ишлар, тўловлар, омбор). Уни ўчириб қўйиш мумкин.';

  @override
  String get userDeleted => 'Ходим ўчирилди';

  @override
  String get qrNotYours =>
      'Бу уста бошқа менежерга бириктирилган. Администратордан уни сизга бириктиришни сўранг.';

  @override
  String get qrRevoked =>
      'Бу QR энди ишламайди: иш тугаган ёки бекор қилинган, ёки уста ўчирилган.';

  @override
  String get errOpenWork =>
      'Аввал унинг ишларини тугатинг ёки бекор қилинг ва гаровни қайтаринг — кейин ўчириш мумкин.';

  @override
  String get errInUse =>
      'Материал ҳозир ишлатилмоқда: устада ёки тўпламда. Аввал уни у ердан олиб ташланг.';

  @override
  String errInUseKits(String kits) {
    return 'Материал тўпламларда бор: $kits. Аввал шу тўпламларни ўчиринг ёки ўзгартиринг.';
  }

  @override
  String get deleteAction => 'Ўчириш';

  @override
  String get deleteDone => 'Ўчирилди';

  @override
  String catalogDeleteConfirm(String name) {
    return '«$name» ҳаммадан каталогдан ёъқолади. Берилган ишлар тарихда қолади. Буни қайтариб бўлмайди.';
  }

  @override
  String materialDeleteConfirm(String name, String left) {
    return '«$name» омбордан ёъқолади. Қолдиқ ($left) ҳисобдан чиқарилади. Буни қайтариб бўлмайди.';
  }

  @override
  String kitDeleteConfirm(String name) {
    return '«$name» тўплами омбордан ёъқолади. Берилган ишлар тарихда қолади. Буни қайтариб бўлмайди.';
  }

  @override
  String get permCatalogDelete => 'Каталогдан ўчириш';

  @override
  String get permInventoryDelete => 'Материал ва тўпламларни ўчириш';

  @override
  String get assignManagerTitle => 'Менежер бириктириш';

  @override
  String get assignManagerSave => 'Бириктириш';

  @override
  String assignManagerDone(int count) {
    return 'Тайёр: $count уста';
  }

  @override
  String get assignWorkersToManager => 'Усталарни бириктириш';

  @override
  String get auditClear => 'Журнални тозалаш';

  @override
  String get auditClearConfirm =>
      'Журнал бошидан бошланади — биринчи қаторда сизнинг исмингиз билан «Журнал тозаланди» бўлади. Эски ёзувлар бу ерда кўринмайди, лекин базадан ўчирилмайди.';

  @override
  String get collateralsTitle => 'Гаровлар';

  @override
  String get collateralsWithUs => 'Ҳозир бизда';

  @override
  String collateralsItems(int count) {
    return '$count та буюм';
  }

  @override
  String get collateralsTabHeld => 'Бизда';

  @override
  String get collateralsTabPending => 'Олинмаган';

  @override
  String get collateralsTabReturned => 'Қайтарилган';

  @override
  String get collateralsEmpty => 'Бу ерда бўш';

  @override
  String get collateralReturnTitle => 'Гаровни қайтариш';

  @override
  String get collateralReturnNote => 'Қандай қайтарилди';

  @override
  String get collateralReturnConfirm => 'Уста гаровни қайтариб олди';

  @override
  String get collateralReturnedToast => 'Гаров қайтарилди';

  @override
  String get mapFilterAll => 'Ҳаммаси';

  @override
  String get mapFilterToDeliver => 'Етказиш керак';

  @override
  String get mapFilterToPickup => 'Олиб кетишга тайёр';

  @override
  String get mapFilterOverdue => 'Муддати ўтган';

  @override
  String get mapFilterAllManagers => 'Барча менежерлар';

  @override
  String get mapAtHome =>
      'Уйда — рўйхатдан ўтгандаги манзил (телефон ҳозир жойлашувни юбормаяпти)';

  @override
  String get ratingTitle => 'Усталар рейтинги';

  @override
  String get ratingThreeMonths => '3 ой';

  @override
  String get ratingHalfYear => 'Ярим йил';

  @override
  String ratingLine(String meters, String defect, int late, int total) {
    return '$meters м · брак $defect% · кечикди $late/$total';
  }

  @override
  String get ratingHowScored =>
      '100 баллдан: 40% — ҳажм (ойига ≈54 м = максимум), 35% — браксиз, 25% — ўз вақтида.';

  @override
  String get profitTitle => 'Фойда';

  @override
  String get profitAdd => 'Сотув ёки харажат';

  @override
  String get profitSale => 'Сотув';

  @override
  String get profitExpense => 'Харажат';

  @override
  String get profitSales => 'Сотувлар';

  @override
  String get profitLabor => 'Усталарга';

  @override
  String get profitMaterials => 'Материаллар';

  @override
  String get profitExpenses => 'Харажатлар';

  @override
  String get profitCustomer => 'Харидор (ихтиёрий)';

  @override
  String get profitNoPriceHint =>
      '* Айрим материалларнинг харид нархи кўрсатилмаган — улар ҳисобланмади. Нархни веб-панелдаги омборда киритинг.';

  @override
  String get profitDeleteConfirm =>
      'Бу ёзув ўчирилсинми? Ойлик фойда қайта ҳисобланади.';

  @override
  String get expenseFuel => 'Бензин / етказиш';

  @override
  String get expensePackaging => 'Қадоқлаш';

  @override
  String get expenseOther => 'Бошқа';

  @override
  String get stockValueTitle => 'Омбор қиймати (харид нархида)';

  @override
  String stockValueSplit(String shelf, String homes) {
    return 'омборда $shelf · усталарда $homes';
  }

  @override
  String stockValueNoPrice(String names) {
    return 'Нархсиз: $names';
  }

  @override
  String get systemTitle => 'Тизим ҳолати';

  @override
  String get systemServer => 'Сервер';

  @override
  String get systemDatabase => 'Маълумотлар базаси';

  @override
  String systemUptime(int hours) {
    return '$hours соат ишлаяпти';
  }

  @override
  String get systemOk => 'жойида';

  @override
  String get systemDown => 'жавоб бермаяпти';

  @override
  String get systemBackups => 'Захира нусхалар';

  @override
  String get systemBackupsHidden =>
      'Сервер захира белгилари папкасини кўрмаяпти.';

  @override
  String get systemBackupFailed => 'хатў';

  @override
  String get systemBackupLate => 'анча бўлмади';

  @override
  String get backupDaily => 'База (ҳар куни)';

  @override
  String get backupWeekly => 'Базанинг тўлиқ нусхаси (ҳафтада бир)';

  @override
  String get backupFiles => 'Расмлар ва файллар';

  @override
  String get backupConfig => 'Созламалар';

  @override
  String get backupVerify => 'Тиклашни текшириш';

  @override
  String get backupRestore => 'Тиклаш';

  @override
  String get editName => 'Исмни ўзгартириш';

  @override
  String get firstName => 'Исм';

  @override
  String get lastName => 'Фамилия';

  @override
  String get nameSaved => 'Исм сақланди';

  @override
  String get nameTooShort => 'Исм камида 2 ҳарф бўлсин';

  @override
  String get chat => 'Чат';

  @override
  String get chatCompany => 'Умумий чат';

  @override
  String get chatNew => 'Янги чат';

  @override
  String get chatNewGroup => 'Янги гуруҳ';

  @override
  String get chatGroupName => 'Гуруҳ номи';

  @override
  String chatMembers(int count) {
    return 'Аъзолар: $count';
  }

  @override
  String get chatSearchPeople => 'Исм бўйича қидириш';

  @override
  String get chatEmpty => 'Ҳозирча хабар ёъқ — биринчи бўлиб ёзинғ';

  @override
  String get chatNoChats => 'Бу ерда ёзишмаларингиз бўлади';

  @override
  String get chatTypeMessage => 'Хабар';

  @override
  String get chatPhoto => 'Расм';

  @override
  String get chatCamera => 'Камера';

  @override
  String get chatVideo => 'Видеў';

  @override
  String get chatRecordVideo => 'Видео олиш';

  @override
  String get chatFile => 'Файл';

  @override
  String get chatVoice => 'Овозли хабар';

  @override
  String get chatAudio => 'Аудиў';

  @override
  String get chatHoldToRecord => 'Ёзиш учун микрофон тугмасини босиб туринғ';

  @override
  String get chatRecording => 'Ёзилмоқда… қўйиб юборинг — юборилади';

  @override
  String get chatMessageDeleted => 'Хабар ўчирилди';

  @override
  String get chatDeleteMessage => 'Хабарни ўчириш';

  @override
  String get chatDeleteMessageBody => 'Хабар барча аъзоларда ўчади.';

  @override
  String get chatCopy => 'Нусха олиш';

  @override
  String get chatCopied => 'Нусха олинди';

  @override
  String get chatFileTooLarge => 'Файл 50 MB дан катта — юбориб бўлмайди';

  @override
  String chatSendingProgress(int percent) {
    return 'Юборилмоқда… $percent%';
  }

  @override
  String get chatSendFailed => 'Юборилмади — қайта уриниш учун босинғ';

  @override
  String get chatRead => 'Ўқилди';

  @override
  String get chatLeaveGroup => 'Гуруҳдан чиқиш';

  @override
  String get chatLeaveGroupBody => 'Сиз бу гуруҳ хабарларини бошқа кўрмайсиз.';

  @override
  String get chatAddMembers => 'Аъзо қўшиш';

  @override
  String get chatRemoveMember => 'Гуруҳдан чиқариш';

  @override
  String get chatRename => 'Номини ўзгартириш';

  @override
  String get chatOwner => 'яратувчи';

  @override
  String get chatMicPermission =>
      'Овозли хабар ёзиш учун микрофонга рухсат беринғ';

  @override
  String get chatYou => 'Сиз';

  @override
  String get chatDownloading => 'Юкланмоқда…';

  @override
  String get chatFileFailed => 'Файлни юклаб бўлмади';

  @override
  String get chatCreate => 'Яратиш';

  @override
  String get chatGroupInfo => 'Гуруҳ ҳақида';

  @override
  String get chatToday => 'Бугун';

  @override
  String get chatYesterday => 'Кеча';

  @override
  String get chatCompanyHint => 'Барча ходимлар ва усталар';

  @override
  String get chatAttach => 'Бириктириш';

  @override
  String get chatSend => 'Юбориш';

  @override
  String get chatReply => 'Жавоб бериш';

  @override
  String get chatEdit => 'Ўзгартириш';

  @override
  String get chatEdited => 'ўзгартирилди';

  @override
  String get chatEditing => 'Таҳрирлаш';

  @override
  String get chatForward => 'Узатиш';

  @override
  String get chatForwardTo => 'Қаерга узатиш…';

  @override
  String get chatForwarded => 'Узатилди';

  @override
  String chatForwardedFrom(String name) {
    return '$name дан узатилган';
  }

  @override
  String get chatPin => 'Қадаш';

  @override
  String get chatUnpin => 'Қадашни олиш';

  @override
  String get chatPinned => 'Қадалган хабар';

  @override
  String get chatPinChat => 'Чатни қадаш';

  @override
  String get chatUnpinChat => 'Чатни қадашдан олиш';

  @override
  String get chatMute => 'Билдиришномасиз';

  @override
  String get chatUnmute => 'Билдиришномаларни ёқиш';

  @override
  String get chatSearch => 'Қидирув';

  @override
  String get chatSearchHint => 'Чатлар, одамлар, хабарлар';

  @override
  String get chatSectionChats => 'Чатлар';

  @override
  String get chatSectionPeople => 'Одамлар';

  @override
  String get chatSectionMessages => 'Хабарлар';

  @override
  String get chatNothingFound => 'Ҳеч нарса топилмади';

  @override
  String get chatTyping => 'ёзмоқда…';

  @override
  String chatTypingName(String name) {
    return '$name ёзмоқда…';
  }

  @override
  String get chatRecordingVoice => 'овозли хабар ёзмоқда…';

  @override
  String chatRecordingVoiceName(String name) {
    return '$name овозли хабар ёзмоқда…';
  }

  @override
  String chatLastSeen(String time) {
    return '$time да тармоқда эди';
  }

  @override
  String chatReplyTo(String name) {
    return 'Жавоб: $name';
  }

  @override
  String get chatEmoji => 'Еможи';

  @override
  String get chatNewChannel => 'Янги канал';

  @override
  String get chatChannelName => 'Канал номи';

  @override
  String get chatDescription => 'Тавсиф';

  @override
  String get chatAudience => 'Ким ўқийди';

  @override
  String get chatAudienceAll => 'Барча ходимлар ва усталар';

  @override
  String get chatAudienceStaff => 'Фақат ходимлар';

  @override
  String get chatAudienceWorkers => 'Фақат усталар';

  @override
  String get chatAudienceCustom => 'Танланган одамлар';

  @override
  String chatChoosePeople(int count) {
    return 'Одамларни танлаш ($count)';
  }

  @override
  String get chatChannelHint =>
      'Фақат канал админлари эълон қилади; ўқувчилар эълонларни кўради ва билдиришнома олади.';

  @override
  String get chatChannelReadOnly =>
      'Бу канал: фақат унинг админлари эълон қилади';

  @override
  String get chatGroupReadOnly => 'Фақат гуруҳ админлари ёза олади';

  @override
  String get chatOnlyAdminsWrite => 'Фақат админлар ёза олади';

  @override
  String get chatMakeAdmin => 'Админ қилиш';

  @override
  String get chatRemoveAdmin => 'Админликдан олиш';

  @override
  String get chatAddAdmin => 'Админ қўшиш';

  @override
  String get chatAdmin => 'админ';

  @override
  String get chatChangePhoto => 'Расмни ўзгартириш';

  @override
  String get chatInfo => 'Чат ҳақида маълумот';

  @override
  String get chatChannelInfo => 'Канал ҳақида';

  @override
  String get chatTabMembers => 'Аъзолар';

  @override
  String get chatTabMedia => 'Медиа';

  @override
  String get chatTabFiles => 'Файллар';

  @override
  String get chatTabVoice => 'Овозли';

  @override
  String get chatTabLinks => 'Ҳаволалар';

  @override
  String get chatNothingYet => 'Ҳозирча ҳеч нарса ёъқ';

  @override
  String chatSubscribers(int count) {
    return 'Канал · обуначилар: $count';
  }

  @override
  String get chatLeaveChannel => 'Каналдан чиқиш';

  @override
  String get chatVideoTooLarge => 'Видео 150 MB дан катта — юбориб бўлмайди';

  @override
  String get chatMyProfile => 'Менинг профилим';

  @override
  String get chatBio => 'Ўзим ҳақимда';

  @override
  String get chatBioHint => 'Исталган тафсилот: лавозим, туман ёки иш вақти.';

  @override
  String get chatUsername => 'Фойдаланувчи номи';

  @override
  String get chatUsernameHint =>
      'Лотин ҳарфлари, рақамлар ва _, камида 5 белги.';

  @override
  String get chatUsernameTaken => 'Бу ном банд';

  @override
  String get chatPhone => 'Телефон';

  @override
  String get chatRole => 'Рол';

  @override
  String get chatChangeAvatar => 'Профил расмини ўзгартириш';

  @override
  String get chatRemoveAvatar => 'Расмни ўчириш';

  @override
  String chatReadAt(String time) {
    return '$time да ўқилди';
  }

  @override
  String get chatNotReadYet => 'ҳали ўқилмаган';

  @override
  String get chatWhoRead => 'Ким ўқиди';

  @override
  String get chatNobodyYet => 'Ҳали ҳеч ким';

  @override
  String get chatClearHistory => 'Тарихни тозалаш';

  @override
  String get chatClearHistoryBody => 'Хабарлар фақат сизда ўчади.';

  @override
  String get chatDeleteChat => 'Чатни ўчириш';

  @override
  String get chatDeleteChatBody => 'Ёзишма фақат сизда ўчади.';

  @override
  String get chatProtectOn => 'Нусхалашни тақиқлаш';

  @override
  String get chatProtectOff => 'Нусхалашга рухсат бериш';

  @override
  String get chatProtected => 'Бу чатда нусхалаш ва узатиш тақиқланган';

  @override
  String get chatExport => 'Чат тарихини экспорт қилиш';

  @override
  String get chatSearchInChat => 'Шу чатда қидириш';

  @override
  String get chatOlderMessage => 'Бу хабар юқорида — юқорига суринғ';

  @override
  String get chatCancelUpload => 'Юборишни бекор қилиш';

  @override
  String chatCountPhotos(int count) {
    return 'Расмлар: $count';
  }

  @override
  String chatCountVideos(int count) {
    return 'Видеолар: $count';
  }

  @override
  String chatCountFiles(int count) {
    return 'Файллар: $count';
  }

  @override
  String chatCountVoice(int count) {
    return 'Овозли: $count';
  }

  @override
  String chatCountLinks(int count) {
    return 'Ҳаволалар: $count';
  }

  @override
  String get chatShowProfile => 'Профилни кўрсатиш';

  @override
  String chatTodayAt(String time) {
    return 'бугун $time да';
  }

  @override
  String chatYesterdayAt(String time) {
    return 'кеча $time да';
  }

  @override
  String chatDateAt(String date, String time) {
    return '$date $time да';
  }

  @override
  String get chatAudioPrev => 'Олдинги';

  @override
  String get chatAudioNext => 'Кейинги';

  @override
  String get chatAudioPlay => 'Тинглаш';

  @override
  String get chatAudioPause => 'Пауза';

  @override
  String get chatAudioSpeed => 'Тезлик';

  @override
  String get chatAudioMute => 'Овоз';

  @override
  String get chatAudioClose => 'Плеерни ёпиш';

  @override
  String updateDownloading(String version, int percent) {
    return 'Янги версия $version юкланмоқда — $percent%';
  }

  @override
  String get mapZoomIn => 'Яқинлаштириш';

  @override
  String get mapZoomOut => 'Узоқлаштириш';

  @override
  String get mapMyPlace => 'Мен қаердаман';

  @override
  String get mapNoMyPlace => 'Жойлашувингиз аниқланмади. Геолокатсияни ёқинг.';

  @override
  String get mapNorth => 'Шимолга';

  @override
  String get mapTraffic => 'Тирбандлик';

  @override
  String get mapShowAll => 'Ҳаммаси харитада';

  @override
  String get map3d => 'Ҳажмли кўриниш';

  @override
  String get updateAppVersion => 'Илова версияси';

  @override
  String get updateCheck => 'Текшириш';

  @override
  String get updateLatest => 'Сизда энг сўнгги версия';

  @override
  String stockLasts(int days) {
    return '≈ $days кунга етади';
  }

  @override
  String get goalTitle => 'Ой мақсади';

  @override
  String goalPlace(int place, int of) {
    return '$of тадан $place-ўрин';
  }

  @override
  String goalProgress(String done, int goal) {
    return '$goal м дан $done м';
  }

  @override
  String goalLeft(String left, int days) {
    return 'Яна $left м · ой охиригача $days кун';
  }

  @override
  String get goalDone => 'Мақсад бажарилди! Раҳмат 🎉';

  @override
  String goalNoGoal(String done) {
    return 'Бу ой қабул қилинди: $done м';
  }

  @override
  String get routeTitle => 'Маршрут';

  @override
  String routeReady(int count, String km) {
    return 'Маршрут: $count та бекат, ≈ $km км';
  }

  @override
  String routeBuild(int count) {
    return 'Маршрут тузиш ($count)';
  }

  @override
  String get routeOpenYandex => 'Яндех Харитада очиш';

  @override
  String get routeChange => 'Рўйхатни ўзгартириш';

  @override
  String get routeToPickup => 'ишни олиб кетиш';

  @override
  String get routeToDeliver => 'материалларни олиб бориш';

  @override
  String get routeOverdue => 'муддати ўтган';

  @override
  String get routeNobody => 'Харитада ҳали усталар ёъқ.';

  @override
  String get routeNoStart =>
      'Жойлашувингиз аниқланмади — маршрут биринчи нуқтадан бошланади.';

  @override
  String get offlineSaved =>
      'Интернет ёъқ — телефонда сақланди, алоқа пайдо бўлганда ўзи юборилади';

  @override
  String offlineSent(int count) {
    return 'Интернетсиз қилинганлар юборилди: $count';
  }

  @override
  String offlineWaiting(int count) {
    return 'Юборилмаган: $count';
  }

  @override
  String get offlineWillSend => 'интернет бўлганда ўзи юборилади';

  @override
  String get offlineSendNow => 'Ҳозир юбориш';

  @override
  String offlineRefused(String what) {
    return 'Қабул қилинмади: $what';
  }

  @override
  String get offlineRefusedHint =>
      'Сервер бу амални қабул қилмади. Қайта бажаринг ёки менежерга қўнғироқ қилинг.';

  @override
  String get offlineKindProgress => 'қанча қилинди';

  @override
  String get offlineKindReady => 'иш тайёр';

  @override
  String get offlineKindReceive => 'ишни қабул қилиш';

  @override
  String get offlineScanNoInternet =>
      'Интернет ёъқ. Сақлаш мумкин — алоқа пайдо бўлганда иш қабул қилинади.';

  @override
  String get offlineScanSave => 'Сақлаш ва кейинроқ қабул қилиш';

  @override
  String get assignSuggestTitle =>
      'Аввал — кимга бериш яхшироқ (бўш, тез, нуқсонсиз, ўз вақтида)';

  @override
  String get visitTimeTitle => 'Қачон келишлари қулай';

  @override
  String get visitTimeShort => 'Қулай';

  @override
  String get visitTimeNotSet => 'Кўрсатилмаган — кун ва соатларни танланғ';

  @override
  String get visitTimeHint =>
      'Менежер бу вақтни кўради ва материалларни сизга қулай вақтда олиб келади.';

  @override
  String get visitFrom => 'дан';

  @override
  String get visitTo => 'гача';

  @override
  String get visitTimeOrder => 'Бошланиш вақти тугашдан олдин бўлиши керак';

  @override
  String get visitTimeNote => 'Изоҳ (ихтиёрий)';

  @override
  String get visitTimeNoteHint => 'масалан: олдиндан қўнғироқ қилинғ';

  @override
  String get visitTimeClear => 'Вақтни олиб ташлаш';

  @override
  String get dayMon => 'Ду';

  @override
  String get dayTue => 'Се';

  @override
  String get dayWed => 'Ч';

  @override
  String get dayThu => 'Па';

  @override
  String get dayFri => 'Жу';

  @override
  String get daySat => 'Ш';

  @override
  String get daySun => 'Я';

  @override
  String get ordersTitle => 'Мижозлар буюртмалари';

  @override
  String get ordersEmpty => 'Ҳозирча бўш';

  @override
  String get ordersNew => 'Янги';

  @override
  String get ordersConfirmed => 'Тасдиқланган';

  @override
  String get ordersInWork => 'Ишда';

  @override
  String get ordersDone => 'Бажарилган';

  @override
  String get ordersCancelled => 'Бекор қилинган';

  @override
  String get ordersAll => 'Ҳаммаси';

  @override
  String get ordersAccept => 'Буюртмани қабул қилиш';

  @override
  String get ordersStart => 'Ишни бошлаш';

  @override
  String get ordersFinish => 'Тайёр';

  @override
  String get ordersCancel => 'Бекор қилиш';

  @override
  String get ordersCancelAsk => 'Бу буюртмани бекор қиласизми?';

  @override
  String get ordersFromSite => 'сайтдан';

  @override
  String get ordersFromBot => 'Телеграмдан';

  @override
  String get ordersFromPanel => 'ходим ёзган';

  @override
  String get ordersNoItem => 'Маҳсулот танланмаган';

  @override
  String ordersTotal(String m) {
    return 'Жами: $m м';
  }

  @override
  String get badgeFirstKit => 'Биринчи комплект';

  @override
  String get badge100 => '100 метр';

  @override
  String get badge500 => '500 метр';

  @override
  String get badgeGoal => 'Ой мақсади';

  @override
  String get badgeNoDefects => 'Браксиз';

  @override
  String get badgeOnTime => 'Ҳаммаси ўз вақтида';

  @override
  String get visitEveryDay => 'Ҳар куни';

  @override
  String get learnTitle => 'Ўқитиш';

  @override
  String get learnSubtitle => 'Қисқа видеолар: Diamoraa\'да қандай ишлаш';

  @override
  String get learnNone => 'Ҳозирча видео ёъқ. Кейинроқ қаранг.';

  @override
  String learnMinutes(int n) {
    return '$n дақ';
  }

  @override
  String get signInWithPassword => 'Парол билан кириш (ходимлар учун)';

  @override
  String get waitingForTelegram =>
      'Телеграмда кутяпмиз… Кейин шу ерга қайтинг.';

  @override
  String get progressTitle => 'Менинг ютуқларим';

  @override
  String get progressOpenHint =>
      'Қанча топширдингиз, сифат, бонус ва даромад калкулятори';

  @override
  String get progressThisMonth => 'Шу ой';

  @override
  String get progressAccepted => 'Топширилди';

  @override
  String get progressQuality => 'Браксиз';

  @override
  String get progressEarned => 'Ишлаб топилди';

  @override
  String get progressRecord => '🏆 Янги шахсий рекорд!';

  @override
  String progressBest(String month, String meters) {
    return 'Енг яхши ой: $month — $meters м';
  }

  @override
  String get progressAllTime => 'Барча вақт';

  @override
  String progressChecksCount(String count) {
    return 'Текширилган ишлар: $count';
  }

  @override
  String get progressChecks => 'Ишлар текшируви';

  @override
  String get progressNoChecks =>
      'Ишингиз қабул қилинганда, бу ерда текширув чиқади: нима қабул қилинди ва нима нотўғри';

  @override
  String get bonusQuality => 'Сифат учун бонус';

  @override
  String bonusRule(String percent, String maxDefect, String minMeters) {
    return 'Ойлик даромадга +$percent%, агар брак $maxDefect% дан ошмаса ва камида $minMeters м топширилса';
  }

  @override
  String bonusYes(String amount) {
    return 'Ҳозир сизга бонус ≈ $amount сўм. Шундай давом этинг!';
  }

  @override
  String bonusTooManyDefects(String defect) {
    return 'Бу ой брак $defect% — меъёрдан кўп. Кейинги ойда албатта бўлади!';
  }

  @override
  String bonusNeedMeters(String meters) {
    return 'Яна $meters м браксиз топширинг — бонус сизники';
  }

  @override
  String get bonusPaidOn1st =>
      'Бонус ҳар ойнинг 1-санасида ўтган ой учун берилади';

  @override
  String get calcTitle => 'Даромад калкулятори';

  @override
  String get calcHint => 'Неча метр топширасиз?';

  @override
  String calcResult(String amount) {
    return '≈ $amount сўм';
  }

  @override
  String calcWithBonus(String amount) {
    return '+ сифат бонуси ≈ $amount сўм';
  }

  @override
  String calcRate(String rate) {
    return '9 м учун $rate сўм ставка бўйича';
  }

  @override
  String get checkAccepted => 'Қабул қилинди';

  @override
  String get checkDefective => 'Брак';

  @override
  String get checkRework => 'Қайта ишлашга';

  @override
  String get workHowToSew => 'Қандай тикиш (видео)';

  @override
  String get acceptanceDefectPhoto => 'Брак расми';

  @override
  String get acceptanceWhatsWrong => 'Нима нотўғри? Уста буни кўради';

  @override
  String get idleTitle => 'Ишсиз турганлар';

  @override
  String get idleHint =>
      'Ишсиз усталарингиз: аввал иш сўраганлар, кейин узоқ кутаётганлар.';

  @override
  String get idleNone => 'Барча усталар иш билан банд 🎉';

  @override
  String idleDays(String days) {
    return '$days кундан бери ишсиз';
  }

  @override
  String get idleNeverWorked => 'Ҳали иш олмаган';

  @override
  String idleQuality(String percent) {
    return 'браксиз $percent%';
  }

  @override
  String get idleWantsWork => 'Иш сўрамоқда';

  @override
  String get idleGiveWork => 'Иш бериш';

  @override
  String idleBanner(String count) {
    return 'Ишсиз: $count';
  }

  @override
  String get remindersTitle => 'Еслатмалар';

  @override
  String get reminderAdd => 'Еслатиш';

  @override
  String get remindersEmpty => 'Еслатмалар ёъқ';

  @override
  String get remindersEmptyHint =>
      'Масалан: «Жума куни Нигорага қўнғироқ қилиш». «Эслатиш» тугмасини босинг.';

  @override
  String get reminderWhat => 'Нима ҳақида эслатиш';

  @override
  String get reminderWhatHint => 'Масалан: тайёр ишни олиб кетиш';

  @override
  String get reminderTomorrow => 'Ертага 9:00';

  @override
  String get reminderIn3Days => '3 кундан кейин';

  @override
  String get reminderNextMonday => 'Душанба куни';

  @override
  String reminderSaved(String when) {
    return '$when да эслатаман';
  }

  @override
  String get awayTitle => 'Таътил';

  @override
  String awayHint(String count) {
    return 'Таътилга кетяпсизми? Усталарингиз ($count) шу вақтга бошқа менежерга ўтади ва белгиланган куни ўзи сизга қайтади.';
  }

  @override
  String get awaySubstitute => 'Ким алмаштиради';

  @override
  String get awayUntilPick => 'Қайси кунгача';

  @override
  String awayUntil(String date) {
    return '$date гача';
  }

  @override
  String get awayGo => 'Усталарни топшириш';

  @override
  String awayNow(String date, String name) {
    return 'Сиз $date гача таътилдасиз. Усталарингизни $name олиб бормоқда.';
  }

  @override
  String get awayBack => 'Қайтдим — усталарни олиш';

  @override
  String get awayCovering => 'Сиз алмаштиряпсиз';

  @override
  String awayCoveringLine(String count, String date) {
    return 'Усталар: $count · $date гача';
  }

  @override
  String get myQrTitle => 'Менинг QR-кодим';

  @override
  String get myQrHint =>
      'Менежерга кўрсатинг — у сканерлаб, картангизни дарҳол кўради';

  @override
  String get widgetToday => 'Бугун';

  @override
  String widgetDeliver(String count) {
    return 'Олиб бориш: $count';
  }

  @override
  String widgetPickup(String count) {
    return 'Олиб кетиш: $count';
  }

  @override
  String widgetOverdue(String count) {
    return 'Муддати ўтган: $count';
  }

  @override
  String get acceptAllAction => 'Ҳаммасини қабул қилиш';

  @override
  String get acceptWithDefects => 'Брак бор';

  @override
  String acceptAllConfirm(String name, String meters, String sum) {
    return '$name: ҳаммасини браксиз қабул қилиш — $meters м? ≈ $sum сўм ҳисобланади.';
  }

  @override
  String get visitTitle => 'Ташриф';

  @override
  String get visitOpenCard => 'Уста картаси';

  @override
  String get visitNothing => 'Ҳозир ундан ҳеч нарса олиш ёки бериш керак эмас';

  @override
  String visitPickup(String count) {
    return 'Олиб кетиш: $count';
  }

  @override
  String visitPickupAll(String count) {
    return 'Ҳаммасини олиш ($count)';
  }

  @override
  String visitPickedAll(String count) {
    return 'Олинган ишлар: $count';
  }

  @override
  String visitDeliver(String count) {
    return 'Бериш: $count';
  }

  @override
  String get visitDeliverHint => 'У олганини ўз иловасида тасдиқлайди';

  @override
  String get visitInProgress => 'Ишда';

  @override
  String get visitPay => 'Тўлов';

  @override
  String get payManyTitle => 'Бир нечтасига тўлаш';

  @override
  String payManyConfirm(String count, String sum) {
    return '$count та устага жами $sum сўм нақд тўлансинми? Ҳар бирига — тўлиқ суммаси.';
  }

  @override
  String payManyButton(String count, String sum) {
    return 'Танланганларга: $count · $sum сўм';
  }

  @override
  String payManyDone(String count) {
    return 'Тўланди: $count';
  }

  @override
  String payManyFailed(String names) {
    return 'бўлмади: $names';
  }

  @override
  String get payManyComment => 'Бир нечтасига тўлов';

  @override
  String get permPresets => 'Тайёр тўпламлар';

  @override
  String get presetManagerBasic => 'Етказиш ва олиб кетиш';

  @override
  String get presetManagerCash => 'Тўловлар билан';

  @override
  String get presetManagerStock => 'Омборчи';

  @override
  String get presetManagerFull => 'Ўз усталари учун ҳаммаси';

  @override
  String get presetAdminStandard => 'Стандарт';

  @override
  String get presetAdminStock => 'Омбор ва каталоғ';

  @override
  String get presetAdminMoney => 'Пул';

  @override
  String get searchHint => 'Қидирув';

  @override
  String get searchExplain =>
      'Усталар, ишлар, буюртмалар, материаллар, моделлар, ходимлар — исм, телефон ёки код бўйича';

  @override
  String get searchNothing => 'Ҳеч нарса топилмади';

  @override
  String get searchWorks => 'Ишлар';

  @override
  String get searchMaterials => 'Материаллар';

  @override
  String get moneyTitle => 'Пул';

  @override
  String get moneyOwed => 'Усталарга қарздорлик';

  @override
  String moneyOwedWorkers(String count) {
    return 'Усталар: $count';
  }

  @override
  String get moneyEarned => 'Иш учун ҳисобланган';

  @override
  String get moneyPaid => 'Тўланган';

  @override
  String get moneySales => 'Сотувлар';

  @override
  String get moneyMaterials => 'Материаллар';

  @override
  String get moneyExpenses => 'Харажатлар';

  @override
  String get moneyProfit => 'Фойда';

  @override
  String get chatSlideToCancel => 'Чапга — бекор қилиш';

  @override
  String get chatPoll => 'Сўровнома';

  @override
  String get chatPollQuestion => 'Савол';

  @override
  String get chatPollQuestionHint => 'Масалан: шанба куни ким иш ола олади?';

  @override
  String chatPollOption(String n) {
    return '$n-вариант';
  }

  @override
  String get chatPollAddOption => 'Вариант қўшиш';

  @override
  String get chatPollMultiple => 'Бир нечтасини танлаш мумкин';

  @override
  String get chatPollSingle => 'Битта жавоб';

  @override
  String get chatPollAnswer => 'Жавоб бериш';

  @override
  String chatPollVotes(String n) {
    return 'Жавоб берганлар: $n';
  }

  @override
  String get chatPollWho => 'Ким жавоб берди';

  @override
  String get chatPollVoters => 'Ким қандай жавоб берди';

  @override
  String get chatLocation => 'Жойлашув';

  @override
  String get chatMyLocation => 'Менинг жойлашувим';

  @override
  String get chatOpenMap => 'Харитада очиш';

  @override
  String get chatLocationDenied =>
      'Телефон созламаларида жойлашувга рухсат беринғ';

  @override
  String get chatLocationFailed =>
      'Жойлашув аниқланмади. Геолокатсияни ёқиб, қайта уриниб кўринғ';

  @override
  String get chatContact => 'Контакт';

  @override
  String get chatCardAttach => 'Иш / буюртма / уста';

  @override
  String get chatCardSearch => 'Иш, уста ёки буюртмани топинғ';

  @override
  String get chatOpenCard => 'Очиш';

  @override
  String get chatVideoNote => 'Видео хабар';

  @override
  String get chatSaved => 'Сақланганлар';

  @override
  String get chatSaveToSaved => 'Сақланганларга';

  @override
  String get chatSavedDone => 'Сақланганларга қўшилди';

  @override
  String get chatSendSilent => 'Овозсиз юбориш';

  @override
  String get chatSendLater => 'Кейинроқ юбориш';

  @override
  String get chatLaterInPast => 'Келажакдаги вақтни танланғ';

  @override
  String chatLaterSaved(String when) {
    return '$when да юборилади';
  }

  @override
  String get chatScheduled => 'Режалаштирилган хабарлар';

  @override
  String get chatScheduledNone => 'Режалаштирилган хабарлар ёъқ';

  @override
  String get quickReplies => 'Тезкор жавоблар';

  @override
  String get quickReplyAdd => 'Жавоб қўшиш';

  @override
  String get quickReply1 => 'Сизга келяпман';

  @override
  String get quickReply2 => '30 дақиқада бораман';

  @override
  String get quickReply3 => 'Иш тайёрми? Бугун олиб кета оламан';

  @override
  String get quickReply4 => 'Раҳмат, ҳаммасини олдим';

  @override
  String get chatArchive => 'Архив';

  @override
  String get chatArchiveAction => 'Архивлаш';

  @override
  String get chatUnarchive => 'Архивдан қайтариш';

  @override
  String get chatMarkUnread => 'Ўқилмаган деб белгилаш';

  @override
  String get chatMarkRead => 'Ўқилган деб белгилаш';

  @override
  String get chatMuteFor => 'Овозсиз…';

  @override
  String get chatMute1h => '1 соатга';

  @override
  String get chatMute8h => '8 соатга';

  @override
  String get chatMute2d => '2 кунга';

  @override
  String get chatMuteForever => 'Бутунлай';

  @override
  String get chatFolders => 'Папкалар';

  @override
  String get chatTranscribe => 'Матн';

  @override
  String get chatTranscribeEmpty => 'Сўзларни аниқлаб бўлмади';

  @override
  String get chatTranslate => 'Таржима қилиш';

  @override
  String get chatTranslateBy => 'Таржима: Яндех';

  @override
  String get chatCameraFailed =>
      'Камерани ёқиб бўлмади. Созламаларда камера ва микрофонга рухсат беринғ';

  @override
  String get chatVideoNoteHint =>
      'Ёзиш учун қизил тугмани босинг (60 сониягача)';

  @override
  String get chatVideoNoteReady => 'Тайёр — юборинг ёки қайта ёзинғ';

  @override
  String get chatSwitchCamera => 'Камерани алмаштириш';

  @override
  String get chatFolderAll => 'Ҳаммаси';

  @override
  String get chatFolderNew => 'Папка';

  @override
  String get chatFolderEdit => 'Папкани ўзгартириш';

  @override
  String get chatFolderName => 'Номи';

  @override
  String get chatFolderNameHint => 'Масалан: Иш';

  @override
  String get chatFolderChats => 'Папкадаги чатлар';

  @override
  String get chatAddToFolder => 'Папкага қўшиш';
}
