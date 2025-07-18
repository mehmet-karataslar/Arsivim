import '../models/invoice_model.dart';
import '../models/activity_model.dart';
import 'veritabani_servisi.dart';
import 'calendar_activity_service.dart';
import 'notification_service.dart';

class InvoiceService {
  static final InvoiceService _instance = InvoiceService._internal();
  factory InvoiceService() => _instance;
  InvoiceService._internal();

  final VeriTabaniServisi _veritabani = VeriTabaniServisi();
  final CalendarActivityService _calendarService = CalendarActivityService();

  // Invoice ekleme
  Future<int> createInvoice(InvoiceModel invoice) async {
    try {
      // Validation
      _validateInvoice(invoice);

      // Invoice numarasının benzersizliğini kontrol et
      final existingInvoice = await getInvoiceByNumber(invoice.invoiceNumber);
      if (existingInvoice != null) {
        throw Exception('Bu fatura numarası zaten kullanılıyor: ${invoice.invoiceNumber}');
      }

      final now = DateTime.now().toIso8601String();
      final invoiceData = invoice.toMap();
      invoiceData['olusturma_tarihi'] = now;
      invoiceData['guncelleme_tarihi'] = now;

      final invoiceId = await _veritabani.invoiceEkle(invoiceData);
      
      // Track invoice creation activity
      try {
        await _calendarService.trackActivity(
          type: ActivityType.INVOICE_CREATE,
          title: 'Fatura Oluşturuldu: ${invoice.invoiceNumber}',
          description: '${_getInvoiceTypeText(invoice.invoiceType)} oluşturuldu - ${invoice.supplierName ?? 'Tedarikçi'} (${invoice.grossAmount.toStringAsFixed(2)} ${invoice.currency})',
          activityDate: DateTime.now(),
          relatedItemId: invoiceId.toString(),
          relatedItemType: 'invoice',
          metadata: {
            'invoice_number': invoice.invoiceNumber,
            'supplier_name': invoice.supplierName,
            'amount': invoice.grossAmount,
            'currency': invoice.currency,
            'invoice_type': invoice.invoiceType.toString(),
            'payment_status': invoice.paymentStatus.toString(),
            'operation': 'create',
          },
        );
        
        // Show immediate notification for invoice creation
        await NotificationService.instance.showNotification(
          title: '📄 Fatura Oluşturuldu',
          body: 'Yeni fatura eklendi: ${invoice.invoiceNumber} - ${invoice.supplierName ?? 'Tedarikçi'}',
          payload: 'invoice_$invoiceId',
        );
      } catch (e) {
        print('Calendar activity tracking hatası: $e');
      }
      
      return invoiceId;
    } catch (e) {
      throw Exception('Fatura ekleme hatası: $e');
    }
  }

  // Tüm invoice'ları getir
  Future<List<InvoiceModel>> getAllInvoices({
    int? kisiId,
    PaymentStatus? paymentStatus,
    InvoiceType? invoiceType,
  }) async {
    try {
      final invoices = await _veritabani.invoicesGetir(
        kisiId: kisiId,
        paymentStatus: paymentStatus?.toString().split('.').last,
        invoiceType: invoiceType?.toString().split('.').last,
      );

      return invoices.map((data) => InvoiceModel.fromMap(data)).toList();
    } catch (e) {
      throw Exception('Fatura alma hatası: $e');
    }
  }

  // Fatura numarası ile getir
  Future<InvoiceModel?> getInvoiceByNumber(String invoiceNumber) async {
    try {
      final invoice = await _veritabani.invoiceGetirByNumber(invoiceNumber);
      return invoice != null ? InvoiceModel.fromMap(invoice) : null;
    } catch (e) {
      throw Exception('Fatura alma hatası: $e');
    }
  }

  // ID ile getir
  Future<InvoiceModel?> getInvoiceById(int id) async {
    try {
      final invoice = await _veritabani.invoiceGetir(id);
      return invoice != null ? InvoiceModel.fromMap(invoice) : null;
    } catch (e) {
      throw Exception('Fatura alma hatası: $e');
    }
  }

  // Invoice güncelle
  Future<void> updateInvoice(InvoiceModel invoice) async {
    try {
      _validateInvoice(invoice);

      final invoiceData = invoice.toMap();
      invoiceData['guncelleme_tarihi'] = DateTime.now().toIso8601String();

      await _veritabani.invoiceGuncelle(invoice.id!, invoiceData);
    } catch (e) {
      throw Exception('Fatura güncelleme hatası: $e');
    }
  }

