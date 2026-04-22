import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/entities/expense.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_member.dart';
import 'settlement_calculator.dart';

Future<Uint8List> generateGroupReportPdf({
  required ExpenseGroup group,
  required List<ExpenseItem> expenses,
  required Map<String, double> balances,
  required String currencyCode,
}) async {
  final pw.Document pdf = pw.Document();

  final List<Settlement> settlements = calculateOptimalSettlements(balances);

  String getMemberName(String id) {
    for (final GroupMember m in group.members) {
      if (m.id == id) return m.name;
    }
    return 'Unknown';
  }

  final PdfColor primaryColor = PdfColor.fromHex('#1CC29F');
  final PdfColor errorColor = PdfColors.red;
  final PdfColor surfaceColor = PdfColors.grey100;

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
      build: (pw.Context context) {
        return <pw.Widget>[
          // Header Block
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: <pw.Widget>[
                pw.Text(
                  'Expense Report: ${group.name}',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                ),
                pw.Text(
                  DateTime.now().toIso8601String().split('T').first,
                  style: const pw.TextStyle(fontSize: 14, color: PdfColors.white),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 30),

          // Settlement Plan Section
          pw.Text('Settlement Plan', style: pw.TextStyle(fontSize: 18, color: primaryColor, fontWeight: pw.FontWeight.bold)),
          pw.Divider(color: primaryColor, thickness: 2),
          pw.SizedBox(height: 10),
          
          if (settlements.isEmpty)
            pw.Text('Everyone is cleanly settled up!', style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700))
          else
            pw.Column(
              children: settlements.map((Settlement s) {
                final String from = getMemberName(s.fromId);
                final String to = getMemberName(s.toId);
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: pw.BoxDecoration(
                    color: surfaceColor,
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: <pw.Widget>[
                      pw.RichText(
                        text: pw.TextSpan(
                          children: <pw.InlineSpan>[
                            pw.TextSpan(text: '$from ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                            const pw.TextSpan(text: 'owes '),
                            pw.TextSpan(text: to, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                      pw.Text(
                        '$currencyCode ${s.amount.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          color: errorColor,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

          pw.SizedBox(height: 30),

          // Expenses Section
          pw.Text('All Expenses', style: pw.TextStyle(fontSize: 18, color: primaryColor, fontWeight: pw.FontWeight.bold)),
          pw.Divider(color: primaryColor, thickness: 2),
          pw.SizedBox(height: 10),

          if (expenses.isEmpty)
            pw.Text('No expenses recorded in this group.', style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700))
          else
            pw.Table.fromTextArray(
              context: context,
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerDecoration: pw.BoxDecoration(color: primaryColor.shade(.1)),
              headerStyle: pw.TextStyle(color: primaryColor, fontWeight: pw.FontWeight.bold),
              cellHeight: 30,
              cellAlignments: <int, pw.Alignment>{
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerRight,
              },
              headers: <String>['Date', 'Description', 'Action', 'Cost ($currencyCode)'],
              data: expenses.map((ExpenseItem e) {
                final String dateStr = '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}';
                String paidByStr = 'Multiple';
                if (e.payers.length == 1) {
                  paidByStr = getMemberName(e.payers.first.memberId);
                }
                return <String>[
                  dateStr,
                  e.title,
                  'Paid by $paidByStr',
                  e.totalAmount.toStringAsFixed(2),
                ];
              }).toList(),
            ),
        ];
      },
    ),
  );

  return pdf.save();
}
