import 'base_model.dart';
import '../utils/yardimci_fonksiyonlar.dart';

/// Vergi dönemi enum'u - Alman vergi sistemi için
enum TaxPeriod {
  MONTHLY,    // Aylık (Monatlich)
  QUARTERLY,  // Çeyreklik (Vierteljährlich)
  YEARLY,     // Yıllık (Jährlich)
}

/// Vergi durumu enum'u
enum TaxStatus {
  DRAFT,      // Taslak
  READY,      // Hazır
  SUBMITTED,  // Teslim edilmiş
  APPROVED,   // Onaylanmış
  REJECTED,   // Reddedilmiş
  INCOMPLETE, // Eksik
}

/// Vergi kategorisi enum'u - Alman vergi sistemi
enum TaxCategory {
  BUSINESS_INCOME,     // İş geliri (Einkünfte aus Gewerbebetrieb)
  EMPLOYMENT_INCOME,   // Maaş geliri (Einkünfte aus nichtselbständiger Arbeit)
  CAPITAL_INCOME,      // Sermaye geliri (Einkünfte aus Kapitalvermögen)
  RENTAL_INCOME,       // Kira geliri (Einkünfte aus Vermietung und Verpachtung)
  OTHER_INCOME,        // Diğer gelirler (Sonstige Einkünfte)
  
  BUSINESS_EXPENSE,    // İş giderleri (Betriebsausgaben)
  SPECIAL_EXPENSE,     // Özel giderler (Sonderausgaben)
  EXTRAORDINARY_EXPENSE, // Olağanüstü giderler (Außergewöhnliche Belastungen)
  TAX_DEDUCTIBLE,      // Vergiden düşülebilir
}

/// Vergi türü enum'u
enum TaxType {
  INCOME_TAX,          // Gelir vergisi (Einkommensteuer)
  VAT,                 // KDV (Umsatzsteuer)
  TRADE_TAX,           // Ticaret vergisi (Gewerbesteuer)
  SOLIDARITY_SURCHARGE, // Dayanışma katkısı (Solidaritätszuschlag)
  CHURCH_TAX,          // Kilise vergisi (Kirchensteuer)
}

/// Vergi modeli - Alman vergi yasalarına uygun
class TaxModel extends BaseModel {
  int? id;
  int? kisiId;                   // Verginin ait olduğu kişi ID'si
  String taxNumber;              // Vergi numarası
  
  TaxPeriod taxPeriod;           // Vergi dönemi
  int taxYear;                   // Vergi yılı
  int? taxMonth;                 // Vergi ayı (aylık dönem için)
  int? taxQuarter;               // Vergi çeyreği (çeyreklik dönem için)
  
  TaxStatus taxStatus;           // Vergi durumu
  TaxType taxType;               // Vergi türü
  TaxCategory primaryCategory;   // Ana kategori
  
  double totalIncome;            // Toplam gelir
  double totalExpenses;          // Toplam giderler
  double taxableIncome;          // Vergiye tabi gelir
  double calculatedTax;          // Hesaplanan vergi
  double paidTax;                // Ödenen vergi
  double refundAmount;           // İade tutarı
  String currency;               // Para birimi
  
  DateTime? submissionDeadline;  // Teslim son tarihi
  DateTime? submissionDate;      // Teslim tarihi
  DateTime? assessmentDate;      // Değerlendirme tarihi
  
  String? description;           // Açıklama/Notlar
  String? taxOffice;             // Finanzamt
  String? taxAdvisor;            // Mali müşavir
  String? preparationSoftware;   // Hazırlama yazılımı
  
  List<String>? attachmentPaths; // Ek dosya yolları
  List<String>? invoiceIds;      // Bağlı fatura ID'leri
  String? elsterData;            // ELSTER veri (XML format)
  
  DateTime olusturmaTarihi;
  DateTime guncellemeTarihi;
  bool aktif;
  
  // German-specific fields
  String? ustIdNr;               // USt-IdNr. (EU VAT number)
  String? steuernummer;          // Steuernummer
  bool isFreelancer;             // Serbest meslek mi?
  bool isSmallBusiness;          // Kleinunternehmer mi?
  String? businessType;          // İş türü
  double? churchTaxRate;         // Kilise vergisi oranı
  Map<String, dynamic>? detailedBreakdown; // Detaylı döküm (JSON)

