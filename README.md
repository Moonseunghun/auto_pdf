# auto_pdf — 재직증명서 발급

입력창에 인적사항·재직사항·회사정보를 넣고 **[양식에 채우기]** 를 누르면
A4 재직증명서 PDF 양식의 빈칸이 채워진 미리보기가 열립니다. 미리보기에서 인쇄 / PDF 저장·공유가 가능합니다.

- 재직기간은 입사일 ~ 발급일로 자동 계산 (N년 N개월)
- 직인 자리는 비워 둠 — 인쇄 후 실제 날인
- 한글 폰트(나눔명조)는 처음 PDF를 만들 때 Google Fonts에서 받아옴 (인터넷 필요)

## 실행

```bash
flutter pub get
flutter run -d chrome
```

## 구조

- `lib/main.dart` — 입력 화면, 미리보기 화면 (`PdfPreview`)
- `lib/cert_pdf.dart` — 재직증명서 PDF 양식 (`pdf` 패키지)

사용 패키지: `pdf`, `printing`, `intl`
