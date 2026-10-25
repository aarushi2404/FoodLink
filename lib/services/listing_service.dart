import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/listing.dart';
import 'auth_service.dart';
import 'image_service.dart';

class ListingService {
  ListingService._();
  static final instance = ListingService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _listings =>
      _db.collection('listings');
  CollectionReference<Map<String, dynamic>> get _claims =>
      _db.collection('claims');
  CollectionReference<Map<String, dynamic>> get _images =>
      _db.collection('listing_images');

  // ---------------------------------------------------------------- listings

  /// Live feed for consumers: listings whose pickup window hasn't closed.
  Stream<List<Listing>> activeListings() {
    return _listings
        .where('pickupBy', isGreaterThan: Timestamp.now())
        .orderBy('pickupBy')
        .snapshots()
        .map((s) => s.docs.map(Listing.fromDoc).where((l) => l.remaining > 0).toList());
  }

  /// A vendor's own listings (sorted client-side to avoid a composite index).

  Stream<List<Listing>> vendorListings(String vendorId) {
    debugPrint('Vendor listings query UID: $vendorId');

    return _listings
        .where('vendorId', isEqualTo: vendorId)
        .snapshots()
        .map((s) {
      debugPrint('Vendor listings returned: ${s.docs.length}');

      for (final doc in s.docs) {
        debugPrint(
          'Listing ${doc.id}: vendorId=${doc.data()['vendorId']}',
        );
      }

      final list = s.docs.map(Listing.fromDoc).toList();
      list.sort((a, b) => b.pickupBy.compareTo(a.pickupBy));
      return list;
    });
  }

  /// Every listing on the platform (admin dashboard).
  Stream<List<Listing>> allListings() {
    return _listings.snapshots().map((s) => s.docs.map(Listing.fromDoc).toList());
  }

  /// Posts a listing. If [imageBytes] is given, the photo is saved in the
  /// same atomic batch (so a listing never points at a missing photo).
  /// Make sure `listing.hasImage` matches whether you pass bytes.
  Future<void> postListing(Listing listing, {Uint8List? imageBytes}) async {
    final ref = _listings.doc();
    final batch = _db.batch();
    batch.set(ref, listing.toMap());
    if (imageBytes != null) {
      batch.set(_images.doc(ref.id), {
        'vendorId': listing.vendorId,
        'data': base64Encode(imageBytes),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> deleteListing(Listing listing) async {
    final batch = _db.batch();
    batch.delete(_listings.doc(listing.id));
    // only delete the photo document if there is one: deleting a document
    // that doesn't exist would be rejected by the security rules
    if (listing.hasImage) batch.delete(_images.doc(listing.id));
    await batch.commit();
    ImageService.instance.forget(listing.id);
  }

  // ------------------------------------------------------------------ claims

  Stream<List<Claim>> userClaims(String uid) {
    return _claims.where('userId', isEqualTo: uid).snapshots().map((s) {
      final list = s.docs.map(Claim.fromDoc).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<List<Claim>> vendorClaims(String vendorId) {
    return _claims.where('vendorId', isEqualTo: vendorId).snapshots().map((s) {
      final list = s.docs.map(Claim.fromDoc).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<List<Claim>> allClaims() {
    return _claims.snapshots().map((s) => s.docs.map(Claim.fromDoc).toList());
  }

  /// One claim, live. Used by the pickup screen so it flips to "collected"
  /// the moment the vendor completes the order.
  Stream<Claim?> claimById(String id) {
    return _claims
        .doc(id)
        .snapshots()
        .map((s) => s.exists ? Claim.fromDoc(s) : null);
  }

  /// Claim one portion. Runs in a transaction so two users can't take the
  /// last portion at the same time. Returns the new claim id.
  Future<String> claim(Listing listing, AppUser user) async {
    // One active claim per listing per user (stops hoarding).
    final existing = await _claims
        .where('userId', isEqualTo: user.uid)
        .where('listingId', isEqualTo: listing.id)
        .where('status', isEqualTo: 'claimed')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw Exception(
          'You already have an active claim on this listing. See "My claims".');
    }

    final code = (Random.secure().nextInt(900000) + 100000).toString();
    final listingRef = _listings.doc(listing.id);
    final claimRef = _claims.doc();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(listingRef);
      if (!snap.exists) throw Exception('This listing no longer exists.');
      final fresh = Listing.fromDoc(snap);
      if (fresh.isExpired) throw Exception('The pickup window has closed.');
      if (fresh.remaining <= 0) throw Exception('Sorry, all portions are claimed.');

      tx.update(listingRef, {'remaining': fresh.remaining - 1});
      tx.set(claimRef, {
        'listingId': fresh.id,
        'listingTitle': fresh.title,
        'vendorId': fresh.vendorId,
        'vendorName': fresh.vendorName,
        'vendorType': fresh.vendorType,
        'userId': user.uid,
        'userName': user.name,
        'status': 'claimed',
        'pickupCode': code,
        'pickupBy': Timestamp.fromDate(fresh.pickupBy),
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    return claimRef.id;
  }

  // --------------------------------------------------- completing an order
  // Three ways to finish a pickup, all ending in the same transaction:
  //   1. scan the customer's QR           -> verifyAndCollect
  //   2. type the customer's 6-digit code -> collectByCode
  //   3. tap "Mark collected" in the list -> markCollected

  Future<Claim> _collect(
      DocumentReference<Map<String, dynamic>> ref, String vendorId) async {
    late Claim result;
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Invalid code.');
      final claim = Claim.fromDoc(snap);
      if (claim.vendorId != vendorId) {
        throw Exception('This order belongs to a different vendor.');
      }
      if (claim.isCollected) throw Exception('Already collected.');
      tx.update(ref, {
        'status': 'collected',
        'collectedAt': FieldValue.serverTimestamp(),
      });
      result = claim;
    });
    return result;
  }

  Future<Claim> verifyAndCollect(String claimId, String vendorId) {
    if (claimId.isEmpty || claimId.contains('/')) {
      throw Exception('Invalid QR code.');
    }
    return _collect(_claims.doc(claimId), vendorId);
  }

  Future<Claim> markCollected(Claim claim, String vendorId) {
    return _collect(_claims.doc(claim.id), vendorId);
  }

  Future<Claim> collectByCode(String code, String vendorId) async {
    final clean = code.trim();
    if (clean.length != 6) throw Exception('Enter the 6-digit code.');
    final q = await _claims
        .where('vendorId', isEqualTo: vendorId)
        .where('pickupCode', isEqualTo: clean)
        .where('status', isEqualTo: 'claimed')
        .limit(2)
        .get();
    if (q.docs.isEmpty) throw Exception('No pending order with that code.');
    if (q.docs.length > 1) {
      throw Exception(
          'That code matches more than one order. Use "Mark collected" instead.');
    }
    return _collect(q.docs.first.reference, vendorId);
  }
}
