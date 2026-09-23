import type { RegAction, RegError, RegPrompt } from '@yusmus/shared';

/** Everything the bot says lives here (pure functions) — the bot process only renders these (D-005). */
export type BotPrompt =
  | RegPrompt
  | 'WELCOME'
  | 'CANCELLED'
  | 'STATUS_PENDING'
  | 'STATUS_ACTIVE'
  | 'STATUS_REJECTED'
  | 'STATUS_PAUSED'
  | 'LOCATION_UPDATED';
export type BotError = RegError | 'PHONE_TAKEN' | 'PHOTO_FAILED';

export interface RegSummary {
  fullName?: string;
  phone?: string;
  secondaryPhone?: string | null;
  hasLocation: boolean;
  collateralType?: 'MONEY' | 'ITEM';
  collateralAmount?: string;
  collateralDescription?: string;
  photoCount: number;
  note?: string | null;
}
export interface BotReply {
  prompt: BotPrompt;
  error?: BotError;
  summary?: RegSummary;
  photoCount?: number;
  rejectedReason?: string | null;
  /** WORKER Telegram-only login (§): set only when this Telegram user has a linked app login session — never present
   * for an organic bot conversation. Renders as ONE inline URL button, replacing whatever keyboard the prompt would
   * otherwise show, so confirming (or just reading a status) and opening Diamoraa is a single tap. */
  telegramHandoffUrl?: string;
}

export interface BotButton { text: string; requestContact?: boolean; requestLocation?: boolean }
export type BotKeyboard = { type: 'remove' } | { type: 'reply'; rows: BotButton[][] } | { type: 'inline'; text: string; url: string };
export interface Rendered { text: string; keyboard: BotKeyboard }

// ---- buttons (text buttons only: no callback queries, so a restart can never orphan a button) --------------------------------
export const BTN = {
  contact: '📱 Отправить мой номер',
  skip: 'Пропустить',
  location: '📍 Отправить геолокацию',
  money: '💵 Деньги',
  item: '💍 Вещь',
  done: '✅ Готово',
  confirm: '✅ Подтвердить',
  edit: '✏️ Изменить',
  editName: 'Имя',
  editPhone: 'Мой телефон',
  editSecondary: 'Доп. телефон',
  editLocation: 'Геолокация',
  editCollateral: 'Залог',
  editNote: 'Заметка',
  back: '⬅️ Назад',
} as const;

const ACTION_BY_TEXT: Record<string, RegAction> = {
  [BTN.skip]: 'skip',
  [BTN.money]: 'type_money',
  [BTN.item]: 'type_item',
  [BTN.done]: 'photos_done',
  [BTN.confirm]: 'confirm',
  [BTN.edit]: 'edit',
  [BTN.editName]: 'edit_name',
  [BTN.editPhone]: 'edit_phone',
  [BTN.editSecondary]: 'edit_secondary',
  [BTN.editLocation]: 'edit_location',
  [BTN.editCollateral]: 'edit_collateral',
  [BTN.editNote]: 'edit_note',
  [BTN.back]: 'back_to_confirm',
};
export const parseAction = (text: string): RegAction | null => ACTION_BY_TEXT[text.trim()] ?? null;

const grouped = (s: string) => s.replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
const kb = (...rows: BotButton[][]): BotKeyboard => ({ type: 'reply', rows });
const REMOVE: BotKeyboard = { type: 'remove' };

const ERRORS: Record<BotError, string> = {
  NAME_INVALID: 'Напишите фамилию и имя (не короче 2 букв).',
  PHONE_NOT_OWN: 'Нужен именно ваш номер. Нажмите кнопку «Отправить мой номер».',
  PHONE_INVALID: 'Не похоже на номер телефона. Напишите номер, например +998 90 123 45 67.',
  PHONE_TAKEN: 'Этот номер уже зарегистрирован. Если это ошибка — напишите администратору.',
  LOCATION_INVALID: 'Не удалось прочитать геолокацию. Нажмите кнопку «Отправить геолокацию».',
  AMOUNT_INVALID: 'Напишите сумму цифрами, например 1 500 000.',
  DESCRIPTION_INVALID: 'Опишите вещь подробнее (от 3 символов).',
  PHOTO_REQUIRED: 'Пришлите хотя бы одну фотографию вещи.',
  PHOTO_LIMIT: 'Достаточно фотографий (максимум 10). Нажмите «Готово».',
  PHOTO_FAILED: 'Не получилось сохранить фото. Отправьте его ещё раз.',
  NOTE_INVALID: 'Слишком длинная заметка (до 1000 символов).',
  INCOMPLETE: 'Не все данные заполнены. Нажмите «Изменить» и дополните.',
  UNEXPECTED_INPUT: 'Пожалуйста, ответьте на вопрос выше.',
};

