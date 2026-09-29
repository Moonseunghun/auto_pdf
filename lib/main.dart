import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import 'cert_pdf.dart';

void main() => runApp(const CertApp());

class CertApp extends StatelessWidget {
  const CertApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '재직증명서 발급',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: const CertFormPage(),
      );
}

class CertFormPage extends StatefulWidget {
  const CertFormPage({super.key});

  @override
  State<CertFormPage> createState() => _CertFormPageState();
}

class _CertFormPageState extends State<CertFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _c = {
    for (final k in [
      'name', 'birth', 'address', 'department', 'position', 'purpose',
      'companyName', 'bizNumber', 'companyAddress', 'ceoName', 'issueNo',
    ])
      k: TextEditingController(),
  };
  DateTime? _joinDate;
  DateTime _issueDate = DateTime.now();
  final _fmt = DateFormat('yyyy-MM-dd');

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(bool join) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: join ? (_joinDate ?? DateTime.now()) : _issueDate,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (join) {
        _joinDate = picked;
      } else {
        _issueDate = picked;
      }
    });
  }

  String _v(String key) => _c[key]!.text.trim();

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_joinDate == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('입사일을 선택하세요.')));
      return;
    }
    final data = CertData(
      name: _v('name'),
      birth: _v('birth'),
      address: _v('address'),
      department: _v('department'),
      position: _v('position'),
      joinDate: _joinDate!,
      purpose: _v('purpose'),
      companyName: _v('companyName'),
      bizNumber: _v('bizNumber'),
      companyAddress: _v('companyAddress'),
      ceoName: _v('ceoName'),
      issueDate: _issueDate,
      issueNo: _v('issueNo'),
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CertPreviewPage(data: data)),
    );
  }

  Widget _field(String key, String label,
          {String? hint, bool required = true}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: _c[key],
          decoration: InputDecoration(
            labelText: required ? '$label *' : label,
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
          validator: required
              ? (v) => (v == null || v.trim().isEmpty) ? '$label을(를) 입력하세요.' : null
              : null,
        ),
      );

  Widget _dateField(String label, DateTime? value, bool join) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () => _pickDate(join),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: '$label *',
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(Icons.calendar_today, size: 18),
            ),
            child: Text(value == null ? '선택' : _fmt.format(value)),
          ),
        ),
      );

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(t, style: Theme.of(context).textTheme.titleMedium),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('재직증명서 발급')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _title('인적사항'),
                  _field('name', '성명'),
                  _field('birth', '생년월일', hint: '1990-01-01'),
                  _field('address', '주소'),
                  _title('재직사항'),
                  _field('department', '부서'),
                  _field('position', '직위'),
                  _dateField('입사일', _joinDate, true),
                  _field('purpose', '용도', hint: '금융기관 제출용'),
                  _title('회사정보'),
                  _field('companyName', '회사명'),
                  _field('bizNumber', '사업자등록번호', hint: '000-00-00000'),
                  _field('companyAddress', '소재지'),
                  _field('ceoName', '대표자'),
                  _title('발급정보'),
                  _dateField('발급일', _issueDate, false),
                  _field('issueNo', '발급번호', required: false),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.description_outlined),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('양식에 채우기'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// 채워진 재직증명서 미리보기. 하단 버튼으로 인쇄 / PDF 저장·공유.
class CertPreviewPage extends StatelessWidget {
  const CertPreviewPage({super.key, required this.data});

  final CertData data;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('미리보기')),
        body: PdfPreview(
          build: (format) => buildCertPdf(data, format),
          pdfFileName: certFileName(data),
          canChangeOrientation: false,
          canDebug: false,
        ),
      );
}
