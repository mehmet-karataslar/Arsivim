import 'package:flutter/material.dart';
import '../models/tax_model.dart';
import '../models/kisi_modeli.dart';
import '../services/tax_service.dart';
import '../services/veritabani_servisi.dart';

class TaxAddScreen extends StatefulWidget {
  final TaxModel? tax;
  final Function(TaxModel)? onSaved;

  const TaxAddScreen({Key? key, this.tax, this.onSaved}) : super(key: key);

  @override
  State<TaxAddScreen> createState() => _TaxAddScreenState();
}

class _TaxAddScreenState extends State<TaxAddScreen> {
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
      
      if (tax.kisiId != null) {
        _selectedPerson = _people.firstWhere(
          (p) => p.id == tax.kisiId,
          orElse: () => _people.first,
        );
      }
    }
  }

  void _setupCalculations() {
    _calculatedTaxController.addListener(_updateRemainingTax);
    _paidTaxController.addListener(_updateRemainingTax);
  }

  void _updateRemainingTax() {
    // This can be used for real-time calculation updates
    setState(() {});
  }

  double get _remainingTax {
    final calculated = double.tryParse(_calculatedTaxController.text.replaceAll(',', '.')) ?? 0.0;
    final paid = double.tryParse(_paidTaxController.text.replaceAll(',', '.')) ?? 0.0;
    return calculated - paid;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.tax == null ? 'Neue Steuererklärung' : 'Steuererklärung bearbeiten',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green[600],
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
                      _buildTaxAmountsSection(),
                      const SizedBox(height: 32),
                      _buildTaxOfficeSection(),
                      const SizedBox(height: 32),
                      _buildDatesSection(),
                      const SizedBox(height: 32),
                      _buildCategoriesSection(),
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
              Icon(Icons.account_balance_rounded, color: Colors.green[600], size: 24),
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
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _taxYear,
                  decoration: InputDecoration(
                    labelText: 'Steuerjahr *',
                    prefixIcon: const Icon(Icons.calendar_today_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  items: List.generate(10, (index) {
                    final year = DateTime.now().year - index;
                    return DropdownMenuItem(
                      value: year,
                      child: Text(year.toString()),
                    );
                  }),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _taxYear = value;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<TaxPeriod>(
                  value: _taxPeriod,
                  decoration: InputDecoration(
                    labelText: 'Zeitraum',
                    prefixIcon: const Icon(Icons.date_range_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  items: TaxPeriod.values.map((period) {
                    return DropdownMenuItem(
                      value: period,
                      child: Text(_getTaxPeriodText(period)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _taxPeriod = value;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<TaxType>(
            value: _taxType,
            decoration: InputDecoration(
              labelText: 'Steuerart',
              prefixIcon: const Icon(Icons.category_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            items: TaxType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(_getTaxTypeText(type)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _taxType = value;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<TaxStatus>(
            value: _taxStatus,
            decoration: InputDecoration(
              labelText: 'Status',
              prefixIcon: const Icon(Icons.flag_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            items: TaxStatus.values.map((status) {
              return DropdownMenuItem(
                value: status,
                child: Text(_getTaxStatusText(status)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _taxStatus = value;
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

  Widget _buildTaxAmountsSection() {
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
              Icon(Icons.euro_rounded, color: Colors.green[600], size: 24),
              const SizedBox(width: 12),
              Text(
                'Steuerbeträge',
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
            controller: _calculatedTaxController,
            decoration: InputDecoration(
              labelText: 'Berechnete Steuer *',
              prefixIcon: const Icon(Icons.calculate_rounded),
              suffixText: 'EUR',
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
              if (amount == null || amount < 0) {
                return 'Bitte geben Sie einen gültigen Betrag ein';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _paidTaxController,
            decoration: InputDecoration(
              labelText: 'Gezahlte Steuer',
              prefixIcon: const Icon(Icons.payment_rounded),
              suffixText: 'EUR',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                final amount = double.tryParse(value.replaceAll(',', '.'));
                if (amount == null || amount < 0) {
                  return 'Bitte geben Sie einen gültigen Betrag ein';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _remainingTax > 0 ? Colors.orange[50] : Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _remainingTax > 0 ? Colors.orange[200]! : Colors.green[200]!,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Verbleibendes Steuer:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                Text(
                  '${_remainingTax.toStringAsFixed(2)} EUR',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _remainingTax > 0 ? Colors.orange[700] : Colors.green[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxOfficeSection() {
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
              Icon(Icons.business_rounded, color: Colors.green[600], size: 24),
              const SizedBox(width: 12),
              Text(
                'Finanzamt',
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
            controller: _taxOfficeController,
            decoration: InputDecoration(
              labelText: 'Finanzamt',
              prefixIcon: const Icon(Icons.account_balance_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _taxNumberController,
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
            controller: _ustIdNrController,
            decoration: InputDecoration(
              labelText: 'USt-ID Nr.',
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
              Icon(Icons.date_range_rounded, color: Colors.green[600], size: 24),
              const SizedBox(width: 12),
              Text(
                'Fristen',
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
                          'Abgabefrist',
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
                              _submissionDeadline != null
                                  ? '${_submissionDeadline!.day}.${_submissionDeadline!.month}.${_submissionDeadline!.year}'
                                  : 'Auswählen',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: _submissionDeadline != null ? Colors.black : Colors.grey[500],
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
                          'Abgabedatum',
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
                              _submissionDate != null
                                  ? '${_submissionDate!.day}.${_submissionDate!.month}.${_submissionDate!.year}'
                                  : 'Auswählen',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: _submissionDate != null ? Colors.black : Colors.grey[500],
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
        ],
      ),
    );
  }

  Widget _buildCategoriesSection() {
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
              Icon(Icons.category_rounded, color: Colors.green[600], size: 24),
              const SizedBox(width: 12),
              Text(
                'Kategorien',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<TaxCategory>(
            value: _primaryCategory,
            decoration: InputDecoration(
              labelText: 'Primäre Kategorie',
              prefixIcon: const Icon(Icons.folder_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            items: TaxCategory.values.map((category) {
              return DropdownMenuItem(
                value: category,
                child: Text(_getTaxCategoryText(category)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _primaryCategory = value;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_rounded, color: Colors.blue[600]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Steuerart: ${_getTaxTypeText(_taxType)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                      Text(
                        'Status: ${_getTaxStatusText(_taxStatus)}',
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
              Icon(Icons.description_rounded, color: Colors.green[600], size: 24),
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
              onPressed: _isLoading ? null : _saveTax,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
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
                      widget.tax == null ? 'Steuer erstellen' : 'Steuer aktualisieren',
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

  Future<void> _selectDate(BuildContext context, bool isDeadline) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isDeadline 
          ? (_submissionDeadline ?? DateTime.now()) 
          : (_submissionDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green[600]!,
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
        if (isDeadline) {
          _submissionDeadline = picked;
        } else {
          _submissionDate = picked;
        }
      });
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
        taxYear: _taxYear,
        taxPeriod: _taxPeriod,
        taxType: _taxType,
        taxStatus: _taxStatus,
        calculatedTax: double.parse(_calculatedTaxController.text.replaceAll(',', '.')),
        paidTax: double.tryParse(_paidTaxController.text.replaceAll(',', '.')) ?? 0.0,
        submissionDeadline: _submissionDeadline,
        submissionDate: _submissionDate,
        taxOffice: _taxOfficeController.text.isEmpty ? null : _taxOfficeController.text,
        taxNumber: _taxNumberController.text.isEmpty ? 'TEMP-${DateTime.now().millisecondsSinceEpoch}' : _taxNumberController.text,
        ustIdNr: _ustIdNrController.text.isEmpty ? null : _ustIdNrController.text,
        primaryCategory: _primaryCategory,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        kisiId: _selectedPerson?.id,
        olusturmaTarihi: widget.tax?.olusturmaTarihi ?? DateTime.now(),
        guncellemeTarihi: DateTime.now(),
      );

      if (widget.tax == null) {
        await _taxService.createTax(tax);
      } else {
        await _taxService.updateTax(tax);
      }

      if (widget.onSaved != null) {
        widget.onSaved!(tax);
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

  String _getTaxPeriodText(TaxPeriod period) {
    switch (period) {
      case TaxPeriod.MONTHLY:
        return 'Monatlich';
      case TaxPeriod.QUARTERLY:
        return 'Vierteljährlich';
      case TaxPeriod.YEARLY:
        return 'Jährlich';
    }
  }

  String _getTaxTypeText(TaxType type) {
    switch (type) {
      case TaxType.VAT:
        return 'Umsatzsteuer';
      case TaxType.INCOME_TAX:
        return 'Einkommensteuer';
      case TaxType.TRADE_TAX:
        return 'Gewerbesteuer';
      case TaxType.SOLIDARITY_SURCHARGE:
        return 'Solidaritätszuschlag';
      case TaxType.CHURCH_TAX:
        return 'Kirchensteuer';
    }
  }

  String _getTaxStatusText(TaxStatus status) {
    switch (status) {
      case TaxStatus.DRAFT:
        return 'Entwurf';
      case TaxStatus.READY:
        return 'Bereit';
      case TaxStatus.SUBMITTED:
        return 'Eingereicht';
      case TaxStatus.APPROVED:
        return 'Genehmigt';
      case TaxStatus.REJECTED:
        return 'Abgelehnt';
      case TaxStatus.INCOMPLETE:
        return 'Unvollständig';
    }
  }

  String _getTaxCategoryText(TaxCategory category) {
    switch (category) {
      case TaxCategory.BUSINESS_INCOME:
        return 'Betriebseinnahmen';
      case TaxCategory.EMPLOYMENT_INCOME:
        return 'Lohneinkünfte';
      case TaxCategory.CAPITAL_INCOME:
        return 'Kapitalerträge';
      case TaxCategory.RENTAL_INCOME:
        return 'Mieteinnahmen';
      case TaxCategory.OTHER_INCOME:
        return 'Sonstige Einkünfte';
      case TaxCategory.BUSINESS_EXPENSE:
        return 'Betriebsausgaben';
      case TaxCategory.SPECIAL_EXPENSE:
        return 'Sonderausgaben';
      case TaxCategory.EXTRAORDINARY_EXPENSE:
        return 'Außergewöhnliche Belastungen';
      case TaxCategory.TAX_DEDUCTIBLE:
        return 'Steuerlich absetzbar';
    }
  }
} 