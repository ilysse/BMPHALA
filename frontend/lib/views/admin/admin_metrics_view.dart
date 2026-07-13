import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/api_service.dart';
import '../../core/utils/print_helper.dart';

class AdminMetricsView extends StatefulWidget {
  const AdminMetricsView({super.key});

  @override
  State<AdminMetricsView> createState() => _AdminMetricsViewState();
}

class _AdminMetricsViewState extends State<AdminMetricsView> {
  final ApiService _apiService = ApiService();
  bool _isLoadingReport = false;
  Map<String, dynamic>? _report;
  int _rangeDays = 30;

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    if (!mounted) return;
    setState(() => _isLoadingReport = true);
    try {
      final now = DateTime.now();
      final from = now.subtract(Duration(days: _rangeDays)).toIso8601String().substring(0, 10);
      final to = now.toIso8601String().substring(0, 10);

      if (_apiService.mockMode) {
        await Future.delayed(const Duration(milliseconds: 300));
        _report = {
          'gross_sales': 245980.0,
          'delivered_sales': 180300.0,
          'total_paid': 207530.0,
          'outstanding_balance': 38450.0,
          'total_orders': 845,
          'open_orders': 61,
          'active_retailers_count': 142,
          'delivered_orders': 720,
          'active_retailers': 142,
          'daily_sales': [
            {'date': '2026-06-28', 'sales': 9000.0, 'orders': 9},
            {'date': '2026-06-29', 'sales': 12400.0, 'orders': 12},
            {'date': '2026-06-30', 'sales': 8800.0, 'orders': 7},
            {'date': '2026-07-01', 'sales': 15100.0, 'orders': 16},
            {'date': '2026-07-02', 'sales': 13200.0, 'orders': 14},
          ],
          'status_breakdown': [
            {'label': 'pending', 'count': 18, 'sales': 22000.0},
            {'label': 'confirmed', 'count': 45, 'sales': 55000.0},
            {'label': 'in_transit', 'count': 62, 'sales': 75000.0},
            {'label': 'delivered', 'count': 720, 'sales': 180300.0},
          ],
          'payment_breakdown': [
            {'payment_status': 'paid', 'count': 510},
            {'payment_status': 'partially_paid', 'count': 195},
            {'payment_status': 'unpaid', 'count': 140},
          ],
          'retailer_summary': [
            {
              'retailer_name': 'Corner Market Inc.',
              'orders': 28,
              'sales': 18420.0,
              'outstanding': 2400.0,
            },
            {
              'retailer_name': 'Downtown Superette',
              'orders': 34,
              'sales': 24150.0,
              'outstanding': 1200.0,
            },
          ],
          'product_summary': [
            {
              'product_name': 'Evian Water 500ml',
              'units_sold': 540,
              'sales': 8100.0,
            },
            {
              'product_name': 'Halawa Pistachio 250g',
              'units_sold': 350,
              'sales': 17500.0,
            },
          ],
        };
      } else {
        final res = await _apiService.client.get('/reports/sales', queryParameters: {
          'from': from,
          'to': to,
        });
        _report = res.data['data'] as Map<String, dynamic>?;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.tr('unable_load_report')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingReport = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(context.tr('metrics_and_analytics') == 'metrics_and_analytics' ? 'Metrics & Analytics' : context.tr('metrics_and_analytics')),
        actions: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 7, label: Text('7D')),
              ButtonSegment(value: 30, label: Text('30D')),
              ButtonSegment(value: 90, label: Text('90D')),
            ],
            selected: {_rangeDays},
            onSelectionChanged: (values) {
              setState(() => _rangeDays = values.first);
              _fetchReport();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final report = _report;
    if (report == null) {
      return _isLoadingReport
          ? const Center(child: CircularProgressIndicator())
          : Center(child: Text(context.tr('no_items')));
    }

    return RefreshIndicator(
      onRefresh: _fetchReport,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMetrics(report),
          const SizedBox(height: 16),
          _buildTrendCard(report),
          const SizedBox(height: 16),
          _buildStatusChart(report),
          const SizedBox(height: 16),
          _buildPaymentChart(report),
          const SizedBox(height: 16),
          _buildRetailerTable(_asList(report['retailer_summary'])),
          const SizedBox(height: 16),
          _buildProductTable(_asList(report['product_summary'])),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            icon: const Icon(Icons.print_rounded, size: 18),
            label: Text(context.tr('print_report') == 'print_report' ? 'Print Report' : context.tr('print_report')),
            onPressed: () => _printReport(report),
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics(Map<String, dynamic> report) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ReportMetric(
                label: context.tr('gross_sales'),
                value: '${_money(report['gross_sales'])} DH',
                icon: Icons.payments_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ReportMetric(
                label: context.tr('paid'),
                value: '${_money(report['total_paid'])} DH',
                icon: Icons.check_circle_outline,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ReportMetric(
                label: context.tr('orders'),
                value: '${_intValue(report['total_orders'])}',
                icon: Icons.assignment_outlined,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ReportMetric(
                label: context.tr('outstanding'),
                value: '${_money(report['outstanding_balance'])} DH',
                icon: Icons.account_balance_wallet_outlined,
                color: AppColors.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ReportMetric(
                label: context.tr('delivered'),
                value: '${_intValue(report['delivered_orders'] ?? 0)}',
                icon: Icons.done_all_rounded,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ReportMetric(
                label: context.tr('active_retailers'),
                value: '${_intValue(report['active_retailers'] ?? report['active_retailers_count'] ?? 0)}',
                icon: Icons.storefront_rounded,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrendCard(Map<String, dynamic> report) {
    final rows = _asList(report['daily_sales']);
    final spots = <FlSpot>[];
    for (var i = 0; i < rows.length; i++) {
      spots.add(FlSpot(i.toDouble(), _doubleValue(rows[i]['sales'])));
    }
    final maxY = spots.isEmpty
        ? 1.0
        : spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b) * 1.25;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('sales_trend'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: spots.isEmpty
                  ? Center(child: Text(context.tr('no_sales_period')))
                  : LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: maxY <= 0 ? 1 : maxY,
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              reservedSize: 38,
                              showTitles: true,
                              getTitlesWidget: (value, _) => Text(
                                '${(value / 1000).toStringAsFixed(0)}k',
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              reservedSize: 26,
                              showTitles: true,
                              getTitlesWidget: (value, _) {
                                final index = value.toInt();
                                if (index < 0 || index >= rows.length) {
                                  return const SizedBox.shrink();
                                }
                                final date = '${rows[index]['date']}';
                                return Text(
                                  date.length >= 10 ? date.substring(5) : date,
                                  style: const TextStyle(fontSize: 10),
                                );
                              },
                            ),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: AppColors.primary,
                            barWidth: 4,
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppColors.primary.withOpacity(0.08),
                            ),
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChart(Map<String, dynamic> report) {
    final breakdown = _asList(report['status_breakdown']);
    if (breakdown.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('orders_by_status'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Center(child: Text('No data')),
            ],
          ),
        ),
      );
    }

    final barGroups = <BarChartGroupData>[];
    for (var i = 0; i < breakdown.length; i++) {
      final item = breakdown[i];
      final count = _doubleValue(item['count']);
      final statusLabel = '${item['label'] ?? item['status'] ?? 'pending'}';
      
      Color color = Colors.blue;
      if (statusLabel == 'delivered') {
        color = Colors.amber;
      } else if (statusLabel == 'in_transit') {
        color = Colors.purple;
      } else if (statusLabel == 'cancelled') {
        color = Colors.red;
      } else if (statusLabel == 'confirmed') {
        color = Colors.green;
      }

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: count,
              color: color,
              width: 16,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('orders_by_status'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 30),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < breakdown.length) {
                            final raw = '${breakdown[idx]['label'] ?? breakdown[idx]['status'] ?? ''}';
                            final localizedStr = context.tr('status_${raw.toLowerCase()}');
                            return Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                localizedStr.length > 8 ? '${localizedStr.substring(0, 7)}..' : localizedStr,
                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  barGroups: barGroups,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentChart(Map<String, dynamic> report) {
    final breakdown = _asList(report['payment_breakdown']);
    if (breakdown.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('payment_distribution'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Center(child: Text('No data')),
            ],
          ),
        ),
      );
    }

    final sections = <PieChartSectionData>[];
    final legend = <Widget>[];

    for (var i = 0; i < breakdown.length; i++) {
      final item = breakdown[i];
      final count = _doubleValue(item['count']);
      final rawStatus = '${item['payment_status'] ?? 'unpaid'}';
      
      Color color = Colors.red;
      if (rawStatus == 'paid') {
        color = Colors.green;
      } else if (rawStatus == 'partially_paid') {
        color = Colors.orange;
      }

      sections.add(
        PieChartSectionData(
          value: count,
          title: count.toStringAsFixed(0),
          color: color,
          radius: 40,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );

      final localizedStatus = context.tr('payment_${rawStatus.toLowerCase()}');
      legend.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 12, height: 12, color: color),
            const SizedBox(width: 6),
            Text(localizedStatus, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 12),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('payment_distribution'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              children: legend,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRetailerTable(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('retailer'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Center(child: Text(context.tr('no_retailer_data') == 'no_retailer_data' ? 'No retailer data' : context.tr('no_retailer_data'))),
            ],
          ),
        ),
      );
    }

    final sortedRows = List<Map<String, dynamic>>.from(rows);
    sortedRows.sort((a, b) => _doubleValue(b['sales']).compareTo(_doubleValue(a['sales'])));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('retailer'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text(context.tr('retailer'), style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text(context.tr('orders'), style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text(context.tr('sales') == 'sales' ? 'Sales' : context.tr('sales'), style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text(context.tr('outstanding'), style: const TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: sortedRows.take(10).map((row) {
                  return DataRow(cells: [
                    DataCell(Text('${row['retailer_name'] ?? 'Unknown'}')),
                    DataCell(Text('${_intValue(row['orders'])}')),
                    DataCell(Text('${_money(row['sales'])} DH')),
                    DataCell(Text('${_money(row['outstanding'])} DH')),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductTable(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('product'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Center(child: Text(context.tr('no_product_data') == 'no_product_data' ? 'No product data' : context.tr('no_product_data'))),
            ],
          ),
        ),
      );
    }

    final sortedRows = List<Map<String, dynamic>>.from(rows);
    sortedRows.sort((a, b) => _doubleValue(b['sales']).compareTo(_doubleValue(a['sales'])));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('product'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text(context.tr('product'), style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text(context.tr('units_sold'), style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text(context.tr('sales') == 'sales' ? 'Sales' : context.tr('sales'), style: const TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: sortedRows.take(10).map((row) {
                  return DataRow(cells: [
                    DataCell(Text('${row['product_name'] ?? 'Unknown'}')),
                    DataCell(Text('${_intValue(row['units_sold'])}')),
                    DataCell(Text('${_money(row['sales'])} DH')),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printReport(Map<String, dynamic> report) async {
    final now = DateTime.now();
    final fromDate = now.subtract(Duration(days: _rangeDays)).toIso8601String().substring(0, 10);
    final toDate = now.toIso8601String().substring(0, 10);

    final grossSales = _money(report['gross_sales']);
    final totalPaid = _money(report['total_paid']);
    final totalOrders = _intValue(report['total_orders']);
    final outstanding = _money(report['outstanding_balance']);
    final deliveredOrders = _intValue(report['delivered_orders'] ?? 0);
    final activeRetailers = _intValue(report['active_retailers'] ?? report['active_retailers_count'] ?? 0);

    final retailerSummary = _asList(report['retailer_summary']);
    retailerSummary.sort((a, b) => _doubleValue(b['sales']).compareTo(_doubleValue(a['sales'])));
    final retailerRows = retailerSummary.map((row) {
      final name = row['retailer_name'] ?? 'Unknown';
      final orders = _intValue(row['orders']);
      final sales = _money(row['sales']);
      final outstanding = _money(row['outstanding']);
      return '<tr>'
          '<td>$name</td>'
          '<td style="text-align:right;">$orders</td>'
          '<td style="text-align:right;">$sales DH</td>'
          '<td style="text-align:right;">$outstanding DH</td>'
          '</tr>';
    }).join();

    final productSummary = _asList(report['product_summary']);
    productSummary.sort((a, b) => _doubleValue(b['sales']).compareTo(_doubleValue(a['sales'])));
    final productRows = productSummary.map((row) {
      final name = row['product_name'] ?? 'Unknown';
      final units = _intValue(row['units_sold']);
      final sales = _money(row['sales']);
      return '<tr>'
          '<td>$name</td>'
          '<td style="text-align:right;">$units</td>'
          '<td style="text-align:right;">$sales DH</td>'
          '</tr>';
    }).join();

    final html = '''
<style>
  body { font-family: 'Segoe UI', Arial, sans-serif; color: #111827; margin: 24px; }
  .report-header { border-bottom: 2px solid #173B33; padding-bottom: 12px; margin-bottom: 24px; }
  .report-title { font-size: 24px; font-weight: 700; color: #173B33; margin: 0; }
  .report-meta { font-size: 13px; color: #6b7280; margin-top: 4px; }
  
  .metrics-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; margin-bottom: 28px; }
  .metric-card { border: 1px solid #e5e7eb; padding: 16px; border-radius: 8px; background: #f9fafb; }
  .metric-label { font-size: 11px; font-weight: 700; color: #9ca3af; text-transform: uppercase; margin-bottom: 4px; }
  .metric-value { font-size: 20px; font-weight: 700; color: #111827; }

  .section-title { font-size: 16px; font-weight: 700; color: #173B33; margin-top: 24px; margin-bottom: 12px; border-bottom: 1px solid #e5e7eb; padding-bottom: 6px; }
  
  table { width: 100%; border-collapse: collapse; margin-bottom: 24px; }
  th { background: #f3f4f6; text-align: left; font-size: 12px; font-weight: 700; text-transform: uppercase; color: #374151; padding: 10px 8px; border-bottom: 2px solid #d1d5db; }
  td { padding: 10px 8px; border-bottom: 1px solid #e5e7eb; font-size: 13px; }
  tr:nth-child(even) td { background: #fafafa; }
</style>

<div class="report-header">
  <div class="report-title">Sales Summary Report</div>
  <div class="report-meta">Period: $fromDate to $toDate | Generated on ${DateTime.now().toLocal().toString().split('.').first}</div>
</div>

<div class="metrics-grid">
  <div class="metric-card">
    <div class="metric-label">Gross Sales</div>
    <div class="metric-value">$grossSales DH</div>
  </div>
  <div class="metric-card">
    <div class="metric-label">Paid Amount</div>
    <div class="metric-value">$totalPaid DH</div>
  </div>
  <div class="metric-card">
    <div class="metric-label">Outstanding Balance</div>
    <div class="metric-value">$outstanding DH</div>
  </div>
  <div class="metric-card">
    <div class="metric-label">Total Orders</div>
    <div class="metric-value">$totalOrders</div>
  </div>
  <div class="metric-card">
    <div class="metric-label">Delivered Orders</div>
    <div class="metric-value">$deliveredOrders</div>
  </div>
  <div class="metric-card">
    <div class="metric-label">Active Retailers</div>
    <div class="metric-value">$activeRetailers</div>
  </div>
</div>

<div class="section-title">Top Retailers by Sales</div>
<table>
  <thead>
    <tr>
      <th>Retailer</th>
      <th style="text-align:right;width:80px;">Orders</th>
      <th style="text-align:right;width:120px;">Sales</th>
      <th style="text-align:right;width:120px;">Outstanding</th>
    </tr>
  </thead>
  <tbody>
    ${retailerRows.isEmpty ? '<tr><td colspan="4" style="text-align:center;">No retailer data</td></tr>' : retailerRows}
  </tbody>
</table>

<div class="section-title">Top Selling Products</div>
<table>
  <thead>
    <tr>
      <th>Product</th>
      <th style="text-align:right;width:100px;">Units Sold</th>
      <th style="text-align:right;width:150px;">Sales</th>
    </tr>
  </thead>
  <tbody>
    ${productRows.isEmpty ? '<tr><td colspan="3" style="text-align:center;">No product data</td></tr>' : productRows}
  </tbody>
</table>
''';

    await printHtmlDocument(
      title: 'Sales Report - $fromDate to $toDate',
      bodyHtml: html,
    );
  }

  List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return [];
  }

  String _money(dynamic value) => _doubleValue(value).toStringAsFixed(0);

  double _doubleValue(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

class _ReportMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ReportMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 19,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
