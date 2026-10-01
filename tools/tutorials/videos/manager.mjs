// For MANAGERs: the app on the road - deliver work by QR, pick up finished work, the map and the route, orders.
import { adb, freshApp } from '../mlib.mjs';

export default {
  name: 'manager',
  title: { uz: 'Menejer uchun: yo‘lda ilova bilan ishlash', ru: 'Для менеджера: работа в приложении в дороге' },
  roles: ['MANAGER'],
  app: true,
  async setup() {
    adb('emu', 'geo', 'fix', '69.2401', '41.2995'); // the manager is in Tashkent
    await freshApp();
  },
  async script(h) {
    await h.say({ uz: 'Xodimlar telefon va parol bilan kiradi', ru: 'Сотрудники входят по телефону и паролю' });
    await h.tapAt(540, 1638, 800);
    await h.type('900000003');
    await h.back(600);
    await h.tap('Продолжить', { after: 2000 });
    await h.tapAt(540, 1500, 800);
    await h.type('Demo-12345');
    await h.back(600);
    await h.tap('Войти', { after: 4000 });
    if (await h.tapIfShown('Разрешить', { after: 2500, timeout: 25000 })) {
      await h.say({ uz: 'Joylashuvga «Har doim» ruxsat bering', ru: 'Разрешите доступ к местоположению «Всегда»' });
      if (await h.tapIfShown('Allow all the time', { after: 1500, timeout: 30000 })) await h.back(2500);
    }

    await h.say({ uz: '«Обзор»: bugun kimga olib borish va kimdan olish kerak', ru: '«Обзор»: кому сегодня отвезти и у кого забрать' }, 3500);
    await h.say({ uz: 'Ish olib borish: «1 доставка»', ru: 'Отвезти работу: «1 доставка»' });
    await h.tap('1 доставка', { after: 2000 });
    await h.tap('S', { after: 2500 });
    await h.say({ uz: 'Ustaning oldida «Начать передачу» ni bosing', ru: 'У мастерицы нажмите «Начать передачу»' });
    await h.tap('Начать передачу', { after: 1800 });
    await h.tap('Начать передачу', { last: true, after: 2500 });
    await h.say({ uz: 'Usta o‘z ilovasida QR-ni skanerlab, qabul qilganini tasdiqlaydi', ru: 'Мастерица сканирует QR в своём приложении и подтверждает получение' }, 4500);
    await h.back(1200);

    await h.say({ uz: 'Tayyor ishni olish: «Есть что забрать» → «Забрал»', ru: 'Забрать готовую работу: «Есть что забрать» → «Забрал»' });
    await h.tap('Есть что забрать', { after: 2000 });
    await h.tap('N', { after: 2500 });
    await h.tap('Забрал', { after: 3000 });
    await h.say({ uz: 'Ish ofisga keldi — admin tekshirib, pulni hisoblaydi', ru: 'Работа поехала в офис — админ проверит и начислит оплату' }, 3500);
    await h.back(1000);
    await h.back(1500);

    await h.say({ uz: '«Карта»: barcha ustalar xaritada', ru: '«Карта»: все мастерицы на карте' });
    await h.tap('Карта', { after: 2500 });
    await h.tap('Все на карте', { after: 4000 });
    await h.say({ uz: '«Маршрут»: bugungi yo‘l — qachon kelish qulayligi bilan', ru: '«Маршрут»: путь на сегодня — с удобным временем каждой' });
    await h.tap('Маршрут', { after: 4500 });
    await h.say({ uz: '«Построить маршрут» — Yandex xaritada yo‘l ochiladi', ru: '«Построить маршрут» — путь откроется в Яндекс Картах' }, 3500);
    await h.back(1500);

    await h.say({ uz: 'Xaridorlar buyurtmalari: «Ещё» → «Заказы клиентов»', ru: 'Заказы покупателей: «Ещё» → «Заказы клиентов»' });
    await h.tap('Ещё', { after: 1800 });
    await h.tap('Заказы клиентов', { after: 2500 });
    await h.say({ uz: 'Qo‘ng‘iroq qiling va «Принять заказ»', ru: 'Позвоните и нажмите «Принять заказ»' });
    await h.tap('Принять заказ', { after: 3000 });
    await h.back(1500);
    await h.say({ uz: 'Savollar — «Чат». Yo‘lingiz ochiq bo‘lsin!', ru: 'Вопросы — в «Чат». Хорошей дороги!' });
    await h.tap('Чат', { after: 3500 });
  },
};
