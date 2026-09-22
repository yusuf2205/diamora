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
  String get iAmAdmin => 'Men administratorman';

  @override
  String get iAmWorker => 'Men ustaman';

  @override
  String get phone => 'Telefon';

  @override
  String get password => 'Parol';

  @override
  String get signIn => 'Kirish';

  @override
  String get signOut => 'Chiqish';

  @override
  String get getCode => 'Telegramdan kod olish';

  @override
  String get codeSent => 'Kod Telegramingizga yuborildi. Uni pastga kiriting.';

  @override
  String get codeHint => 'Telegramdagi kod (6 raqam)';

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
    return '$minutes daqiqa oldin';
  }

  @override
  String get locationJustNow => 'hozirgina';

  @override
  String get onlineNow => 'onlayn';

  @override
  String get offlineNow => 'oflayn';
}
