/**
 * The real colour of a bead / ribbon colour: its hex from the settings, otherwise guessed from the name (Russian, Uzbek or
 * English, as the owner types them - «Желтый», «Бардовый», «sariq», «Pink»…). The same list as the app
 * (apps/mobile/lib/core/ui/color_swatch.dart). undefined = unknown.
 */
const NAMED: [string[], string][] = [
  [['темно-син', 'темносин', 'navy', "to'q ko'k", 'toq kok'], '#1E3A8A'],
  [['голуб', 'havorang', 'sky', 'light blue'], '#60A5FA'],
  [['бирюз', 'turquoise', 'firuza'], '#14B8A6'],
  [['бордо', 'бардо', 'марсал', 'burgundy', 'maroon', 'bordo'], '#800020'],
  [['малин', 'crimson', 'raspberry'], '#DC143C'],
  [['розов', 'pink', 'pushti'], '#F472B6'],
  [['красн', 'red', 'qizil'], '#DC2626'],
  [['оранж', 'orange', "to'q sariq"], '#F97316'],
  [['золот', 'gold', 'oltin'], '#D4AF37'],
  [['желт', 'yellow', 'sariq'], '#FACC15'],
  [['салат', 'lime'], '#84CC16'],
  [['зелен', 'green', 'yashil'], '#16A34A'],
  [['фиолет', 'сирен', 'лилов', 'purple', 'violet', 'binafsha', 'siyohrang'], '#8B5CF6'],
  [['син', 'blue', "ko'k", 'kok'], '#2563EB'],
  [['коричн', 'шоколад', 'brown', 'jigarrang'], '#8B5A2B'],
  [['беж', 'капуч', 'beige', 'krem', 'cream', 'крем'], '#E8D5B5'],
  [['серебр', 'silver', 'kumush'], '#C0C0C0'],
  [['сер', 'grey', 'gray', 'kulrang'], '#9CA3AF'],
  [['черн', 'black', 'qora'], '#111111'],
  [['бел', 'white', 'oq'], '#FFFFFF'],
  [['прозрач', 'transparent', 'shaffof'], '#E5F3FF'],
];

export function swatch(hex?: string | null, name?: string | null): string | undefined {
  const h = (hex ?? '').replace('#', '').trim();
  if (/^[0-9a-f]{6}$/i.test(h)) return `#${h}`;
  const n = (name ?? '').toLowerCase().replace(/ё/g, 'е').trim();
  if (!n) return undefined;
  return NAMED.find(([words]) => words.some((w) => n.includes(w)))?.[1];
}
