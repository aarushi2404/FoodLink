import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Food photos on the free plan.
///
/// Firebase Storage needs a paid plan on new projects, so each photo is
/// shrunk on the phone (max 900 px, JPEG quality 70, typically 50-150 KB),
/// base64-encoded and kept in its own Firestore document,
/// `listing_images/{listingId}`. It lives apart from the listing so the
/// live feed stays light: a photo is downloaded once per listing and then
/// served from memory.
class ImageService {
  ImageService._();
  static final instance = ImageService._();

  /// Firestore documents are limited to 1 MiB; base64 adds about a third.
  static const int maxBytes = 600 * 1024;

  final _picker = ImagePicker();
  final _db = FirebaseFirestore.instance;
  final Map<String, Future<Uint8List?>> _cache = {};

  /// Opens the gallery or camera and returns the compressed photo,
  /// or null if the user cancelled. Throws a readable Exception if the
  /// photo can't be used.
  Future<Uint8List?> pick(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 900,
      maxHeight: 900,
      imageQuality: 70,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.length > maxBytes) {
      throw Exception(
          'That photo is still too large (${bytes.length ~/ 1024} KB). Try a different one.');
    }
    return bytes;
  }

  /// Photo for a listing (null if it has none or couldn't be loaded).
  /// The same Future is returned on repeat calls, so each photo is
  /// fetched only once per app session.
  Future<Uint8List?> load(String listingId) {
    final cached = _cache[listingId];
    if (cached != null) return cached;
    final future = _fetch(listingId);
    _cache[listingId] = future;
    future.then((bytes) {
      if (bytes == null) _cache.remove(listingId); // allow a retry later
    });
    return future;
  }

  Future<Uint8List?> _fetch(String listingId) async {
    try {
      final snap = await _db.collection('listing_images').doc(listingId).get();
      final data = snap.data()?['data'];
      if (data is String && data.isNotEmpty) return base64Decode(data);
    } catch (e) {
      debugPrint('Could not load photo for $listingId: $e');
    }
    return null;
  }

  void forget(String listingId) => _cache.remove(listingId);
}
