import 'package:flutter/material.dart';
import '../models/invoice_model.dart';
import '../services/invoice_service.dart';
import 'invoice_add_screen.dart';
import '../utils/screen_utils.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({Key? key}) : super(key: key);

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> 
    with TickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  List<InvoiceModel> _invoices = [];
  bool _isLoading = false;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _loadInvoices();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Gerçek veriler servisden alınıyor
      final invoices = await InvoiceService().getAllInvoices();
      
      // Eğer gerçek veri yoksa sample data kullan
      if (invoices.isEmpty) {
        _invoices = _createSampleInvoices();
      } else {
        _invoices = invoices;
      }
      
      setState(() {
        _isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      // Hata durumunda sample data kullan
      _invoices = _createSampleInvoices();
      setState(() {
        _isLoading = false;
      });
      _showError('Faturalar yüklenirken hata oluştu: $e');
    }
  }

  List<InvoiceModel> _createSampleInvoices() {
    final now = DateTime.now();
    return [
      InvoiceModel(
        invoiceNumber: 'INV-2024-001',
        netAmount: 850.0,
        taxAmount: 161.5,
        grossAmount: 1011.5,
        invoiceDate: now.subtract(const Duration(days: 5)),
        dueDate: now.add(const Duration(days: 25)),
        paymentStatus: PaymentStatus.PENDING,
        invoiceType: InvoiceType.INCOMING,
        supplierName: 'ABC Technology GmbH',
        description: 'Software License & Support',
        category: 'IT Services',
        olusturmaTarihi: now.subtract(const Duration(days: 5)),
        guncellemeTarihi: now.subtract(const Duration(days: 5)),
      ),
      InvoiceModel(
        invoiceNumber: 'INV-2024-002',
        netAmount: 420.0,
        taxAmount: 79.8,
        grossAmount: 499.8,
        invoiceDate: now.subtract(const Duration(days: 10)),
        dueDate: now.subtract(const Duration(days: 2)),
        paymentDate: now.subtract(const Duration(days: 1)),
        paymentStatus: PaymentStatus.PAID,
        invoiceType: InvoiceType.INCOMING,
        supplierName: 'Office Supplies Pro',
        description: 'Office Equipment',
        category: 'Office Expenses',
        olusturmaTarihi: now.subtract(const Duration(days: 10)),
        guncellemeTarihi: now.subtract(const Duration(days: 1)),
      ),
      InvoiceModel(
        invoiceNumber: 'INV-2024-003',
        netAmount: 1200.0,
        taxAmount: 228.0,
        grossAmount: 1428.0,
        invoiceDate: now.subtract(const Duration(days: 3)),
        dueDate: now.subtract(const Duration(days: 5)),
        paymentStatus: PaymentStatus.OVERDUE,
        invoiceType: InvoiceType.INCOMING,
        supplierName: 'Marketing Solutions Ltd',
        description: 'Digital Marketing Campaign',
        category: 'Marketing',
        olusturmaTarihi: now.subtract(const Duration(days: 3)),
        guncellemeTarihi: now.subtract(const Duration(days: 3)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.orange.shade50,
              Colors.red.shade50,
              Colors.pink.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              if (_isLoading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        _buildFilterChips(),
                        _buildStats(),
                        Expanded(child: _buildInvoicesList()),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade400, Colors.red.shade400],
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.receipt_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Faturalar',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'Fatura yönetimi ve takibi',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(15),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadInvoices,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = {
      'all': 'Tümü',
      'pending': 'Beklemede',
      'overdue': 'Gecikmiş',
      'paid': 'Ödenmiş',
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.entries.map((entry) {
            final isSelected = _selectedFilter == entry.key;
            return Container(
              margin: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(
                  entry.value,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.orange.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = entry.key;
                  });
                },
                selectedColor: Colors.orange.shade400,
                backgroundColor: Colors.orange.shade50,
                side: BorderSide(color: Colors.orange.shade300),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStats() {
    final totalAmount = _invoices.fold<double>(
      0.0, 
      (sum, invoice) => sum + invoice.grossAmount,
    );
    
    final pendingCount = _invoices.where(
      (invoice) => invoice.paymentStatus == PaymentStatus.PENDING,
    ).length;

    final overdueCount = _invoices.where(
      (invoice) => invoice.paymentStatus == PaymentStatus.OVERDUE,
    ).length;

    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Toplam Tutar',
              '€${totalAmount.toStringAsFixed(2)}',
              Icons.euro_rounded,
              [Colors.green.shade400, Colors.green.shade600],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Beklemede',
              '$pendingCount',
              Icons.schedule_rounded,
              [Colors.blue.shade400, Colors.blue.shade600],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Gecikmiş',
              '$overdueCount',
              Icons.warning_rounded,
              [Colors.red.shade400, Colors.red.shade600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    List<Color> colors,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicesList() {
    final filteredInvoices = _getFilteredInvoices();

    if (filteredInvoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Fatura bulunamadı',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Yeni fatura eklemek için + butonunu kullanın',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: filteredInvoices.length,
      itemBuilder: (context, index) {
        return _buildInvoiceCard(filteredInvoices[index]);
      },
    );
  }

  List<InvoiceModel> _getFilteredInvoices() {
    switch (_selectedFilter) {
      case 'pending':
        return _invoices.where((i) => i.paymentStatus == PaymentStatus.PENDING).toList();
      case 'overdue':
        return _invoices.where((i) => i.paymentStatus == PaymentStatus.OVERDUE).toList();
      case 'paid':
        return _invoices.where((i) => i.paymentStatus == PaymentStatus.PAID).toList();
      default:
        return _invoices;
    }
  }

  Widget _buildInvoiceCard(InvoiceModel invoice) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Color(int.parse(invoice.statusColor.replaceFirst('#', '0xFF'))),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.receipt_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Text(
          invoice.invoiceNumber,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (invoice.supplierName != null) ...[
              const SizedBox(height: 4),
              Text(
                invoice.supplierName!,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(int.parse(invoice.statusColor.replaceFirst('#', '0xFF'))),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    invoice.paymentStatus.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  invoice.formatliGrossAmount,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Vade: ${invoice.formatliDueDate}',
              style: TextStyle(
                fontSize: 12,
                color: invoice.isOverdue ? Colors.red : Colors.grey.shade600,
                fontWeight: invoice.isOverdue ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 4),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
        onTap: () => _editInvoice(invoice),
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: _addNewInvoice,
      backgroundColor: Colors.orange.shade400,
      child: const Icon(Icons.add_rounded, color: Colors.white),
    );
  }

  Future<void> _addNewInvoice() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => InvoiceAddScreen(
          onSaved: (invoice) {
            // Refresh the invoice list when a new invoice is saved
            _loadInvoices();
          },
        ),
      ),
    );

    if (result == true) {
      _loadInvoices();
    }
  }

  Future<void> _editInvoice(InvoiceModel invoice) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => InvoiceAddScreen(
          invoice: invoice,
          onSaved: (updatedInvoice) {
            // Refresh the invoice list when invoice is updated
            _loadInvoices();
          },
        ),
      ),
    );

    if (result == true) {
      _loadInvoices();
    }
  }

  void _showError(String message) {
    ScreenUtils.showErrorSnackBar(context, message);
  }
} 