  TaxModel({
    this.id,
    this.kisiId,
    required this.taxNumber,
    this.taxPeriod = TaxPeriod.YEARLY,
    required this.taxYear,
    this.taxMonth,
    this.taxQuarter,
    this.taxStatus = TaxStatus.DRAFT,
    this.taxType = TaxType.INCOME_TAX,
    this.primaryCategory = TaxCategory.BUSINESS_INCOME,
    this.totalIncome = 0.0,
    this.totalExpenses = 0.0,
    this.taxableIncome = 0.0,
    this.calculatedTax = 0.0,
    this.paidTax = 0.0,
    this.refundAmount = 0.0,
    this.currency = 'EUR',
    this.submissionDeadline,
    this.submissionDate,
    this.assessmentDate,
    this.description,
    this.taxOffice,
    this.taxAdvisor,
    this.preparationSoftware,
    this.attachmentPaths,
    this.invoiceIds,
    this.elsterData,
    required this.olusturmaTarihi,
    required this.guncellemeTarihi,
    this.aktif = true,
    this.ustIdNr,
    this.steuernummer,
    this.isFreelancer = false,
    this.isSmallBusiness = false,
    this.businessType,
    this.churchTaxRate,
    this.detailedBreakdown,
  });

  /// Map'ten model oluştur
  factory TaxModel.fromMap(Map<String, dynamic> map) {
    return TaxModel(
      id: map['id'],
      kisiId: map['kisi_id'],
      taxNumber: map['tax_number'],
      taxPeriod: TaxPeriod.values[map['tax_period'] ?? 0],
      taxYear: map['tax_year'],
      taxMonth: map['tax_month'],
      taxQuarter: map['tax_quarter'],
      taxStatus: TaxStatus.values[map['tax_status'] ?? 0],
      taxType: TaxType.values[map['tax_type'] ?? 0],
      primaryCategory: TaxCategory.values[map['primary_category'] ?? 0],
      totalIncome: (map['total_income'] as num).toDouble(),
      totalExpenses: (map['total_expenses'] as num).toDouble(),
      taxableIncome: (map['taxable_income'] as num).toDouble(),
      calculatedTax: (map['calculated_tax'] as num).toDouble(),
      paidTax: (map['paid_tax'] as num).toDouble(),
      refundAmount: (map['refund_amount'] as num).toDouble(),
      currency: map['currency'] ?? 'EUR',
      submissionDeadline: map['submission_deadline'] != null 
          ? DateTime.parse(map['submission_deadline']) : null,
      submissionDate: map['submission_date'] != null 
          ? DateTime.parse(map['submission_date']) : null,
      assessmentDate: map['assessment_date'] != null 
          ? DateTime.parse(map['assessment_date']) : null,
      description: map['description'],
      taxOffice: map['tax_office'],
      taxAdvisor: map['tax_advisor'],
      preparationSoftware: map['preparation_software'],
      attachmentPaths: map['attachment_paths']?.split(',').cast<String>(),
      invoiceIds: map['invoice_ids']?.split(',').cast<String>(),
      elsterData: map['elster_data'],
      olusturmaTarihi: DateTime.parse(map['olusturma_tarihi']),
      guncellemeTarihi: DateTime.parse(map['guncelleme_tarihi']),
      aktif: map['aktif'] == 1,
      ustIdNr: map['ust_id_nr'],
      steuernummer: map['steuernummer'],
      isFreelancer: map['is_freelancer'] == 1,
      isSmallBusiness: map['is_small_business'] == 1,
      businessType: map['business_type'],
      churchTaxRate: map['church_tax_rate']?.toDouble(),
      detailedBreakdown: map['detailed_breakdown'] != null 
          ? Map<String, dynamic>.from(map['detailed_breakdown']) : null,
    );
  }

  /// JSON'dan model oluştur
  factory TaxModel.fromJson(Map<String, dynamic> json) =>
      TaxModel.fromMap(json);

