import 'package:flutter/material.dart';

/// Represents different types of activities that can be tracked in the calendar
enum ActivityType {
  DOCUMENT_UPLOAD,    // Document uploaded
  DOCUMENT_UPDATE,    // Document updated
  DOCUMENT_DELETE,    // Document deleted
  INVOICE_CREATE,     // Invoice created
  INVOICE_UPDATE,     // Invoice updated
  INVOICE_PAYMENT,    // Invoice payment made
  INVOICE_DUE,        // Invoice due date
  TAX_CREATE,         // Tax record created
  TAX_UPDATE,         // Tax record updated
  TAX_SUBMISSION,     // Tax submitted
  TAX_DEADLINE,       // Tax deadline
  REMINDER_MANUAL,    // Manual reminder
  REMINDER_RECURRING, // Recurring reminder
}

/// Activity model to track all user actions for calendar display
class ActivityModel {
  final int? id;
  final ActivityType type;
  final String title;
  final String description;
  final DateTime activityDate;
  final String? relatedItemId;
  final String? relatedItemType; // 'document', 'invoice', 'tax'
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  ActivityModel({
    this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.activityDate,
    this.relatedItemId,
    this.relatedItemType,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  // Color coding for different activity types
  Color get activityColor {
    switch (type) {
      case ActivityType.DOCUMENT_UPLOAD:
      case ActivityType.DOCUMENT_UPDATE:
        return Colors.blue.shade600;
      case ActivityType.DOCUMENT_DELETE:
        return Colors.red.shade600;
      case ActivityType.INVOICE_CREATE:
      case ActivityType.INVOICE_UPDATE:
        return Colors.green.shade600;
      case ActivityType.INVOICE_PAYMENT:
        return Colors.teal.shade600;
      case ActivityType.INVOICE_DUE:
        return Colors.orange.shade600;
      case ActivityType.TAX_CREATE:
      case ActivityType.TAX_UPDATE:
        return Colors.purple.shade600;
      case ActivityType.TAX_SUBMISSION:
        return Colors.indigo.shade600;
      case ActivityType.TAX_DEADLINE:
        return Colors.deepPurple.shade600;
      case ActivityType.REMINDER_MANUAL:
        return Colors.amber.shade600;
      case ActivityType.REMINDER_RECURRING:
        return Colors.pink.shade600;
    }
  }

  // Icon for activity type
  IconData get activityIcon {
    switch (type) {
      case ActivityType.DOCUMENT_UPLOAD:
        return Icons.upload_file_rounded;
      case ActivityType.DOCUMENT_UPDATE:
        return Icons.edit_rounded;
      case ActivityType.DOCUMENT_DELETE:
        return Icons.delete_rounded;
      case ActivityType.INVOICE_CREATE:
        return Icons.receipt_long_rounded;
      case ActivityType.INVOICE_UPDATE:
        return Icons.edit_rounded;
      case ActivityType.INVOICE_PAYMENT:
        return Icons.payment_rounded;
      case ActivityType.INVOICE_DUE:
        return Icons.schedule_rounded;
      case ActivityType.TAX_CREATE:
        return Icons.account_balance_rounded;
      case ActivityType.TAX_UPDATE:
        return Icons.edit_rounded;
      case ActivityType.TAX_SUBMISSION:
        return Icons.send_rounded;
      case ActivityType.TAX_DEADLINE:
        return Icons.alarm_rounded;
      case ActivityType.REMINDER_MANUAL:
        return Icons.notification_add_rounded;
      case ActivityType.REMINDER_RECURRING:
        return Icons.repeat_rounded;
    }
  }

  // Human readable activity type name
  String get typeDisplayName {
    switch (type) {
      case ActivityType.DOCUMENT_UPLOAD:
        return 'Belge Yüklendi';
      case ActivityType.DOCUMENT_UPDATE:
        return 'Belge Güncellendi';
      case ActivityType.DOCUMENT_DELETE:
        return 'Belge Silindi';
      case ActivityType.INVOICE_CREATE:
        return 'Fatura Oluşturuldu';
      case ActivityType.INVOICE_UPDATE:
        return 'Fatura Güncellendi';
      case ActivityType.INVOICE_PAYMENT:
        return 'Fatura Ödendi';
      case ActivityType.INVOICE_DUE:
        return 'Fatura Vadesi';
      case ActivityType.TAX_CREATE:
        return 'Vergi Kaydı';
      case ActivityType.TAX_UPDATE:
        return 'Vergi Güncellendi';
      case ActivityType.TAX_SUBMISSION:
        return 'Vergi Gönderildi';
      case ActivityType.TAX_DEADLINE:
        return 'Vergi Son Tarihi';
      case ActivityType.REMINDER_MANUAL:
        return 'Hatırlatıcı';
      case ActivityType.REMINDER_RECURRING:
        return 'Tekrarlı Hatırlatıcı';
    }
  }

  // Create ActivityModel from database map
  factory ActivityModel.fromMap(Map<String, dynamic> map) {
    return ActivityModel(
      id: map['id'] as int?,
      type: ActivityType.values[map['type'] as int],
      title: map['title'] as String,
      description: map['description'] as String,
      activityDate: DateTime.parse(map['activity_date'] as String),
      relatedItemId: map['related_item_id'] as String?,
      relatedItemType: map['related_item_type'] as String?,
      metadata: map['metadata'] != null 
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  // Convert ActivityModel to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.index,
      'title': title,
      'description': description,
      'activity_date': activityDate.toIso8601String(),
      'related_item_id': relatedItemId,
      'related_item_type': relatedItemType,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Copy with method for updates
  ActivityModel copyWith({
    int? id,
    ActivityType? type,
    String? title,
    String? description,
    DateTime? activityDate,
    String? relatedItemId,
    String? relatedItemType,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ActivityModel(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      activityDate: activityDate ?? this.activityDate,
      relatedItemId: relatedItemId ?? this.relatedItemId,
      relatedItemType: relatedItemType ?? this.relatedItemType,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'ActivityModel(id: $id, type: $type, title: $title, activityDate: $activityDate)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ActivityModel &&
        other.id == id &&
        other.type == type &&
        other.title == title &&
        other.activityDate == activityDate;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        type.hashCode ^
        title.hashCode ^
        activityDate.hashCode;
  }
} 