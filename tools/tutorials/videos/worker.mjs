// For masters (ustalar): the Diamoraa app - sign in with Telegram, the current work, progress, money, profile.
import { freshApp } from '../mlib.mjs';

export default {
  name: 'worker',
  title: { uz: 'Ustalar uchun: Diamoraa ilovasi', ru: 'Для мастериц: приложение Diamoraa' },
  roles: ['WORKER'],
  app: true,
  setup: freshApp,
  async script(h) {
    await h.say({ uz: 'Diamoraa ilovasi. Avval tilni tanlang', ru: 'Приложение Diamoraa. Сначала выберите язык' });
    await h.tap("O'zbek");
    await h.say({ uz: 'Ustalar parolsiz, Telegram orqali kiradi', ru: 'Мастерицы входят без пароля, через Telegram' });
    await h.tap('Telegram orqali kirish', { after: 3500 });
    await h.say({ uz: 'Telegram ochiladi. Botda «START» tugmasini bosing', ru: 'Откроется Telegram. Нажмите в боте «START»' });
    await h.find('START BOT', { timeout: 40000 }).catch(() => undefined);
    await h.pause(3000);
    await h.telegramStart('+998901110002');
    await h.say({ uz: 'Ilova o‘zi ochiladi. Joylashuvga ruxsat bering', ru: 'Приложение откроется само. Разрешите доступ к местоположению' });
    if (await h.tapIfShown('Ruxsat berish', { after: 2500, timeout: 25000 })) {
      await h.say({ uz: '«Har doim ruxsat berish»ni tanlang — menejer sizni xaritada topadi', ru: 'Выберите «Разрешать всегда» — менеджер найдёт вас на карте' });
      if (await h.tapIfShown('Allow all the time', { after: 1500, timeout: 30000 })) await h.back(2500);
    }

    await h.say({ uz: '«Bizning ishlarimiz» — barcha mahsulotlar', ru: '«Наши работы» — все изделия' }, 2500);
    await h.say({ uz: '«Asosiy» — sizning joriy ishingiz', ru: '«Главная» — ваша текущая работа' });
    await h.tap('Asosiy', { after: 2500 });
    await h.say({ uz: 'Ish, rang, qancha metr va qancha pul olasiz', ru: 'Работа, цвет, сколько метров и сколько вы получите' }, 3500);
    await h.say({ uz: 'Qancha bajarganingizni yozib boring: «Jarayonni yangilash»', ru: 'Отмечайте, сколько сделали: «Jarayonni yangilash»' });
    await h.tap('Jarayonni yangilash', { after: 1800 });
    await h.tap(/^\d+\.\d$/, { after: 600 });
    await h.clearField(6);
    await h.type('8');
    await h.back(800); // hides the keyboard only
    await h.tap('Saqlash', { after: 2500 });
    await h.say({ uz: 'Hammasi tayyor bo‘lsa — «Ish tayyor». Menejer kelib oladi', ru: 'Когда всё готово — «Ish tayyor». Менеджер приедет и заберёт' }, 4000);
    await h.say({ uz: 'Yangi ish olib kelishganda — «QR-ni skanerlash» va tasdiqlang', ru: 'Когда привезут новую работу — «QR-ni skanerlash» и подтвердите' }, 4000);

    await h.say({ uz: 'Pastda: oylik maqsad, ishlab topgan pulingiz va to‘lovlar', ru: 'Ниже: цель месяца, заработок и выплаты' });
    await h.swipeUp(1100, 3000);
    await h.swipeUp(700, 3000);
    await h.swipeDown(1800, 1500);

    await h.say({ uz: '«Profil»: qachon kelishlari qulay — kun va soatni belgilang', ru: '«Профиль»: когда удобно, чтобы приезжали — выберите дни и часы' });
    await h.tap('Profil', { after: 3000 });
    await h.say({ uz: 'Savol bo‘lsa — «Chat»', ru: 'Есть вопрос — «Chat»' });
    await h.tap('Chat', { after: 3000 });
    await h.say({ uz: 'Omad! Yangi versiya chiqsa, ilova o‘zi taklif qiladi', ru: 'Удачи! Когда выйдет новая версия, приложение само предложит обновиться' }, 3500);
  },
};
