import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<void> printHtmlDocument({
  required String title,
  required String bodyHtml,
}) async {
  final safeTitle = htmlEscape.convert(title);
  final documentHtml =
      '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>$safeTitle</title>
  <style>
    body { font-family: 'Segoe UI', Arial, sans-serif; color: #111827; margin: 24px; }
    .invoice { break-after: page; page-break-after: always; border: 1px solid #d1d5db; padding: 28px; margin-bottom: 24px; }
    .invoice:last-child { break-after: auto; page-break-after: auto; }

    /* === Three-column header === */
    .inv-header { display: flex; justify-content: space-between; align-items: flex-start; gap: 16px; padding-bottom: 20px; border-bottom: 2px solid #173B33; }
    .inv-client, .inv-company { flex: 1; }
    .inv-company { text-align: right; }
    .inv-logo { flex: 0 0 160px; text-align: center; }
    .inv-logo-image { width: 76px; height: 76px; border-radius: 50%; object-fit: cover; display: block; margin: 0 auto 6px; }
    .inv-logo-circle { width: 56px; height: 56px; border-radius: 50%; background: #173B33; color: #fff; font-size: 28px; line-height: 56px; margin: 0 auto 6px; font-family: 'Arial', sans-serif; }
    .inv-brand-ar { font-size: 16px; font-weight: 700; color: #173B33; }
    .inv-brand-en { font-size: 11px; color: #6b7280; }
    .inv-label { font-size: 10px; font-weight: 700; letter-spacing: 1px; color: #9ca3af; text-transform: uppercase; margin-bottom: 4px; }
    .inv-name { font-size: 15px; font-weight: 700; color: #111827; margin-bottom: 2px; }
    .inv-detail { font-size: 12px; color: #6b7280; line-height: 1.5; }

    /* === Invoice meta === */
    .inv-meta { display: flex; flex-wrap: wrap; gap: 12px; padding: 14px 0; border-bottom: 1px solid #e5e7eb; margin-bottom: 16px; }
    .inv-meta-item { font-size: 13px; }
    .inv-meta-label { font-weight: 600; margin-right: 6px; color: #374151; }
    .inv-status-badge { display: inline-block; background: #173B33; color: #fff; padding: 2px 10px; border-radius: 10px; font-size: 11px; font-weight: 600; text-transform: uppercase; }

    /* === Items table === */
    .inv-table { width: 100%; border-collapse: collapse; margin-top: 8px; }
    .inv-table th { background: #f3f4f6; font-size: 12px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; color: #374151; padding: 10px 8px; border-bottom: 2px solid #d1d5db; }
    .inv-table td { padding: 10px 8px; border-bottom: 1px solid #e5e7eb; font-size: 13px; }
    .inv-table tbody tr:last-child td { border-bottom: 2px solid #d1d5db; }

    /* === Totals === */
    .inv-totals { margin-top: 16px; margin-left: auto; width: 260px; }
    .inv-total-row { display: flex; justify-content: space-between; padding: 6px 0; font-size: 13px; }
    .inv-grand-total { font-weight: 700; font-size: 16px; border-top: 2px solid #173B33; padding-top: 10px; margin-top: 4px; color: #173B33; }

    /* Legacy compat */
    h1, h2, h3 { margin: 0; }
    .muted { color: #6b7280; font-size: 12px; }
    .header { display: flex; justify-content: space-between; gap: 24px; border-bottom: 2px solid #111827; padding-bottom: 16px; }
    table { width: 100%; border-collapse: collapse; margin-top: 18px; }
    th, td { border-bottom: 1px solid #e5e7eb; padding: 8px; text-align: left; font-size: 13px; }
    th { background: #f3f4f6; }
    .totals { margin-top: 18px; margin-left: auto; width: 280px; }
    .totals div { display: flex; justify-content: space-between; padding: 6px 0; }
    .total { font-weight: 700; border-top: 2px solid #111827; }
    @media print { button { display: none; } body { margin: 0; } }
  </style>
</head>
<body>
  <button onclick="window.print()" style="margin-bottom:16px;padding:10px 14px">Print invoices</button>
  $bodyHtml
  <script>
    window.addEventListener('load', function () {
      var images = Array.from(document.images);
      Promise.all(images.map(function (image) {
        if (image.complete) return Promise.resolve();
        return new Promise(function (resolve) {
          image.addEventListener('load', resolve, { once: true });
          image.addEventListener('error', resolve, { once: true });
        });
      })).then(function () {
        window.setTimeout(function () { window.print(); }, 300);
      });
    });
  </script>
</body>
</html>
''';
  final blob = html.Blob([documentHtml], 'text/html');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
  await Future<void>.delayed(const Duration(milliseconds: 400));
  html.Url.revokeObjectUrl(url);
}
