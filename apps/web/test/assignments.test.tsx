import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import AssignmentsPage, { CreateAssignmentDialog } from '@/app/(app)/assignments/page';
import AssignmentDetailPage, { AcceptDialog, PayoutDialog } from '@/app/(app)/assignments/[id]/page';
import WorkerDetailPage from '@/app/(app)/workers/[id]/page';
import { errorResponse, mockFetch, renderWithProviders, signIn } from './helpers';

const push = vi.fn();
let searchParams = new URLSearchParams();
vi.mock('next/navigation', () => ({
  useRouter: () => ({ push }),
  useParams: () => ({ id: 'a1' }),
  useSearchParams: () => searchParams,
}));

const ME = { id: 'sa1', fullName: 'Owner', phone: '+998901112233', role: 'SUPER_ADMIN' as const, workerId: null, permissions: ['ASSIGNMENT_VIEW_ALL', 'ASSIGNMENT_CREATE', 'ASSIGNMENT_ACCEPT', 'CASH_PAYOUT', 'FINANCE_VIEW_ALL'] };

const assignmentSummary = (over: Record<string, unknown> = {}) => ({
  id: 'a1', status: 'READY_TO_DELIVER', plannedMeters: 9, reportedMeters: 0, dueAt: null,
  worker: { id: 'w1', fullName: 'Малика Каримова', phone: '+998901234567' },
  product: { name: 'Комплект «Роза»' }, color: { name: 'Розовое золото', hex: '#E8B4B8' }, ...over,
});
const assignmentDetail = (over: Record<string, unknown> = {}) => ({
  ...assignmentSummary(), code: 'A-0001', kitCount: 1, deliveredMeters: 0, acceptedMeters: 0, defectiveMeters: 0,
  calculatedPayment: null, notes: null, qrCode: null, variant: null, materials: [], statusHistory: [], deliveries: [], ...over,
});

describe('assignments list (M3 §28): same statuses and wording as the mobile app', () => {
  it('lists a row with worker, model, colour, volume and a human status — never the raw enum', async () => {
    signIn(ME);
    mockFetch({ '/auth/me': ME, '/admin/assignments': { items: [assignmentSummary()], nextCursor: null } });
    renderWithProviders(<AssignmentsPage />);
    expect(await screen.findByText('Малика Каримова')).toBeInTheDocument();
    expect(screen.getByText('Комплект «Роза»')).toBeInTheDocument();
    expect(screen.getByText('Готово к доставке')).toBeInTheDocument();
    expect(screen.queryByText('READY_TO_DELIVER')).not.toBeInTheDocument();
  });

  it('no assignments yet: an honest empty state', async () => {
    signIn(ME);
    mockFetch({ '/auth/me': ME, '/admin/assignments': { items: [], nextCursor: null } });
    renderWithProviders(<AssignmentsPage />);
    expect(await screen.findByText('Заданий нет')).toBeInTheDocument();
  });
});

