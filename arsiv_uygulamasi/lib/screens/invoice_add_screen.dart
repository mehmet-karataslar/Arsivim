import 'package:flutter/material.dart';
import '../models/invoice_model.dart';
import '../models/kisi_modeli.dart';
import '../services/invoice_service.dart';
import '../services/veritabani_servisi.dart';

class InvoiceAddScreen extends StatefulWidget {
  final InvoiceModel? invoice;
  final Function(InvoiceModel)? onSaved;

  const InvoiceAddScreen({Key? key, this.invoice, this.onSaved}) : super(key: key);

  @override
  State<InvoiceAddScreen> createState() => _InvoiceAddScreenState();
}

class _InvoiceAddScreenState extends State<InvoiceAddScreen> {
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

  Future<void> _loadPeople() async {
    try {
      final people = await _veriTabani.kisileriGetir();
      setState(() {
        _people = people;
      });
    } catch (e) {
      print('Error loading people: $e');
    }
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
      
      if (invoice.kisiId != null) {
        _selectedPerson = _people.firstWhere(
          (p) => p.id == invoice.kisiId,
          orElse: () => _people.first,
        );
      }
    }
  }

  void _setupCalculations() {
    _netAmountController.addListener(_calculateAmounts);
  }

  void _calculateAmounts() {
    final netAmountText = _netAmountController.text.replaceAll(',', '.');
    final netAmount = double.tryParse(netAmountText) ?? 0.0;
    
    double taxRate = 0.0;
    switch (_taxRate) {
      case TaxRate.REDUCED:
        taxRate = 0.07; // 7%
        break;
      case TaxRate.STANDARD:
        taxRate = 0.19; // 19%
        break;
      case TaxRate.ZERO:
        taxRate = 0.0; // 0%
        break;
      case TaxRate.EXEMPT:
        taxRate = 0.0; // 0%
        break;
    }
    
    setState(() {
      _taxAmount = netAmount * taxRate;
      _grossAmount = netAmount + _taxAmount;
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.invoice == null ? 'Neue Rechnung' : 'Rechnung bearbeiten',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.indigo[600],
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBasicInfoSection(),
                      const SizedBox(height: 32),
                      _buildSupplierSection(),
                      const SizedBox(height: 32),
                      _buildAmountSection(),
                      const SizedBox(height: 32),
                      _buildDatesSection(),
                      const SizedBox(height: 32),
                      _buildAdditionalInfoSection(),
                      const SizedBox(height: 32),
                      _buildDescriptionSection(),
                      const SizedBox(height: 100), // Space for bottom button
                    ],
                  ),
                ),
              ),
            ),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_rounded, color: Colors.indigo[600], size: 24),
              const SizedBox(width: 12),
              Text(
                'Grundinformationen',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _invoiceNumberController,
            decoration: InputDecoration(
              labelText: 'Rechnungsnummer *',
              prefixIcon: const Icon(Icons.numbers_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Bitte geben Sie eine Rechnungsnummer ein';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<InvoiceType>(
            value: _invoiceType,
            decoration: InputDecoration(
              labelText: 'Rechnungsart',
              prefixIcon: const Icon(Icons.category_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            items: InvoiceType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(_getInvoiceTypeText(type)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _invoiceType = value;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          if (_people.isNotEmpty)
            DropdownButtonFormField<KisiModeli>(
              value: _selectedPerson,
              decoration: InputDecoration(
                labelText: 'Person zuordnen',
                prefixIcon: const Icon(Icons.person_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              hint: const Text('Person auswählen (optional)'),
              items: _people.map((person) {
                return DropdownMenuItem(
                  value: person,
                  child: Text(
                    '${person.ad} ${person.soyad}',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPerson = value;
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSupplierSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.business_rounded, color: Colors.indigo[600], size: 24),
              const SizedBox(width: 12),
              Text(
                'Lieferant/Kunde',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _supplierNameController,
            decoration: InputDecoration(
              labelText: 'Name *',
              prefixIcon: const Icon(Icons.business_center_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Bitte geben Sie einen Namen ein';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _supplierAddressController,
            decoration: InputDecoration(
              labelText: 'Adresse',
              prefixIcon: const Icon(Icons.location_on_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _supplierTaxNumberController,
            decoration: InputDecoration(
              labelText: 'Steuernummer',
              prefixIcon: const Icon(Icons.confirmation_number_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _ustIdController,
            decoration: InputDecoration(
              labelText: 'USt-ID',
              prefixIcon: const Icon(Icons.badge_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.euro_rounded, color: Colors.indigo[600], size: 24),
              const SizedBox(width: 12),
              Text(
                'Beträge',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _netAmountController,
                  decoration: InputDecoration(
                    labelText: 'Nettobetrag *',
                    prefixIcon: const Icon(Icons.euro_rounded),
                    suffixText: _currency,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Bitte geben Sie einen Betrag ein';
                    }
                    final amount = double.tryParse(value.replaceAll(',', '.'));
                    if (amount == null || amount <= 0) {
                      return 'Bitte geben Sie einen gültigen Betrag ein';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _currency,
                  decoration: InputDecoration(
                    labelText: 'Währung',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  items: ['EUR', 'USD', 'GBP', 'CHF'].map((currency) {
                    return DropdownMenuItem(
                      value: currency,
                      child: Text(currency),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _currency = value;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<TaxRate>(
            value: _taxRate,
            decoration: InputDecoration(
              labelText: 'Steuersatz',
              prefixIcon: const Icon(Icons.percent_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            items: TaxRate.values.map((rate) {
              return DropdownMenuItem(
                value: rate,
                child: Text(_getTaxRateText(rate)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _taxRate = value;
                  _calculateAmounts();
                });
              }
            },
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.indigo[200]!),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Steuer:',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      '${_taxAmount.toStringAsFixed(2)} $_currency',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.indigo[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Bruttobetrag:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      '${_grossAmount.toStringAsFixed(2)} $_currency',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatesSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.date_range_rounded, color: Colors.indigo[600], size: 24),
              const SizedBox(width: 12),
              Text(
                'Termine',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context, true),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[50],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rechnungsdatum *',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 20, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text(
                              '${_invoiceDate.day}.${_invoiceDate.month}.${_invoiceDate.year}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context, false),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[50],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fälligkeitsdatum',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.event_rounded, size: 20, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text(
                              _dueDate != null
                                  ? '${_dueDate!.day}.${_dueDate!.month}.${_dueDate!.year}'
                                  : 'Auswählen',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: _dueDate != null ? Colors.black : Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<PaymentStatus>(
            value: _paymentStatus,
            decoration: InputDecoration(
              labelText: 'Zahlungsstatus',
              prefixIcon: const Icon(Icons.payment_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            items: PaymentStatus.values.map((status) {
              return DropdownMenuItem(
                value: status,
                child: Text(_getPaymentStatusText(status)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _paymentStatus = value;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_rounded, color: Colors.indigo[600], size: 24),
              const SizedBox(width: 12),
              Text(
                'Weitere Informationen',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.receipt_long_rounded, color: Colors.blue[600]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rechnungstyp: ${_getInvoiceTypeText(_invoiceType)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                      Text(
                        'Status: ${_getPaymentStatusText(_paymentStatus)}',
                        style: TextStyle(
                          color: Colors.blue[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_rounded, color: Colors.indigo[600], size: 24),
              const SizedBox(width: 12),
              Text(
                'Beschreibung',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: 'Notizen/Beschreibung',
              prefixIcon: const Icon(Icons.note_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: Colors.grey[400]!),
              ),
              child: Text(
                'Abbrechen',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveInvoice,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo[600],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.invoice == null ? 'Rechnung erstellen' : 'Rechnung aktualisieren',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.indigo[600]!,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
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
        invoiceNumber: _invoiceNumberController.text,
        supplierName: _supplierNameController.text,
        supplierAddress: _supplierAddressController.text.isEmpty ? null : _supplierAddressController.text,
        supplierTaxNumber: _supplierTaxNumberController.text.isEmpty ? null : _supplierTaxNumberController.text,
        ustIdNr: _ustIdController.text.isEmpty ? null : _ustIdController.text,
        invoiceDate: _invoiceDate,
        dueDate: _dueDate,
        netAmount: double.parse(_netAmountController.text.replaceAll(',', '.')),
        taxAmount: _taxAmount,
        grossAmount: _grossAmount,
        currency: _currency,
        paymentStatus: _paymentStatus,
        invoiceType: _invoiceType,
        taxRate: _taxRate,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        kisiId: _selectedPerson?.id,
        olusturmaTarihi: widget.invoice?.olusturmaTarihi ?? DateTime.now(),
        guncellemeTarihi: DateTime.now(),
      );

      if (widget.invoice == null) {
        await _invoiceService.createInvoice(invoice);
      } else {
        await _invoiceService.updateInvoice(invoice);
      }

      if (widget.onSaved != null) {
        widget.onSaved!(invoice);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getInvoiceTypeText(InvoiceType type) {
    switch (type) {
      case InvoiceType.INCOMING:
        return 'Eingangsrechnung';
      case InvoiceType.OUTGOING:
        return 'Ausgangsrechnung';
      case InvoiceType.RECEIPT:
        return 'Fiş/Makbuz';
      case InvoiceType.CREDIT_NOTE:
        return 'İade faturası';
    }
  }

  String _getTaxRateText(TaxRate rate) {
    switch (rate) {
      case TaxRate.REDUCED:
        return 'Ermäßigt (7%)';
      case TaxRate.STANDARD:
        return 'Standard (19%)';
      case TaxRate.ZERO:
        return 'Null (0%)';
      case TaxRate.EXEMPT:
        return 'Befreit';
    }
  }

  String _getPaymentStatusText(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.PENDING:
        return 'Ausstehend';
      case PaymentStatus.PAID:
        return 'Bezahlt';
      case PaymentStatus.OVERDUE:
        return 'Überfällig';
      case PaymentStatus.CANCELLED:
        return 'Storniert';
      case PaymentStatus.PARTIAL:
        return 'Teilweise bezahlt';
    }
  }
} 