// For customers: shop.diamoraa.uz on a phone - choose, colours, metres, order; then the shop bot.
export default {
  name: 'customer',
  title: { uz: 'Xaridorlar uchun: qanday buyurtma berish', ru: 'Для покупателей: как сделать заказ' },
  roles: ['CUSTOMER'],
  viewport: { width: 400, height: 860 },
  mobile: true,
  async script(h) {
    await h.goto('/shop');
    await h.say({ uz: 'Diamoraa do‘koni: shop.diamoraa.uz', ru: 'Магазин Diamoraa: shop.diamoraa.uz' }, 2500);
    await h.say({ uz: 'Bu yerda barcha mahsulotlar rasmi va ranglari bilan', ru: 'Здесь все изделия с фото и цветами' });
    await h.scroll(350);
    await h.scroll(-350);
    await h.say({ uz: 'Yoqqan mahsulotni bosing', ru: 'Нажмите на изделие, которое понравилось' });
    await h.click(h.page.getByRole('button', { name: /Oddiy tekis/ }), { after: 1800 });
    await h.say({ uz: 'Bir yoki bir nechta rangni tanlang', ru: 'Выберите один или несколько цветов' });
    await h.click(h.page.getByRole('button', { name: 'Pushti', exact: true }));
    await h.click(h.page.getByRole('button', { name: "Ko'k", exact: true }));
    await h.say({ uz: 'Har bir rangdan necha metr kerakligini yozing', ru: 'Напишите, сколько метров каждого цвета' });
    await h.type(h.page.getByLabel('Метров: Pushti'), '20');
    await h.type(h.page.getByLabel("Метров: Ko'k"), '10');
    await h.say({ uz: 'Ismingiz va telefon raqamingiz', ru: 'Ваше имя и номер телефона' });
    await h.type(h.page.getByLabel('Ваше имя *'), 'Zarina');
    await h.type(h.page.getByLabel('Телефон *'), '93 555 11 22', { clear: false });
    await h.say({ uz: 'Xohlasangiz izoh: muddat, manzil', ru: 'Если нужно — комментарий: срок, адрес' });
    await h.type(h.page.getByLabel('Комментарий'), 'Juma kuniga kerak');
    await h.say({ uz: '«Заказать» tugmasini bosing. Hozir to‘lash shart emas', ru: 'Нажмите «Заказать». Платить сейчас не нужно' });
    await h.click(h.page.getByRole('button', { name: 'Заказать', exact: true }), { after: 2500 });
    await h.say({ uz: 'Tayyor! Buyurtma raqami shu yerda. Biz qo‘ng‘iroq qilamiz', ru: 'Готово! Здесь номер заказа. Мы вам позвоним' }, 3500);
    await h.say({ uz: 'Bu tugma orqali buyurtma holatini Telegram’da kuzating', ru: 'Этой кнопкой следите за заказом в Telegram' });
    await h.point(h.page.getByText('Следить за заказом в Telegram'), { wait: 2500 });
    await h.unring();
    await h.say({ uz: 'Telegram bot @diamoraa_shop_bot: «📝 Заказать» — xuddi shu qadamlar', ru: 'Бот @diamoraa_shop_bot: «📝 Заказать» — те же шаги' }, 4000);
    await h.say({ uz: 'Savol bo‘lsa — botda «📞 Связаться» yoki yuqoridagi tugmalar', ru: 'Вопросы — «📞 Связаться» в боте или кнопки вверху сайта' }, 4000);
  },
};
