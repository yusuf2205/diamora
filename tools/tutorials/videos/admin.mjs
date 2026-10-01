// For ADMINs: the daily work in the panel admin.diamoraa.uz.
import { staffLogin } from '../lib.mjs';

export default {
  name: 'admin',
  title: { uz: 'Admin uchun: panelda kundalik ish', ru: 'Для админа: ежедневная работа в панели' },
  roles: ['ADMIN'],
  viewport: { width: 1280, height: 800 },
  async script(h) {
    const { page } = h;
    await h.goto('/login');
    await h.say({ uz: 'Panel: admin.diamoraa.uz. Telefon va parol bilan kiring', ru: 'Панель: admin.diamoraa.uz. Войдите по телефону и паролю' });
    await staffLogin(h, '90 000 00 02');
    await h.say({ uz: '«Обзор» — bugun nima qilish kerakligi', ru: '«Обзор» — что нужно сделать сегодня' });
    await h.point(page.getByText('Требует внимания'), { wait: 2500 });
    await h.unring();

    // a new master
    await h.say({ uz: 'Yangi usta Telegram bot orqali ro‘yxatdan o‘tadi. Arizani ko‘rib chiqamiz', ru: 'Новая мастерица регистрируется через Telegram-бот. Смотрим заявку' });
    await h.click(page.getByRole('link', { name: 'Мастерицы' }));
    await h.click(page.getByRole('button', { name: 'Заявки', exact: true }));
    await h.click(page.getByText('Madina Qodirova').first(), { after: 1800 });
    await h.say({ uz: 'Garovni olgan bo‘lsangiz belgilang va «Одобрить»', ru: 'Если залог получен — отметьте и нажмите «Одобрить»' });
    await h.click(page.getByRole('button', { name: 'Одобрить' }));
    await h.click(page.getByText('Залог получен'));
    await h.click(page.getByRole('dialog').getByRole('button', { name: 'Одобрить' }), { after: 2000 });
    await h.say({ uz: 'Tayyor: usta faol, endi ilovaga kira oladi', ru: 'Готово: мастерица активна и может войти в приложение' }, 2500);

    // give work
    await h.say({ uz: 'Ish berish: «+ Подготовить работу»', ru: 'Выдать работу: «+ Подготовить работу»' });
    await h.click(page.getByRole('link', { name: 'Задания' }));
    await h.click(page.getByRole('button', { name: '+ Подготовить работу' }), { after: 1500 });
    await h.say({ uz: 'Avval modelni tanlang — tizim kimga berish yaxshiroq ekanini taklif qiladi', ru: 'Сначала модель — система подскажет, кому лучше дать' });
    await h.select(page.getByLabel('Модель'), 'Oddiy tekis', { after: 1800 });
    await h.point(page.getByText(/Кому лучше дать/), { wait: 2500 });
    await h.unring();
    await h.say({ uz: 'Ustani, rangni va hajmni tanlang', ru: 'Выберите мастерицу, цвет и объём' });
    await h.selectStarting(page.getByLabel('Мастерица'), 'Madina Qodirova');
    await h.select(page.getByLabel('Цвет'), 'Pushti');
    await h.click(page.getByRole('button', { name: '18 м' }));
    await h.click(page.getByRole('button', { name: 'Далее' }), { after: 1500 });
    await h.say({ uz: 'Tekshiring: ombordan qanday material chiqadi va ustaga qancha to‘lanadi', ru: 'Проверьте: какие материалы уйдут со склада и сколько заплатят мастерице' }, 3000);
    await h.click(page.getByRole('dialog').getByRole('button', { name: 'Подготовить работу' }), { after: 2500 });
    await h.say({ uz: 'Ish tayyor. Menejer olib boradi, usta QR-kodni skanerlab qabul qiladi', ru: 'Работа готова. Менеджер отвезёт, мастерица примет, отсканировав QR' }, 3500);

    // accept finished work, pay out
    await h.say({ uz: 'Tayyor ishni qabul qilish: «На приёмке»', ru: 'Приёмка готовой работы: «На приёмке»' });
    await h.goto('/assignments');
    await h.click(page.getByRole('button', { name: 'На приёмке' }));
    await h.click(page.getByText('Gulnora Ismoilova').first(), { after: 1800 });
    await h.click(page.getByRole('button', { name: 'Принять работу' }).first(), { after: 1200 });
    await h.say({ uz: 'Qancha olib kelindi, qancha qabul qilindi, brak bormi — yozing', ru: 'Укажите, сколько принесла, сколько принято и есть ли брак' });
    await h.type(page.getByLabel('Принесено, м'), '9');
    await h.type(page.getByLabel('Принято, м'), '9');
    await h.click(page.getByRole('dialog').getByRole('button', { name: 'Принять работу' }), { after: 2200 });
    await h.say({ uz: 'Pul avtomatik hisoblandi. Naqd to‘lash: «Выплатить наличными»', ru: 'Оплата начислена сама. Выдать наличными: «Выплатить наличными»' });
    await h.click(page.getByRole('button', { name: 'Выплатить наличными' }).first(), { after: 1200 });
    await h.click(page.getByRole('button', { name: 'Вся сумма' }));
    await h.click(page.getByRole('dialog').getByRole('button', { name: 'Выплатить' }));
    await h.say({ uz: 'Yana bir bor tasdiqlang — pul berilgani yoziladi', ru: 'Подтвердите ещё раз — выплата запишется' });
    await h.click(page.getByRole('dialog').getByRole('button', { name: 'Выплатить' }), { after: 2200 });

    // customer orders
    await h.say({ uz: 'Xaridorlar buyurtmalari: sayt va Telegram’dan keladi', ru: 'Заказы покупателей приходят с сайта и из Telegram' });
    await h.click(page.getByRole('link', { name: 'Заказы клиентов' }), { after: 1500 });
    await h.say({ uz: 'Xaridorga qo‘ng‘iroq qiling va «Принять заказ». U Telegram’da xabar oladi', ru: 'Позвоните покупателю и нажмите «Принять заказ». Он получит сообщение в Telegram' });
    await h.click(page.getByRole('button', { name: '✅ Принять заказ' }).first(), { after: 2000 });
    await h.say({ uz: 'Telefon orqali buyurtma bo‘lsa — «+ Новый заказ»', ru: 'Заказ по телефону — «+ Новый заказ»' });
    await h.point(page.getByRole('button', { name: '+ Новый заказ' }), { wait: 2000 });
    await h.unring();

    // stock and purchases
    await h.say({ uz: 'Ombor: nima qolgani va qancha kunga yetishi', ru: 'Склад: что осталось и на сколько дней хватит' });
    await h.click(page.getByRole('link', { name: 'Склад' }), { after: 2500 });
    await h.say({ uz: '«Закупки»: yetkazib beruvchiga buyurtma — bot orqali to‘g‘ridan-to‘g‘ri Telegram’ga', ru: '«Закупки»: заказ поставщику — через бота прямо в его Telegram' });
    await h.click(page.getByRole('link', { name: 'Закупки' }), { after: 2500 });
    await h.point(page.getByRole('button', { name: /Отправить поставщику/ }).first(), { wait: 2200 });
    await h.unring();

    await h.say({ uz: 'Savollar bo‘lsa — «Чат». Omad!', ru: 'Вопросы — в «Чат». Удачной работы!' });
    await h.point(page.getByRole('link', { name: /Чат/ }).first(), { wait: 3000 });
    await h.unring();
  },
};
