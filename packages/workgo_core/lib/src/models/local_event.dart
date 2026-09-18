import "package:cloud_firestore/cloud_firestore.dart";

/// Represents a local festival or event entered by a cooperative admin.
/// Local Indian festivals and community events serve as strong demand drivers
/// for artisan trades and cannot be accurately scraped from generic public sources.
class LocalEvent {
  final String id;
  final String organizationId;
  final String title;
  final String date; // YYYY-MM-DD format
  final List<String> expectedDemandTags; // Array of service types (e.g. ['Electrician', 'Carpenter'])
  final String severity; // "low" | "medium" | "high"
  final String addedBy; // Admin UID
  final DateTime createdAt;

  LocalEvent({
    required this.id,
    required this.organizationId,
    required this.title,
    required this.date,
    required this.expectedDemandTags,
    required this.severity,
    required this.addedBy,
    required this.createdAt,
  });

  factory LocalEvent.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    DateTime parsedCreatedAt;
    if (data["createdAt"] is Timestamp) {
      parsedCreatedAt = (data["createdAt"] as Timestamp).toDate();
    } else if (data["createdAt"] is String) {
      parsedCreatedAt = DateTime.tryParse(data["createdAt"]) ?? DateTime.now();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    return LocalEvent(
      id: doc.id,
      organizationId: data["organizationId"] ?? "",
      title: data["title"] ?? "",
      date: data["date"] ?? "",
      expectedDemandTags: List<String>.from(data["expectedDemandTags"] ?? []),
      severity: data["severity"] ?? "medium",
      addedBy: data["addedBy"] ?? "",
      createdAt: parsedCreatedAt,
    );
  }

  factory LocalEvent.fromMap(String id, Map<String, dynamic> data) {
    DateTime parsedCreatedAt;
    if (data["createdAt"] is Timestamp) {
      parsedCreatedAt = (data["createdAt"] as Timestamp).toDate();
    } else if (data["createdAt"] is String) {
      parsedCreatedAt = DateTime.tryParse(data["createdAt"]) ?? DateTime.now();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    return LocalEvent(
      id: id,
      organizationId: data["organizationId"] ?? "",
      title: data["title"] ?? "",
      date: data["date"] ?? "",
      expectedDemandTags: List<String>.from(data["expectedDemandTags"] ?? []),
      severity: data["severity"] ?? "medium",
      addedBy: data["addedBy"] ?? "",
      createdAt: parsedCreatedAt,
    );
  }

  Map<String, dynamic> toFirestore() => {
    "organizationId": organizationId,
    "title": title,
    "date": date,
    "expectedDemandTags": expectedDemandTags,
    "severity": severity,
    "addedBy": addedBy,
    "createdAt": Timestamp.fromDate(createdAt),
  };

  Map<String, dynamic> toMap() => {
    "id": id,
    "organizationId": organizationId,
    "title": title,
    "date": date,
    "expectedDemandTags": expectedDemandTags,
    "severity": severity,
    "addedBy": addedBy,
    "createdAt": createdAt.toIso8601String(),
  };
}
