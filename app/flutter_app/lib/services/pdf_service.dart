import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Generates and shares a forensic analysis PDF report.
Future<void> generateAndShareForensicPdf({
  required File? imageFile,
  required Map<String, dynamic> result,
  required bool isReal,
}) async {
  final pdf = pw.Document();

  // ── Colours ──────────────────────────────────────────────────
  const bgDeep    = PdfColor.fromInt(0xFF0A0A1A);
  const bgSurface = PdfColor.fromInt(0xFF12122A);
  const primary   = PdfColor.fromInt(0xFF7C3AED);
  const success   = PdfColor.fromInt(0xFF00C896);
  const danger    = PdfColor.fromInt(0xFFEF4444);
  const warning   = PdfColor.fromInt(0xFFF59E0B);
  const textPrime = PdfColors.white;
  const textMuted = PdfColor.fromInt(0xFF8884A0);

  final verdictColor = isReal ? success : danger;
  final verdictLabel = isReal ? 'VERIFIED REAL' : 'DETECTION ALERT';

  // ── Date / report ID ─────────────────────────────────────────
  final now      = DateTime.now();
  final dateStr  = DateFormat('dd MMM yyyy, HH:mm:ss').format(now);
  final reportId = 'MVR-${now.millisecondsSinceEpoch ~/ 1000}';

  // ── Grayscale image embed ─────────────────────────────────────
  pw.ImageProvider? bwImage;
  if (imageFile != null) {
    try {
      final rawBytes = await imageFile.readAsBytes();
      final decoded  = img.decodeImage(rawBytes);
      if (decoded != null) {
        final grayImg  = img.grayscale(decoded);
        final pngBytes = Uint8List.fromList(img.encodePng(grayImg));
        bwImage        = pw.MemoryImage(pngBytes);
      }
    } catch (_) {}
  }

  // ── Text style helper ─────────────────────────────────────────
  pw.TextStyle ts({
    double size          = 10,
    PdfColor color       = textPrime,
    pw.FontWeight weight = pw.FontWeight.normal,
  }) =>
      pw.TextStyle(fontSize: size, color: color, fontWeight: weight);

  // ── Divider ───────────────────────────────────────────────────
  pw.Widget hr() => pw.Container(
        height: 0.5,
        color: PdfColor.fromInt(0xFF2E2E50),
        margin: const pw.EdgeInsets.symmetric(vertical: 8),
      );

  // ── Metric box ────────────────────────────────────────────────
  pw.Widget metricBox(String label, String value, PdfColor valColor) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: bgSurface,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            border: pw.Border.all(color: PdfColor.fromInt(0xFF2E2E50), width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label, style: ts(size: 7, color: textMuted)),
              pw.SizedBox(height: 4),
              pw.Text(value, style: ts(size: 13, color: valColor, weight: pw.FontWeight.bold)),
            ],
          ),
        ),
      );

  // ── Forensic rows ─────────────────────────────────────────────
  List<pw.Widget> forensicRows() {
    final rows = <pw.Widget>[];

    // Structural pipeline
    final goResults = result['go_results'] as List?;
    if (goResults != null && goResults.isNotEmpty) {
      rows.add(pw.Text('STRUCTURAL PIPELINE', style: ts(size: 8, color: primary, weight: pw.FontWeight.bold)));
      rows.add(pw.SizedBox(height: 6));
      for (final r in goResults) {
        final isPass = (r['status'] ?? '').toString().toUpperCase() == 'REAL';
        rows.add(pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 8, height: 8,
              margin: const pw.EdgeInsets.only(top: 2, right: 6),
              decoration: pw.BoxDecoration(
                shape: pw.BoxShape.circle,
                color: isPass ? success : danger,
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                '${r["method"]}: ${r["details"]}',
                style: ts(size: 9),
              ),
            ),
          ],
        ));
        rows.add(pw.SizedBox(height: 4));
      }
      rows.add(hr());
    }

    // Forensic flags
    final flags = result['forensic_flags'] as List?;
    if (flags != null && flags.isNotEmpty) {
      rows.add(pw.Text('FORENSIC FLAGS', style: ts(size: 8, color: warning, weight: pw.FontWeight.bold)));
      rows.add(pw.SizedBox(height: 6));
      for (final flag in flags) {
        rows.add(pw.Row(children: [
          pw.Container(
            width: 4, height: 4,
            margin: const pw.EdgeInsets.only(top: 3, right: 6),
            decoration: const pw.BoxDecoration(shape: pw.BoxShape.circle, color: warning),
          ),
          pw.Text(flag.toString().replaceAll('_', ' ').toUpperCase(), style: ts(size: 9)),
        ]));
        rows.add(pw.SizedBox(height: 4));
      }
      rows.add(hr());
    }

    // Forensic detail
    final detail = result['forensic_detail']?.toString();
    if (detail != null && detail.isNotEmpty) {
      rows.add(pw.Text('FORENSIC ANALYSIS DETAIL', style: ts(size: 8, color: primary, weight: pw.FontWeight.bold)));
      rows.add(pw.SizedBox(height: 6));
      for (final part in detail.split(' | ')) {
        if (part.trim().isEmpty) continue;
        rows.add(pw.Text('• ${part.trim()}', style: ts(size: 9)));
        rows.add(pw.SizedBox(height: 3));
      }
      rows.add(hr());
    }

    // Video flow stats
    final flowStats = result['flow_stats'] as Map?;
    if (flowStats != null) {
      rows.add(pw.Text('VIDEO OPTICAL FLOW STATS', style: ts(size: 8, color: primary, weight: pw.FontWeight.bold)));
      rows.add(pw.SizedBox(height: 6));
      flowStats.forEach((k, v) {
        rows.add(pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(k.toString().toUpperCase().replaceAll('_', ' '), style: ts(size: 9, color: textMuted)),
            pw.Text(v.toString(), style: ts(size: 9)),
          ],
        ));
        rows.add(pw.SizedBox(height: 3));
      });
      rows.add(hr());
    }

    // pHash
    final phash = result['phash']?.toString();
    if (phash != null && phash.isNotEmpty) {
      rows.add(pw.Text('PERCEPTUAL HASH (pHash)', style: ts(size: 8, color: primary, weight: pw.FontWeight.bold)));
      rows.add(pw.SizedBox(height: 4));
      rows.add(pw.Text(phash, style: ts(size: 8, color: textMuted)));
      rows.add(hr());
    }

    return rows;
  }

  // ── Build PDF page ────────────────────────────────────────────
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(0),
      build: (context) => pw.Stack(
        children: [
          // Background
          pw.Container(color: bgDeep),

          // Header bar
          pw.Positioned(
            top: 0, left: 0, right: 0,
            child: pw.Container(
              height: 90,
              padding: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              decoration: const pw.BoxDecoration(
                gradient: pw.LinearGradient(
                  colors: [PdfColor.fromInt(0xFF1A0A3A), PdfColor.fromInt(0xFF0A0A1A)],
                  begin: pw.Alignment.topLeft,
                  end: pw.Alignment.bottomRight,
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text('MEDIA VALIDATER', style: ts(size: 18, weight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 3),
                      pw.Text('Deep Authenticity Engine — Forensic Report', style: ts(size: 9, color: primary)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(dateStr, style: ts(size: 8, color: textMuted)),
                      pw.SizedBox(height: 3),
                      pw.Text('Report ID: $reportId', style: ts(size: 8, color: textMuted)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Main body
          pw.Positioned(
            top: 100, left: 24, right: 24, bottom: 40,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Verdict badge
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: pw.BoxDecoration(
                    color: verdictColor.shade(0.15),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                    border: pw.Border.all(color: verdictColor, width: 1.5),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: 10, height: 10,
                        decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, color: verdictColor),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Text(verdictLabel, style: ts(size: 16, color: verdictColor, weight: pw.FontWeight.bold)),
                      pw.Spacer(),
                      pw.Text('Confidence: ${result['confidence']}%', style: ts(size: 12, color: verdictColor, weight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),

                // Score metrics
                pw.Row(
                  children: [
                    metricBox('CONFIDENCE', '${result['confidence']}%', verdictColor),
                    pw.SizedBox(width: 8),
                    metricBox(
                      'AI RAW SCORE',
                      result['ai_raw_score'] != null
                          ? (result['ai_raw_score'] as num).toStringAsFixed(3)
                          : '-',
                      textPrime,
                    ),
                    pw.SizedBox(width: 8),
                    metricBox(
                      'FORENSIC PENALTY',
                      result['forensic_penalty'] != null
                          ? '${((result['forensic_penalty'] as num) * 100).toStringAsFixed(1)}%'
                          : '-',
                      result['forensic_penalty'] != null && (result['forensic_penalty'] as num) > 0.3
                          ? warning
                          : success,
                    ),
                  ],
                ),
                pw.SizedBox(height: 14),

                // Two-column: image + forensic detail
                pw.Expanded(
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // B&W image column
                      if (bwImage != null)
                        pw.Container(
                          width: 160,
                          margin: const pw.EdgeInsets.only(right: 14),
                          child: pw.Column(
                            children: [
                              pw.Container(
                                decoration: pw.BoxDecoration(
                                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                                  border: pw.Border.all(color: primary, width: 1.5),
                                ),
                                child: pw.Image(bwImage, fit: pw.BoxFit.cover),
                              ),
                              pw.SizedBox(height: 6),
                              pw.Text(
                                'Analysed image\n(grayscale forensic copy)',
                                style: ts(size: 7, color: textMuted),
                                textAlign: pw.TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                      // Forensic details column
                      pw.Expanded(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(14),
                          decoration: pw.BoxDecoration(
                            color: bgSurface,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                            border: pw.Border.all(color: PdfColor.fromInt(0xFF2E2E50), width: 0.5),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'FORENSIC ANALYSIS DETAILS',
                                style: ts(size: 9, color: primary, weight: pw.FontWeight.bold),
                              ),
                              pw.SizedBox(height: 8),
                              ...forensicRows(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 10),
                pw.Text('AI Model: ${result['ai_model'] ?? '-'}', style: ts(size: 8, color: textMuted)),
              ],
            ),
          ),

          // Watermark
          pw.Positioned.fill(
            child: pw.Center(
              child: pw.Transform.rotate(
                angle: -0.5236, // -30 degrees
                child: pw.Opacity(
                  opacity: 0.06,
                  child: pw.Column(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text(
                        'MEDIA VALIDATER',
                        style: pw.TextStyle(fontSize: 42, fontWeight: pw.FontWeight.bold, color: primary),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'NOT DUPLICATE',
                        style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Footer
          pw.Positioned(
            bottom: 0, left: 0, right: 0,
            child: pw.Container(
              height: 36,
              padding: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              color: bgSurface,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Generated by Media Validater — Deep Authenticity Engine', style: ts(size: 7, color: textMuted)),
                  pw.Text('This report is machine-generated. For reference only.', style: ts(size: 7, color: textMuted)),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  // Share PDF
  await Printing.sharePdf(
    bytes: await pdf.save(),
    filename: 'media_validater_report_$reportId.pdf',
  );
}
