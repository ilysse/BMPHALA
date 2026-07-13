import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/network/api_service.dart';
import '../../core/utils/print_helper.dart';
import '../../core/utils/invoice_branding.dart';

class AdminInvoicesView extends StatefulWidget {
  const AdminInvoicesView({super.key});

  @override
  State<AdminInvoicesView> createState() => _AdminInvoicesViewState();
}

class _AdminInvoicesViewState extends State<AdminInvoicesView> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dueFromController = TextEditingController();
  final TextEditingController _dueToController = TextEditingController();
  final TextEditingController _createdFromController = TextEditingController();
  final TextEditingController _createdToController = TextEditingController();
  List<dynamic> _invoices = [];
  List<dynamic> _orders = [];
  final Set<String> _selectedInvoiceIds = {};
  String _statusFilter = 'all';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _setDatePreset('month');
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dueFromController.dispose();
    _dueToController.dispose();
    _createdFromController.dispose();
    _createdToController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      if (_apiService.mockMode) {
        await Future.delayed(const Duration(milliseconds: 300));
        _invoices = [
          {
            'id': 'INV01',
            'invoice_number': 'INV-2026-001',
            'amount_due': 1500.0,
            'status': 'paid',
            'due_date': '2026-07-15',
          },
        ];
        _orders = [];
      } else {
        final query = <String, dynamic>{
          'per_page': 250,
          if (_statusFilter != 'all') 'status': _statusFilter,
          if (_searchController.text.trim().isNotEmpty)
            'search': _searchController.text.trim(),
          if (_dueFromController.text.trim().isNotEmpty)
            'due_from': _dueFromController.text.trim(),
          if (_dueToController.text.trim().isNotEmpty)
            'due_to': _dueToController.text.trim(),
          if (_createdFromController.text.trim().isNotEmpty)
            'created_from': _createdFromController.text.trim(),
          if (_createdToController.text.trim().isNotEmpty)
            'created_to': _createdToController.text.trim(),
        };
        final responses = await Future.wait([
          _apiService.client.get('/invoices', queryParameters: query),
          _apiService.client.get('/orders', queryParameters: {'per_page': 250}),
        ]);
        _invoices = responses[0].data['data'] ?? [];
        _orders = responses[1].data['data'] ?? [];
      }
      _selectedInvoiceIds.removeWhere(
        (id) => !_invoices.any((invoice) => '${invoice['id']}' == id),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading invoices: $e')));
      }
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  List<dynamic> get _filteredInvoices => _invoices;

  void _setDatePreset(String preset) {
    final now = DateTime.now();
    DateTime? from;
    DateTime? to = now;

    switch (preset) {
      case 'today':
        from = DateTime(now.year, now.month, now.day);
        break;
      case 'week':
        from = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        from = DateTime(now.year, now.month, 1);
        break;
      case 'quarter':
        from = DateTime(now.year, now.month - 2, 1);
        break;
      case 'year':
        from = DateTime(now.year, 1, 1);
        break;
      default:
        to = null;
    }

    _createdFromController.text = from == null ? '' : _date(from);
    _createdToController.text = to == null ? '' : _date(to);
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final initial = DateTime.tryParse(controller.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => controller.text = _date(picked));
    }
  }

  Future<void> _showGenerateInvoiceDialog() async {
    String? orderId;
    int termsDays = 14;
    final dueDateController = TextEditingController(
      text: _date(DateTime.now().add(Duration(days: termsDays))),
    );

    final generated = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Generate Invoice'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: orderId,
                  decoration: const InputDecoration(labelText: 'Order'),
                  items: _orders.map<DropdownMenuItem<String>>((order) {
                    return DropdownMenuItem(
                      value: order['id'] as String,
                      child: Text(
                        '${order['order_number'] ?? order['id']} - ${order['retailer']?['name'] ?? 'Retailer'} - ${order['grand_total'] ?? order['total_amount']} DH',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => setModalState(() => orderId = value),
                ),
                const SizedBox(height: 12),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Now')),
                    ButtonSegment(value: 7, label: Text('7D')),
                    ButtonSegment(value: 14, label: Text('14D')),
                    ButtonSegment(value: 30, label: Text('30D')),
                  ],
                  selected: {termsDays},
                  onSelectionChanged: (values) {
                    termsDays = values.first;
                    dueDateController.text = _date(
                      DateTime.now().add(Duration(days: termsDays)),
                    );
                    setModalState(() {});
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dueDateController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Due Date',
                    helperText: 'Pick any due date required by the customer',
                    prefixIcon: const Icon(Icons.event_rounded),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_month_rounded),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate:
                              DateTime.tryParse(dueDateController.text) ??
                              DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setModalState(() {
                            dueDateController.text = _date(picked);
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.receipt_long_rounded),
              label: const Text('Generate'),
              onPressed: () async {
                if (orderId == null) return;
                try {
                  if (!_apiService.mockMode) {
                    await _apiService.client.post(
                      '/invoices',
                      data: {
                        'order_id': orderId,
                        'due_date': dueDateController.text.trim(),
                      },
                    );
                  }
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Invoice generation failed: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );

    dueDateController.dispose();
    if (generated == true) await _fetchData();
  }

  Future<void> _updateInvoiceStatus(dynamic invoice, String status) async {
    try {
      if (!_apiService.mockMode) {
        await _apiService.client.put(
          '/invoices/${invoice['id']}/status',
          data: {'status': status},
        );
      }
      await _fetchData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to update invoice: $e')));
    }
  }

  Future<void> _printSelectedInvoices() async {
    final selected = _invoices
        .where((invoice) => _selectedInvoiceIds.contains('${invoice['id']}'))
        .toList();
    await _printInvoices(selected, 'selected');
  }

  Future<void> _printVisibleInvoices() async {
    await _printInvoices(_filteredInvoices, 'visible');
  }

  Future<void> _printInvoices(List<dynamic> invoices, String scope) async {
    if (invoices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No invoices available to print.')),
      );
      return;
    }

    try {
      final fallbackLogo = await loadDefaultInvoiceLogoDataUri();
      await printHtmlDocument(
        title: 'Halawat Bulk Invoices',
        bodyHtml: invoices
            .map((invoice) => _invoiceHtml(invoice, fallbackLogo))
            .join(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Opened bulk print for ${invoices.length} $scope invoices.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to print invoices: $e')));
    }
  }

  String _invoiceHtml(dynamic invoice, String fallbackLogo) {
    final order = invoice['order'] as Map<String, dynamic>? ?? {};
    final company = invoice['company'] as Map<String, dynamic>? ?? {};
    final retailer = order['retailer'] as Map<String, dynamic>? ?? {};
    final items = order['items'] as List<dynamic>? ?? [];
    final invoiceNumber = _escape(invoice['invoice_number'] ?? 'Invoice');
    final retailerName = _escape(
      retailer['name'] ?? retailer['username'] ?? 'Unknown Retailer',
    );
    final retailerAddress = _escape(retailer['address'] ?? '');
    final retailerPhone = _escape(retailer['phone'] ?? retailer['email'] ?? '');
    final orderNumber = _escape(order['order_number'] ?? order['id'] ?? '');
    final createdDate = _escape(
      _shortDate(invoice['created_at'] ?? order['created_at']),
    );
    final dueDate = _escape(_shortDate(invoice['due_date']));
    final status = _escape(invoice['status'] ?? 'draft');
    final amount = _money(invoice['amount_due'] ?? invoice['amount'] ?? 0);
    final companyName = _escape(company['name'] ?? 'Halawat Lil Moaamalat');
    final companyAddress = _escape(company['address'] ?? 'Casablanca, Morocco');
    final companyContact = _escape(company['phone'] ?? company['email'] ?? '');
    final logoUrl = _escape(company['logo_url'] ?? fallbackLogo);

    // Build numbered item rows with running subtotal
    double subtotal = 0;
    int rowIndex = 0;
    final itemRows = items.isEmpty
        ? '<tr><td colspan="5" style="text-align:center;color:#6b7280;">No line items returned.</td></tr>'
        : items.map((item) {
            rowIndex++;
            final row = item as Map<String, dynamic>;
            final name = _escape(
              row['product_name'] ?? row['product']?['name'] ?? 'Product',
            );
            final qty = row['quantity'] ?? 0;
            final unitVal = _toNum(row['unit_price'] ?? 0);
            final totalVal = _toNum(row['total_price'] ?? 0);
            subtotal += totalVal;
            return '<tr>'
                '<td style="text-align:center;color:#6b7280;">$rowIndex</td>'
                '<td>$name</td>'
                '<td style="text-align:center;">$qty</td>'
                '<td style="text-align:right;">${_money(unitVal)} DH</td>'
                '<td style="text-align:right;">${_money(totalVal)} DH</td>'
                '</tr>';
          }).join();

    // If subtotal is 0, fall back to the invoice amount
    if (subtotal == 0) {
      subtotal = _toNum(invoice['amount_due'] ?? invoice['amount'] ?? 0);
    }

    return '''
<section class="invoice">
  <!-- ===== Three-column header: Client | Logo | Halawat ===== -->
  <div class="inv-header">
    <div class="inv-client">
      <div class="inv-label">BILL TO</div>
      <div class="inv-name">$retailerName</div>
      <div class="inv-detail">$retailerAddress</div>
      <div class="inv-detail">$retailerPhone</div>
    </div>
    <div class="inv-logo">
      <img class="inv-logo-image" src="$logoUrl" alt="$companyName logo">
      <div class="inv-brand-en">$companyName</div>
    </div>
    <div class="inv-company">
      <div class="inv-label">FROM</div>
      <div class="inv-name">$companyName</div>
      <div class="inv-detail">$companyAddress</div>
      <div class="inv-detail">$companyContact</div>
    </div>
  </div>

  <!-- ===== Invoice meta ===== -->
  <div class="inv-meta">
    <div class="inv-meta-item"><span class="inv-meta-label">Invoice</span><span>$invoiceNumber</span></div>
    <div class="inv-meta-item"><span class="inv-meta-label">Order</span><span>$orderNumber</span></div>
    <div class="inv-meta-item"><span class="inv-meta-label">Date</span><span>$createdDate</span></div>
    <div class="inv-meta-item"><span class="inv-meta-label">Due Date</span><span>$dueDate</span></div>
    <div class="inv-meta-item"><span class="inv-meta-label">Status</span><span class="inv-status-badge">$status</span></div>
  </div>

  <!-- ===== Items table ===== -->
  <table class="inv-table">
    <thead>
      <tr>
        <th style="width:40px;text-align:center;">#</th>
        <th>Product</th>
        <th style="width:60px;text-align:center;">Qty</th>
        <th style="width:100px;text-align:right;">Unit Price</th>
        <th style="width:100px;text-align:right;">Total</th>
      </tr>
    </thead>
    <tbody>$itemRows</tbody>
  </table>

  <!-- ===== Totals ===== -->
  <div class="inv-totals">
    <div class="inv-total-row"><span>Subtotal</span><span>${_money(subtotal)} DH</span></div>
    <div class="inv-total-row inv-grand-total"><span>TOTAL</span><span>$amount DH</span></div>
  </div>
</section>
''';
  }

  double _toNum(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final invoices = _filteredInvoices;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showGenerateInvoiceDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Invoice'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search invoice, retailer',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: _fetchData,
                      ),
                    ),
                    onSubmitted: (_) => _fetchData(),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _datePresetChip('Today', 'today'),
                        _datePresetChip('7D', 'week'),
                        _datePresetChip('Month', 'month'),
                        _datePresetChip('Quarter', 'quarter'),
                        _datePresetChip('Year', 'year'),
                        _datePresetChip('All', 'all'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _dateField('Created From', _createdFromController),
                      _dateField('Created To', _createdToController),
                      _dateField('Due From', _dueFromController),
                      _dateField('Due To', _dueToController),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final status in const [
                          'all',
                          'draft',
                          'sent',
                          'paid',
                          'overdue',
                          'cancelled',
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(status),
                              selected: _statusFilter == status,
                              onSelected: (_) {
                                setState(() => _statusFilter = status);
                                _fetchData();
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: invoices.isEmpty
                            ? null
                            : _toggleVisibleSelection,
                        icon: const Icon(Icons.select_all_rounded),
                        label: const Text('Select visible'),
                      ),
                      const Spacer(),
                      IconButton.filledTonal(
                        tooltip: 'Print visible invoices',
                        onPressed: invoices.isEmpty
                            ? null
                            : _printVisibleInvoices,
                        icon: const Icon(Icons.print_rounded),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _selectedInvoiceIds.isEmpty
                            ? null
                            : _printSelectedInvoices,
                        icon: const Icon(Icons.fact_check_rounded),
                        label: Text(
                          'Print selected (${_selectedInvoiceIds.length})',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : invoices.isEmpty
                  ? const Center(child: Text('No invoices'))
                  : RefreshIndicator(
                      onRefresh: _fetchData,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                        itemCount: invoices.length,
                        itemBuilder: (context, index) {
                          final item = invoices[index];
                          return Card(
                            child: ListTile(
                              leading: Checkbox(
                                value: _selectedInvoiceIds.contains(
                                  '${item['id']}',
                                ),
                                onChanged: (selected) {
                                  setState(() {
                                    final id = '${item['id']}';
                                    if (selected == true) {
                                      _selectedInvoiceIds.add(id);
                                    } else {
                                      _selectedInvoiceIds.remove(id);
                                    }
                                  });
                                },
                              ),
                              title: Text(
                                item['invoice_number'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${item['order']?['retailer']?['name'] ?? item['order']?['retailer']?['username'] ?? 'Retailer'} | Amount: ${item['amount_due'] ?? item['amount'] ?? 0} DH | Due: ${_shortDate(item['due_date'])}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: DropdownButton<String>(
                                value: item['status'] ?? 'draft',
                                underline: const SizedBox.shrink(),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'draft',
                                    child: Text('draft'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'sent',
                                    child: Text('sent'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'paid',
                                    child: Text('paid'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'overdue',
                                    child: Text('overdue'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'cancelled',
                                    child: Text('cancelled'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    _updateInvoiceStatus(item, value);
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _datePresetChip(String label, String preset) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: const Icon(Icons.date_range_rounded, size: 18),
        label: Text(label),
        onPressed: () {
          setState(() => _setDatePreset(preset));
          _fetchData();
        },
      ),
    );
  }

  Widget _dateField(String label, TextEditingController controller) {
    return SizedBox(
      width: 165,
      child: TextField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: () => _pickDate(controller),
          ),
        ),
      ),
    );
  }

  void _toggleVisibleSelection() {
    setState(() {
      final ids = _filteredInvoices
          .map((invoice) => '${invoice['id']}')
          .toSet();
      final allSelected = ids.every(_selectedInvoiceIds.contains);
      if (allSelected) {
        _selectedInvoiceIds.removeAll(ids);
      } else {
        _selectedInvoiceIds.addAll(ids);
      }
    });
  }

  String _date(DateTime value) => value.toIso8601String().substring(0, 10);

  String _shortDate(dynamic value) {
    final text = '${value ?? 'N/A'}';
    return text.length >= 10 ? text.substring(0, 10) : text;
  }

  String _escape(dynamic value) => htmlEscape.convert('$value');

  String _money(dynamic value) {
    if (value is num) return value.toStringAsFixed(2);
    if (value is String) {
      return (double.tryParse(value) ?? 0).toStringAsFixed(2);
    }
    return '0.00';
  }
}
