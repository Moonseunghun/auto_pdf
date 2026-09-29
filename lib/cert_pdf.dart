import 'dart:math' as math;
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;

/// 재직증명서 양식 종류.
enum CertTemplate {
  basic('기본형'),
  standard('표준형');

  const CertTemplate(this.label);
  final String label;
}

/// 재직증명서에 들어갈 값. 양식마다 쓰는 항목이 다르고, 안 쓰는 항목은 빈 문자열.
class CertData {
  CertData({
    required this.template,
    required this.name,
    required this.address,
    required this.department,
    required this.position,
    required this.joinDate,
    required this.companyName,
    required this.bizNumber,
    required this.companyAddress,
    required this.ceoName,
    required this.issueDate,
    this.birth = '',
    this.rrn = '',
    this.purpose = '',
    this.issueNo = '',
    this.companyPhone = '',
    this.confirmerTitle = '',
    this.confirmerName = '',
    this.showSeal = true,
  });

  final CertTemplate template;
  final String name;
  final String birth; // 기본형
  final String rrn; // 표준형: 주민등록번호
  final String address;
  final String department;
  final String position;
  final DateTime joinDate;
  final String purpose; // 기본형
  final String companyName;
  final String companyPhone; // 표준형
  final String bizNumber;
  final String companyAddress;
  final String ceoName;
  final String confirmerTitle; // 표준형: 확인자 직위
  final String confirmerName; // 표준형: 확인자 성명
  final DateTime issueDate;
  final String issueNo; // 기본형
  final bool showSeal;
}

/// PDF에 쓸 폰트. 기본값은 앱에 들어 있는 나눔 폰트(assets/fonts, 오프라인 동작).
class CertFonts {
  const CertFonts({
    required this.serif,
    required this.serifBold,
    required this.sans,
    required this.sansBold,
  });

  final pw.Font serif, serifBold, sans, sansBold;

  static CertFonts? _cache;

  static Future<pw.Font> _load(String file) async =>
      pw.Font.ttf(await rootBundle.load('assets/fonts/$file.ttf'));

  static Future<CertFonts> bundled() async => _cache ??= CertFonts(
        serif: await _load('NanumMyeongjo-Regular'),
        serifBold: await _load('NanumMyeongjo-Bold'),
        sans: await _load('NanumGothic-Regular'),
        sansBold: await _load('NanumGothic-Bold'),
      );
}

final _ymd = DateFormat('yyyy년 MM월 dd일');
const _sealRed = PdfColor.fromInt(0xFFD7263D);

String _period(DateTime from, DateTime to) {
  var months = (to.year - from.year) * 12 + to.month - from.month;
  if (to.day < from.day) months--;
  if (months < 0) months = 0;
  final y = months ~/ 12, m = months % 12;
  final len = [if (y > 0) '$y년', '$m개월'].join(' ');
  return '${_ymd.format(from)} ~ ${_ymd.format(to)} ($len)';
}

/// 개인 도장: 빨간 원 안에 이름을 한 글자씩 세로로.
/// 4자 이상이면 한 줄에 두 글자씩(예: 남궁 / 민수).
pw.Widget personalSeal(String name, pw.Font font, {double size = 38}) {
  final chars = name.replaceAll(' ', '').split('');
  if (chars.isEmpty) return pw.SizedBox(width: size, height: size);
  final perLine = chars.length <= 3 ? 1 : 2;
  final rows = (chars.length / perLine).ceil();
  final fs = size * 0.7 / rows;
  final lines = [
    for (var r = 0; r < rows; r++)
      pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          for (final ch in chars.skip(r * perLine).take(perLine))
            pw.Text(ch,
                style: pw.TextStyle(
                    font: font, fontSize: fs, color: _sealRed, height: 1)),
        ],
      ),
  ];
  return pw.Opacity(
    opacity: 0.88,
    child: pw.Container(
      width: size,
      height: size,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        shape: pw.BoxShape.circle,
        border: pw.Border.all(color: _sealRed, width: size * 0.05),
      ),
      child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: lines),
    ),
  );
}

