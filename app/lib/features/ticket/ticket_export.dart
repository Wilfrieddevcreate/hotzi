import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/format.dart';
import '../../data/models.dart';
import '../../data/ticket_codes.dart';

/// Partage et impression des tickets.
abstract final class TicketExport {
  /// Partage l'image de la carte (WhatsApp, etc.). Renvoie false si l'image n'a pas pu être faite.
  static Future<bool> shareImage(RenderRepaintBoundary? card, Ticket ticket) async {
    if (card == null) return false;
    final image = await card.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) return false;
    final code = TicketCodes.format(ticket.code);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes.buffer.asUint8List(), mimeType: 'image/png')],
        fileNameOverrides: ['ticket-hotzi-$code.png'],
        text: 'Ton ticket Wi-Fi Hotzi : $code',
      ),
    );
    return true;
  }

  /// Ouvre l'impression Android avec une page par ticket.
  static Future<void> printTickets(List<Ticket> tickets) => Printing.layoutPdf(
    name: tickets.length == 1 ? 'Ticket Hotzi ${TicketCodes.format(tickets.first.code)}' : 'Tickets Hotzi',
    onLayout: (format) => pdf(tickets, format),
  );

  /// Mise en page noir et blanc, lisible aussi sur une imprimante de tickets.
  /// Les polices standard du PDF suffisent : tous les textes sont en Latin-1.
  static Future<Uint8List> pdf(List<Ticket> tickets, PdfPageFormat format) async {
    final doc = pw.Document(title: 'Tickets Hotzi', author: 'Hotzi');
    final width = format.availableWidth.clamp(0, 72 * PdfPageFormat.mm).toDouble();
    for (final ticket in tickets) {
      doc.addPage(
        pw.Page(
          pageFormat: format,
          build: (context) => pw.Center(
            child: pw.SizedBox(width: width, child: _ticket(ticket)),
          ),
        ),
      );
    }
    return doc.save();
  }

  static pw.Widget _ticket(Ticket ticket) {
    const mm = PdfPageFormat.mm;
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('hotzi', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text('TICKET WI-FI', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          ],
        ),
        pw.Divider(thickness: 1.5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  Format.longDuration(ticket.durationMinutes),
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text('Forfait ${ticket.planName}', style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 1.2),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                Format.fcfa(ticket.priceFcfa, plain: true),
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4 * mm),
        pw.Center(
          child: pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: ticket.code, width: 38 * mm, height: 38 * mm),
        ),
        pw.SizedBox(height: 2 * mm),
        pw.Center(child: pw.Text('Ton code', style: const pw.TextStyle(fontSize: 8))),
        pw.Center(
          child: pw.Text(
            TicketCodes.format(ticket.code),
            style: pw.TextStyle(font: pw.Font.courierBold(), fontSize: 20),
          ),
        ),
        pw.SizedBox(height: 3 * mm),
        pw.Divider(borderStyle: pw.BorderStyle.dashed),
        pw.Center(
          child: pw.Text(
            'Le temps démarre à la première connexion · un seul téléphone',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
      ],
    );
  }
}
