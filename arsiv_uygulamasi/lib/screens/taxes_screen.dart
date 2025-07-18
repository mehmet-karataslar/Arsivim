import 'package:flutter/material.dart';
import '../models/tax_model.dart';
import '../services/tax_service.dart';
import 'tax_add_screen.dart';
import '../utils/screen_utils.dart';

class TaxesScreen extends StatefulWidget {
  const TaxesScreen({Key? key}) : super(key: key);

  @override
  State<TaxesScreen> createState() => _TaxesScreenState();
}

class _TaxesScreenState extends State<TaxesScreen> 
    with TickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  List<TaxModel> _taxes = [];
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

    _loadTaxes();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadTaxes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Gerçek veriler servisden alınıyor
      final taxes = await TaxService().getAllTaxes();
      
      // Eğer gerçek veri yoksa sample data kullan
      if (taxes.isEmpty) {
        _taxes = _createSampleTaxes();
      } else {
        _taxes = taxes;
      }
      
      setState(() {
        _isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      // Hata durumunda sample data kullan
      _taxes = _createSampleTaxes();
      setState(() {
        _isLoading = false;
      });
      _showError('Vergiler yüklenirken hata oluştu: $e');
    }
  }

  List<TaxModel> _createSampleTaxes() {
    final now = DateTime.now();
    final currentYear = now.year;
    
    return [
      TaxModel(
        taxNumber: 'UST-2024-Q1',
        taxYear: currentYear,
        taxQuarter: 1,
        taxPeriod: TaxPeriod.QUARTERLY,
        taxStatus: TaxStatus.SUBMITTED,
        taxType: TaxType.VAT,
        totalIncome: 15000.0,
        totalExpenses: 8500.0,
        taxableIncome: 6500.0,
        calculatedTax: 1235.0,
        paidTax: 1235.0,
        submissionDeadline: DateTime(currentYear, 3, 31),
        submissionDate: DateTime(currentYear, 3, 28),
        taxOffice: 'Finanzamt Berlin',
        olusturmaTarihi: DateTime(currentYear, 1, 1),
        guncellemeTarihi: DateTime(currentYear, 3, 28),
      ),
      TaxModel(
        taxNumber: 'UST-2024-Q2',
        taxYear: currentYear,
        taxQuarter: 2,
        taxPeriod: TaxPeriod.QUARTERLY,
        taxStatus: TaxStatus.READY,
        taxType: TaxType.VAT,
        totalIncome: 18500.0,
        totalExpenses: 9200.0,
        taxableIncome: 9300.0,
        calculatedTax: 1767.0,
        paidTax: 0.0,
        submissionDeadline: DateTime(currentYear, 6, 30),
        taxOffice: 'Finanzamt Berlin',
        olusturmaTarihi: DateTime(currentYear, 4, 1),
        guncellemeTarihi: DateTime(currentYear, 6, 15),
      ),
      TaxModel(
        taxNumber: 'EST-2023',
        taxYear: currentYear - 1,
        taxPeriod: TaxPeriod.YEARLY,
        taxStatus: TaxStatus.INCOMPLETE,
        taxType: TaxType.INCOME_TAX,
        totalIncome: 65000.0,
        totalExpenses: 12000.0,
        taxableIncome: 53000.0,
        calculatedTax: 15900.0,
        paidTax: 14500.0,
        submissionDeadline: DateTime(currentYear, 7, 31),
        taxOffice: 'Finanzamt Berlin',
        isFreelancer: true,
        businessType: 'Software Development',
        olusturmaTarihi: DateTime(currentYear - 1, 1, 1),
        guncellemeTarihi: DateTime(currentYear, 5, 20),
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
              Colors.purple.shade50,
              Colors.indigo.shade50,
              Colors.blue.shade50,
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
                        Expanded(child: _buildTaxesList()),
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
                colors: [Colors.purple.shade400, Colors.indigo.shade400],
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.account_balance_rounded,
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
                  'Vergiler',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'Vergi yönetimi ve takibi',
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
              onPressed: _loadTaxes,
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
      'draft': 'Taslak',
      'ready': 'Hazır',
      'submitted': 'Teslim Edilmiş',
      'incomplete': 'Eksik',
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
                    color: isSelected ? Colors.white : Colors.purple.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = entry.key;
                  });
                },
                selectedColor: Colors.purple.shade400,
                backgroundColor: Colors.purple.shade50,
                side: BorderSide(color: Colors.purple.shade300),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStats() {
    final totalCalculatedTax = _taxes.fold<double>(
      0.0, 
      (sum, tax) => sum + tax.calculatedTax,
    );
    
    final totalPaidTax = _taxes.fold<double>(
      0.0, 
      (sum, tax) => sum + tax.paidTax,
    );

    final pendingCount = _taxes.where(
      (tax) => tax.taxStatus == TaxStatus.DRAFT || tax.taxStatus == TaxStatus.READY,
    ).length;

    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Hesaplanan',
              '€${totalCalculatedTax.toStringAsFixed(2)}',
              Icons.calculate_rounded,
              [Colors.blue.shade400, Colors.blue.shade600],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Ödenen',
              '€${totalPaidTax.toStringAsFixed(2)}',
              Icons.payment_rounded,
              [Colors.green.shade400, Colors.green.shade600],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Beklemede',
              '$pendingCount',
              Icons.schedule_rounded,
              [Colors.orange.shade400, Colors.orange.shade600],
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

  Widget _buildTaxesList() {
    final filteredTaxes = _getFilteredTaxes();

    if (filteredTaxes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_rounded,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Vergi kaydı bulunamadı',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Yeni vergi kaydı eklemek için + butonunu kullanın',
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
      itemCount: filteredTaxes.length,
      itemBuilder: (context, index) {
        return _buildTaxCard(filteredTaxes[index]);
      },
    );
  }

  List<TaxModel> _getFilteredTaxes() {
    switch (_selectedFilter) {
      case 'draft':
        return _taxes.where((t) => t.taxStatus == TaxStatus.DRAFT).toList();
      case 'ready':
        return _taxes.where((t) => t.taxStatus == TaxStatus.READY).toList();
      case 'submitted':
        return _taxes.where((t) => t.taxStatus == TaxStatus.SUBMITTED).toList();
      case 'incomplete':
        return _taxes.where((t) => t.taxStatus == TaxStatus.INCOMPLETE).toList();
      default:
        return _taxes;
    }
  }

  Widget _buildTaxCard(TaxModel tax) {
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
            color: Color(int.parse(tax.statusColor.replaceFirst('#', '0xFF'))),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            tax.taxType == TaxType.VAT 
                ? Icons.percent_rounded 
                : Icons.account_balance_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Text(
          tax.taxNumber,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              tax.periodName,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(int.parse(tax.statusColor.replaceFirst('#', '0xFF'))),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tax.taxStatus.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tax.formatliCalculatedTax,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
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
            if (tax.submissionDeadline != null)
              Text(
                'Son: ${tax.formatliSubmissionDeadline}',
                style: TextStyle(
                  fontSize: 12,
                  color: tax.isOverdue ? Colors.red : Colors.grey.shade600,
                  fontWeight: tax.isOverdue ? FontWeight.bold : FontWeight.normal,
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
        onTap: () => _editTax(tax),
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: _addNewTax,
      backgroundColor: Colors.purple.shade400,
      child: const Icon(Icons.add_rounded, color: Colors.white),
    );
  }

  Future<void> _addNewTax() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => TaxAddScreen(
          onSaved: (tax) {
            // Refresh the tax list when a new tax is saved
            _loadTaxes();
          },
        ),
      ),
    );

    if (result == true) {
      _loadTaxes();
    }
  }

  Future<void> _editTax(TaxModel tax) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => TaxAddScreen(
          tax: tax,
          onSaved: (updatedTax) {
            // Refresh the tax list when tax is updated
            _loadTaxes();
          },
        ),
      ),
    );

    if (result == true) {
      _loadTaxes();
    }
  }

  void _showError(String message) {
    ScreenUtils.showErrorSnackBar(context, message);
  }
} 