export function summaryText(s: RegSummary): string {
  const collateral =
    s.collateralType === 'MONEY'
      ? `Деньги — ${grouped(s.collateralAmount ?? '0')} сум`
      : `${s.collateralDescription ?? '—'} (фото: ${s.photoCount})`;
  return [
    'Проверьте данные:',
    `👤 ФИО: ${s.fullName ?? '—'}`,
    `📱 Телефон: ${s.phone ?? '—'}`,
    `📞 Доп. телефон: ${s.secondaryPhone ?? '—'}`,
    `📍 Геолокация: ${s.hasLocation ? 'получена' : '—'}`,
    `💰 Залог: ${collateral}`,
    `📝 Заметка: ${s.note ?? '—'}`,
  ].join('\n');
}

export function render(r: BotReply): Rendered {
  const err = r.error ? `${ERRORS[r.error]}\n\n` : '';
  const ask = (text: string, keyboard: BotKeyboard = REMOVE): Rendered => ({
    text: err + text,
    keyboard: r.telegramHandoffUrl ? { type: 'inline', text: BTN.confirm, url: r.telegramHandoffUrl } : keyboard,
  });
  switch (r.prompt) {
    case 'WELCOME':
      return ask('Здравствуйте! Давайте познакомимся — это займёт пару минут.\n\nНапишите ваши фамилию и имя.');
    case 'ASK_NAME':
      return ask('Напишите ваши фамилию и имя.');
    case 'ASK_PHONE':
      return ask('Нажмите кнопку, чтобы отправить ваш номер телефона.', kb([{ text: BTN.contact, requestContact: true }]));
    case 'ASK_SECONDARY':
      return ask('Дополнительный номер телефона (по желанию). Напишите номер или нажмите «Пропустить».', kb([{ text: BTN.skip }]));
    case 'ASK_LOCATION':
      return ask('Отправьте вашу геолокацию — так мы будем знать, куда привозить материалы. Нажмите кнопку ниже.', kb([{ text: BTN.location, requestLocation: true }]));
    case 'ASK_COLLATERAL_TYPE':
      return ask('Какой залог вы оставляете?', kb([{ text: BTN.money }, { text: BTN.item }]));
    case 'ASK_AMOUNT':
      return ask('Напишите сумму залога в сумах цифрами, например 1 500 000.');
    case 'ASK_DESCRIPTION':
      return ask('Опишите вещь, которую оставляете в залог (например: золотое кольцо, 585).');
    case 'ASK_PHOTOS':
      return ask(
        `Пришлите фотографии вещи (можно несколько). Когда закончите — нажмите «Готово».${r.photoCount ? `\nПолучено фото: ${r.photoCount}` : ''}`,
        kb([{ text: BTN.done }]),
      );
    case 'ASK_NOTE':
      return ask('Хотите добавить заметку? Напишите её или нажмите «Пропустить».', kb([{ text: BTN.skip }]));
    case 'CONFIRM':
      return ask(`${r.summary ? summaryText(r.summary) : ''}\n\nВсё верно?`, kb([{ text: BTN.confirm }], [{ text: BTN.edit }]));
    case 'EDIT_MENU':
      return ask('Что хотите изменить?', kb([{ text: BTN.editName }, { text: BTN.editPhone }], [{ text: BTN.editSecondary }, { text: BTN.editLocation }], [{ text: BTN.editCollateral }, { text: BTN.editNote }], [{ text: BTN.back }]));
    case 'SUBMITTED':
      return ask(
        r.telegramHandoffUrl
          ? 'Спасибо! Заявка отправлена. Нажмите «Подтвердить», чтобы открыть Diamoraa.'
          : 'Спасибо! Заявка отправлена. Мы сообщим о решении здесь, в Telegram.',
      );
    case 'CANCELLED':
      return ask('Регистрация отменена. Чтобы начать заново, отправьте /start.');
    case 'STATUS_PENDING':
      return ask('Ваша заявка на рассмотрении. Мы сообщим о решении здесь, в Telegram.');
    case 'STATUS_ACTIVE':
      return ask(
        r.telegramHandoffUrl ? 'С возвращением! Нажмите «Подтвердить», чтобы открыть Diamoraa.' : 'Вы уже зарегистрированы ✅ Чтобы войти, откройте Diamoraa и нажмите «Войти через Telegram».',
      );
    case 'STATUS_PAUSED':
      return ask('Ваш профиль временно приостановлен. Свяжитесь с администратором.');
    case 'STATUS_REJECTED':
      return ask(`К сожалению, заявка отклонена.${r.rejectedReason ? `\nПричина: ${r.rejectedReason}` : ''}`);
    case 'LOCATION_UPDATED':
      return ask('Геолокация обновлена ✅');
  }
}
