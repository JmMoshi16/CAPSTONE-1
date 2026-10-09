import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Print-ready receipt for an admin-generated code: an 80 mm roll page (thermal printers),
/// black on white, with a vector QR that stays sharp at any size. The QR carries exactly the
/// same payload as the on-screen code (ECOBIN:<Type>:<uuid>).
Future<Uint8List> buildReceiptPdf({
  required String qrData,
  required String wasteType,
  required int points,
  required DateTime createdAt,
  required DateTime expiresAt,
}) async {
  final doc = pw.Document(title: 'ECOReward receipt', author: 'ECOReward Bin');
  final time = DateFormat('h:mm a');
  pw.Widget row(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(k, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
          pw.Text(v, style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ]),
      );
  pw.Widget rule() => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 6),
        child: pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 0.6, color: PdfColors.grey600),
      );

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.roll80.copyWith(marginLeft: 12, marginRight: 12, marginTop: 14, marginBottom: 14),
    build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
      pw.Text('ECOReward Bin', style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.Text('Smart Waste Recycling', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
      pw.SizedBox(height: 2),
      pw.Text(DateFormat('MMM d, yyyy  h:mm a').format(createdAt), style: const pw.TextStyle(fontSize: 8)),
      rule(),
      row('Waste type', wasteType),
      row('Points to earn', '+$points pts (base)'),
      row('Valid until', time.format(expiresAt)),
      rule(),
      pw.Text('Scan with the ECOReward app', style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: qrData, width: 140, height: 140),
      pw.SizedBox(height: 6),
      pw.Text('Single use. Valid for 20 minutes from when it was made (see time above).',
          textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
      rule(),
      pw.Text('Thank you for helping the environment!', style: const pw.TextStyle(fontSize: 8)),
    ]),
  ));
  return doc.save();
}