describe('create assignment (M3 §16): the server computes the material kit and the payment, never the browser', () => {
  const catalogRoutes = {
    '/auth/me': ME,
    '/workers': { items: [{ id: 'w1', code: 'W-0001', fullName: 'Малика Каримова', phone: '+998901234567', secondaryPhone: null, status: 'ACTIVE', latitude: null, longitude: null, locationReceivedAt: null, balance: '0', manager: null, collateral: null, createdAt: '2026-01-01T00:00:00Z', updatedAt: '2026-01-01T00:00:00Z' }], nextCursor: null },
    '/admin/catalog': { items: [{ id: 'p1', code: 'PRD-1', name: 'Комплект «Роза»', description: null, status: 'PUBLISHED', availability: 'AVAILABLE', isNew: false, sortOrder: 0, media: [], variants: [{ id: 'v1', label: 'Классика', active: true, color: { id: 'col1', name: 'Розовое золото', hex: '#E8B4B8' } }] }], nextCursor: null },
    '/admin/kits': { items: [{ id: 'k1', name: 'Комплект 9м', variantId: null, ribbonMeters: 9, baseMeters: 9, active: true, items: [{ materialId: 'm1', materialName: 'Атлас 1000ток', unit: 'METER', requiredQuantity: 9 }] }] },
    '/settings/pay-rate': { ratePerKit: '30000', kitMeters: 9, updatedAt: '2026-01-01T00:00:00Z' },
  };

  it('picking worker/model/colour/volume and submitting sends exactly the resolved ids', async () => {
    signIn(ME);
    const fetchMock = mockFetch({ ...catalogRoutes, '/admin/assignments': assignmentDetail() });
    renderWithProviders(<CreateAssignmentDialog onClose={() => {}} />);
    const user = userEvent.setup();

    await screen.findByRole('option', { name: /Малика Каримова/ });
    await user.selectOptions(screen.getByDisplayValue('Выберите мастерицу'), 'w1');
    await user.selectOptions(screen.getByDisplayValue('Выберите модель'), 'p1');
    await user.selectOptions(await screen.findByDisplayValue('Выберите цвет'), 'v1');
    await user.click(screen.getByText('18 м'));
    await user.click(screen.getByRole('button', { name: 'Далее' }));
    // the summary shows what leaves the stock (kit × 2) and the pay at today's rate before anything is sent
    expect(await screen.findByText('Проверьте перед выдачей')).toBeInTheDocument();
    expect(screen.getByText('18 м')).toBeInTheDocument();
    expect(screen.getByText('60 000 сум')).toBeInTheDocument();
    expect(fetchMock.mock.calls.some(([u, i]) => String(u).includes('/admin/assignments') && (i as RequestInit | undefined)?.method === 'POST')).toBe(false);
    await user.click(screen.getByRole('button', { name: 'Выдать работу' }));

    await waitFor(() => expect(push).toHaveBeenCalledWith('/assignments/a1'));
    const call = fetchMock.mock.calls.find(([u]) => String(u).includes('/admin/assignments') && !String(u).includes('workerId'));
    const body = JSON.parse((call?.[1] as RequestInit).body as string);
    expect(body).toMatchObject({ workerId: 'w1', productModelId: 'p1', productVariantId: 'v1', colorId: 'col1', materialKitTemplateId: 'k1', kitCount: 2 });
  });

  it('insufficient material: names the exact material, never the raw error code', async () => {
    signIn(ME);
    mockFetch({
      ...catalogRoutes,
      '/admin/assignments': errorResponse(409, { error: { code: 'INSUFFICIENT_STOCK', message: 'Not enough stock', details: { materialId: 'm1' } } }),
    });
    renderWithProviders(<CreateAssignmentDialog onClose={() => {}} />);
    const user = userEvent.setup();
    await screen.findByRole('option', { name: /Малика Каримова/ });
    await user.selectOptions(screen.getByDisplayValue('Выберите мастерицу'), 'w1');
    await user.selectOptions(screen.getByDisplayValue('Выберите модель'), 'p1');
    await user.selectOptions(await screen.findByDisplayValue('Выберите цвет'), 'v1');
    await user.click(screen.getByRole('button', { name: 'Далее' }));
    await user.click(await screen.findByRole('button', { name: 'Выдать работу' }));

    expect(await screen.findByText('На складе не хватает: Атлас 1000ток')).toBeInTheDocument();
    expect(screen.queryByText('INSUFFICIENT_STOCK')).not.toBeInTheDocument();
  });
});

describe('assignment detail (M3 §17): exactly one contextual action per status', () => {
  it('READY_TO_DELIVER shows only "Доставлено"; confirming calls the deliver endpoint', async () => {
    signIn(ME);
    const fetchMock = mockFetch({ '/auth/me': ME, '/admin/assignments/a1': assignmentDetail({ status: 'READY_TO_DELIVER' }) });
    renderWithProviders(<AssignmentDetailPage />);
    const btn = await screen.findByRole('button', { name: 'Доставлено' });
    expect(screen.queryByRole('button', { name: 'Забрал' })).not.toBeInTheDocument();
    await userEvent.click(btn);
    await waitFor(() => expect(fetchMock.mock.calls.some(([u]) => String(u).includes('/admin/assignments/a1/deliver'))).toBe(true));
  });

  it('READY_FOR_PICKUP shows only "Забрал"', async () => {
    signIn(ME);
    mockFetch({ '/auth/me': ME, '/admin/assignments/a1': assignmentDetail({ status: 'READY_FOR_PICKUP' }) });
    renderWithProviders(<AssignmentDetailPage />);
    await screen.findByRole('button', { name: 'Забрал' });
    expect(screen.queryByRole('button', { name: 'Доставлено' })).not.toBeInTheDocument();
  });

  it('UNDER_REVIEW opens the acceptance dialog with a live-valid submit button', async () => {
    signIn(ME);
    mockFetch({ '/auth/me': ME, '/admin/assignments/a1': assignmentDetail({ status: 'UNDER_REVIEW', plannedMeters: 9, reportedMeters: 9 }) });
    renderWithProviders(<AssignmentDetailPage />);
    await userEvent.click(await screen.findByRole('button', { name: 'Принять работу' }));
    expect(await screen.findByText('Приёмка работы')).toBeInTheDocument();
    // brought=accepted=9, defective=rework=0 -> already valid; two buttons now share the name (the page's own action
    // is still in the DOM behind the modal) — the dialog's own submit is the LAST one rendered
    const buttons = screen.getAllByRole('button', { name: 'Принять работу' });
    expect(buttons[buttons.length - 1]).not.toBeDisabled();
  });
});

