import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/listing.dart';
import '../services/auth_service.dart';
import '../services/image_service.dart';
import '../services/listing_service.dart';
import '../services/location_service.dart';
import '../ui.dart';
import '../validators.dart';
import 'map_screen.dart';

class PostListingScreen extends StatefulWidget {
  final AppUser vendor;
  const PostListingScreen({super.key, required this.vendor});

  @override
  State<PostListingScreen> createState() => _PostListingScreenState();
}

class _PostListingScreenState extends State<PostListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _qty = TextEditingController(text: '10');
  final _price = TextEditingController(text: '0');
  final _location = TextEditingController();

  late DateTime _pickupBy = DateTime.now().add(const Duration(hours: 1));
  bool _isVeg = true;
  bool _busy = false;
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  Uint8List? _image;

  static const _maxQty = 1000;
  static const _maxPrice = 10000.0;

  LatLng? _point;
  String _pointNote = 'Finding your location...';

  @override
  void initState() {
    super.initState();
    _useGps();
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _qty.dispose();
    _price.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _useGps() async {
    setState(() => _pointNote = 'Finding your location...');
    final res = await LocationService.instance.current();
    if (!mounted) return;
    final p = res.position;
    setState(() {
      if (p != null) {
        _point = LatLng(p.latitude, p.longitude);
        _pointNote = 'From device location';
      } else {
        _pointNote = '${res.error ?? 'No location'} Use "Pick on map".';
      }
    });
  }

  Future<void> _pickOnMap() async {
    final start = _point;
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => PickLocationScreen(
          initial: start ?? const LatLng(20.5937, 78.9629),
          initialZoom: start == null ? 4 : 15,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _point = result;
        _pointNote = 'Chosen on map';
      });
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final bytes = await ImageService.instance.pick(source);
      if (bytes != null && mounted) setState(() => _image = bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_pickupBy),
    );
    if (t == null) return;
    final now = DateTime.now();
    var dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    // If the chosen time already passed today, assume tomorrow.
    if (dt.isBefore(now)) dt = dt.add(const Duration(days: 1));
    setState(() => _pickupBy = dt);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      _snack('Please fix the highlighted fields.');
      return;
    }
    // The form may have sat open long enough for the chosen time to pass.
    if (!_pickupBy.isAfter(DateTime.now())) {
      _snack('"Available until" is in the past. Pick a later time.');
      return;
    }
    setState(() => _busy = true);
    try {
      final qty = int.parse(_qty.text.trim());
      await ListingService.instance.postListing(
        Listing(
        id: '',
        vendorId: widget.vendor.uid,
        vendorName: widget.vendor.name,
        vendorType: widget.vendor.vendorType,
        title: _title.text.trim(),
        description: _desc.text.trim(),
        quantity: qty,
        remaining: qty,
        price: double.parse(_price.text.trim()),
        pickupBy: _pickupBy,
        location: _location.text.trim(),
        lat: _point?.latitude,
        lng: _point?.longitude,
        isVeg: _isVeg,
        hasImage: _image != null,
      ),
        imageBytes: _image,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not post: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _photoBox(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final img = _image;
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          SizedBox(
            height: 180,
            width: double.infinity,
            child: img == null
                ? InkWell(
                    onTap: () => _pickPhoto(ImageSource.gallery),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 48, color: scheme.primary),
                        const SizedBox(height: 8),
                        const Text('Add a photo of the food'),
                        Text('optional, but it helps', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  )
                : Image.memory(img, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
                TextButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Camera'),
                ),
                if (img != null)
                  TextButton.icon(
                    onPressed: () => setState(() => _image = null),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEE, h:mm a');
    final point = _point;
    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: 'Post surplus food',
            subtitle: 'A good photo gets claimed faster',
            actions: [
              HeaderIconButton(
                icon: Icons.close,
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Expanded(
            child: Form(
        key: _formKey,
        autovalidateMode: _autovalidate,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _photoBox(context),
            const SizedBox(height: 16),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              maxLength: 60,
              decoration: fieldDeco('What is available?',
                  hint: 'e.g. Rice + Dal + Paneer', icon: Icons.restaurant_menu),
              validator: (v) => Validators.text(v, field: 'Food name', min: 3, max: 60),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _desc,
              maxLines: 2,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              decoration: fieldDeco('Details (optional)',
                  hint: 'e.g. Freshly made at 1 pm, bring your own box'),
              validator: (v) => Validators.optionalText(v, field: 'Details', max: 200),
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Veg'), icon: Icon(Icons.eco)),
                ButtonSegment(
                    value: false, label: Text('Non-veg'), icon: Icon(Icons.set_meal)),
              ],
              selected: {_isVeg},
              onSelectionChanged: (s) => setState(() => _isVeg = s.first),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _qty,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: fieldDeco('Portions', hint: 'e.g. 10', helper: '1 to $_maxQty'),
                    validator: (v) => Validators.intInRange(v,
                        field: 'Portions', min: 1, max: _maxQty),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      LengthLimitingTextInputFormatter(8),
                    ],
                    decoration: fieldDeco('Price / portion (₹)',
                        hint: 'e.g. 20', helper: '0 = free'),
                    validator: (v) =>
                        Validators.money(v, field: 'Price', max: _maxPrice),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _location,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              maxLength: 100,
              decoration: fieldDeco('Pickup location',
                  hint: 'e.g. Hostel Mess, Gate 2', icon: Icons.storefront_outlined),
              validator: (v) =>
                  Validators.text(v, field: 'Pickup location', min: 3, max: 100),
            ),
            const SizedBox(height: 12),
            AppCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(12),
              child: Padding(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.place_outlined),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            point == null
                                ? 'Map location not set'
                                : '${point.latitude.toStringAsFixed(5)}, '
                                    '${point.longitude.toStringAsFixed(5)}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(_pointNote, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _useGps,
                          icon: const Icon(Icons.my_location),
                          label: const Text('Use GPS'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _pickOnMap,
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Pick on map'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(4),
              ),
              leading: const Icon(Icons.schedule),
              title: const Text('Available until'),
              subtitle: Text(fmt.format(_pickupBy)),
              trailing: const Icon(Icons.edit),
              onTap: _pickTime,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check),
              label: const Text('Post listing'),
            ),
          ],
        ),
      ),
          ),
        ],
      ),
    );
  }
}
