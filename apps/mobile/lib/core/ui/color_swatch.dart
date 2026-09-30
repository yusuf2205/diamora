import 'package:flutter/material.dart';

/// The real colour of a bead / ribbon colour: its hex from the settings, otherwise guessed from the name
/// (Russian, Uzbek or English, as the owner types them - «Желтый», «Бардовый», «sariq», «Pink»…). null = unknown.
Color? swatchColor(String? hex, [String? name]) {
  final h = (hex ?? '').replaceFirst('#', '').trim();
  if (h.length == 6) {
    final v = int.tryParse(h, radix: 16);
    if (v != null) return Color(0xFF000000 | v);
  }
  final n = (name ?? '').toLowerCase().replaceAll('ё', 'е').trim();
  if (n.isEmpty) return null;
  for (final (words, color) in _named) {
    if (words.any(n.contains)) return color;
  }
  return null;
}

// the more specific names first («тёмно-синий» before «синий», «голубой» before «синий»)
const _named = <(List<String>, Color)>[
  (['темно-син', 'темносин', 'navy', "to'q ko'k", 'toq kok'], Color(0xFF1E3A8A)),
  (['голуб', 'havorang', 'sky', 'light blue'], Color(0xFF60A5FA)),
  (['бирюз', 'turquoise', 'firuza'], Color(0xFF14B8A6)),
  (['бордо', 'бардо', 'марсал', 'burgundy', 'maroon', 'bordo'], Color(0xFF800020)),
  (['малин', 'crimson', 'raspberry'], Color(0xFFDC143C)),
  (['розов', 'pink', 'pushti'], Color(0xFFF472B6)),
  (['красн', 'red', 'qizil'], Color(0xFFDC2626)),
  (['оранж', 'orange', "to'q sariq"], Color(0xFFF97316)),
  (['золот', 'gold', 'oltin'], Color(0xFFD4AF37)),
  (['желт', 'yellow', 'sariq'], Color(0xFFFACC15)),
  (['салат', 'lime'], Color(0xFF84CC16)),
  (['зелен', 'green', 'yashil'], Color(0xFF16A34A)),
  (['фиолет', 'сирен', 'лилов', 'purple', 'violet', 'binafsha', 'siyohrang'], Color(0xFF8B5CF6)),
  (['син', 'blue', "ko'k", 'kok'], Color(0xFF2563EB)),
  (['коричн', 'шоколад', 'brown', 'jigarrang'], Color(0xFF8B5A2B)),
  (['беж', 'капуч', 'beige', 'krem', 'cream', 'крем'], Color(0xFFE8D5B5)),
  (['серебр', 'silver', 'kumush'], Color(0xFFC0C0C0)),
  (['сер', 'grey', 'gray', 'kulrang'], Color(0xFF9CA3AF)),
  (['черн', 'black', 'qora'], Color(0xFF111111)),
  (['бел', 'white', 'oq'], Color(0xFFFFFFFF)),
  (['прозрач', 'transparent', 'shaffof'], Color(0xFFE5F3FF)),
];

/// Text / border that reads on top of [c].
Color onSwatch(Color c) => c.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

/// A colour's name on a chip painted in that colour (a neutral chip with a dot when the colour is unknown).
class ColorNameChip extends StatelessWidget {
  const ColorNameChip({super.key, required this.name, this.hex, this.suffix, this.selected, this.onSelected});
  final String name;
  final String? hex;
  final String? suffix;
  /// with [onSelected]: a choice (a check mark and a thick ring when chosen)
  final bool? selected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = swatchColor(hex, name);
    final fg = c == null ? scheme.onSurface : onSwatch(c);
    final chosen = selected ?? false;
    final text = suffix == null || suffix!.isEmpty ? name : '$name · $suffix';
    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: c ?? scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        // a light ring keeps black on a dark screen and white on a light one visible; a thick one marks the choice
        border: Border.all(color: chosen ? scheme.primary : scheme.outlineVariant, width: chosen ? 3 : 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (chosen) ...[Icon(Icons.check_rounded, size: 18, color: fg), const SizedBox(width: 4)],
        Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
      ]),
    );
    if (onSelected == null) return Semantics(label: text, child: chip);
    return Semantics(
      button: true,
      selected: chosen,
      label: text,
      child: InkWell(borderRadius: BorderRadius.circular(20), onTap: () => onSelected!(!chosen), child: chip),
    );
  }
}
