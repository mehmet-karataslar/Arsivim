import 'package:flutter/material.dart';
import '../models/invoice_model.dart';
import '../models/kisi_modeli.dart';
import '../services/invoice_service.dart';
import '../services/veritabani_servisi.dart';

class InvoiceFormDialog extends StatefulWidget {
  final InvoiceModel? invoice;
  final Function(InvoiceModel)? onSaved;

  const InvoiceFormDialog({Key? key, this.invoice, this.onSaved}) : super(key: key);

  @override
  State<InvoiceFormDialog> createState() => _InvoiceFormDialogState();
}

class _InvoiceFormDialogState extends State<InvoiceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceService = InvoiceService();
  final _veriTabani = VeriTabaniServisi();
  
  bool _isLoading = false;
  List<KisiModeli> _people = [];
  KisiModeli? _selectedPerson;

  // Controllers
  final _invoiceNumberController = TextEditingController();
  final _supplierNameController = TextEditingController();
  final _supplierAddressController = TextEditingController();
  final _supplierTaxNumberController = TextEditingController();
  final _ustIdController = TextEditingController();
  final _netAmountController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Form fields
  DateTime _invoiceDate = DateTime.now();
  DateTime? _dueDate;
  PaymentStatus _paymentStatus = PaymentStatus.PENDING;
  InvoiceType _invoiceType = InvoiceType.INCOMING;
  TaxRate _taxRate = TaxRate.STANDARD;
  String _currency = 'EUR';
  double _taxAmount = 0.0;
  double _grossAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _loadPeople();
    _initializeForm();
    _setupCalculations();
  }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _supplierNameController.dispose();
    _supplierAddressController.dispose();
    _supplierTaxNumberController.dispose();
    _ustIdController.dispose();
    _netAmountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _initializeForm() {
    if (widget.invoice != null) {
      final invoice = widget.invoice!;
      _invoiceNumberController.text = invoice.invoiceNumber;
      _supplierNameController.text = invoice.supplierName ?? '';
      _supplierAddressController.text = invoice.supplierAddress ?? '';
      _supplierTaxNumberController.text = invoice.supplierTaxNumber ?? '';
      _ustIdController.text = invoice.ustIdNr ?? '';
      _netAmountController.text = invoice.netAmount.toString();
      _descriptionController.text = invoice.description ?? '';

      _invoiceDate = invoice.invoiceDate;
      _dueDate = invoice.dueDate;
      _paymentStatus = invoice.paymentStatus;
      _invoiceType = invoice.invoiceType;
      _taxRate = invoice.taxRate;
      _currency = invoice.currency;
      _taxAmount = invoice.taxAmount;
      _grossAmount = invoice.grossAmount;

      // Kişiyi seç
      _selectedPerson = _people.where((p) => p.id == invoice.kisiId).firstOrNull;
    } else {
      // Yeni fatura için otomatik numara oluştur
      _generateInvoiceNumber();
      _dueDate = DateTime.now().add(const Duration(days: 30)); // 30 gün vade
    }
  }

  void _setupCalculations() {
    _netAmountController.addListener(_calculateTaxAmounts);
  }

  void _calculateTaxAmounts() {
    final netAmount = double.tryParse(_netAmountController.text) ?? 0.0;
    
    final calculations = _invoiceService.calculateFromNet(netAmount, _taxRate);

    setState(() {
      _taxAmount = calculations['tax']!;
      _grossAmount = calculations['gross']!;
    });
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

  Future<void> _generateInvoiceNumber() async {
    try {
      final number = await _invoiceService.generateInvoiceNumber();
      setState(() {
        _invoiceNumberController.text = number;
      });
    } catch (e) {
      _showErrorSnackBar('Fatura numarası oluşturulurken hata oluştu: $e');
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
                      _buildSupplierSection(),
                      const SizedBox(height: 24),
                      _buildAmountSection(),
                      const SizedBox(height: 24),
                      _buildPaymentSection(),
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
          Icon(Icons.receipt_long, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              widget.invoice == null ? 'Yeni Fatura' : 'Fatura Düzenle',
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
              flex: 2,
              child: TextFormField(
                controller: _invoiceNumberController,
                decoration: const InputDecoration(
                  labelText: 'Fatura Numarası *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty == true ? 'Fatura numarası gerekli' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<InvoiceType>(
                value: _invoiceType,
                decoration: const InputDecoration(
                  labelText: 'Fatura Türü',
                  border: OutlineInputBorder(),
                ),
                items: InvoiceType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(
                      _getInvoiceTypeText(type),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _invoiceType = value!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
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
              child: DropdownButtonFormField<PaymentStatus>(
                value: _paymentStatus,
                decoration: const InputDecoration(
                  labelText: 'Ödeme Durumu',
                  border: OutlineInputBorder(),
                ),
                items: PaymentStatus.values.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(
                      _getPaymentStatusText(status),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _paymentStatus = value!),
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
                    labelText: 'Fatura Tarihi *',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(_formatDate(_invoiceDate)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: InkWell(
                onTap: () => _selectDate(context, false),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Vade Tarihi',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(_dueDate != null ? _formatDate(_dueDate!) : 'Seç'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSupplierSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tedarikçi/Müşteri Bilgileri',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _supplierNameController,
          decoration: const InputDecoration(
            labelText: 'Tedarikçi/Müşteri Adı',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _supplierAddressController,
          decoration: const InputDecoration(
            labelText: 'Adres',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _supplierTaxNumberController,
                decoration: const InputDecoration(
                  labelText: 'Vergi Numarası',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _ustIdController,
                decoration: const InputDecoration(
                  labelText: 'USt-IdNr.',
                  border: OutlineInputBorder(),
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
              flex: 2,
              child: TextFormField(
                controller: _netAmountController,
                decoration: InputDecoration(
                  labelText: 'Net Tutar *',
                  border: OutlineInputBorder(),
                  suffixText: _currency,
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty == true) return 'Net tutar gerekli';
                  if (double.tryParse(value!) == null) return 'Geçerli bir sayı girin';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<TaxRate>(
                value: _taxRate,
                decoration: const InputDecoration(
                  labelText: 'Vergi Oranı',
                  border: OutlineInputBorder(),
                ),
                items: TaxRate.values.map((rate) {
                  return DropdownMenuItem(
                    value: rate,
                    child: Text(
                      _getTaxRateText(rate),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _taxRate = value!;
                    _calculateTaxAmounts();
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Vergi Tutarı',
                  border: OutlineInputBorder(),
                ),
                child: Text('${_taxAmount.toStringAsFixed(2)} $_currency'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Toplam Tutar',
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  '${_grossAmount.toStringAsFixed(2)} $_currency',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ek Bilgiler',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
              onPressed: _isLoading ? null : _saveInvoice,
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

  Future<void> _selectDate(BuildContext context, bool isInvoiceDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isInvoiceDate ? _invoiceDate : (_dueDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isInvoiceDate) {
          _invoiceDate = picked;
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
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

  String _getPaymentStatusText(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.PENDING:
        return 'Beklemede';
      case PaymentStatus.PAID:
        return 'Ödenmiş';
      case PaymentStatus.OVERDUE:
        return 'Gecikmiş';
      case PaymentStatus.CANCELLED:
        return 'İptal';
      case PaymentStatus.PARTIAL:
        return 'Kısmi';
    }
  }

  String _getTaxRateText(TaxRate rate) {
    switch (rate) {
      case TaxRate.STANDARD:
        return '19% (Standard)';
      case TaxRate.REDUCED:
        return '7% (İndirimli)';
      case TaxRate.ZERO:
        return '0% (Sıfır)';
      case TaxRate.EXEMPT:
        return 'Muaf';
    }
  }

  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final invoice = InvoiceModel(
        id: widget.invoice?.id,
        kisiId: _selectedPerson!.id!,
        invoiceNumber: _invoiceNumberController.text.trim(),
        invoiceDate: _invoiceDate,
        dueDate: _dueDate,
        paymentStatus: _paymentStatus,
        invoiceType: _invoiceType,
        supplierName: _supplierNameController.text.trim().isEmpty ? null : _supplierNameController.text.trim(),
        supplierAddress: _supplierAddressController.text.trim().isEmpty ? null : _supplierAddressController.text.trim(),
        supplierTaxNumber: _supplierTaxNumberController.text.trim().isEmpty ? null : _supplierTaxNumberController.text.trim(),
        ustIdNr: _ustIdController.text.trim().isEmpty ? null : _ustIdController.text.trim(),
        currency: _currency,
        netAmount: double.parse(_netAmountController.text),
        taxAmount: _taxAmount,
        taxRate: _taxRate,
        grossAmount: _grossAmount,
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        olusturmaTarihi: widget.invoice?.olusturmaTarihi ?? DateTime.now(),
        guncellemeTarihi: DateTime.now(),
      );

      if (widget.invoice == null) {
        await _invoiceService.createInvoice(invoice);
        _showSuccessSnackBar('Fatura başarıyla oluşturuldu');
      } else {
        await _invoiceService.updateInvoice(invoice);
        _showSuccessSnackBar('Fatura başarıyla güncellendi');
      }

      if (widget.onSaved != null) {
        widget.onSaved!(invoice);
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