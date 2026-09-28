import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../l10n/app_localizations.dart';
import 'widgets.dart';

/// «Печать QR»: a label (80 × 60 mm) with the QR and 1-3 lines of text, sent to the Android print dialog (any printer
/// the phone knows, or «Сохранить как PDF»). Manrope is embedded: the PDF base fonts have no Cyrillic.
Future<void> printQrLabel({required String code, required String title, List<String> lines = const [], int copies = 1}) async {
  final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Manrope-500.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Manrope-800.ttf'));
  final doc = pw.Document(title: title, author: 'Diamoraa');
  const format = PdfPageFormat(80 * PdfPageFormat.mm, 60 * PdfPageFormat.mm, marginAll: 4 * PdfPageFormat.mm);
  for (var i = 0; i < copies; i++) {
    doc.addPage(pw.Page(
      pageFormat: format,
      build: (_) => pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: code, width: 44 * PdfPageFormat.mm, height: 44 * PdfPageFormat.mm),
        pw.SizedBox(width: 4 * PdfPageFormat.mm),
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, mainAxisAlignment: pw.MainAxisAlignment.center, children: [
            pw.Text('Diamoraa', style: pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.grey700)),
            pw.SizedBox(height: 2),
            pw.Text(title, style: pw.TextStyle(font: bold, fontSize: 11), maxLines: 3),
            for (final line in lines) ...[pw.SizedBox(height: 2), pw.Text(line, style: pw.TextStyle(font: regular, fontSize: 9), maxLines: 2)],
          ]),
        ),
      ]),
    ));
  }
  await Printing.layoutPdf(name: 'QR $title', format: format, onLayout: (_) async => doc.save());
}

/// The «Печать QR» button used next to every QR on screen.
class PrintQrButton extends StatelessWidget {
  const PrintQrButton({super.key, required this.code, required this.title, this.lines = const []});
  final String code;
  final String title;
  final List<String> lines;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return FitButton(
      icon: Icons.print_rounded,
      label: l.qrPrint,
      onPressed: () async {
        try {
          await printQrLabel(code: code, title: title, lines: lines);
        } catch (e) {
          if (context.mounted) showError(context, e);
        }
      },
    );
  }
}
