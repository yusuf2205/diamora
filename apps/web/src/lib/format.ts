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
