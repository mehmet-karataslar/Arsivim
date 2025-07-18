import '../models/activity_model.dart';
import '../models/reminder_model.dart';
import 'veritabani_servisi.dart';
import 'notification_service.dart';

/// Service to manage calendar activities, reminders, and automatic pattern recognition
class CalendarActivityService {
  static final CalendarActivityService _instance = CalendarActivityService._internal();
  factory CalendarActivityService() => _instance;
  CalendarActivityService._internal();

  final VeriTabaniServisi _veritabani = VeriTabaniServisi();
  final NotificationService _notificationService = NotificationService.instance;

  /// Track a new activity in the calendar
  Future<int> trackActivity({
    required ActivityType type,
    required String title,
    required String description,
    required DateTime activityDate,
    String? relatedItemId,
    String? relatedItemType,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final activity = ActivityModel(
        type: type,
        title: title,
        description: description,
        activityDate: activityDate,
        relatedItemId: relatedItemId,
        relatedItemType: relatedItemType,
        metadata: metadata,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      return await _veritabani.activityEkle(activity.toMap());
    } catch (e) {
      throw Exception('Activity tracking hatası: $e');
    }
  }

  /// Get activities for a specific date
  Future<List<ActivityModel>> getActivitiesForDate(DateTime date) async {
    try {
      final activities = await _veritabani.activitiesGetirByDate(date);
      return activities.map((data) => ActivityModel.fromMap(data)).toList();
    } catch (e) {
      throw Exception('Tarih için aktivite alma hatası: $e');
    }
  }

  /// Get activities for a date range
  Future<List<ActivityModel>> getActivitiesForDateRange(DateTime startDate, DateTime endDate) async {
    try {
      final activities = await _veritabani.activitiesGetirByDateRange(startDate, endDate);
      return activities.map((data) => ActivityModel.fromMap(data)).toList();
    } catch (e) {
      throw Exception('Tarih aralığı için aktivite alma hatası: $e');
    }
  }

  /// Get all activities grouped by date
  Future<Map<DateTime, List<ActivityModel>>> getActivitiesGroupedByDate({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final activities = await getActivitiesForDateRange(
        startDate ?? DateTime.now().subtract(const Duration(days: 30)),
        endDate ?? DateTime.now().add(const Duration(days: 365)),
      );

      final Map<DateTime, List<ActivityModel>> grouped = {};
      
      for (final activity in activities) {
        final date = DateTime(
          activity.activityDate.year,
          activity.activityDate.month,
          activity.activityDate.day,
        );
        
        if (grouped[date] == null) {
          grouped[date] = [];
        }
        grouped[date]!.add(activity);
      }

      return grouped;
    } catch (e) {
      throw Exception('Gruplu aktivite alma hatası: $e');
    }
  }

  /// Create a reminder
  Future<int> createReminder(ReminderModel reminder) async {
    try {
      final reminderData = reminder.toMap();
      final id = await _veritabani.reminderEkle(reminderData);

      // Schedule notification for this reminder
      final reminderWithId = reminder.copyWith(id: id);
      await _notificationService.scheduleReminder(reminderWithId);
      
      print('✅ Reminder created and notification scheduled: ${reminder.title}');

      // If recurring, calculate next occurrence
      if (reminder.recurrenceType != RecurrenceType.NONE) {
        final nextOccurrence = reminder.calculateNextOccurrence();
        if (nextOccurrence != null) {
          await _veritabani.reminderGuncelle(id, {
            'next_occurrence': nextOccurrence.toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      }

      return id;
    } catch (e) {
      throw Exception('Hatırlatıcı oluşturma hatası: $e');
    }
  }

  /// Get reminders for a specific date
  Future<List<ReminderModel>> getRemindersForDate(DateTime date) async {
    try {
      final reminders = await _veritabani.remindersGetirByDate(date);
      return reminders.map((data) => ReminderModel.fromMap(data)).toList();
    } catch (e) {
      throw Exception('Tarih için hatırlatıcı alma hatası: $e');
    }
  }

  /// Get all active reminders
  Future<List<ReminderModel>> getActiveReminders() async {
    try {
      final reminders = await _veritabani.remindersGetirActive();
      return reminders.map((data) => ReminderModel.fromMap(data)).toList();
    } catch (e) {
      throw Exception('Aktif hatırlatıcı alma hatası: $e');
    }
  }

  /// Get overdue reminders
  Future<List<ReminderModel>> getOverdueReminders() async {
    try {
      final today = DateTime.now();
      final reminders = await getActiveReminders();
      
      return reminders.where((reminder) => reminder.isOverdue).toList();
    } catch (e) {
      throw Exception('Vadesi geçen hatırlatıcı alma hatası: $e');
    }
  }

  /// Get today's reminders
  Future<List<ReminderModel>> getTodaysReminders() async {
    try {
      final today = DateTime.now();
      return await getRemindersForDate(today);
    } catch (e) {
      throw Exception('Bugünün hatırlatıcı alma hatası: $e');
    }
  }

  /// Auto-generate recurring reminders based on invoice patterns
  Future<void> generateInvoiceReminders() async {
    try {
      // Get all invoices to analyze patterns
      final invoices = await _veritabani.invoicesGetir();
      final Map<String, List<Map<String, dynamic>>> invoicesByPattern = {};
      
      // Group invoices by potential patterns (supplier + amount similarity)
      for (final invoice in invoices) {
        final supplierName = invoice['supplier_name'] as String? ?? '';
        final netAmount = invoice['net_amount'] as double? ?? 0.0;
        
        // Create a pattern key based on supplier and rounded amount
        final amountRange = (netAmount / 50).round() * 50; // Group by 50 euro ranges
        final patternKey = '${supplierName.toLowerCase()}_$amountRange';
        
        if (invoicesByPattern[patternKey] == null) {
          invoicesByPattern[patternKey] = [];
        }
        invoicesByPattern[patternKey]!.add(invoice);
      }

      // Analyze patterns and create reminders
      for (final pattern in invoicesByPattern.entries) {
        if (pattern.value.isNotEmpty && pattern.value.length >= 2) { // Need at least 2 occurrences
          await _analyzeAndCreateRecurringReminder(pattern.value, 'invoice');
        }
      }
    } catch (e) {
      throw Exception('Fatura hatırlatıcı oluşturma hatası: $e');
    }
  }

  /// Auto-generate recurring reminders based on tax patterns
  Future<void> generateTaxReminders() async {
    try {
      // Get all tax records
      final taxes = await _veritabani.taxesGetir();
      
      // Group by tax type and period
      final Map<String, List<Map<String, dynamic>>> taxesByPattern = {};
      
      for (final tax in taxes) {
        final taxType = tax['tax_type'] as String? ?? '';
        final taxPeriod = tax['tax_period'] as String? ?? '';
        final patternKey = '${taxType}_$taxPeriod';
        
        if (taxesByPattern[patternKey] == null) {
          taxesByPattern[patternKey] = [];
        }
        taxesByPattern[patternKey]!.add(tax);
      }

      // Create reminders for recurring tax obligations
      for (final pattern in taxesByPattern.entries) {
        if (pattern.value.isNotEmpty) { // Even single tax records can create reminders
          await _analyzeAndCreateRecurringReminder(pattern.value, 'tax');
        }
      }
    } catch (e) {
      throw Exception('Vergi hatırlatıcı oluşturma hatası: $e');
    }
  }

  /// Analyze pattern and create recurring reminder
  Future<void> _analyzeAndCreateRecurringReminder(
    List<Map<String, dynamic>> items,
    String itemType,
  ) async {
    try {
      if (items.isEmpty) return;

      final firstItem = items.first;
      final lastItem = items.last;

      String title = '';
      String description = '';
      RecurrenceType recurrenceType = RecurrenceType.MONTHLY;
      DateTime reminderDate = DateTime.now();

      if (itemType == 'invoice') {
        final supplierName = firstItem['supplier_name'] as String? ?? 'Bilinmeyen Tedarikçi';
        final amount = firstItem['net_amount'] as double? ?? 0.0;
        
        title = '$supplierName Fatura Hatırlatıcısı';
        description = 'Düzenli fatura ödemesi: €${amount.toStringAsFixed(2)}';
        
        // Try to determine recurrence pattern from invoice dates
        if (items.length >= 2) {
          final dates = items.map((item) => DateTime.parse(item['invoice_date'] as String)).toList();
          dates.sort();
          
          if (dates.length >= 2) {
            final daysBetween = dates[1].difference(dates[0]).inDays;
            
            if (daysBetween <= 7) {
              recurrenceType = RecurrenceType.WEEKLY;
            } else if (daysBetween <= 35) {
              recurrenceType = RecurrenceType.MONTHLY;
            } else if (daysBetween <= 100) {
              recurrenceType = RecurrenceType.QUARTERLY;
            } else {
              recurrenceType = RecurrenceType.YEARLY;
            }
          }
        }
        
        // Set reminder date based on last invoice + pattern
        final lastInvoiceDate = DateTime.parse(lastItem['invoice_date'] as String);
        reminderDate = _calculateNextReminderDate(lastInvoiceDate, recurrenceType);
        
      } else if (itemType == 'tax') {
        final taxType = firstItem['tax_type'] as String? ?? 'Bilinmeyen Vergi';
        final taxPeriod = firstItem['tax_period'] as String? ?? '';
        
        title = '$taxType Vergi Hatırlatıcısı';
        description = 'Vergi teslim tarihi yaklaşıyor: $taxPeriod';
        
        // Tax reminders are typically quarterly or yearly
        switch (taxPeriod.toLowerCase()) {
          case 'monthly':
            recurrenceType = RecurrenceType.MONTHLY;
            break;
          case 'quarterly':
            recurrenceType = RecurrenceType.QUARTERLY;
            break;
          case 'yearly':
            recurrenceType = RecurrenceType.YEARLY;
            break;
          default:
            recurrenceType = RecurrenceType.QUARTERLY;
        }
        
        // Calculate next tax deadline
        final submissionDeadline = firstItem['submission_deadline'] as String?;
        if (submissionDeadline != null) {
          final deadline = DateTime.parse(submissionDeadline);
          reminderDate = _calculateNextReminderDate(deadline, recurrenceType);
        }
      }

      // Check if similar reminder already exists
      final existingReminders = await _veritabani.remindersGetirByRelatedItem(
        firstItem['id'].toString(),
        itemType,
      );

      if (existingReminders.isEmpty) {
        final reminder = ReminderModel(
          title: title,
          description: description,
          reminderDate: reminderDate,
          recurrenceType: recurrenceType,
          priority: ReminderPriority.MEDIUM,
          isEnabled: true,
          isAutoGenerated: true,
          relatedItemId: firstItem['id'].toString(),
          relatedItemType: itemType,
          metadata: {
            'pattern_items_count': items.length,
            'auto_generated_at': DateTime.now().toIso8601String(),
          },
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await createReminder(reminder);
      }
    } catch (e) {
      print('Error creating recurring reminder: $e');
    }
  }

  /// Calculate next reminder date based on recurrence type
  DateTime _calculateNextReminderDate(DateTime baseDate, RecurrenceType recurrenceType) {
    final now = DateTime.now();
    
    switch (recurrenceType) {
      case RecurrenceType.WEEKLY:
        DateTime nextDate = baseDate;
        while (nextDate.isBefore(now)) {
          nextDate = nextDate.add(const Duration(days: 7));
        }
        return nextDate;
        
      case RecurrenceType.MONTHLY:
        DateTime nextDate = DateTime(baseDate.year, baseDate.month + 1, baseDate.day);
        while (nextDate.isBefore(now)) {
          nextDate = DateTime(nextDate.year, nextDate.month + 1, nextDate.day);
        }
        return nextDate;
        
      case RecurrenceType.QUARTERLY:
        DateTime nextDate = DateTime(baseDate.year, baseDate.month + 3, baseDate.day);
        while (nextDate.isBefore(now)) {
          nextDate = DateTime(nextDate.year, nextDate.month + 3, nextDate.day);
        }
        return nextDate;
        
      case RecurrenceType.YEARLY:
        DateTime nextDate = DateTime(baseDate.year + 1, baseDate.month, baseDate.day);
        while (nextDate.isBefore(now)) {
          nextDate = DateTime(nextDate.year + 1, nextDate.month, nextDate.day);
        }
        return nextDate;
        
      default:
        return baseDate.isAfter(now) ? baseDate : now.add(const Duration(days: 30));
    }
  }

  /// Update reminder and handle recurrence
  Future<void> updateReminder(int id, Map<String, dynamic> updates) async {
    try {
      updates['updated_at'] = DateTime.now().toIso8601String();
      await _veritabani.reminderGuncelle(id, updates);
    } catch (e) {
      throw Exception('Hatırlatıcı güncelleme hatası: $e');
    }
  }

  /// Mark reminder as triggered and calculate next occurrence
  Future<void> triggerReminder(int id) async {
    try {
      final reminderData = await _veritabani.reminderGetir(id);
      if (reminderData == null) throw Exception('Hatırlatıcı bulunamadı');

      final reminder = ReminderModel.fromMap(reminderData);
      final now = DateTime.now();

      if (reminder.recurrenceType != RecurrenceType.NONE) {
        // Calculate next occurrence
        final nextOccurrence = reminder.calculateNextOccurrence();
        
        await updateReminder(id, {
          'last_triggered': now.toIso8601String(),
          'next_occurrence': nextOccurrence?.toIso8601String(),
        });
      } else {
        // Disable one-time reminder
        await updateReminder(id, {
          'last_triggered': now.toIso8601String(),
          'is_enabled': 0,
        });
      }
    } catch (e) {
      throw Exception('Hatırlatıcı tetikleme hatası: $e');
    }
  }

  /// Delete reminder
  Future<void> deleteReminder(int id) async {
    try {
      await _veritabani.reminderSil(id);
    } catch (e) {
      throw Exception('Hatırlatıcı silme hatası: $e');
    }
  }

  /// Get calendar summary for dashboard
  Future<Map<String, dynamic>> getCalendarSummary() async {
    try {
      final today = DateTime.now();
      final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
      final thisWeekEnd = thisWeekStart.add(const Duration(days: 6));
      
      final todaysActivities = await getActivitiesForDate(today);
      final thisWeekActivities = await getActivitiesForDateRange(thisWeekStart, thisWeekEnd);
      
      final todaysReminders = await getTodaysReminders();
      final overdueReminders = await getOverdueReminders();
      
      return {
        'todays_activities_count': todaysActivities.length,
        'this_week_activities_count': thisWeekActivities.length,
        'todays_reminders_count': todaysReminders.length,
        'overdue_reminders_count': overdueReminders.length,
        'todays_activities': todaysActivities.map((a) => a.toMap()).toList(),
        'todays_reminders': todaysReminders.map((r) => r.toMap()).toList(),
        'overdue_reminders': overdueReminders.map((r) => r.toMap()).toList(),
      };
    } catch (e) {
      throw Exception('Takvim özeti alma hatası: $e');
    }
  }
} 