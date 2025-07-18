import 'base_model.dart';
import '../utils/yardimci_fonksiyonlar.dart';

/// Fatura ödeme durumu enum'u
enum PaymentStatus {
  PENDING,    // Beklemede
  PAID,       // Ödenmiş
  OVERDUE,    // Gecikmiş
  CANCELLED,  // İptal edilmiş
  PARTIAL,    // Kısmi ödenmiş
}

/// Fatura türü enum'u - Alman vergi sistemi için
enum InvoiceType {
  INCOMING,   // Gelen fatura (expense)
  OUTGOING,   // Giden fatura (income)
  RECEIPT,    // Fiş/Makbuz
  CREDIT_NOTE, // İade faturası
}

/// Vergi oranı enum'u - Almanya için
enum TaxRate {
  STANDARD,   // 19% (Regelsteuersatz)
  REDUCED,    // 7% (ermäßigter Steuersatz)
  ZERO,       // 0% (steuerbefreit)
  EXEMPT,     // Vergiden muaf
}

/// Fatura modeli - Alman vergi yasalarına uygun
class InvoiceModel extends BaseModel {
  int? id;
  String invoiceNumber;          // Fatura numarası
  int? kisiId;                   // Faturanın ait olduğu kişi ID'si
  String? supplierName;          // Tedarikçi/Müşteri adı
  String? supplierTaxNumber;     // Tedarikçi vergi numarası
  String? supplierAddress;       // Tedarikçi adresi
  
  DateTime invoiceDate;          // Fatura tarihi
  DateTime? dueDate;             // Vade tarihi
  DateTime? paymentDate;         // Ödeme tarihi
  
  InvoiceType invoiceType;       // Fatura türü
  PaymentStatus paymentStatus;   // Ödeme durumu
  TaxRate taxRate;              // Vergi oranı
  
  double netAmount;             // Net tutar
  double taxAmount;             // Vergi tutarı
  double grossAmount;           // Brüt tutar (toplam)
  String currency;              // Para birimi (EUR, USD, etc.)
  
  String? description;          // Açıklama/Notlar
  String? category;             // Kategori (Business expense, etc.)
  String? projectName;          // Proje adı (opsiyonel)
  
  List<String>? attachmentPaths; // Ek dosya yolları
  String? qrCode;               // QR kod (German tax requirements)
  
  DateTime olusturmaTarihi;
  DateTime guncellemeTarihi;
  bool aktif;
  
  // German-specific fields
  String? ustIdNr;              // USt-IdNr. (EU VAT number)
  String? taxOffice;            // Finanzamt
  bool isDeductible;            // Gider indirilebilir mi?
  String? businessPurpose;      // İş amacı
  
  InvoiceModel({
    this.id,
    required this.invoiceNumber,
    this.kisiId,
    this.supplierName,
    this.supplierTaxNumber,
    this.supplierAddress,
    required this.invoiceDate,
    this.dueDate,
    this.paymentDate,
    this.invoiceType = InvoiceType.INCOMING,
    this.paymentStatus = PaymentStatus.PENDING,
    this.taxRate = TaxRate.STANDARD,
    required this.netAmount,
    required this.taxAmount,
    required this.grossAmount,
    this.currency = 'EUR',
    this.description,
    this.category,
    this.projectName,
    this.attachmentPaths,
    this.qrCode,
    required this.olusturmaTarihi,
    required this.guncellemeTarihi,
    this.aktif = true,
    this.ustIdNr,
    this.taxOffice,
    this.isDeductible = true,
    this.businessPurpose,
  });

  /// Map'ten model oluştur
  factory InvoiceModel.fromMap(Map<String, dynamic> map) {
    return InvoiceModel(
      id: map['id'],
      invoiceNumber: map['invoice_number'],
      kisiId: map['kisi_id'],
      supplierName: map['supplier_name'],
      supplierTaxNumber: map['supplier_tax_number'],
      supplierAddress: map['supplier_address'],
      invoiceDate: DateTime.parse(map['invoice_date']),
      dueDate: map['due_date'] != null ? DateTime.parse(map['due_date']) : null,
      paymentDate: map['payment_date'] != null ? DateTime.parse(map['payment_date']) : null,
      invoiceType: InvoiceType.values[map['invoice_type'] ?? 0],
      paymentStatus: PaymentStatus.values[map['payment_status'] ?? 0],
      taxRate: TaxRate.values[map['tax_rate'] ?? 0],
      netAmount: (map['net_amount'] as num).toDouble(),
      taxAmount: (map['tax_amount'] as num).toDouble(),
      grossAmount: (map['gross_amount'] as num).toDouble(),
      currency: map['currency'] ?? 'EUR',
      description: map['description'],
      category: map['category'],
      projectName: map['project_name'],
      attachmentPaths: map['attachment_paths']?.split(',').cast<String>(),
      qrCode: map['qr_code'],
      olusturmaTarihi: DateTime.parse(map['olusturma_tarihi']),
      guncellemeTarihi: DateTime.parse(map['guncelleme_tarihi']),
      aktif: map['aktif'] == 1,
      ustIdNr: map['ust_id_nr'],
      taxOffice: map['tax_office'],
      isDeductible: map['is_deductible'] == 1,
      businessPurpose: map['business_purpose'],
    );
  }

  /// JSON'dan model oluştur
  factory InvoiceModel.fromJson(Map<String, dynamic> json) =>
      InvoiceModel.fromMap(json);

