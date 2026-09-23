import { LOCATION_LIVE_SECONDS, LOCATION_RECENT_SECONDS } from '@yusmus/shared';

/** LIVE / RECENT / STALE (M2 §17) — same thresholds as the API and the Flutter app (packages/shared). A RECENT or
 * STALE point is never worded as if it were happening right now. */
export function freshnessLabel(ageSeconds: number): string {
  const minutes = Math.floor(ageSeconds / 60);
  if (ageSeconds < LOCATION_LIVE_SECONDS) return 'Сейчас';
  if (ageSeconds < LOCATION_RECENT_SECONDS) return `Обновлено ${minutes} мин назад`;
  return `Последняя позиция ${minutes} мин назад`;
}

export function formatUzs(amount: string | null | undefined): string {
  if (amount == null) return '—';
  const negative = amount.startsWith('-');
  const digits = negative ? amount.slice(1) : amount;
  const grouped = digits.replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
  return `${negative ? '-' : ''}${grouped} сум`;
}

export function initials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return '?';
  return parts.length === 1 ? parts[0][0].toUpperCase() : (parts[0][0] + parts[1][0]).toUpperCase();
}

export function formatDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  return iso.length >= 16 ? iso.slice(0, 16).replace('T', ' ') : iso;
}

const ROLE_LABELS: Record<string, string> = { SUPER_ADMIN: 'Главный администратор', ADMIN: 'Администратор', MANAGER: 'Менеджер', WORKER: 'Мастерица' };
export const roleLabel = (role: string) => ROLE_LABELS[role] ?? role;

const STATUS_LABELS: Record<string, string> = {
  PENDING_APPROVAL: 'На рассмотрении', ACTIVE: 'Активна', PAUSED: 'На паузе', REJECTED: 'Отклонена', ARCHIVED: 'В архиве',
  DRAFT: 'Черновик', PUBLISHED: 'Опубликовано', HIDDEN: 'Скрыто',
};
export const statusLabel = (status: string) => STATUS_LABELS[status] ?? status;

// M3 work-order statuses — human labels only, the raw enum never reaches the screen (same wording as the mobile app).
const ASSIGNMENT_STATUS_LABELS: Record<string, string> = {
  DRAFT: 'Готовится', READY_TO_DELIVER: 'Готово к доставке', DELIVERED: 'Доставлено', IN_PROGRESS: 'В работе',
  READY_FOR_PICKUP: 'Готово к забору', PICKED_UP: 'Забрано', UNDER_REVIEW: 'На проверке',
  PARTIALLY_ACCEPTED: 'Принято частично', ACCEPTED: 'Принято', REWORK_REQUIRED: 'Нужна доработка',
  COMPLETED: 'Завершено', CANCELLED: 'Отменено',
};
export const assignmentStatusLabel = (status: string) => ASSIGNMENT_STATUS_LABELS[status] ?? status;

const ASSIGNMENT_STATUS_TONE: Record<string, 'default' | 'ok' | 'danger' | 'warn'> = {
  DRAFT: 'default', READY_TO_DELIVER: 'warn', DELIVERED: 'warn', IN_PROGRESS: 'default', READY_FOR_PICKUP: 'warn',
  PICKED_UP: 'default', UNDER_REVIEW: 'warn', PARTIALLY_ACCEPTED: 'warn', ACCEPTED: 'ok', REWORK_REQUIRED: 'danger',
  COMPLETED: 'ok', CANCELLED: 'danger',
};
export const assignmentStatusTone = (status: string) => ASSIGNMENT_STATUS_TONE[status] ?? 'default';
