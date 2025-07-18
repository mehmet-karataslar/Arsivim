import '../models/tax_model.dart';
import '../models/activity_model.dart';
import 'veritabani_servisi.dart';
import 'calendar_activity_service.dart';
import 'notification_service.dart';

class TaxService {
  static final TaxService _instance = TaxService._internal();
  factory TaxService() => _instance;
  TaxService._internal();

  final VeriTabaniServisi _veritabani = VeriTabaniServisi();
  final CalendarActivityService _calendarService = CalendarActivityService();

  // Tax ekleme
  Future<int> createTax(TaxModel tax) async {
    try {
      // Validation
      _validateTax(tax);

      // Aynı kişi için aynı dönemde başka bir vergi kaydı var mı kontrol et
      final existingTax = await getTaxByPeriod(
        tax.kisiId!, 
        tax.taxYear, 
        tax.taxPeriod
      );
      if (existingTax != null) {
        throw Exception('Bu kişi için ${tax.taxYear} yılı ${tax.taxPeriod} dönemi zaten mevcut');
      }

      final now = DateTime.now().toIso8601String();
      final taxData = tax.toMap();
      taxData['olusturma_tarihi'] = now;
      taxData['guncelleme_tarihi'] = now;

      final taxId = await _veritabani.taxEkle(taxData);
      
      // Track tax creation activity
      try {
        await _calendarService.trackActivity(
          type: ActivityType.TAX_CREATE,
          title: 'Vergi Kaydı Oluşturuldu: ${tax.taxNumber}',
          description: '${_getTaxTypeText(tax.taxType)} kaydı oluşturuldu - ${tax.taxYear} yılı (${tax.calculatedTax.toStringAsFixed(2)} EUR)',
          activityDate: DateTime.now(),
          relatedItemId: taxId.toString(),
          relatedItemType: 'tax',
          metadata: {
            'tax_number': tax.taxNumber,
            'tax_year': tax.taxYear,
            'tax_type': tax.taxType.toString(),
            'calculated_tax': tax.calculatedTax,
            'paid_tax': tax.paidTax,
            'tax_status': tax.taxStatus.toString(),
            'operation': 'create',
          },
        );
        
        // Show immediate notification for tax creation
        await NotificationService.instance.showNotification(
          title: '💰 Vergi Kaydı Oluşturuldu',
          body: 'Yeni vergi kaydı eklendi: ${tax.taxNumber} - ${tax.taxYear} yılı',
          payload: 'tax_$taxId',
        );
      } catch (e) {
        print('Calendar activity tracking hatası: $e');
      }
      
      return taxId;
    } catch (e) {
      throw Exception('Vergi ekleme hatası: $e');
    }
  }

  // Tüm tax'ları getir
  Future<List<TaxModel>> getAllTaxes({
    int? kisiId,
    TaxStatus? taxStatus,
    int? taxYear,
  }) async {
    try {
      final taxes = await _veritabani.taxesGetir(
        kisiId: kisiId,
        taxStatus: taxStatus?.toString().split('.').last,
        taxYear: taxYear,
      );

      return taxes.map((data) => TaxModel.fromMap(data)).toList();
    } catch (e) {
      throw Exception('Vergi alma hatası: $e');
    }
  }

  // Tax dönem ile getir
  Future<TaxModel?> getTaxByPeriod(int kisiId, int year, TaxPeriod period) async {
    try {
      final tax = await _veritabani.taxGetirByPeriod(kisiId, year, period.index);
      return tax != null ? TaxModel.fromMap(tax) : null;
    } catch (e) {
      throw Exception('Dönemsel vergi alma hatası: $e');
    }
  }

  // ID ile tax getir
  Future<TaxModel?> getTaxById(int id) async {
    try {
      final tax = await _veritabani.taxGetir(id);
      return tax != null ? TaxModel.fromMap(tax) : null;
    } catch (e) {
      throw Exception('Vergi alma hatası: $e');
    }
  }

  // Tax güncelle
  Future<void> updateTax(TaxModel tax) async {
    try {
      _validateTax(tax);

      final taxData = tax.toMap();
      taxData['guncelleme_tarihi'] = DateTime.now().toIso8601String();

      await _veritabani.taxGuncelle(tax.id!, taxData);
    } catch (e) {
      throw Exception('Vergi güncelleme hatası: $e');
    }
  }