  // Invoice sil
  Future<void> deleteInvoice(int id) async {
    try {
      await _veritabani.invoiceSil(id);
    } catch (e) {
      throw Exception('Fatura silme hatası: $e');
    }
  }

  // Brüt tutardan net ve vergi hesapla
  Map<String, double> calculateFromGross(double grossAmount, TaxRate taxRate) {
    double taxPercentage;
    switch (taxRate) {
      case TaxRate.STANDARD:
        taxPercentage = 19.0;
        break;
      case TaxRate.REDUCED:
        taxPercentage = 7.0;
        break;
      case TaxRate.ZERO:
      case TaxRate.EXEMPT:
        taxPercentage = 0.0;
        break;
    }

    final taxMultiplier = 1 + (taxPercentage / 100);
    final netAmount = grossAmount / taxMultiplier;
    final taxAmount = grossAmount - netAmount;

    return {
      'net': double.parse(netAmount.toStringAsFixed(2)),
      'tax': double.parse(taxAmount.toStringAsFixed(2)),
      'gross': grossAmount,
    };
  }

  // Net tutardan brüt ve vergi hesapla
  Map<String, double> calculateFromNet(double netAmount, TaxRate taxRate) {
    double taxPercentage;
    switch (taxRate) {
      case TaxRate.STANDARD:
        taxPercentage = 19.0;
        break;
      case TaxRate.REDUCED:
        taxPercentage = 7.0;
        break;
      case TaxRate.ZERO:
      case TaxRate.EXEMPT:
        taxPercentage = 0.0;
        break;
    }

    final taxAmount = netAmount * (taxPercentage / 100);
    final grossAmount = netAmount + taxAmount;

    return {
      'net': netAmount,
      'tax': double.parse(taxAmount.toStringAsFixed(2)),
      'gross': double.parse(grossAmount.toStringAsFixed(2)),
    };
  }

  // Ödeme durumuna göre faturalar
  Future<List<InvoiceModel>> getInvoicesByPaymentStatus(PaymentStatus status) async {
    try {
      return await getAllInvoices(paymentStatus: status);
    } catch (e) {
      throw Exception('Ödeme durumuna göre fatura alma hatası: $e');
    }
  }

  // Vadesi geçen faturalar
  Future<List<InvoiceModel>> getOverdueInvoices() async {
    try {
      final allInvoices = await getAllInvoices(paymentStatus: PaymentStatus.PENDING);
      final now = DateTime.now();
      
      return allInvoices.where((invoice) => 
        invoice.dueDate != null && invoice.dueDate!.isBefore(now)
      ).toList();
    } catch (e) {
      throw Exception('Vadesi geçen fatura alma hatası: $e');
    }
  }

  // Bu ay oluşturulan faturalar
  Future<List<InvoiceModel>> getThisMonthInvoices() async {
    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0);

      final allInvoices = await getAllInvoices();
      
