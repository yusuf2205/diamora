// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Uzbek (`uz`).
class AppLocalizationsUz extends AppLocalizations {
  AppLocalizationsUz([String locale = 'uz']) : super(locale);

  @override
  String get appTitle => 'Yusmus';

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
  String get getCode => 'Telegramdan kod olish';

  @override
  String get codeSent => 'Kod Telegramingizga yuborildi. Uni pastga kiriting.';

  @override
  String get codeHint => 'Telegramdagi kod (6 raqam)';

  @override
  String get resendCode => 'Kodni qayta yuborish';

  @override
  String get workerLoginHint =>
      'Ro\'yxatdan o\'tgan Telegramingizga bir martalik kod yuboramiz.';

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
    return 'Oxirgi joylashuv $minutes daqiqa oldin';
  }

  @override
  String locationRecentMinutes(int minutes) {
    return '$minutes daqiqa oldin yangilangan';
  }

  @override
  String get locationJustNow => 'Hozir';

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
  String get kits => 'Toʻplamlar (9 m)';

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
  String get workStatusReadyToDeliver => 'Material yetkazilishini kutmoqda';

  @override
  String get workStatusDelivered => 'Material yetkazildi';

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
  String insufficientStockDetail(String material) {
    return 'Material yetarli emas: $material';
  }

  @override
  String get back => 'Orqaga';

  @override
  String get next => 'Keyingisi';

  @override
  String get assignCreateTitle => 'Ish berish';

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
  String get assignSubmit => 'Ish berish';

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
  String get deliveryDone => 'Yetkazildi';

  @override
  String get pickupNeeded => 'Olib ketish kerak';

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
  String get earningsEarned => 'Ishlab topildi';

  @override
  String get earningsPaid => 'Toʻlandi';

  @override
  String get earningsHistory => 'Tarix';

  @override
  String get earningsEmpty => 'Hozircha hisoblanganlar yoʻq';

  @override
  String get actionAssign => 'Ish berish';

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
}
