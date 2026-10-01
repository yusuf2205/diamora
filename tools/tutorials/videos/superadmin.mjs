// For the SUPER_ADMIN (the owner): what only the owner does - people and rights, pay rate, money, reports, safety.
import { staffLogin } from '../lib.mjs';

export default {
  name: 'superadmin',
  title: { uz: 'Bosh admin uchun: boshqaruv va xavfsizlik', ru: 'Для главного админа: управление и безопасность' },
  roles: ['SUPER_ADMIN'],
  viewport: { width: 1280, height: 800 },
  async script(h) {
    const { page } = h;
    const nav = (name) => page.getByRole('link', { name, exact: true });
    await h.goto('/login');
    await h.say({ uz: 'Bosh admin hamma narsani ko‘radi. Kundalik ish — «Admin» videosida', ru: 'Главный админ видит всё. Ежедневная работа — в ролике «Для админа»' });
    await staffLogin(h, '90 000 00 01');
    await h.say({ uz: 'Bu yerda faqat bosh admin qiladigan ishlar', ru: 'Здесь — то, что делает только главный админ' }, 2500);

    // people and rights
    await h.say({ uz: '«Команда»: xodimlarni qo‘shish — admin yoki menejer', ru: '«Команда»: добавить сотрудника — админа или менеджера' });
    await h.click(nav('Команда'), { after: 1500 });
    await h.click(page.getByRole('button', { name: '+ Добавить пользователя' }), { after: 1200 });
    await h.type(page.getByLabel('ФИО'), 'Shahzoda Karimova');
    await h.type(page.getByLabel('Телефон'), ' 90 000 00 07', { clear: false });
    await h.say({ uz: 'Rolni tanlang va kirish uchun parol bering', ru: 'Выберите роль и задайте пароль для входа' });
    await h.select(page.getByRole('dialog').getByLabel('Роль'), 'Менеджер').catch(() => h.selectStarting(page.getByRole('dialog').getByLabel('Роль'), 'Менедж'));
    await h.type(page.getByLabel('Пароль для входа'), 'Shahzoda-2026');
    await h.click(page.getByRole('dialog').getByRole('button', { name: /Создать|Добавить|Сохранить/ }).last(), { after: 2000 });
    await h.say({ uz: 'Har bir xodimning huquqlarini uning sahifasida o‘zgartirish mumkin', ru: 'Права каждого сотрудника можно менять на его странице' }, 3000);

    // pay rate, contacts, goals
    await h.say({ uz: '«Настройки»: 9 metr uchun narx — barcha ustalarga bir xil', ru: '«Настройки»: цена за 9 м — одна для всех мастериц' });
    await h.click(nav('Настройки'), { after: 1500 });
    await h.point(page.getByText('Ставка за 9 м'), { wait: 2500 });
    await h.say({ uz: 'Kompaniya telefoni va Telegram — ustalar va xaridorlar ko‘radi', ru: 'Телефон и Telegram компании — их видят мастерицы и покупатели' });
    await h.point(page.getByText('Телефон и Telegram компании'), { wait: 2500 });
    await h.say({ uz: 'Oylik maqsad — ustalar ilovada o‘z natijasini ko‘radi', ru: 'Цель месяца — мастерицы видят свой прогресс в приложении' });
    await h.point(page.getByText('Цель месяца для мастериц'), { wait: 2500 });
    await h.unring();

    // money and reports
    await h.say({ uz: '«Прибыль»: savdo, ustalarga to‘lov, material va xarajatlar', ru: '«Прибыль»: продажи, оплата мастерицам, материалы и расходы' });
    await h.click(nav('Прибыль'), { after: 2500 });
    await h.say({ uz: '«Отчёты»: oy bo‘yicha — Excel yoki PDF', ru: '«Отчёты»: по месяцам — Excel или PDF' });
    await h.click(nav('Отчёты'), { after: 2000 });
    await h.point(page.getByRole('button', { name: /Excel/ }), { wait: 2200 });
    await h.unring();

    // safety
    await h.say({ uz: '«Журнал»: kim, nima va qachon o‘zgartirgan', ru: '«Журнал»: кто, что и когда изменил' });
    await h.click(nav('Журнал'), { after: 2500 });
    await h.say({ uz: '«Система»: server ishlayaptimi, zaxira nusxalar va tashqi disk', ru: '«Система»: работает ли сервер, резервные копии и внешний диск' });
    await h.click(nav('Система'), { after: 2500 });
    await h.scroll(500);
    await h.say({ uz: 'Profil → «Оповещения в Telegram»: server to‘xtasa, darhol xabar keladi', ru: 'Профиль → «Оповещения в Telegram»: если сервер остановится, придёт сообщение' });
    await h.goto('/profile');
    await h.point(page.getByText('Оповещения в Telegram'), { wait: 3000 });
    await h.unring();
    await h.say({ uz: 'Shu bilan bosh admin uchun hammasi. Omad!', ru: 'Вот и всё для главного админа. Удачи!' }, 2500);
  },
};
