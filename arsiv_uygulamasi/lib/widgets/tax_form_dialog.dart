import 'package:flutter/material.dart';
import '../models/tax_model.dart';
import '../models/kisi_modeli.dart';
import '../services/tax_service.dart';
import '../services/veritabani_servisi.dart';

class TaxFormDialog extends StatefulWidget {
  final TaxModel? tax;
  final Function(TaxModel)? onSaved;

  const TaxFormDialog({Key? key, this.tax, this.onSaved}) : super(key: key);

  @override
  State<TaxFormDialog> createState() => _TaxFormDialogState();
}

class _TaxFormDialogState extends State<TaxFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _taxService = TaxService();
  final _veriTabani = VeriTabaniServisi();
  
  bool _isLoading = false;
  List<KisiModeli> _people = [];
  KisiModeli? _selectedPerson;

  // Controllers
  final _calculatedTaxController = TextEditingController();
  final _paidTaxController = TextEditingController();
  final _taxOfficeController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _ustIdNrController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Form fields
  int _taxYear = DateTime.now().year;
  TaxPeriod _taxPeriod = TaxPeriod.MONTHLY;
  TaxStatus _taxStatus = TaxStatus.DRAFT;
  TaxType _taxType = TaxType.VAT;
  TaxCategory _primaryCategory = TaxCategory.BUSINESS_INCOME;
  DateTime? _submissionDeadline;
  DateTime? _submissionDate;
  
  @override
  void initState() {
    super.initState();
    _loadPeople();
    _initializeForm();
    _setupCalculations();
  }

  @override
  void dispose() {
    _calculatedTaxController.dispose();
    _paidTaxController.dispose();
    _taxOfficeController.dispose();
    _taxNumberController.dispose();
    _ustIdNrController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _initializeForm() {
    if (widget.tax != null) {
      final tax = widget.tax!;
      _calculatedTaxController.text = tax.calculatedTax.toString();
      _paidTaxController.text = tax.paidTax.toString();
      _taxOfficeController.text = tax.taxOffice ?? '';
      _taxNumberController.text = tax.taxNumber;
      _ustIdNrController.text = tax.ustIdNr ?? '';
      _descriptionController.text = tax.description ?? '';

      _taxYear = tax.taxYear;
      _taxPeriod = tax.taxPeriod;
      _taxStatus = tax.taxStatus;
      _taxType = tax.taxType;
      _primaryCategory = tax.primaryCategory;
      _submissionDeadline = tax.submissionDeadline;
      _submissionDate = tax.submissionDate;

      // Kişiyi seç
      _selectedPerson = _people.where((p) => p.id == tax.kisiId).firstOrNull;
    } else {
      // Yeni vergi kaydı için varsayılan değerler
      _calculatedTaxController.text = '0.0';
      _paidTaxController.text = '0.0';
      _calculateSubmissionDeadline();
    }
  }

  void _setupCalculations() {
    // Hesaplama listeners gerekirse eklenebilir
  }

  void _calculateSubmissionDeadline() {
    // Vergi türüne göre teslim son tarihini hesapla
    final now = DateTime.now();
    switch (_taxType) {
      case TaxType.VAT:
        _submissionDeadline = DateTime(now.year, now.month + 1, 10);
        break;
      case TaxType.INCOME_TAX:
        _submissionDeadline = DateTime(now.year + 1, 5, 31);
        break;
      default:
        _submissionDeadline = DateTime(now.year + 1, 5, 31);
        break;
    }
  }

  Future<void> _loadPeople() async {
    try {
      final people = await _veriTabani.kisileriGetir();
      setState(() {
        _people = people;
      });
    } catch (e) {
      _showErrorSnackBar('Kişiler yüklenirken hata oluştu: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildBasicInfoSection(),
                      const SizedBox(height: 24),
                      _buildTaxDetailsSection(),
                      const SizedBox(height: 24),
                      _buildAmountSection(),
                      const SizedBox(height: 24),
                      _buildAdditionalInfoSection(),
                    ],
                  ),
                ),
              ),
            ),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              widget.tax == null ? 'Yeni Vergi Kaydı' : 'Vergi Kaydı Düzenle',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Temel Bilgiler',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<KisiModeli>(
                value: _selectedPerson,
                decoration: const InputDecoration(
                  labelText: 'Kişi *',
                  border: OutlineInputBorder(),
                ),
                items: _people.map((person) {
                  return DropdownMenuItem(
                    value: person,
                    child: Text(
                      '${person.ad} ${person.soyad}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedPerson = value),
                validator: (value) => value == null ? 'Kişi seçimi gerekli' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                initialValue: _taxYear.toString(),
                decoration: const InputDecoration(
                  labelText: 'Vergi Yılı *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final year = int.tryParse(value);
                  if (year != null) {
                    setState(() => _taxYear = year);
                  }
                },
                validator: (value) {
                  final year = int.tryParse(value ?? '');
                  if (year == null || year < 2000 || year > DateTime.now().year + 5) {
                    return 'Geçerli bir yıl girin';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<TaxPeriod>(
                value: _taxPeriod,
                decoration: const InputDecoration(
                  labelText: 'Vergi Dönemi',
                  border: OutlineInputBorder(),
                ),
                items: TaxPeriod.values.map((period) {
                  return DropdownMenuItem(
                    value: period,
                    child: Text(
                      _getTaxPeriodText(period),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _taxPeriod = value!;
                    _calculateSubmissionDeadline();
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<TaxStatus>(
                value: _taxStatus,
                decoration: const InputDecoration(
                  labelText: 'Vergi Durumu',
                  border: OutlineInputBorder(),
                ),
                items: TaxStatus.values.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(
                      _getTaxStatusText(status),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _taxStatus = value!),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTaxDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vergi Detayları',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<TaxType>(
                value: _taxType,
                decoration: const InputDecoration(
                  labelText: 'Vergi Türü',
                  border: OutlineInputBorder(),
                ),
                items: TaxType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(
                      _getTaxTypeText(type),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _taxType = value!;
                    _calculateSubmissionDeadline();
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<TaxCategory>(
                value: _primaryCategory,
                decoration: const InputDecoration(
                  labelText: 'Vergi Kategorisi',
                  border: OutlineInputBorder(),
                ),
                items: TaxCategory.values.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(
                      _getTaxCategoryText(category),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _primaryCategory = value!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _taxNumberController,
                decoration: const InputDecoration(
                  labelText: 'Vergi Numarası *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty == true ? 'Vergi numarası gerekli' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _ustIdNrController,
                decoration: const InputDecoration(
                  labelText: 'USt-IdNr.',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _selectDate(context, true),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Teslim Son Tarihi',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(_submissionDeadline != null ? _formatDate(_submissionDeadline!) : 'Hesaplanıyor...'),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: InkWell(
                onTap: () => _selectDate(context, false),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Teslim Tarihi',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(_submissionDate != null ? _formatDate(_submissionDate!) : 'Seç'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAmountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tutar Bilgileri',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _calculatedTaxController,
                decoration: const InputDecoration(
                  labelText: 'Hesaplanan Vergi *',
                  border: OutlineInputBorder(),
                  suffixText: 'EUR',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty == true) return 'Hesaplanan vergi gerekli';
                  if (double.tryParse(value!) == null) return 'Geçerli bir sayı girin';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _paidTaxController,
                decoration: const InputDecoration(
                  labelText: 'Ödenen Vergi',
                  border: OutlineInputBorder(),
                  suffixText: 'EUR',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isNotEmpty == true && double.tryParse(value!) == null) {
                    return 'Geçerli bir sayı girin';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Kalan Tutar',
            border: OutlineInputBorder(),
          ),
          child: Text(
            '${_calculateRemainingAmount().toStringAsFixed(2)} EUR',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _calculateRemainingAmount() > 0 ? Colors.red : Colors.green,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdditionalInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ek Bilgiler',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _taxOfficeController,
          decoration: const InputDecoration(
            labelText: 'Finanzamt',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Açıklama',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveTax,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Kaydet'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isSubmissionDeadline) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isSubmissionDeadline ? (_submissionDeadline ?? DateTime.now()) : (_submissionDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isSubmissionDeadline) {
          _submissionDeadline = picked;
        } else {
          _submissionDate = picked;
        }
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  double _calculateRemainingAmount() {
    final calculated = double.tryParse(_calculatedTaxController.text) ?? 0.0;
    final paid = double.tryParse(_paidTaxController.text) ?? 0.0;
    return calculated - paid;
  }

  String _getTaxPeriodText(TaxPeriod period) {
    switch (period) {
      case TaxPeriod.MONTHLY:
        return 'Aylık';
      case TaxPeriod.QUARTERLY:
        return 'Çeyreklik';
      case TaxPeriod.YEARLY:
        return 'Yıllık';
    }
  }

  String _getTaxStatusText(TaxStatus status) {
    switch (status) {
      case TaxStatus.DRAFT:
        return 'Taslak';
      case TaxStatus.READY:
        return 'Hazır';
      case TaxStatus.SUBMITTED:
        return 'Teslim Edilmiş';
      case TaxStatus.APPROVED:
        return 'Onaylanmış';
      case TaxStatus.REJECTED:
        return 'Reddedilmiş';
      case TaxStatus.INCOMPLETE:
        return 'Eksik';
    }
  }

  String _getTaxTypeText(TaxType type) {
    switch (type) {
      case TaxType.INCOME_TAX:
        return 'Gelir Vergisi';
      case TaxType.VAT:
        return 'KDV (Umsatzsteuer)';
      case TaxType.TRADE_TAX:
        return 'Ticaret Vergisi';
      case TaxType.SOLIDARITY_SURCHARGE:
        return 'Dayanışma Katkısı';
      case TaxType.CHURCH_TAX:
        return 'Kilise Vergisi';
    }
  }

  String _getTaxCategoryText(TaxCategory category) {
    switch (category) {
      case TaxCategory.BUSINESS_INCOME:
        return 'İş Geliri';
      case TaxCategory.EMPLOYMENT_INCOME:
        return 'Maaş Geliri';
      case TaxCategory.CAPITAL_INCOME:
        return 'Sermaye Geliri';
      case TaxCategory.RENTAL_INCOME:
        return 'Kira Geliri';
      case TaxCategory.OTHER_INCOME:
        return 'Diğer Gelirler';
      case TaxCategory.BUSINESS_EXPENSE:
        return 'İş Giderleri';
      case TaxCategory.SPECIAL_EXPENSE:
        return 'Özel Giderler';
      case TaxCategory.EXTRAORDINARY_EXPENSE:
        return 'Olağanüstü Giderler';
      case TaxCategory.TAX_DEDUCTIBLE:
        return 'Vergiden Düşülebilir';
    }
  }

  Future<void> _saveTax() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final tax = TaxModel(
        id: widget.tax?.id,
        kisiId: _selectedPerson!.id!,
        taxNumber: _taxNumberController.text.trim(),
        taxYear: _taxYear,
        taxPeriod: _taxPeriod,
        taxStatus: _taxStatus,
        taxType: _taxType,
        primaryCategory: _primaryCategory,
        calculatedTax: double.parse(_calculatedTaxController.text),
        paidTax: double.parse(_paidTaxController.text),
        submissionDeadline: _submissionDeadline,
        submissionDate: _submissionDate,
        taxOffice: _taxOfficeController.text.trim().isEmpty ? null : _taxOfficeController.text.trim(),
        ustIdNr: _ustIdNrController.text.trim().isEmpty ? null : _ustIdNrController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        olusturmaTarihi: widget.tax?.olusturmaTarihi ?? DateTime.now(),
        guncellemeTarihi: DateTime.now(),
      );

      if (widget.tax == null) {
        await _taxService.createTax(tax);
        _showSuccessSnackBar('Vergi kaydı başarıyla oluşturuldu');
      } else {
        await _taxService.updateTax(tax);
        _showSuccessSnackBar('Vergi kaydı başarıyla güncellendi');
      }

      if (widget.onSaved != null) {
        widget.onSaved!(tax);
      }

      Navigator.of(context).pop(true);
    } catch (e) {
      _showErrorSnackBar('Hata: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
} 