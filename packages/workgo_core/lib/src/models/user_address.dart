import 'package:flutter/material.dart';

enum AddressLabel {
  home,
  work,
  other;

  String get displayName {
    switch (this) {
      case AddressLabel.home:
        return "Home";
      case AddressLabel.work:
        return "Work";
      case AddressLabel.other:
        return "Other";
    }
  }

  IconData get icon {
    switch (this) {
      case AddressLabel.home:
        return Icons.home_rounded;
      case AddressLabel.work:
        return Icons.business_rounded;
      case AddressLabel.other:
        return Icons.location_on_rounded;
    }
  }
}

class UserAddress {
  final String id;
  final AddressLabel label;
  final String customLabel;
  final String flatBuilding;
  final String streetArea;
  final String landmark;
  final String city;
  final String state;
  final String pincode;
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final bool isDefault;
  final DateTime createdAt;

  const UserAddress({
    required this.id,
    this.label = AddressLabel.home,
    this.customLabel = "",
    this.flatBuilding = "",
    this.streetArea = "",
    this.landmark = "",
    this.city = "",
    this.state = "Tamil Nadu",
    this.pincode = "",
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    this.isDefault = false,
    required this.createdAt,
  });

  String get displayTitle {
    if (label == AddressLabel.other && customLabel.trim().isNotEmpty) {
      return customLabel.trim();
    }
    return label.displayName;
  }

  String get shortSummary {
    if (streetArea.isNotEmpty && city.isNotEmpty) {
      return "$streetArea, $city";
    }
    if (formattedAddress.isNotEmpty) {
      final parts = formattedAddress.split(',');
      if (parts.length > 2) {
        return "${parts[0].trim()}, ${parts[1].trim()}";
      }
      return formattedAddress;
    }
    return "$city, $state";
  }

  String get fullDisplayAddress {
    final List<String> parts = [];
    if (flatBuilding.isNotEmpty) parts.add(flatBuilding);
    if (streetArea.isNotEmpty) parts.add(streetArea);
    if (landmark.isNotEmpty) parts.add("Near $landmark");
    if (city.isNotEmpty) parts.add(city);
    if (state.isNotEmpty) parts.add(state);
    if (pincode.isNotEmpty) parts.add(pincode);

    if (parts.isNotEmpty) {
      return parts.join(", ");
    }
    return formattedAddress;
  }

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "label": label.name,
      "customLabel": customLabel,
      "flatBuilding": flatBuilding,
      "streetArea": streetArea,
      "landmark": landmark,
      "city": city,
      "state": state,
      "pincode": pincode,
      "formattedAddress": formattedAddress,
      "latitude": latitude,
      "longitude": longitude,
      "isDefault": isDefault,
      "createdAt": createdAt.toIso8601String(),
    };
  }

  factory UserAddress.fromMap(Map<String, dynamic> map) {
    return UserAddress(
      id: map["id"] ?? "",
      label: AddressLabel.values.firstWhere(
        (l) => l.name == (map["label"] ?? "home"),
        orElse: () => AddressLabel.home,
      ),
      customLabel: map["customLabel"] ?? "",
      flatBuilding: map["flatBuilding"] ?? "",
      streetArea: map["streetArea"] ?? "",
      landmark: map["landmark"] ?? "",
      city: map["city"] ?? "Chennai",
      state: map["state"] ?? "Tamil Nadu",
      pincode: map["pincode"] ?? "",
      formattedAddress: map["formattedAddress"] ?? "",
      latitude: (map["latitude"] as num?)?.toDouble() ?? 13.0827,
      longitude: (map["longitude"] as num?)?.toDouble() ?? 80.2707,
      isDefault: map["isDefault"] ?? false,
      createdAt: map["createdAt"] != null
          ? DateTime.tryParse(map["createdAt"].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  UserAddress copyWith({
    String? id,
    AddressLabel? label,
    String? customLabel,
    String? flatBuilding,
    String? streetArea,
    String? landmark,
    String? city,
    String? state,
    String? pincode,
    String? formattedAddress,
    double? latitude,
    double? longitude,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return UserAddress(
      id: id ?? this.id,
      label: label ?? this.label,
      customLabel: customLabel ?? this.customLabel,
      flatBuilding: flatBuilding ?? this.flatBuilding,
      streetArea: streetArea ?? this.streetArea,
      landmark: landmark ?? this.landmark,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
