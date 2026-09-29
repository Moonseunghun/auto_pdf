import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// 재직증명서에 들어갈 값.
class CertData {
  CertData({
    required this.name,
    required this.birth,
    required this.address,
    required this.department,
    required this.position,
    required this.joinDate,
    required this.purpose,
    required this.companyName,
    required this.bizNumber,
    required this.companyAddress,
    required this.ceoName,
    required this.issueDate,
    this.issueNo = '',
  });

  final String name;
  final String birth;
  final String address;
  final String department;
  final String position;
  final DateTime joinDate;
  final String purpose;
  final String companyName;
  final String bizNumber;
  final String companyAddress;
  final String ceoName;
  final DateTime issueDate;
  final String issueNo;
}

final _ymd = DateFormat('yyyy년 MM월 dd일');

String _period(DateTime from, DateTime to) {
  var months = (to.year - from.year) * 12 + to.month - from.month;
  if (to.day < from.day) months--;
  if (months < 0) months = 0;
  final y = months ~/ 12, m = months % 12;
  final len = [if (y > 0) '$y년', '$m개월'].join(' ');
  return '${_ymd.format(from)} ~ ${_ymd.format(to)} ($len)';
}

/// A4 한 장짜리 재직증명서 PDF를 만든다.
/// 한글 폰트는 printing 패키지가 Google Fonts에서 받아온다(첫 실행 시 인터넷 필요).
Future<Uint8List> buildCertPdf(CertData d, PdfPageFormat format) async {
  final regular = await PdfGoogleFonts.nanumMyeongjoRegular();
  final bold = await PdfGoogleFonts.nanumMyeongjoBold();
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );

  const border = pw.BorderSide(width: 0.8);
  const labelBg = PdfColor.fromInt(0xFFF2F2F2);

  pw.Widget cell(String text, {bool label = false, int flex = 1}) =>
      pw.Expanded(
        flex: flex,
        child: pw.Container(
          height: 30,
          alignment:
              label ? pw.Alignment.center : pw.Alignment.centerLeft,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8),
          decoration: pw.BoxDecoration(
            color: label ? labelBg : null,
            border: const pw.Border(right: border),
          ),
          child: pw.Text(text,
              style: pw.TextStyle(
                  fontSize: 10.5,
                  fontWeight: label ? pw.FontWeight.bold : null)),
        ),
      );

  pw.Widget row(List<pw.Widget> cells) => pw.Container(
        decoration: const pw.BoxDecoration(
            border: pw.Border(left: border, bottom: border)),
        child: pw.Row(children: cells),
      );

  pw.Widget section(String title, List<pw.Widget> rows) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            height: 28,
            alignment: pw.Alignment.center,
            decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFDDDDDD),
              border: pw.Border(left: border, right: border, bottom: border),
            ),
            child: pw.Text(title,
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold)),
          ),
          ...rows,
        ],
      );

  doc.addPage(
    pw.Page(
      pageFormat: format,
      margin: const pw.EdgeInsets.fromLTRB(56, 48, 56, 48),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text('발급번호: ${d.issueNo}',
              style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 28),
          pw.Center(
            child: pw.Text('재 직 증 명 서',
                style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 4)),
          ),
          pw.SizedBox(height: 32),
          pw.Container(
              decoration: const pw.BoxDecoration(
                  border: pw.Border(top: border))),
          section('인 적 사 항', [
            row([
              cell('성    명', label: true, flex: 2),
              cell(d.name, flex: 3),
              cell('생년월일', label: true, flex: 2),
              cell(d.birth, flex: 3),
            ]),
            row([
              cell('주    소', label: true, flex: 2),
              cell(d.address, flex: 8),
            ]),
          ]),
          section('재 직 사 항', [
            row([
              cell('부    서', label: true, flex: 2),
              cell(d.department, flex: 3),
              cell('직    위', label: true, flex: 2),
              cell(d.position, flex: 3),
            ]),
            row([
              cell('재직기간', label: true, flex: 2),
              cell(_period(d.joinDate, d.issueDate), flex: 8),
            ]),
            row([
              cell('용    도', label: true, flex: 2),
              cell(d.purpose, flex: 8),
            ]),
          ]),
          section('회 사 정 보', [
            row([
              cell('회 사 명', label: true, flex: 2),
              cell(d.companyName, flex: 3),
              cell('사업자번호', label: true, flex: 2),
              cell(d.bizNumber, flex: 3),
            ]),
            row([
              cell('소 재 지', label: true, flex: 2),
              cell(d.companyAddress, flex: 8),
            ]),
          ]),
          pw.SizedBox(height: 56),
          pw.Center(
            child: pw.Text('위와 같이 재직하고 있음을 증명합니다.',
                style: const pw.TextStyle(fontSize: 13)),
          ),
          pw.SizedBox(height: 40),
          pw.Center(
            child: pw.Text(_ymd.format(d.issueDate),
                style: const pw.TextStyle(fontSize: 13)),
          ),
          pw.Spacer(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(d.companyName,
                      style: pw.TextStyle(
                          fontSize: 15, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  pw.Text('대표이사   ${d.ceoName}',
                      style: const pw.TextStyle(fontSize: 14)),
                ],
              ),
              pw.SizedBox(width: 16),
              // 직인은 인쇄 후 실제로 날인한다.
              pw.Container(
                width: 52,
                height: 52,
                alignment: pw.Alignment.center,
                child: pw.Text('(인)',
                    style: const pw.TextStyle(
                        fontSize: 12, color: PdfColors.grey600)),
              ),
            ],
          ),
          pw.SizedBox(height: 24),
        ],
      ),
    ),
  );

  return doc.save();
}

/// 미리보기 화면에서 쓰는 파일 이름.
String certFileName(CertData d) =>
    '재직증명서_${d.name}_${DateFormat('yyyyMMdd').format(d.issueDate)}.pdf';