/// 회사 직인: 빨간 사각형 안에 '회사명 + 인'을 격자로(왼→오른쪽, 위→아래 줄 순서).
/// 예) 언더핀 → 언더 / 핀인
pw.Widget companySeal(String company, pw.Font font, {double size = 52}) {
  var text = company
      .replaceAll('(주)', '주식회사')
      .replaceAll(RegExp(r'[\s()]'), '');
  if (text.isEmpty) return pw.SizedBox(width: size, height: size);
  if (!text.endsWith('인')) text += '인';
  final chars = text.split('');
  final cols = math.sqrt(chars.length).ceil();
  final rows = (chars.length / cols).ceil();
  final fs = size * 0.72 / math.max(cols, rows);
  final lines = [
    for (var r = 0; r < rows; r++)
      pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          for (final ch in chars.skip(r * cols).take(cols))
            pw.SizedBox(
              width: fs * 1.05,
              height: fs * 1.05,
              child: pw.Center(
                child: pw.Text(ch,
                    style: pw.TextStyle(
                        font: font, fontSize: fs, color: _sealRed, height: 1)),
              ),
            ),
        ],
      ),
  ];
  return pw.Opacity(
    opacity: 0.88,
    child: pw.Container(
      width: size,
      height: size,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _sealRed, width: size * 0.05),
      ),
      child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: lines),
    ),
  );
}

/// '(인)' 글자 위에 도장을 겹쳐 찍는다.
pw.Widget _stamped(pw.Widget mark, pw.Widget? seal) => seal == null
    ? mark
    : pw.Stack(
        alignment: pw.Alignment.center,
        overflow: pw.Overflow.visible,
        children: [mark, seal],
      );

/// A4 한 장짜리 재직증명서 PDF를 만든다.
Future<Uint8List> buildCertPdf(CertData d, PdfPageFormat format,
    {CertFonts? fonts}) async {
  final f = fonts ?? await CertFonts.bundled();
  final doc = pw.Document();
  doc.addPage(switch (d.template) {
    CertTemplate.basic => _basicPage(d, format, f),
    CertTemplate.standard => _standardPage(d, format, f),
  });
  return doc.save();
}

// ───────────────────────── 기본형 ─────────────────────────

