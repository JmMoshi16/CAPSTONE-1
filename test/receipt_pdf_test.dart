import 'package:flutter_test/flutter_test.dart';
import 'package:ecoreward_bin/screens/admin/receipt_pdf.dart';

void main() {
  test('receipt builds a real PDF with the same QR payload format', () async {
    final now = DateTime(2026, 10, 10, 9, 30);
    final bytes = await buildReceiptPdf(
      qrData: 'ECOBIN:Recyclable:123e4567-e89b-12d3-a456-426614174000',
      wasteType: 'Recyclable',
      points: 10,
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 20)),
    );
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