  // Tax sil
  Future<void> deleteTax(int id) async {
    try {
      await _veritabani.taxSil(id);
    } catch (e) {
      throw Exception('Vergi silme hatası: $e');
    }
  }

  // Duruma göre vergiler
  Future<List<TaxModel>> getTaxesByStatus(TaxStatus status) async {
    try {
      return await getAllTaxes(taxStatus: status);
    } catch (e) {
      throw Exception('Duruma göre vergi alma hatası: $e');
    }
  }

  // Vadesi geçen vergiler
  Future<List<TaxModel>> getOverdueTaxes() async {
    try {
      final allTaxes = await getAllTaxes(taxStatus: TaxStatus.READY);
      final now = DateTime.now();
      
      return allTaxes.where((tax) => 
        tax.submissionDeadline != null && tax.submissionDeadline!.isBefore(now)
      ).toList();
    } catch (e) {
      throw Exception('Vadesi geçen vergi alma hatası: $e');
    }
  }

  // Bu yıl vergileri
  Future<List<TaxModel>> getThisYearTaxes() async {
    try {
      final currentYear = DateTime.now().year;
      return await getAllTaxes(taxYear: currentYear);
    } catch (e) {
      throw Exception('Bu yıl vergi alma hatası: $e');
    }
  }

  // Vergi arama
  Future<List<TaxModel>> searchTaxes(String query) async {
    try {
      final allTaxes = await getAllTaxes();
      final searchTerm = query.toLowerCase();
      
      return allTaxes.where((tax) {
        return tax.taxNumber.toLowerCase().contains(searchTerm) ||
               tax.taxType.toString().toLowerCase().contains(searchTerm) ||
               tax.primaryCategory.toString().toLowerCase().contains(searchTerm) ||
               tax.taxOffice?.toLowerCase().contains(searchTerm) == true ||
               tax.ustIdNr?.toLowerCase().contains(searchTerm) == true;
      }).toList();
    } catch (e) {
      throw Exception('Vergi arama hatası: $e');
    }
  }

  // Otomatik vergi dönemi hesaplama
  TaxPeriod getCurrentTaxPeriod(TaxType taxType) {
    switch (taxType) {
      case TaxType.VAT:
        // Aylık KDV
        return TaxPeriod.MONTHLY;
      case TaxType.INCOME_TAX:
        // Yıllık gelir vergisi
        return TaxPeriod.YEARLY;
      case TaxType.TRADE_TAX:
        // Çeyreklik ticaret vergisi
        return TaxPeriod.QUARTERLY;
      case TaxType.SOLIDARITY_SURCHARGE:
      case TaxType.CHURCH_TAX:
        // Yıllık diğer vergiler
        return TaxPeriod.YEARLY;
      default:
        return TaxPeriod.MONTHLY;
    }
  }

  // Vergi dönem tarihlerini hesaplama
  Map<String, DateTime> calculateTaxPeriodDates(int year, TaxPeriod period, {int? month, int? quarter}) {
    switch (period) {
      case TaxPeriod.MONTHLY:
        if (month == null) throw Exception('Aylık dönem için ay belirtilmelidir');
        return {
          'start': DateTime(year, month, 1),
          'end': DateTime(year, month + 1, 0),
        };
      
      case TaxPeriod.QUARTERLY:
        if (quarter == null) throw Exception('Çeyreklik dönem için çeyrek belirtilmelidir');
        final startMonth = (quarter - 1) * 3 + 1;
        final endMonth = startMonth + 2;
        return {
          'start': DateTime(year, startMonth, 1),
          'end': DateTime(year, endMonth + 1, 0),
        };
      
      case TaxPeriod.YEARLY:
        return {
          'start': DateTime(year, 1, 1),
          'end': DateTime(year, 12, 31),
        };
    }
  }

