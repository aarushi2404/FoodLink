import 'package:cloud_firestore/cloud_firestore.dart';

/// A surplus food listing posted by a vendor.
class Listing {
  final String id;
  final String vendorId;
  final String vendorName;
  final String vendorType; // canteen | restaurant | bakery | dairy
  final String title;
  final String description;
  final int quantity;
  final int remaining;
  final double price; // 0 = free
  final DateTime pickupBy;
  final String location; // human-readable ("Hostel Mess, Gate 2")
  final double? lat;
  final double? lng;
  final bool isVeg;
  final bool hasImage; // photo lives in listing_images/{id}

  const Listing({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.vendorType,
    required this.title,
    required this.description,
    required this.quantity,
    required this.remaining,
    required this.price,
    required this.pickupBy,
    required this.location,
    this.lat,
    this.lng,
    this.isVeg = true,
    this.hasImage = false,
  });

  bool get isExpired => DateTime.now().isAfter(pickupBy);
  bool get isAvailable => !isExpired && remaining > 0;
  bool get hasCoords => lat != null && lng != null;

  String get timeLeftLabel {
    final diff = pickupBy.difference(DateTime.now());
    if (diff.isNegative) return 'Closed';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min left';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return m == 0 ? '$h h left' : '$h h $m min left';
  }

  factory Listing.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final pickup = d['pickupBy'];
    return Listing(
      id: doc.id,
      vendorId: d['vendorId'] ?? '',
      vendorName: d['vendorName'] ?? '',
      vendorType: d['vendorType'] ?? 'canteen',
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      quantity: (d['quantity'] ?? 0) as int,
      remaining: (d['remaining'] ?? 0) as int,
      price: ((d['price'] ?? 0) as num).toDouble(),
      pickupBy: pickup is Timestamp ? pickup.toDate() : DateTime.now(),
      location: d['location'] ?? '',
      lat: (d['lat'] as num?)?.toDouble(),
      lng: (d['lng'] as num?)?.toDouble(),
      isVeg: d['isVeg'] ?? true,
      hasImage: d['hasImage'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'vendorId': vendorId,
        'vendorName': vendorName,
        'vendorType': vendorType,
        'title': title,
        'description': description,
        'quantity': quantity,
        'remaining': remaining,
        'price': price,
        'pickupBy': Timestamp.fromDate(pickupBy),
        'location': location,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        'isVeg': isVeg,
        'hasImage': hasImage,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

/// A user's claim on a listing. Its id is what the QR code encodes;
/// [pickupCode] is the 6-digit fallback the vendor can type or tap.
class Claim {
  final String id;
  final String listingId;
  final String listingTitle;
  final String vendorId;
  final String vendorName;
  final String vendorType;
  final String userId;
  final String userName;
  final String status; // claimed | collected
  final String pickupCode;
  final DateTime createdAt;
  final DateTime pickupBy;
  final DateTime? collectedAt;

  const Claim({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.vendorId,
    required this.vendorName,
    required this.vendorType,
    required this.userId,
    required this.userName,
    required this.status,
    required this.pickupCode,
    required this.createdAt,
    required this.pickupBy,
    this.collectedAt,
  });

  bool get isCollected => status == 'collected';

  /// Claimed but the pickup window closed before it was collected.
  bool get isNoShow => !isCollected && DateTime.now().isAfter(pickupBy);

  factory Claim.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final created = d['createdAt'];
    final createdAt = created is Timestamp ? created.toDate() : DateTime.now();
    final pickup = d['pickupBy'];
    final collected = d['collectedAt'];
    return Claim(
      id: doc.id,
      listingId: d['listingId'] ?? '',
      listingTitle: d['listingTitle'] ?? '',
      vendorId: d['vendorId'] ?? '',
      vendorName: d['vendorName'] ?? '',
      vendorType: d['vendorType'] ?? 'canteen',
      userId: d['userId'] ?? '',
      userName: d['userName'] ?? '',
      status: d['status'] ?? 'claimed',
      pickupCode: d['pickupCode'] ?? '',
      createdAt: createdAt,
      // claims made with the v1 app have no pickupBy
      pickupBy: pickup is Timestamp ? pickup.toDate() : createdAt,
      collectedAt: collected is Timestamp ? collected.toDate() : null,
    );
  }
}