describe('acceptance dialog (M3 §20): validation and payload mirror the server rule exactly', () => {
  const assignment = assignmentDetail({ status: 'UNDER_REVIEW', plannedMeters: 9, reportedMeters: 9 }) as never;

  it('accepted + defective + rework must equal brought, or the submit button stays disabled', async () => {
    signIn(ME);
    mockFetch({ '/auth/me': ME });
    renderWithProviders(<AcceptDialog assignment={assignment} onClose={() => {}} />);
    const user = userEvent.setup();
    const accepted = screen.getByLabelText('Принято, м');
    await user.clear(accepted);
    await user.type(accepted, '5');
    expect(await screen.findByText('Принято + брак + доработка должно равняться принесено')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Принять работу' })).toBeDisabled();
  });

  it('a valid split (accepted + defective) submits exactly those figures', async () => {
    signIn(ME);
    const fetchMock = mockFetch({ '/auth/me': ME, '/admin/assignments/a1/accept': assignmentDetail({ status: 'PARTIALLY_ACCEPTED' }) });
    renderWithProviders(<AcceptDialog assignment={assignment} onClose={() => {}} />);
    const user = userEvent.setup();
    await user.clear(screen.getByLabelText('Принято, м'));
    await user.type(screen.getByLabelText('Принято, м'), '7');
    await user.clear(screen.getByLabelText('Брак, м'));
    await user.type(screen.getByLabelText('Брак, м'), '2');
    await user.click(screen.getByRole('button', { name: 'Принять работу' }));

    await waitFor(() => expect(fetchMock.mock.calls.some(([u]) => String(u).includes('/accept'))).toBe(true));
    const call = fetchMock.mock.calls.find(([u]) => String(u).includes('/accept'))!;
    const body = JSON.parse((call[1] as RequestInit).body as string);
    expect(body).toMatchObject({ broughtMeters: '9.00', acceptedMeters: '7.00', defectiveMeters: '2.00', reworkMeters: '0.00' });
  });
});

describe('cash payout dialog (M3 §21): presets, confirmation, and a friendly over-balance message', () => {
  it('full amount preset, confirmation states the exact figure, then submits it', async () => {
    signIn(ME);
    const fetchMock = mockFetch({ '/auth/me': ME, '/admin/workers/w1/ledger': { workerId: 'w1', balance: '100000', earned: '100000', paid: '0', history: [] } });
    renderWithProviders(<PayoutDialog workerId="w1" onClose={() => {}} />);
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Вся сумма' }));
    await user.click(screen.getByRole('button', { name: 'Выплатить' }));
    expect(await screen.findByText(/Вы действительно выдали/)).toHaveTextContent('100 000 сум');

    await user.click(screen.getByRole('button', { name: 'Выплатить' }));
    await waitFor(() => expect(fetchMock.mock.calls.some(([u]) => String(u).includes('/payout'))).toBe(true));
    const call = fetchMock.mock.calls.find(([u]) => String(u).includes('/payout'))!;
    expect(JSON.parse((call[1] as RequestInit).body as string)).toEqual({ amount: '100000' });
  });

  it('over the balance: blocked on the spot with a plain reason; nothing is sent', async () => {
    signIn(ME);
    mockFetch({
      '/auth/me': ME,
      '/admin/workers/w1/ledger': { workerId: 'w1', balance: '100000', earned: '100000', paid: '0', history: [] },
      '/admin/workers/w1/payout': errorResponse(409, { error: { code: 'INVARIANT_VIOLATION', message: 'Payout exceeds balance: 100000 owed, 999000 requested (use forced:true to override)' } }),
    });
    renderWithProviders(<PayoutDialog workerId="w1" onClose={() => {}} />);
    const user = userEvent.setup();
    const input = await screen.findByLabelText('Сумма');
    await user.type(input, '999000');
    expect(await screen.findByText(/Больше, чем причитается: максимум 100 000 сум/)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Выплатить' })).toBeDisabled();
    expect(screen.queryByText(/use forced:true/)).not.toBeInTheDocument();
  });
});

describe('worker detail (M3 §13): the same earned/paid/due figures the worker sees on her own phone', () => {
  it('shows balance, earned, paid and her assignment list', async () => {
    signIn(ME);
    mockFetch({
      '/auth/me': ME,
      '/workers/a1': { id: 'a1', code: 'W-0001', fullName: 'Малика Каримова', phone: '+998901234567', secondaryPhone: null, status: 'ACTIVE', latitude: null, longitude: null, locationReceivedAt: null, balance: '15000', manager: null, collateral: null, createdAt: '2026-01-01T00:00:00Z', updatedAt: '2026-01-01T00:00:00Z' },
      '/admin/workers/a1/ledger': { workerId: 'a1', balance: '15000', earned: '105000', paid: '90000', history: [{ id: 'h1', type: 'EARNING', amount: '60000', comment: null, createdAt: '2026-01-01T00:00:00Z' }] },
      '/admin/assignments': { items: [assignmentSummary()], nextCursor: null },
    });
    renderWithProviders(<WorkerDetailPage />);
    expect(await screen.findByText(/Малика Каримова/)).toBeInTheDocument();
    expect(await screen.findByText('15 000 сум')).toBeInTheDocument();
    expect(screen.getByText('105 000 сум')).toBeInTheDocument();
    expect(screen.getByText('90 000 сум')).toBeInTheDocument();
    expect(await screen.findByText(/Комплект «Роза»/)).toBeInTheDocument();
  });
});