  /// Model'i Map'e dönüştür
  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kisi_id': kisiId,
      'tax_number': taxNumber,
      'tax_period': taxPeriod.index,
      'tax_year': taxYear,
      'tax_month': taxMonth,
      'tax_quarter': taxQuarter,
      'tax_status': taxStatus.index,
      'tax_type': taxType.index,
      'primary_category': primaryCategory.index,
      'total_income': totalIncome,
      'total_expenses': totalExpenses,
      'taxable_income': taxableIncome,
      'calculated_tax': calculatedTax,
      'paid_tax': paidTax,
      'refund_amount': refundAmount,
      'currency': currency,
      'submission_deadline': submissionDeadline?.toIso8601String(),
      'submission_date': submissionDate?.toIso8601String(),
      'assessment_date': assessmentDate?.toIso8601String(),
      'description': description,
      'tax_office': taxOffice,
      'tax_advisor': taxAdvisor,
      'preparation_software': preparationSoftware,
      'attachment_paths': attachmentPaths?.join(','),
      'invoice_ids': invoiceIds?.join(','),
      'elster_data': elsterData,
      'olusturma_tarihi': olusturmaTarihi.toIso8601String(),
      'guncelleme_tarihi': guncellemeTarihi.toIso8601String(),
      'aktif': aktif ? 1 : 0,
      'ust_id_nr': ustIdNr,
      'steuernummer': steuernummer,
      'is_freelancer': isFreelancer ? 1 : 0,
      'is_small_business': isSmallBusiness ? 1 : 0,
      'business_type': businessType,
      'church_tax_rate': churchTaxRate,
      'detailed_breakdown': detailedBreakdown,
    };
  }

  /// Model'i kopyala
  TaxModel copyWith({
    int? id,
    int? kisiId,
    String? taxNumber,
    TaxPeriod? taxPeriod,
    int? taxYear,
    int? taxMonth,
    int? taxQuarter,
    TaxStatus? taxStatus,
    TaxType? taxType,
    TaxCategory? primaryCategory,
    double? totalIncome,
    double? totalExpenses,
    double? taxableIncome,
    double? calculatedTax,
    double? paidTax,
    double? refundAmount,
    String? currency,
    DateTime? submissionDeadline,
    DateTime? submissionDate,
    DateTime? assessmentDate,
    String? description,
    String? taxOffice,
    String? taxAdvisor,
    String? preparationSoftware,
    List<String>? attachmentPaths,
    List<String>? invoiceIds,
    String? elsterData,
    DateTime? olusturmaTarihi,
    DateTime? guncellemeTarihi,
    bool? aktif,
    String? ustIdNr,
    String? steuernummer,
    bool? isFreelancer,
    bool? isSmallBusiness,
    String? businessType,
    double? churchTaxRate,
    Map<String, dynamic>? detailedBreakdown,
  }) {
    return TaxModel(
      id: id ?? this.id,
      kisiId: kisiId ?? this.kisiId,
      taxNumber: taxNumber ?? this.taxNumber,
      taxPeriod: taxPeriod ?? this.taxPeriod,
      taxYear: taxYear ?? this.taxYear,
      taxMonth: taxMonth ?? this.taxMonth,
      taxQuarter: taxQuarter ?? this.taxQuarter,
      taxStatus: taxStatus ?? this.taxStatus,
      taxType: taxType ?? this.taxType,
      primaryCategory: primaryCategory ?? this.primaryCategory,
      totalIncome: totalIncome ?? this.totalIncome,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      taxableIncome: taxableIncome ?? this.taxableIncome,
      calculatedTax: calculatedTax ?? this.calculatedTax,
      paidTax: paidTax ?? this.paidTax,
      refundAmount: refundAmount ?? this.refundAmount,
      currency: currency ?? this.currency,
      submissionDeadline: submissionDeadline ?? this.submissionDeadline,
      submissionDate: submissionDate ?? this.submissionDate,
      assessmentDate: assessmentDate ?? this.assessmentDate,
      description: description ?? this.description,
      taxOffice: taxOffice ?? this.taxOffice,
      taxAdvisor: taxAdvisor ?? this.taxAdvisor,
      preparationSoftware: preparationSoftware ?? this.preparationSoftware,
      attachmentPaths: attachmentPaths ?? this.attachmentPaths,
      invoiceIds: invoiceIds ?? this.invoiceIds,
      elsterData: elsterData ?? this.elsterData,
      olusturmaTarihi: olusturmaTarihi ?? this.olusturmaTarihi,
      guncellemeTarihi: guncellemeTarihi ?? this.guncellemeTarihi,
      aktif: aktif ?? this.aktif,
      ustIdNr: ustIdNr ?? this.ustIdNr,
      steuernummer: steuernummer ?? this.steuernummer,
      isFreelancer: isFreelancer ?? this.isFreelancer,
      isSmallBusiness: isSmallBusiness ?? this.isSmallBusiness,
      businessType: businessType ?? this.businessType,
      churchTaxRate: churchTaxRate ?? this.churchTaxRate,
      detailedBreakdown: detailedBreakdown ?? this.detailedBreakdown,
    );
  }

  /// Yardımcı getter'lar
  String get formatliSubmissionDeadline =>
      submissionDeadline != null 
          ? YardimciFonksiyonlar.tarihFormatla(submissionDeadline!) 
          : 'Belirtilmemiş';
  String get formatliSubmissionDate =>
      submissionDate != null 
          ? YardimciFonksiyonlar.tarihFormatla(submissionDate!) 
          : 'Teslim edilmemiş';
  String get formatliAssessmentDate =>
      assessmentDate != null 
          ? YardimciFonksiyonlar.tarihFormatla(assessmentDate!) 
          : 'Değerlendirilmemiş';
  String get formatliTotalIncome =>
      '${totalIncome.toStringAsFixed(2)} $currency';
  String get formatliTotalExpenses =>
      '${totalExpenses.toStringAsFixed(2)} $currency';
  String get formatliTaxableIncome =>
      '${taxableIncome.toStringAsFixed(2)} $currency';
  String get formatliCalculatedTax =>
      '${calculatedTax.toStringAsFixed(2)} $currency';
  String get formatliPaidTax =>
      '${paidTax.toStringAsFixed(2)} $currency';
  String get formatliRefundAmount =>
      '${refundAmount.toStringAsFixed(2)} $currency';

  /// Vergi dönemi adı
  String get periodName {
    switch (taxPeriod) {
      case TaxPeriod.MONTHLY:
        return 'Aylık ${taxMonth ?? ''} - $taxYear';
      case TaxPeriod.QUARTERLY:
        return 'Çeyrek ${taxQuarter ?? ''} - $taxYear';
      case TaxPeriod.YEARLY:
        return 'Yıllık $taxYear';
    }
  }

  /// Son teslim tarihi kontrolü
  bool get isOverdue {
    if (submissionDeadline == null || taxStatus == TaxStatus.SUBMITTED) return false;
    return DateTime.now().isAfter(submissionDeadline!) && 
           taxStatus != TaxStatus.SUBMITTED;
  }

  /// Kalan gün sayısı
  int get remainingDays {
    if (submissionDeadline == null || taxStatus == TaxStatus.SUBMITTED) return 0;
    final difference = submissionDeadline!.difference(DateTime.now()).inDays;
    return difference < 0 ? 0 : difference;
  }

  /// Vergi bakiyesi (iade/borç)
  double get taxBalance => calculatedTax - paidTax;

  /// Status color
  String get statusColor {
    switch (taxStatus) {
      case TaxStatus.DRAFT:
        return '#9E9E9E'; // Grey
      case TaxStatus.READY:
        return '#2196F3'; // Blue
      case TaxStatus.SUBMITTED:
        return '#FF9800'; // Orange
      case TaxStatus.APPROVED:
        return '#4CAF50'; // Green
      case TaxStatus.REJECTED:
        return '#F44336'; // Red
      case TaxStatus.INCOMPLETE:
        return '#FF5722'; // Deep Orange
    }
  }

  /// Model'in geçerli olup olmadığını kontrol et
  @override
  bool isValid() =>
      taxNumber.isNotEmpty && 
      taxYear > 1900 && 
      totalIncome >= 0 && 
      totalExpenses >= 0;

  /// Eşitlik kontrolü
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TaxModel && 
           other.taxNumber == taxNumber && 
           other.taxYear == taxYear &&
           other.taxPeriod == taxPeriod;
  }

  @override
  int get hashCode => Object.hash(taxNumber, taxYear, taxPeriod);

  @override
  String toString() =>
      'TaxModel{id: $id, taxNumber: $taxNumber, period: $periodName, status: $taxStatus}';
} 