  // Vergi son tarihini hesaplama
  DateTime calculateTaxDeadline(TaxType taxType, TaxPeriod period, DateTime periodEnd) {
    switch (taxType) {
      case TaxType.VAT:
        // KDV beyannamesi: dönem sonundan 10 gün sonra
        return DateTime(periodEnd.year, periodEnd.month + 1, 10);
      
      case TaxType.INCOME_TAX:
        // Gelir vergisi: sonraki yılın 31 Mayıs'ı
        return DateTime(periodEnd.year + 1, 5, 31);
      
      case TaxType.TRADE_TAX:
        // Ticaret vergisi: sonraki yılın 31 Mayıs'ı
        return DateTime(periodEnd.year + 1, 5, 31);
      
      case TaxType.SOLIDARITY_SURCHARGE:
      case TaxType.CHURCH_TAX:
        // Diğer vergiler: sonraki yılın 31 Mayıs'ı
        return DateTime(periodEnd.year + 1, 5, 31);
      
      default:
        return DateTime(periodEnd.year, periodEnd.month + 1, 10);
    }
  }

  // ELSTER verisi hazırlama
  Map<String, dynamic> prepareElsterData(TaxModel tax) {
    final periods = calculateTaxPeriodDates(tax.taxYear, tax.taxPeriod, 
        month: tax.taxMonth, quarter: tax.taxQuarter);
    
    return {
      'steuernummer': tax.taxNumber,
      'ust_id_nr': tax.ustIdNr,
      'finanzamt': tax.taxOffice,
      'zeitraum_von': periods['start']!.toIso8601String(),
      'zeitraum_bis': periods['end']!.toIso8601String(),
      'steuerart': tax.taxType.toString().split('.').last,
      'berechneter_betrag': tax.calculatedTax,
      'gezahlter_betrag': tax.paidTax,
      'status': tax.taxStatus.toString().split('.').last,
    };
  }

  // Vergi hesaplama yardımcısı
  Map<String, double> calculateTaxAmounts({
    required double income,
    required double expenses,
    required TaxType taxType,
    TaxCategory? category,
  }) {
    final taxableIncome = income - expenses;
    final taxRate = _getTaxRate(taxType, category ?? TaxCategory.BUSINESS_INCOME);
    final calculatedTax = taxableIncome * (taxRate / 100);
    
    return {
      'taxable_income': double.parse(taxableIncome.toStringAsFixed(2)),
      'calculated_tax': double.parse(calculatedTax.toStringAsFixed(2)),
      'tax_rate': taxRate,
    };
  }

  // Vergi oranı hesaplama
  double _getTaxRate(TaxType taxType, TaxCategory category) {
    switch (taxType) {
      case TaxType.VAT:
        switch (category) {
          case TaxCategory.BUSINESS_INCOME:
            return 19.0; // Standard KDV
          case TaxCategory.EMPLOYMENT_INCOME:
            return 7.0; // İndirimli KDV
          default:
            return 19.0;
        }
      
      case TaxType.INCOME_TAX:
        // Gelir vergisi (basitleştirilmiş - gerçekte gelir aralığına göre değişir)
        return 25.0;
      
      case TaxType.TRADE_TAX:
        // Ticaret vergisi (şehre göre değişir, ortalama)
        return 15.0;
      
      case TaxType.SOLIDARITY_SURCHARGE:
        // Dayanışma katkısı
        return 5.5;
      
      case TaxType.CHURCH_TAX:
        // Kilise vergisi
        return 8.0;
      
      default:
        return 19.0;
    }
  }

  // Validation helper
  void _validateTax(TaxModel tax) {
    if (tax.taxYear < 2000 || tax.taxYear > DateTime.now().year + 1) {
      throw Exception('Geçerli bir vergi yılı giriniz');
    }

    if (tax.calculatedTax < 0) {
      throw Exception('Hesaplanan vergi tutarı negatif olamaz');
    }

    if (tax.paidTax < 0) {
      throw Exception('Ödenen vergi tutarı negatif olamaz');
    }

    if (tax.paidTax > tax.calculatedTax) {
      throw Exception('Ödenen tutar toplam vergi tutarından fazla olamaz');
    }

    // German tax compliance checks
    if (tax.taxType == TaxType.VAT && tax.ustIdNr?.isEmpty == true) {
      // USt-IdNr required for VAT
    }
  }

