import 'package:flutter/material.dart';
import 'dart:collection';

import '../models/activity_model.dart';
import '../models/reminder_model.dart';
import '../services/calendar_activity_service.dart';
import '../services/veritabani_servisi.dart';
import '../services/notification_service.dart';
import '../utils/screen_utils.dart';
import '../utils/yardimci_fonksiyonlar.dart';

/// Enhanced calendar screen with interactive features and detailed info panels
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with TickerProviderStateMixin {
  final CalendarActivityService _calendarService = CalendarActivityService();
  final VeriTabaniServisi _veritabaniServisi = VeriTabaniServisi();

  // Calendar state
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDate;
  
  // Data
  Map<DateTime, List<ActivityModel>> _activities = {};
  Map<DateTime, List<ReminderModel>> _reminders = {};
  List<ActivityModel> _selectedDateActivities = [];
  List<ReminderModel> _selectedDateReminders = [];

  // UI state
  bool _isLoading = true;
  bool _showInfoPanel = false;

  // Animations
  late AnimationController _calendarAnimationController;
  late AnimationController _infoPanelAnimationController;
  late Animation<double> _calendarFadeAnimation;
  late Animation<Offset> _infoPanelSlideAnimation;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    
    _setupAnimations();
    _loadCalendarData();
  }

  @override
  void dispose() {
    _calendarAnimationController.dispose();
    _infoPanelAnimationController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _calendarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _infoPanelAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _calendarFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _calendarAnimationController, curve: Curves.easeInOut),
    );

    _infoPanelSlideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _infoPanelAnimationController,
      curve: Curves.easeOutCubic,
    ));
  }

  Future<void> _loadCalendarData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load activities and reminders for the current month range
      final startDate = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
      final endDate = DateTime(_focusedMonth.year, _focusedMonth.month + 2, 0);

      final activitiesData = await _calendarService.getActivitiesGroupedByDate(
        startDate: startDate,
        endDate: endDate,
      );

      final remindersData = await _loadRemindersGroupedByDate(startDate, endDate);

      setState(() {
        _activities = activitiesData;
        _reminders = remindersData;
        _isLoading = false;
      });

      // Load selected date data
      if (_selectedDate != null) {
        await _loadSelectedDateData(_selectedDate!);
      }

      _calendarAnimationController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Takvim verileri yüklenirken hata oluştu: $e');
    }
  }

  Future<Map<DateTime, List<ReminderModel>>> _loadRemindersGroupedByDate(
    DateTime startDate, 
    DateTime endDate,
  ) async {
    try {
      final Map<DateTime, List<ReminderModel>> grouped = {};
      
      // Load active reminders
      final activeReminders = await _calendarService.getActiveReminders();
      
      for (final reminder in activeReminders) {
        final dates = _getRecurringDatesInRange(reminder, startDate, endDate);
        
        for (final date in dates) {
          final dateKey = DateTime(date.year, date.month, date.day);
          if (grouped[dateKey] == null) {
            grouped[dateKey] = [];
          }
          grouped[dateKey]!.add(reminder);
        }
      }

      return grouped;
    } catch (e) {
      print('Error loading reminders: $e');
      return {};
    }
  }

  List<DateTime> _getRecurringDatesInRange(
    ReminderModel reminder,
    DateTime startDate,
    DateTime endDate,
  ) {
    final List<DateTime> dates = [];
    
    DateTime currentDate = reminder.nextOccurrence ?? reminder.reminderDate;
    
    while (currentDate.isBefore(endDate) || _isSameDay(currentDate, endDate)) {
      if (currentDate.isAfter(startDate) || _isSameDay(currentDate, startDate)) {
        dates.add(currentDate);
      }
      
      if (reminder.recurrenceType == RecurrenceType.NONE) break;
      
      currentDate = _calculateNextOccurrence(currentDate, reminder.recurrenceType);
      
      // Prevent infinite loops
      if (dates.length > 100) break;
    }
    
    return dates;
  }

  DateTime _calculateNextOccurrence(DateTime date, RecurrenceType type) {
    switch (type) {
      case RecurrenceType.DAILY:
        return date.add(const Duration(days: 1));
      case RecurrenceType.WEEKLY:
        return date.add(const Duration(days: 7));
      case RecurrenceType.MONTHLY:
        return DateTime(date.year, date.month + 1, date.day);
      case RecurrenceType.QUARTERLY:
        return DateTime(date.year, date.month + 3, date.day);
      case RecurrenceType.YEARLY:
        return DateTime(date.year + 1, date.month, date.day);
      default:
        return date.add(const Duration(days: 30));
    }
  }

  Future<void> _loadSelectedDateData(DateTime date) async {
    try {
      final activities = await _calendarService.getActivitiesForDate(date);
      final reminders = await _calendarService.getRemindersForDate(date);
      
      setState(() {
        _selectedDateActivities = activities;
        _selectedDateReminders = reminders;
      });
    } catch (e) {
      print('Error loading selected date data: $e');
    }
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
      _showInfoPanel = true;
    });

    _loadSelectedDateData(date);
    _infoPanelAnimationController.forward();
  }

  void _hideInfoPanel() {
    _infoPanelAnimationController.reverse().then((_) {
      setState(() {
        _showInfoPanel = false;
      });
    });
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
              Colors.blue.shade50,
              Colors.indigo.shade50,
              Colors.purple.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildAppBar(),
                  if (_isLoading)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    Expanded(
                      child: FadeTransition(
                        opacity: _calendarFadeAnimation,
                        child: _buildCalendarView(),
                      ),
                    ),
                ],
              ),
              
              // Info Panel Overlay
              if (_showInfoPanel)
                _buildInfoPanelOverlay(),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            onPressed: _testNotification,
            backgroundColor: Colors.orange[600],
            foregroundColor: Colors.white,
            heroTag: "test_notification",
            child: const Icon(Icons.notifications_active_rounded),
          ),
          const SizedBox(height: 16),
          FloatingActionButton.extended(
            onPressed: () => _showCreateReminderDialog(),
            backgroundColor: Colors.indigo[600],
            foregroundColor: Colors.white,
            heroTag: "add_reminder",
            icon: const Icon(Icons.add_alert_rounded),
            label: const Text('Hatırlatıcı Ekle'),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildBackButton(),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'İnteraktif Takvim',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                Text(
                  'Belgeler, faturalar ve hatırlatıcılar',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          _buildRefreshButton(),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade200, Colors.grey.shade100],
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              Icons.arrow_back_ios_rounded,
              color: Colors.grey.shade700,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.purple.shade400],
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: _loadCalendarData,
          child: Container(
            padding: const EdgeInsets.all(12),
            child: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarView() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildCalendarHeader(),
          Expanded(child: _buildCalendarGrid()),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.purple.shade600],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
            onPressed: () {
              setState(() {
                _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
              });
              _loadCalendarData();
            },
          ),
          Text(
            _getMonthYearString(_focusedMonth),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white, size: 28),
            onPressed: () {
              setState(() {
                _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
              });
              _loadCalendarData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Weekday headers
          _buildWeekdayHeaders(),
          const SizedBox(height: 16),
          
          // Calendar days
          Expanded(
            child: _buildDaysGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeaders() {
    const weekdays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    
    return Row(
      children: weekdays.map((weekday) => Expanded(
        child: Center(
          child: Text(
            weekday,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildDaysGrid() {
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday;
    final daysInMonth = lastDayOfMonth.day;

    final List<Widget> dayWidgets = [];

    // Add empty cells for days before the first day of the month
    for (int i = 1; i < firstWeekday; i++) {
      dayWidgets.add(const SizedBox());
    }

    // Add day cells
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
      dayWidgets.add(_buildDayCell(date));
    }

    // Add empty cells to complete the grid
    while (dayWidgets.length % 7 != 0) {
      dayWidgets.add(const SizedBox());
    }

    return GridView.count(
      crossAxisCount: 7,
      children: dayWidgets,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
    );
  }

  Widget _buildDayCell(DateTime date) {
    final isToday = _isSameDay(date, DateTime.now());
    final isSelected = _selectedDate != null && _isSameDay(date, _selectedDate!);
    final hasActivities = _getActivitiesForDate(date).isNotEmpty;
    final hasReminders = _getRemindersForDate(date).isNotEmpty;
    
    return GestureDetector(
      onTap: () => _onDateSelected(date),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.blue.shade600
              : isToday 
                  ? Colors.orange.shade100
                  : hasActivities || hasReminders
                      ? Colors.blue.shade50
                      : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isToday 
              ? Border.all(color: Colors.orange.shade400, width: 2)
              : null,
          boxShadow: isSelected 
              ? [BoxShadow(
                  color: Colors.blue.shade200,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              date.day.toString(),
              style: TextStyle(
                color: isSelected 
                    ? Colors.white
                    : isToday 
                        ? Colors.orange.shade700
                        : Colors.grey.shade800,
                fontSize: 16,
                fontWeight: isSelected || isToday 
                    ? FontWeight.bold 
                    : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            _buildActivityIndicators(date),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityIndicators(DateTime date) {
    final activities = _getActivitiesForDate(date);
    final reminders = _getRemindersForDate(date);
    
    if (activities.isEmpty && reminders.isEmpty) {
      return const SizedBox(height: 8);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (activities.isNotEmpty)
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              shape: BoxShape.circle,
            ),
          ),
        if (activities.isNotEmpty && reminders.isNotEmpty)
          const SizedBox(width: 2),
        if (reminders.isNotEmpty)
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.orange.shade600,
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(25),
          bottomRight: Radius.circular(25),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLegendItem(
            icon: Icons.circle,
            color: Colors.blue.shade600,
            label: 'Aktiviteler',
          ),
          _buildLegendItem(
            icon: Icons.circle,
            color: Colors.orange.shade600,
            label: 'Hatırlatıcılar',
          ),
          _buildLegendItem(
            icon: Icons.calendar_today,
            color: Colors.orange.shade400,
            label: 'Bugün',
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoPanelOverlay() {
    return SlideTransition(
      position: _infoPanelSlideAnimation,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        margin: const EdgeInsets.only(left: 40, top: 20, bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 40,
              offset: const Offset(-10, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildInfoPanelHeader(),
            Expanded(
              child: _buildInfoPanelContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPanelHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade600, Colors.purple.shade600],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedDate != null 
                      ? YardimciFonksiyonlar.tarihFormatla(_selectedDate!)
                      : '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_selectedDateActivities.length} aktivite, ${_selectedDateReminders.length} hatırlatıcı',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _hideInfoPanel,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanelContent() {
    if (_selectedDateActivities.isEmpty && _selectedDateReminders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy_rounded,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Bu tarihte etkinlik yok',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Yeni aktivite eklemek için ilgili modülleri kullanın',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedDateActivities.isNotEmpty) ...[
            _buildSectionHeader('Aktiviteler', Icons.timeline_rounded),
            const SizedBox(height: 16),
            ..._selectedDateActivities.map((activity) => _buildActivityCard(activity)),
            const SizedBox(height: 24),
          ],
          
          if (_selectedDateReminders.isNotEmpty) ...[
            _buildSectionHeader('Hatırlatıcılar', Icons.notification_important_rounded),
            const SizedBox(height: 16),
            ..._selectedDateReminders.map((reminder) => _buildReminderCard(reminder)),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: Colors.blue.shade600,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildActivityCard(ActivityModel activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: activity.activityColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: activity.activityColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: activity.activityColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              activity.activityIcon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activity.description,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: activity.activityColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    activity.typeDisplayName,
                    style: TextStyle(
                      color: activity.activityColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(ReminderModel reminder) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: reminder.priorityColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: reminder.priorityColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: reminder.priorityColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              reminder.reminderIcon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        reminder.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: reminder.priorityColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        reminder.priorityDisplayName,
                        style: TextStyle(
                          color: reminder.priorityColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  reminder.description,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
                if (reminder.recurrenceType != RecurrenceType.NONE) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Tekrar: ${reminder.recurrenceDisplayName}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  List<ActivityModel> _getActivitiesForDate(DateTime date) {
    final dateKey = DateTime(date.year, date.month, date.day);
    return _activities[dateKey] ?? [];
  }

  List<ReminderModel> _getRemindersForDate(DateTime date) {
    final dateKey = DateTime(date.year, date.month, date.day);
    return _reminders[dateKey] ?? [];
  }

  String _getMonthYearString(DateTime date) {
    const months = [
      '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    return '${months[date.month]} ${date.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _showError(String message) {
    ScreenUtils.showErrorSnackBar(context, message);
  }

  void _showCreateReminderDialog() {
    showDialog(
      context: context,
      builder: (context) => ReminderCreateDialog(
        initialDate: _selectedDate ?? DateTime.now(),
        onReminderCreated: (reminder) async {
          try {
            await _calendarService.createReminder(reminder);
            await _loadCalendarData();
            ScreenUtils.showSuccessSnackBar(
              context,
              'Hatırlatıcı başarıyla oluşturuldu!',
            );
          } catch (e) {
            _showError('Hatırlatıcı oluşturulurken hata: $e');
          }
        },
      ),
    );
  }

  /// Test notification function
  void _testNotification() async {
    try {
      await NotificationService.instance.showNotification(
        title: '🧪 Test Bildirimi',
        body: 'Bildirim sistemi çalışıyor! Bu bildirimi gördüyseniz sistem başarıyla kurulmuş.',
        payload: 'test_notification',
      );
      
      ScreenUtils.showSuccessSnackBar(
        context,
        'Test bildirimi gönderildi! Üstten aşağıya kaydırarak kontrol edin.',
      );
    } catch (e) {
      _showError('Test bildirimi gönderilemedi: $e');
    }
  }
}

/// Dialog for creating new reminders
class ReminderCreateDialog extends StatefulWidget {
  final DateTime initialDate;
  final Function(ReminderModel) onReminderCreated;

  const ReminderCreateDialog({
    Key? key,
    required this.initialDate,
    required this.onReminderCreated,
  }) : super(key: key);

  @override
  State<ReminderCreateDialog> createState() => _ReminderCreateDialogState();
}

class _ReminderCreateDialogState extends State<ReminderCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  ReminderPriority _priority = ReminderPriority.MEDIUM;
  RecurrenceType _recurrenceType = RecurrenceType.NONE;
  int _recurrenceInterval = 1;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.add_alert_rounded, color: Colors.indigo[600]),
          const SizedBox(width: 12),
          const Text('Yeni Hatırlatıcı'),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Başlık *',
                    prefixIcon: Icon(Icons.title_rounded),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Başlık boş olamaz';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama',
                    prefixIcon: Icon(Icons.description_rounded),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '${_selectedDate.day}.${_selectedDate.month}.${_selectedDate.year}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectTime(context),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time_rounded),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ReminderPriority>(
                  value: _priority,
                  decoration: const InputDecoration(
                    labelText: 'Öncelik',
                    prefixIcon: Icon(Icons.priority_high_rounded),
                    border: OutlineInputBorder(),
                  ),
                  items: ReminderPriority.values.map((priority) {
                    return DropdownMenuItem(
                      value: priority,
                      child: Text(_getPriorityText(priority)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _priority = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<RecurrenceType>(
                  value: _recurrenceType,
                  decoration: const InputDecoration(
                    labelText: 'Tekrar',
                    prefixIcon: Icon(Icons.repeat_rounded),
                    border: OutlineInputBorder(),
                  ),
                  items: RecurrenceType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(_getRecurrenceText(type)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _recurrenceType = value;
                      });
                    }
                  },
                ),
                if (_recurrenceType != RecurrenceType.NONE) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _recurrenceInterval.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Tekrar Aralığı',
                      prefixIcon: Icon(Icons.numbers_rounded),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _recurrenceInterval = int.tryParse(value) ?? 1;
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _createReminder,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo[600],
            foregroundColor: Colors.white,
          ),
          child: const Text('Oluştur'),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _createReminder() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final reminderDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final reminder = ReminderModel(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      reminderDate: reminderDateTime,
      priority: _priority,
      recurrenceType: _recurrenceType,
      recurrenceInterval: _recurrenceInterval,
      isEnabled: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    widget.onReminderCreated(reminder);
    Navigator.of(context).pop();
  }

  String _getPriorityText(ReminderPriority priority) {
    switch (priority) {
      case ReminderPriority.LOW:
        return 'Düşük';
      case ReminderPriority.MEDIUM:
        return 'Orta';
      case ReminderPriority.HIGH:
        return 'Yüksek';
      case ReminderPriority.URGENT:
        return 'Acil';
    }
  }

  String _getRecurrenceText(RecurrenceType type) {
    switch (type) {
      case RecurrenceType.NONE:
        return 'Tekrarlanmaz';
      case RecurrenceType.DAILY:
        return 'Günlük';
      case RecurrenceType.WEEKLY:
        return 'Haftalık';
      case RecurrenceType.MONTHLY:
        return 'Aylık';
      case RecurrenceType.QUARTERLY:
        return 'Üç Aylık';
      case RecurrenceType.YEARLY:
        return 'Yıllık';
      case RecurrenceType.CUSTOM:
        return 'Özel';
    }
  }
} 