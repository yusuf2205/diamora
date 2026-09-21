import { normalizePhone, parseUzs } from './basics';

/**
 * Telegram registration flow as a PURE state machine (D-005). The bot only renders prompts and forwards input;
 * the API persists `RegState` in `registration_drafts`. No I/O here — fully unit-testable.
 */
export type RegStep =
  | 'NAME'
  | 'PHONE'
  | 'SECONDARY_PHONE'
  | 'LOCATION'
  | 'COLLATERAL_TYPE'
  | 'COLLATERAL_AMOUNT'
  | 'COLLATERAL_DESCRIPTION'
  | 'COLLATERAL_PHOTOS'
  | 'NOTE'
  | 'CONFIRM'
  | 'EDIT_MENU'
  | 'SUBMITTED';

export interface RegData {
  fullName?: string;
  phone?: string;
  /** null = explicitly skipped */
  secondaryPhone?: string | null;
  latitude?: number;
  longitude?: number;
  collateralType?: 'MONEY' | 'ITEM';
  /** whole UZS as decimal string */
  collateralAmount?: string;
  collateralDescription?: string;
  /** number of photos stored so far (the API keeps the file ids) */
  photoCount: number;
  note?: string | null;
}

export interface RegState {
  step: RegStep;
  data: RegData;
  /** true while editing from the confirmation screen: after the change go back to CONFIRM */
  returnToConfirm: boolean;
}

export type RegAction =
  | 'skip'
  | 'type_money'
  | 'type_item'
  | 'photos_done'
  | 'confirm'
  | 'edit'
  | 'edit_name'
  | 'edit_phone'
  | 'edit_secondary'
  | 'edit_location'
  | 'edit_collateral'
  | 'edit_note'
  | 'back_to_confirm';

export type RegInput =
  | { kind: 'text'; text: string }
  | { kind: 'contact'; phone: string; contactUserId: number | null; senderUserId: number }
  | { kind: 'location'; latitude: number; longitude: number }
  | { kind: 'photo' }
  | { kind: 'action'; action: RegAction };

export type RegPrompt =
  | 'ASK_NAME'
  | 'ASK_PHONE'
  | 'ASK_SECONDARY'
  | 'ASK_LOCATION'
  | 'ASK_COLLATERAL_TYPE'
  | 'ASK_AMOUNT'
  | 'ASK_DESCRIPTION'
  | 'ASK_PHOTOS'
  | 'ASK_NOTE'
  | 'CONFIRM'
  | 'EDIT_MENU'
  | 'SUBMITTED';

export type RegError =
  | 'NAME_INVALID'
  | 'PHONE_NOT_OWN'
  | 'PHONE_INVALID'
  | 'LOCATION_INVALID'
  | 'AMOUNT_INVALID'
  | 'DESCRIPTION_INVALID'
  | 'PHOTO_REQUIRED'
  | 'PHOTO_LIMIT'
  | 'NOTE_INVALID'
  | 'INCOMPLETE'
  | 'UNEXPECTED_INPUT';

export interface RegResult {
  state: RegState;
  /** what to show next */
  prompt: RegPrompt;
  /** set when the input was rejected; the same step is asked again */
  error?: RegError;
  /** the caller must store this photo (accepted by the machine) */
  acceptPhoto?: boolean;
  /** the caller must discard previously stored photos (collateral type/description changed) */
  resetPhotos?: boolean;
  /** registration is complete: create the worker */
  submit?: boolean;
}

export const MAX_PHOTOS = 10;

export const initialRegState = (): RegState => ({ step: 'NAME', data: { photoCount: 0 }, returnToConfirm: false });

const PROMPT_FOR: Record<RegStep, RegPrompt> = {
  NAME: 'ASK_NAME',
  PHONE: 'ASK_PHONE',
  SECONDARY_PHONE: 'ASK_SECONDARY',
  LOCATION: 'ASK_LOCATION',
  COLLATERAL_TYPE: 'ASK_COLLATERAL_TYPE',
  COLLATERAL_AMOUNT: 'ASK_AMOUNT',
  COLLATERAL_DESCRIPTION: 'ASK_DESCRIPTION',
  COLLATERAL_PHOTOS: 'ASK_PHOTOS',
  NOTE: 'ASK_NOTE',
  CONFIRM: 'CONFIRM',
  EDIT_MENU: 'EDIT_MENU',
  SUBMITTED: 'SUBMITTED',
};

const isMissing = (d: RegData): boolean =>
  !d.fullName ||
  !d.phone ||
  d.latitude === undefined ||
  d.longitude === undefined ||
  !d.collateralType ||
  (d.collateralType === 'MONEY' ? !d.collateralAmount : !d.collateralDescription || d.photoCount < 1);