  // Gelişmiş filtreleme
  Future<List<TaxModel>> getFilteredTaxes({
    int? kisiId,
    TaxStatus? taxStatus,
    TaxType? taxType,
    TaxCategory? taxCategory,
    int? startYear,
    int? endYear,
    TaxPeriod? taxPeriod,
    double? minAmount,
    double? maxAmount,
  }) async {
    try {
      List<TaxModel> taxes = await getAllTaxes(
        kisiId: kisiId,
        taxStatus: taxStatus,
      );

      // Tip filtresi
      if (taxType != null) {
        taxes = taxes.where((tax) => tax.taxType == taxType).toList();
      }

      // Kategori filtresi
      if (taxCategory != null) {
        taxes = taxes.where((tax) => tax.primaryCategory == taxCategory).toList();
      }

      // Yıl filtresi
      if (startYear != null) {
        taxes = taxes.where((tax) => tax.taxYear >= startYear).toList();
      }

      if (endYear != null) {
        taxes = taxes.where((tax) => tax.taxYear <= endYear).toList();
      }

      // Dönem filtresi
      if (taxPeriod != null) {
        taxes = taxes.where((tax) => tax.taxPeriod == taxPeriod).toList();
      }

      // Tutar filtresi
      if (minAmount != null) {
        taxes = taxes.where((tax) => tax.calculatedTax >= minAmount).toList();
      }

      if (maxAmount != null) {
        taxes = taxes.where((tax) => tax.calculatedTax <= maxAmount).toList();
      }

      return taxes;
    } catch (e) {
      throw Exception('Filtreli vergi alma hatası: $e');
    }
  }

  // İstatistikler
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final allTaxes = await getAllTaxes();
      
      final totalCount = allTaxes.length;
      final draftCount = allTaxes.where((t) => t.taxStatus == TaxStatus.DRAFT).length;
      final submittedCount = allTaxes.where((t) => t.taxStatus == TaxStatus.SUBMITTED).length;
      final overdueCount = (await getOverdueTaxes()).length;
      
      final totalCalculated = allTaxes.fold<double>(0, (sum, tax) => sum + tax.calculatedTax);
      final totalPaid = allTaxes.fold<double>(0, (sum, tax) => sum + tax.paidTax);
      final totalRemaining = totalCalculated - totalPaid;

      return {
        'totalCount': totalCount,
        'draftCount': draftCount,
        'submittedCount': submittedCount,
        'overdueCount': overdueCount,
        'totalCalculated': totalCalculated,
        'totalPaid': totalPaid,
        'totalRemaining': totalRemaining,
        'currency': allTaxes.isNotEmpty ? allTaxes.first.currency : 'EUR',
      };
    } catch (e) {
      throw Exception('İstatistik alma hatası: $e');
    }
  }

  // Yıllık vergi özeti
  Future<Map<String, dynamic>> getYearlyTaxSummary(int year) async {
    try {
      final taxes = await getAllTaxes(taxYear: year);
      
      double totalCalculated = 0;
      double totalPaid = 0;
      Map<String, int> statusCounts = {};
      Map<String, double> typeAmounts = {};
      
      for (final tax in taxes) {
        totalCalculated += tax.calculatedTax;
        totalPaid += tax.paidTax;
        
        // Status counts
        final status = tax.taxStatus.toString().split('.').last;
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
        
        // Type amounts
        final type = tax.taxType.toString().split('.').last;
        typeAmounts[type] = (typeAmounts[type] ?? 0) + tax.calculatedTax;
      }
      
      final totalRemaining = totalCalculated - totalPaid;
      
      return {
        'year': year,
        'total_calculated': totalCalculated,
        'total_paid': totalPaid,
        'total_remaining': totalRemaining,
        'total_count': taxes.length,
        'status_counts': statusCounts,
        'type_amounts': typeAmounts,
        'compliance_rate': taxes.isEmpty ? 0 : (totalPaid / totalCalculated * 100),
      };
    } catch (e) {
      throw Exception('Vergi özeti raporu hatası: $e');
    }
  }

  String _getTaxTypeText(TaxType type) {
    switch (type) {
      case TaxType.VAT:
        return 'KDV';
      case TaxType.INCOME_TAX:
        return 'Gelir Vergisi';
      case TaxType.TRADE_TAX:
        return 'Ticaret Vergisi';
      case TaxType.SOLIDARITY_SURCHARGE:
        return 'Dayanışma Katkısı';
      case TaxType.CHURCH_TAX:
        return 'Kilise Vergisi';
    }
  }
} 