  /// Model'i Map'e dönüştür
  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'kisi_id': kisiId,
      'supplier_name': supplierName,
      'supplier_tax_number': supplierTaxNumber,
      'supplier_address': supplierAddress,
      'invoice_date': invoiceDate.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'payment_date': paymentDate?.toIso8601String(),
      'invoice_type': invoiceType.index,
      'payment_status': paymentStatus.index,
      'tax_rate': taxRate.index,
      'net_amount': netAmount,
      'tax_amount': taxAmount,
      'gross_amount': grossAmount,
      'currency': currency,
      'description': description,
      'category': category,
      'project_name': projectName,
      'attachment_paths': attachmentPaths?.join(','),
      'qr_code': qrCode,
      'olusturma_tarihi': olusturmaTarihi.toIso8601String(),
      'guncelleme_tarihi': guncellemeTarihi.toIso8601String(),
      'aktif': aktif ? 1 : 0,
      'ust_id_nr': ustIdNr,
      'tax_office': taxOffice,
      'is_deductible': isDeductible ? 1 : 0,
      'business_purpose': businessPurpose,
    };
  }

  /// Model'i kopyala
  InvoiceModel copyWith({
    int? id,
    String? invoiceNumber,
    int? kisiId,
    String? supplierName,
    String? supplierTaxNumber,
    String? supplierAddress,
    DateTime? invoiceDate,
    DateTime? dueDate,
    DateTime? paymentDate,
    InvoiceType? invoiceType,
    PaymentStatus? paymentStatus,
    TaxRate? taxRate,
    double? netAmount,
    double? taxAmount,
    double? grossAmount,
    String? currency,
    String? description,
    String? category,
    String? projectName,
    List<String>? attachmentPaths,
    String? qrCode,
    DateTime? olusturmaTarihi,
    DateTime? guncellemeTarihi,
    bool? aktif,
    String? ustIdNr,
    String? taxOffice,
    bool? isDeductible,
    String? businessPurpose,
  }) {
    return InvoiceModel(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      kisiId: kisiId ?? this.kisiId,
      supplierName: supplierName ?? this.supplierName,
      supplierTaxNumber: supplierTaxNumber ?? this.supplierTaxNumber,
      supplierAddress: supplierAddress ?? this.supplierAddress,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      dueDate: dueDate ?? this.dueDate,
      paymentDate: paymentDate ?? this.paymentDate,
      invoiceType: invoiceType ?? this.invoiceType,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      taxRate: taxRate ?? this.taxRate,
      netAmount: netAmount ?? this.netAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      grossAmount: grossAmount ?? this.grossAmount,
      currency: currency ?? this.currency,
      description: description ?? this.description,
      category: category ?? this.category,
      projectName: projectName ?? this.projectName,
      attachmentPaths: attachmentPaths ?? this.attachmentPaths,
      qrCode: qrCode ?? this.qrCode,
      olusturmaTarihi: olusturmaTarihi ?? this.olusturmaTarihi,
      guncellemeTarihi: guncellemeTarihi ?? this.guncellemeTarihi,
      aktif: aktif ?? this.aktif,
      ustIdNr: ustIdNr ?? this.ustIdNr,
      taxOffice: taxOffice ?? this.taxOffice,
      isDeductible: isDeductible ?? this.isDeductible,
      businessPurpose: businessPurpose ?? this.businessPurpose,
    );
  }

  /// Yardımcı getter'lar
  String get formatliInvoiceDate =>
      YardimciFonksiyonlar.tarihFormatla(invoiceDate);
  String get formatliDueDate =>
      dueDate != null ? YardimciFonksiyonlar.tarihFormatla(dueDate!) : 'Belirtilmemiş';
  String get formatliPaymentDate =>
      paymentDate != null ? YardimciFonksiyonlar.tarihFormatla(paymentDate!) : 'Ödenmemiş';
  String get formatliGrossAmount =>
      '${grossAmount.toStringAsFixed(2)} $currency';
  String get formatliNetAmount =>
      '${netAmount.toStringAsFixed(2)} $currency';
  String get formatliTaxAmount =>
      '${taxAmount.toStringAsFixed(2)} $currency';
  
  /// Vergi yüzdesi hesapla
  double get taxPercentage {
    switch (taxRate) {
      case TaxRate.STANDARD:
        return 19.0;
      case TaxRate.REDUCED:
        return 7.0;
      case TaxRate.ZERO:
      case TaxRate.EXEMPT:
        return 0.0;
    }
  }
  
  /// Vade durumu kontrolü
  bool get isOverdue {
    if (dueDate == null || paymentStatus == PaymentStatus.PAID) return false;
    return DateTime.now().isAfter(dueDate!) && paymentStatus != PaymentStatus.PAID;
  }
  
  /// Kalan gün sayısı
  int get remainingDays {
    if (dueDate == null || paymentStatus == PaymentStatus.PAID) return 0;
    final difference = dueDate!.difference(DateTime.now()).inDays;
    return difference < 0 ? 0 : difference;
  }

  /// Status color
  String get statusColor {
    switch (paymentStatus) {
      case PaymentStatus.PAID:
        return '#4CAF50'; // Green
      case PaymentStatus.PENDING:
        return '#FF9800'; // Orange
      case PaymentStatus.OVERDUE:
        return '#F44336'; // Red
      case PaymentStatus.CANCELLED:
        return '#9E9E9E'; // Grey
      case PaymentStatus.PARTIAL:
        return '#2196F3'; // Blue
    }
  }

  /// Model'in geçerli olup olmadığını kontrol et
  @override
  bool isValid() =>
      invoiceNumber.isNotEmpty && 
      netAmount >= 0 && 
      taxAmount >= 0 && 
      grossAmount >= 0;

  /// Eşitlik kontrolü
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InvoiceModel && other.invoiceNumber == invoiceNumber;
  }

  @override
  int get hashCode => invoiceNumber.hashCode;

  @override
  String toString() =>
      'InvoiceModel{id: $id, invoiceNumber: $invoiceNumber, grossAmount: $formatliGrossAmount}';
} 