export function advance(state: RegState, input: RegInput): RegResult {
  const s: RegState = { ...state, data: { ...state.data } };
  const to = (step: RegStep, extra: Partial<RegResult> = {}): RegResult => {
    s.step = step;
    return { state: s, prompt: PROMPT_FOR[step], ...extra };
  };
  const reject = (error: RegError): RegResult => ({ state, prompt: PROMPT_FOR[state.step], error });
  /** step to continue with after a field was filled */
  const after = (normalNext: RegStep): RegStep => {
    if (s.returnToConfirm) {
      s.returnToConfirm = false;
      return 'CONFIRM';
    }
    return normalNext;
  };

  if (state.step === 'SUBMITTED') return { state, prompt: 'SUBMITTED' };

  switch (state.step) {
    case 'NAME': {
      if (input.kind !== 'text') return reject('UNEXPECTED_INPUT');
      const name = input.text.trim().replace(/\s+/g, ' ');
      if (name.length < 2 || name.length > 150 || /^[\d\s+()-]+$/.test(name)) return reject('NAME_INVALID');
      s.data.fullName = name;
      return to(after('PHONE'));
    }
    case 'PHONE': {
      if (input.kind !== 'contact') return reject('UNEXPECTED_INPUT');
      if (input.contactUserId === null || input.contactUserId !== input.senderUserId) return reject('PHONE_NOT_OWN');
      const phone = normalizePhone(input.phone);
      if (!phone) return reject('PHONE_INVALID');
      s.data.phone = phone;
      if (s.data.secondaryPhone === phone) s.data.secondaryPhone = null;
      return to(after('SECONDARY_PHONE'));
    }
    case 'SECONDARY_PHONE': {
      if (input.kind === 'action' && input.action === 'skip') {
        s.data.secondaryPhone = null;
        return to(after('LOCATION'));
      }
      if (input.kind !== 'text') return reject('UNEXPECTED_INPUT');
      const phone = normalizePhone(input.text);
      if (!phone || phone === s.data.phone) return reject('PHONE_INVALID');
      s.data.secondaryPhone = phone;
      return to(after('LOCATION'));
    }
    case 'LOCATION': {
      if (input.kind !== 'location') return reject('UNEXPECTED_INPUT');
      const { latitude, longitude } = input;
      if (!Number.isFinite(latitude) || !Number.isFinite(longitude) || Math.abs(latitude) > 90 || Math.abs(longitude) > 180) {
        return reject('LOCATION_INVALID');
      }
      s.data.latitude = latitude;
      s.data.longitude = longitude;
      return to(after('COLLATERAL_TYPE'));
    }
    case 'COLLATERAL_TYPE': {
      if (input.kind !== 'action' || (input.action !== 'type_money' && input.action !== 'type_item')) {
        return reject('UNEXPECTED_INPUT');
      }
      const type = input.action === 'type_money' ? 'MONEY' : 'ITEM';
      const changed = s.data.collateralType !== type;
      s.data.collateralType = type;
      if (type === 'MONEY') {
        const hadPhotos = s.data.photoCount > 0;
        delete s.data.collateralDescription;
        s.data.photoCount = 0;
        return to('COLLATERAL_AMOUNT', { resetPhotos: hadPhotos });
      }
      delete s.data.collateralAmount;
      if (changed) s.data.photoCount = 0;
      return to('COLLATERAL_DESCRIPTION', { resetPhotos: changed });
    }
    case 'COLLATERAL_AMOUNT': {
      if (input.kind !== 'text') return reject('UNEXPECTED_INPUT');
      let amount: bigint;
      try {
        amount = parseUzs(input.text);
      } catch {
        return reject('AMOUNT_INVALID');
      }
      if (amount <= 0n || amount > 1_000_000_000_000n) return reject('AMOUNT_INVALID');
      s.data.collateralAmount = amount.toString();
      return to(after('NOTE'));
    }
    case 'COLLATERAL_DESCRIPTION': {
      if (input.kind !== 'text') return reject('UNEXPECTED_INPUT');
      const d = input.text.trim();
      if (d.length < 3 || d.length > 1000) return reject('DESCRIPTION_INVALID');
      s.data.collateralDescription = d;
      return to('COLLATERAL_PHOTOS');
    }
    case 'COLLATERAL_PHOTOS': {
      if (input.kind === 'photo') {
        if (s.data.photoCount >= MAX_PHOTOS) return reject('PHOTO_LIMIT');
        s.data.photoCount += 1;
        return to('COLLATERAL_PHOTOS', { acceptPhoto: true });
      }
      if (input.kind === 'action' && input.action === 'photos_done') {
        if (s.data.photoCount < 1) return reject('PHOTO_REQUIRED');
        return to(after('NOTE'));
      }
      return reject('UNEXPECTED_INPUT');
    }
    case 'NOTE': {
      if (input.kind === 'action' && input.action === 'skip') {
        s.data.note = null;
        return to('CONFIRM');
      }
      if (input.kind !== 'text') return reject('UNEXPECTED_INPUT');
      const note = input.text.trim();
      if (note.length > 1000) return reject('NOTE_INVALID');
      s.data.note = note.length ? note : null;
      return to('CONFIRM');
    }
    case 'CONFIRM': {
      if (input.kind !== 'action') return reject('UNEXPECTED_INPUT');
      if (input.action === 'edit') return to('EDIT_MENU');
      if (input.action === 'confirm') {
        if (isMissing(s.data)) return reject('INCOMPLETE');
        return to('SUBMITTED', { submit: true });
      }
      return reject('UNEXPECTED_INPUT');
    }
    case 'EDIT_MENU': {
      if (input.kind !== 'action') return reject('UNEXPECTED_INPUT');
      const go = (step: RegStep) => {
        s.returnToConfirm = true;
        return to(step);
      };
      switch (input.action) {
        case 'edit_name':
          return go('NAME');
        case 'edit_phone':
          return go('PHONE');
        case 'edit_secondary':
          return go('SECONDARY_PHONE');
        case 'edit_location':
          return go('LOCATION');
        case 'edit_collateral':
          return go('COLLATERAL_TYPE');
        case 'edit_note':
          return go('NOTE');
        case 'back_to_confirm':
          return to('CONFIRM');
        default:
          return reject('UNEXPECTED_INPUT');
      }
    }
  }
}