      return allInvoices.where((invoice) {
        return invoice.invoiceDate.isAfter(monthStart) && 
               invoice.invoiceDate.isBefore(monthEnd.add(const Duration(days: 1)));
      }).toList();
    } catch (e) {
      throw Exception('Bu ay fatura alma hatası: $e');
    }
  }

  // Fatura arama
  Future<List<InvoiceModel>> searchInvoices(String query) async {
    try {
      final allInvoices = await getAllInvoices();
      final searchTerm = query.toLowerCase();
      
      return allInvoices.where((invoice) {
        return invoice.invoiceNumber.toLowerCase().contains(searchTerm) ||
               invoice.supplierName?.toLowerCase().contains(searchTerm) == true ||
               invoice.description?.toLowerCase().contains(searchTerm) == true;
      }).toList();
    } catch (e) {
      throw Exception('Fatura arama hatası: $e');
    }
  }

  // Otomatik fatura numarası oluştur
  Future<String> generateInvoiceNumber({String prefix = 'INV'}) async {
    try {
      final now = DateTime.now();
      final year = now.year.toString().substring(2);
      final month = now.month.toString().padLeft(2, '0');
      
      // Bu ay için son fatura numarasını bul
      final thisMonthInvoices = await getThisMonthInvoices();
      
      int sequence = 1;
      if (thisMonthInvoices.isNotEmpty) {
        // Extract sequence numbers and find the highest
        final sequences = thisMonthInvoices
            .map((invoice) => invoice.invoiceNumber)
            .where((number) => number.startsWith('$prefix$year$month'))
            .map((number) {
              final parts = number.split('-');
              if (parts.length == 2) {
                return int.tryParse(parts[1]) ?? 0;
              }
              return 0;
            })
            .toList();
        
        if (sequences.isNotEmpty) {
          sequence = sequences.reduce((a, b) => a > b ? a : b) + 1;
        }
      }

      return '$prefix$year$month-${sequence.toString().padLeft(3, '0')}';
    } catch (e) {
      throw Exception('Fatura numarası oluşturma hatası: $e');
    }
  }

  // İstatistikler
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final allInvoices = await getAllInvoices();
      
      final totalCount = allInvoices.length;
      final paidCount = allInvoices.where((i) => i.paymentStatus == PaymentStatus.PAID).length;
      final pendingCount = allInvoices.where((i) => i.paymentStatus == PaymentStatus.PENDING).length;
      final overdueCount = (await getOverdueInvoices()).length;
      
      final totalAmount = allInvoices.fold<double>(0, (sum, invoice) => sum + invoice.grossAmount);
      final paidAmount = allInvoices
          .where((i) => i.paymentStatus == PaymentStatus.PAID)
          .fold<double>(0, (sum, invoice) => sum + invoice.grossAmount);
      final pendingAmount = allInvoices
          .where((i) => i.paymentStatus == PaymentStatus.PENDING)
          .fold<double>(0, (sum, invoice) => sum + invoice.grossAmount);

      return {
        'totalCount': totalCount,
        'paidCount': paidCount,
        'pendingCount': pendingCount,
        'overdueCount': overdueCount,
        'totalAmount': totalAmount,
        'paidAmount': paidAmount,
        'pendingAmount': pendingAmount,
        'currency': allInvoices.isNotEmpty ? allInvoices.first.currency : 'EUR',
      };
    } catch (e) {
      throw Exception('İstatistik alma hatası: $e');
    }
  }

  // Validasyon
  void _validateInvoice(InvoiceModel invoice) {
    if (invoice.invoiceNumber.trim().isEmpty) {
      throw Exception('Fatura numarası boş olamaz');
    }

    if (invoice.netAmount <= 0) {
      throw Exception('Net tutar sıfırdan büyük olmalıdır');
    }

    if (invoice.dueDate != null && invoice.dueDate!.isBefore(invoice.invoiceDate)) {
      throw Exception('Vade tarihi düzenleme tarihinden önce olamaz');
    }

    // German tax compliance checks
    if (invoice.taxRate != TaxRate.ZERO && invoice.taxRate != TaxRate.EXEMPT && invoice.ustIdNr?.isEmpty == true) {
      // USt-IdNr required for tax invoices in Germany
    }
  }

  // Gelişmiş filtreleme
  Future<List<InvoiceModel>> getFilteredInvoices({
    int? kisiId,
    PaymentStatus? paymentStatus,
    InvoiceType? invoiceType,
    DateTime? startDate,
    DateTime? endDate,
    double? minAmount,
    double? maxAmount,
    String? currency,
  }) async {
    try {
      List<InvoiceModel> invoices = await getAllInvoices(
        kisiId: kisiId,
        paymentStatus: paymentStatus,
        invoiceType: invoiceType,
      );

      // Tarih filtresi
      if (startDate != null) {
        invoices = invoices.where((invoice) => 
          invoice.invoiceDate.isAfter(startDate.subtract(const Duration(days: 1)))
        ).toList();
      }

      if (endDate != null) {
        invoices = invoices.where((invoice) => 
          invoice.invoiceDate.isBefore(endDate.add(const Duration(days: 1)))
        ).toList();
      }

      // Tutar filtresi
      if (minAmount != null) {
        invoices = invoices.where((invoice) => 
          invoice.grossAmount >= minAmount
        ).toList();
      }

      if (maxAmount != null) {
        invoices = invoices.where((invoice) => 
          invoice.grossAmount <= maxAmount
        ).toList();
      }

      // Para birimi filtresi
      if (currency != null) {
        invoices = invoices.where((invoice) => 
          invoice.currency == currency
        ).toList();
      }

      return invoices;
    } catch (e) {
      throw Exception('Filtreli fatura alma hatası: $e');
    }
  }

  String _getInvoiceTypeText(InvoiceType type) {
    switch (type) {
      case InvoiceType.INCOMING:
        return 'Gelen Fatura';
      case InvoiceType.OUTGOING:
        return 'Giden Fatura';
      case InvoiceType.RECEIPT:
        return 'Fiş/Makbuz';
      case InvoiceType.CREDIT_NOTE:
        return 'İade Faturası';
    }
  }
} 