pw.Page _basicPage(CertData d, PdfPageFormat format, CertFonts f) {
  const border = pw.BorderSide(width: 0.8);
  const labelBg = PdfColor.fromInt(0xFFF2F2F2);

  pw.Widget cell(String text, {bool label = false, int flex = 1}) =>
      pw.Expanded(
        flex: flex,
        child: pw.Container(
          height: 30,
          alignment: label ? pw.Alignment.center : pw.Alignment.centerLeft,
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

  // 칸 배경이 테두리를 덮지 않도록 선 두께만큼 안쪽으로.
  pw.Widget row(List<pw.Widget> cells) => pw.Container(
        padding: const pw.EdgeInsets.only(left: 1.2, bottom: 1.2),
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

  return pw.Page(
    pageFormat: format,
    theme: pw.ThemeData.withFont(base: f.serif, bold: f.serifBold),
    margin: const pw.EdgeInsets.fromLTRB(56, 48, 56, 48),
    build: (_) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text('발급번호: ${d.issueNo}', style: const pw.TextStyle(fontSize: 9)),
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
            decoration:
                const pw.BoxDecoration(border: pw.Border(top: border))),
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
            pw.SizedBox(width: 12),
            pw.SizedBox(
              width: 60,
              height: 60,
              child: _stamped(
                pw.Text('(인)',
                    style: const pw.TextStyle(
                        fontSize: 12, color: PdfColors.grey600)),
                d.showSeal ? companySeal(d.companyName, f.serifBold) : null,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 24),
      ],
    ),
  );
}

// ───────────────────────── 표준형 ─────────────────────────
// 노란 세로 구분칸(인적사항/재직사항) + 격자 표 양식.

pw.Page _standardPage(CertData d, PdfPageFormat format, CertFonts f) {
  const line = pw.BorderSide(width: 1);
  const yellow = PdfColor.fromInt(0xFFFFFF99);
  // 열 너비(pt): 구분 | 항목 | 값1 | 값2 | 항목2 | 값3
  const wSec = 34.0, wLab = 74.0, w1 = 74.0, w2 = 126.0, wLab2 = 76.0;
  const wVal3 = 131.0;
  const rowH = 41.0;
  const tableW = wSec + wLab + w1 + w2 + wLab2 + wVal3;

  final txt = pw.TextStyle(font: f.sans, fontSize: 11);
  final bold = pw.TextStyle(font: f.sansBold, fontSize: 11);

  pw.Widget cell(double w, String text,
          {bool center = true, pw.TextStyle? style, pw.Widget? child}) =>
      pw.Container(
        width: w,
        height: rowH,
        alignment: center ? pw.Alignment.center : pw.Alignment.centerLeft,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8),
        decoration: const pw.BoxDecoration(
            border: pw.Border(right: line, bottom: line)),
        child: child ??
            pw.Text(text, style: style ?? txt, textAlign: pw.TextAlign.center),
      );

  pw.Widget label(double w, String text) => cell(w, text, style: bold);
  pw.Widget value(double w, String text) => cell(w, text, center: false);

  pw.Widget sectionCol(String title, int rows) => pw.Container(
        width: wSec,
        height: rowH * rows,
        alignment: pw.Alignment.center,
        decoration: const pw.BoxDecoration(
          color: yellow,
          border: pw.Border(right: line, bottom: line),
        ),
        child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            for (final ch in title.split(''))
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: pw.Text(ch, style: bold),
              ),
          ],
        ),
      );

  pw.Widget block(String title, List<List<pw.Widget>> rows) => pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          sectionCol(title, rows.length),
          pw.Column(children: [for (final r in rows) pw.Row(children: r)]),
        ],
      );

  const restW = wLab + w1 + w2 + wLab2 + wVal3 - wLab; // 항목 뒤 전체
  const personLab = wLab + w1;
  const personVal = w2 + wLab2 + wVal3;

  final joinText = DateFormat('yyyy년 MM월 dd일').format(d.joinDate);
  final big = pw.TextStyle(font: f.sansBold, fontSize: 12);

  return pw.Page(
    pageFormat: format,
    margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
    build: (_) => pw.Column(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 2),
          decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(width: 1.2))),
          child: pw.Text('재 직 증 명 서',
              style: pw.TextStyle(
                  font: f.sansBold, fontSize: 24, letterSpacing: 6)),
        ),
        pw.SizedBox(height: 40),
        pw.Container(
          width: tableW,
          decoration: const pw.BoxDecoration(
              border: pw.Border(top: line, left: line)),
          child: pw.Column(
            children: [
              block('인적사항', [
                [label(personLab, '성명'), value(personVal, d.name)],
                [label(personLab, '주민등록번호'), value(personVal, d.rrn)],
                [label(personLab, '현주소'), value(personVal, d.address)],
              ]),
              block('재직사항', [
                [label(wLab, '업체명'), value(restW, d.companyName)],
                [label(wLab, '업체전화'), value(restW, d.companyPhone)],
                [label(wLab, '업체주소'), value(restW, d.companyAddress)],
                [
                  label(wLab, '사업자\n등록번호'),
                  value(w1 + w2, d.bizNumber),
                  label(wLab2, '대표자성명'),
                  value(wVal3, d.ceoName),
                ],
                [
                  label(wLab, '근무부서'),
                  value(w1 + w2, d.department),
                  label(wLab2, '직급'),
                  value(wVal3, d.position),
                ],
                [
                  label(wLab, '재직기간'),
                  cell(restW, '$joinText 부터 현재까지', style: big),
                ],
                [
                  label(wLab, '확인자'),
                  label(w1, '직위'),
                  value(w2, d.confirmerTitle),
                  label(wLab2, '성명'),
                  cell(wVal3, '',
                      child: pw.Row(
                        children: [
                          pw.Expanded(
                              child: pw.Text(d.confirmerName, style: txt)),
                          pw.SizedBox(
                            width: 36,
                            height: rowH,
                            child: _stamped(
                              pw.Text('(인)', style: txt),
                              d.showSeal && d.confirmerName.isNotEmpty
                                  ? personalSeal(d.confirmerName, f.serifBold,
                                      size: 34)
                                  : null,
                            ),
                          ),
                        ],
                      )),
                ],
              ]),
            ],
          ),
        ),
        pw.SizedBox(height: 52),
        pw.Text('위와 같이 재직을 증명함.', style: bold),
        pw.SizedBox(height: 60),
        pw.Text(DateFormat('yyyy 년   MM 월   dd 일').format(d.issueDate),
            style: bold),
        pw.SizedBox(height: 64),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('업체명   :   ${d.companyName}', style: bold),
            pw.SizedBox(width: 40),
            pw.SizedBox(
              width: 64,
              height: 64,
              child: _stamped(
                pw.Text('(직인)', style: bold),
                d.showSeal ? companySeal(d.companyName, f.serifBold) : null,
              ),
            ),
            pw.SizedBox(width: 20),
          ],
        ),
      ],
    ),
  );
}

/// 미리보기 화면에서 쓰는 파일 이름.
String certFileName(CertData d) =>
    '재직증명서_${d.name}_${DateFormat('yyyyMMdd').format(d.issueDate)}.pdf';
