import "package:cloud_firestore/cloud_firestore.dart";

class Rating {
  final String id;
  final String bookingId;
  final String workerId;
  final String customerId;
  final int stars;
  final String? comment;
  final DateTime createdAt;

  Rating({
    required this.id,
    required this.bookingId,
    required this.workerId,
    required this.customerId,
    required this.stars,
    this.comment,
    required this.createdAt,
  });

  factory Rating.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Rating(
      id: doc.id,
      bookingId: d["bookingId"] ?? "",
      workerId: d["workerId"] ?? "",
      customerId: d["customerId"] ?? "",
      stars: d["stars"] ?? 0,
      comment: d["comment"],
      createdAt: (d["createdAt"] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    "bookingId": bookingId,
    "workerId": workerId,
    "customerId": customerId,
    "stars": stars,
    "comment": comment,
    "createdAt": Timestamp.fromDate(createdAt),
  };
}

class Organization {
  final String id;
  final String name;
  final String region;
  final List<String> adminUserIds;

  Organization({
    required this.id,
    required this.name,
    required this.region,
    required this.adminUserIds,
  });

  factory Organization.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Organization(
      id: doc.id,
      name: d["name"] ?? "",
      region: d["region"] ?? "",
      adminUserIds: List<String>.from(d["adminUserIds"] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() => {
    "name": name,
    "region": region,
    "adminUserIds": adminUserIds,
  };
}

class DemandStat {
  final String id; // regionId_dateKey
  final int bookingCount;
  final String topServiceType;
  final DateTime computedAt;

  DemandStat({
    required this.id,
    required this.bookingCount,
    required this.topServiceType,
    required this.computedAt,
  });

  factory DemandStat.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return DemandStat(
      id: doc.id,
      bookingCount: d["bookingCount"] ?? 0,
      topServiceType: d["topServiceType"] ?? "",
      computedAt: (d["computedAt"] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
