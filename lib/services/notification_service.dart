import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

import '../models/listing.dart';
import 'auth_service.dart';
import 'location_service.dart';

/// Real-time local notifications for FoodLink.
/// Notifications are triggered by Firestore changes while listeners are active.
/// Notifications when the app is fully closed require FCM and a server trigger.
class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  static const double alertRadiusKm = 5;

  final _plugin = FlutterLocalNotificationsPlugin();
  final List<StreamSubscription<dynamic>> _subs = [];

  bool _ready = false;
  int _nextId = 1;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'foodlink_alerts',
      'FoodLink alerts',
      channelDescription: 'Surplus food and pickup updates',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  /// Initialise local notifications once at startup.
  Future<void> initialize() async {
    if (kIsWeb || _ready) return;

    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');

      await _plugin.initialize(
        settings: const InitializationSettings(android: android),
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      _ready = true;
      debugPrint('[FoodLink Notifications] Initialisation successful.');
    } catch (e, st) {
      debugPrint(
        '[FoodLink Notifications] Initialisation failed: $e\n$st',
      );
    }
  }

  Future<void> init() => initialize();

  /// Display a local notification.
  Future<void> show(String title, String body) async {
    if (!_ready) {
      debugPrint(
        '[FoodLink Notifications] Cannot show notification: '
            'service is not initialised.',
      );
      return;
    }

    try {
      await _plugin.show(
        id: _nextId++,
        title: title,
        body: body,
        notificationDetails: _details,
      );

      debugPrint('[FoodLink Notifications] Display requested: $title');
    } catch (e, st) {
      debugPrint(
        '[FoodLink Notifications] Display failed: $e\n$st',
      );
    }
  }

  /// Temporary test button.
  Future<void> showTestNotification() async {
    if (!_ready) await initialize();

    if (!_ready) {
      throw Exception(
        'Notifications could not be initialised. Check Android permission '
            'and the debug console.',
      );
    }

    await _plugin.show(
      id: 1001,
      title: 'FoodLink is working!',
      body: 'Your test notification appeared successfully.',
      notificationDetails: _details,
    );
  }

  /// Cancel active Firestore listeners.
  void stop() {
    debugPrint(
      '[FoodLink Notifications] Stopping ${_subs.length} listener(s).',
    );

    for (final sub in _subs) {
      sub.cancel();
    }

    _subs.clear();
  }

  /// Listen to a Firestore query and log incoming changes and errors.
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>> _watch(
      Query<Map<String, dynamic>> query,
      FutureOr<void> Function(
          DocumentChange<Map<String, dynamic>> change,
          ) onChange,
      String listenerName,
      ) {
    var seeded = false;

    debugPrint(
      '[FoodLink Notifications] Starting listener: $listenerName',
    );

    return query.snapshots().listen(
          (snap) {
        debugPrint(
          '[FoodLink Notifications] $listenerName snapshot: '
              '${snap.docs.length} document(s), '
              'fromCache=${snap.metadata.isFromCache}, '
              'changes=${snap.docChanges.length}',
        );

        // Ignore existing records on initial connection.
        if (!seeded) {
          if (!snap.metadata.isFromCache) {
            seeded = true;
            debugPrint(
              '[FoodLink Notifications] $listenerName is ready. '
                  'Waiting for new changes.',
            );
          }
          return;
        }

        for (final change in snap.docChanges) {
          debugPrint(
            '[FoodLink Notifications] $listenerName: '
                '${change.type.name} document ${change.doc.id}',
          );

          Future<void>.sync(() => onChange(change)).catchError(
                (Object e, StackTrace st) {
              debugPrint(
                '[FoodLink Notifications] $listenerName handler failed: '
                    '$e\n$st',
              );
            },
          );
        }
      },
      onError: (Object e, StackTrace st) {
        debugPrint(
          '[FoodLink Notifications] $listenerName Firestore error: '
              '$e\n$st',
        );
      },
    );
  }

  /// Customer: notify about newly posted nearby food and confirmed pickups.
  void startForConsumer(AppUser user) {
    stop();

    debugPrint(
      '[FoodLink Notifications] Starting customer alerts for UID ${user.uid}',
    );

    final db = FirebaseFirestore.instance;

    // 1. New food listing.
    _subs.add(
      _watch(
        db.collection('listings').where(
          'pickupBy',
          isGreaterThan: Timestamp.now(),
        ),
            (change) async {
          if (change.type != DocumentChangeType.added) return;

          final listing = Listing.fromDoc(change.doc);

          debugPrint(
            '[FoodLink Notifications] New listing detected: '
                '${listing.title}, remaining=${listing.remaining}',
          );

          if (!listing.isAvailable) {
            debugPrint(
              '[FoodLink Notifications] Skipping unavailable listing: '
                  '${listing.id}',
            );
            return;
          }

          var where = listing.location;

          if (listing.hasCoords) {
            final locationResult = await LocationService.instance.current();
            final position = locationResult.position;

            if (position != null) {
              final km = LocationService.distanceKm(
                position.latitude,
                position.longitude,
                listing.lat!,
                listing.lng!,
              );

              debugPrint(
                '[FoodLink Notifications] Listing distance: '
                    '${km.toStringAsFixed(2)} km',
              );

              if (km > alertRadiusKm) {
                debugPrint(
                  '[FoodLink Notifications] Listing outside alert radius.',
                );
                return;
              }

              where =
              '${listing.location} (${km.toStringAsFixed(1)} km away)';
            } else {
              debugPrint(
                '[FoodLink Notifications] Location unavailable; '
                    'not applying distance filter.',
              );
            }
          }

          final until = DateFormat('h:mm a').format(listing.pickupBy);

          await show(
            '${listing.quantity} portions: ${listing.title}',
            '${listing.vendorName} - $where. Pickup by $until.',
          );
        },
        'Customer new-food alerts',
      ),
    );

    // 2. Pickup confirmation.
    _subs.add(
      _watch(
        db.collection('claims').where(
          'userId',
          isEqualTo: user.uid,
        ),
            (change) async {
          if (change.type != DocumentChangeType.modified) return;

          final claim = Claim.fromDoc(change.doc);

          debugPrint(
            '[FoodLink Notifications] Claim updated: '
                '${claim.listingTitle}, status=${claim.status}',
          );

          if (claim.isCollected) {
            await show(
              'Pickup confirmed',
              'Enjoy your ${claim.listingTitle} from ${claim.vendorName}!',
            );
          }
        },
        'Customer pickup-confirmation alerts',
      ),
    );
  }

  /// Vendor: notify when a customer claims one of their listings.
  void startForVendor(AppUser vendor) {
    stop();

    debugPrint(
      '[FoodLink Notifications] Starting vendor alerts for UID ${vendor.uid}',
    );

    _subs.add(
      _watch(
        FirebaseFirestore.instance.collection('claims').where(
          'vendorId',
          isEqualTo: vendor.uid,
        ),
            (change) async {
          if (change.type != DocumentChangeType.added) return;

          final claim = Claim.fromDoc(change.doc);

          debugPrint(
            '[FoodLink Notifications] New claim detected: '
                '${claim.listingTitle}, code=${claim.pickupCode}',
          );

          await show(
            'New claim: ${claim.listingTitle}',
            '${claim.userName} claimed a portion. '
                'Pickup code ${claim.pickupCode}.',
          );
        },
        'Vendor new-claim alerts',
      ),
    );
  }
}
