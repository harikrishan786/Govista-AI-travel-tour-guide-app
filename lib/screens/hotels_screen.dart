// lib/screens/hotels_screen.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import 'home_screen.dart';
import 'trips_screen.dart';
import 'ai_guide_screen.dart';
import 'profile_screen.dart';

class HotelsScreen extends StatefulWidget {
  const HotelsScreen({super.key});

  @override
  State<HotelsScreen> createState() => _HotelsScreenState();
}

class _HotelsScreenState extends State<HotelsScreen> with SingleTickerProviderStateMixin {
  final int _selectedNavIndex = 2;
  late TabController _tabController;

  // ═══ HOTEL FIELDS ═══
  final _hotelDestController = TextEditingController();
  DateTime _checkIn = DateTime.now().add(const Duration(days: 1));
  DateTime _checkOut = DateTime.now().add(const Duration(days: 2));
  int _adults = 2;
  int _children = 0;
  int _rooms = 1;

  // ═══ BUS FIELDS ═══
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  DateTime _busDate = DateTime.now().add(const Duration(days: 1));
  int _busPassengers = 1;

  // Helpers
  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  static const _dayNames = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
  String _fmtDDMMM(DateTime d) => '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]}';
  String _fmtDay(DateTime d) => _dayNames[d.weekday - 1];
  String _fmtYMD(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get _hotelDest => _hotelDestController.text.trim();
  bool get _hasHotelDest => _hotelDest.isNotEmpty;
  String get _busFrom => _fromController.text.trim();
  String get _busTo => _toController.text.trim();
  bool get _hasBusRoute => _busFrom.isNotEmpty && _busTo.isNotEmpty;

  final List<Map<String, dynamic>> _hotelPicks = [
    {'name': 'Manali', 'icon': '🏔️', 'color': 0xFF1E88E5},
    {'name': 'Shimla', 'icon': '🌲', 'color': 0xFF43A047},
    {'name': 'Jibhi', 'icon': '🌿', 'color': 0xFF2E7D32},
    {'name': 'Kasol', 'icon': '🏕️', 'color': 0xFF00897B},
    {'name': 'Srinagar', 'icon': '🌷', 'color': 0xFFE53935},
    {'name': 'Rishikesh', 'icon': '🧘', 'color': 0xFFFF9800},
    {'name': 'Leh', 'icon': '🏜️', 'color': 0xFF8E24AA},
    {'name': 'Mussoorie', 'icon': '⛰️', 'color': 0xFF00695C},
    {'name': 'Dharamshala', 'icon': '🕉️', 'color': 0xFFF4511E},
    {'name': 'Nainital', 'icon': '🏞️', 'color': 0xFF1565C0},
    {'name': 'Tirthan Valley', 'icon': '🌊', 'color': 0xFF0277BD},
    {'name': 'Bir Billing', 'icon': '🪂', 'color': 0xFF558B2F},
  ];

  final List<Map<String, dynamic>> _busRoutes = [
    {'from': 'Delhi', 'to': 'Manali', 'icon': '🏔️'},
    {'from': 'Delhi', 'to': 'Shimla', 'icon': '🌲'},
    {'from': 'Delhi', 'to': 'Rishikesh', 'icon': '🧘'},
    {'from': 'Delhi', 'to': 'Dharamshala', 'icon': '🕉️'},
    {'from': 'Chandigarh', 'to': 'Manali', 'icon': '🚌'},
    {'from': 'Delhi', 'to': 'Nainital', 'icon': '🏞️'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hotelDestController.dispose();
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  // ═══ DATE PICKERS ═══
  Future<void> _pickHotelDate(bool isCheckIn) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initial = isCheckIn ? _checkIn : _checkOut;
    final first = isCheckIn ? DateTime.now() : _checkIn.add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context, initialDate: initial,
      firstDate: first, lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (c, child) => Theme(
        data: isDark
          ? ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppColors.primary, surface: Color(0xFF2C2C2C)))
          : ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)),
        child: child!),
    );
    if (date != null) setState(() {
      if (isCheckIn) {
        _checkIn = date;
        if (!_checkOut.isAfter(_checkIn)) _checkOut = _checkIn.add(const Duration(days: 1));
      } else {
        _checkOut = date;
      }
    });
  }

  Future<void> _pickBusDate() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final date = await showDatePicker(
      context: context, initialDate: _busDate,
      firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (c, child) => Theme(
        data: isDark
          ? ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppColors.primary, surface: Color(0xFF2C2C2C)))
          : ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)),
        child: child!),
    );
    if (date != null) setState(() => _busDate = date);
  }

  // ═══ BOOKING URLS ═══
  String _bookingUrl() {
    final q = Uri.encodeComponent('$_hotelDest India');
    return 'https://www.booking.com/searchresults.html?ss=$q'
        '&checkin=${_fmtYMD(_checkIn)}&checkout=${_fmtYMD(_checkOut)}'
        '&group_adults=$_adults&group_children=$_children&no_rooms=$_rooms&selected_currency=INR';
  }

  String _mmtUrl() {
    final q = Uri.encodeComponent('$_hotelDest hotels site:makemytrip.com');
    return 'https://www.google.com/search?q=$q';
  }

  String _goibiboUrl() {
    final q = Uri.encodeComponent('$_hotelDest hotels site:goibibo.com');
    return 'https://www.google.com/search?q=$q';
  }

  String _redBusUrl() {
    // RedBus accepts route from URL but ignores date param (SPA handles dates client-side)
    // Route is prefilled, user just needs to pick their date on RedBus
    final fromSlug = _busFrom.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final toSlug = _busTo.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return 'https://www.redbus.in/bus-tickets/$fromSlug-to-$toSlug';
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      try { await launchUrl(uri, mode: LaunchMode.platformDefault); } catch (e2) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open: $e2'), backgroundColor: Colors.red));
      }
    }
  }

  void _handleNavTap(int index) {
    // Navigation handled by MainShell
  }

  // ═══════════════════════════════════
  //               BUILD
  // ═══════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(
          backgroundColor: AppColors.background(context), elevation: 0, automaticallyImplyLeading: false,
          title: Row(children: [
            const Icon(Icons.luggage, color: AppColors.primary, size: 26),
            const SizedBox(width: 10),
            Text('Book Travel', style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold, fontSize: 22)),
          ]),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: _buildTabBar(),
          ),
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildHotelTab(),
              _buildBusTab(),
            ],
          ),
        ),
        // bottomNavigationBar handled by MainShell
    );
  }

  // ═══ TAB BAR ═══
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary(context),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        dividerHeight: 0,
        tabs: const [
          Tab(
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.hotel, size: 18), SizedBox(width: 8), Text('Hotels'),
            ]),
          ),
          Tab(
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.directions_bus, size: 18), SizedBox(width: 8), Text('Bus'),
            ]),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════
  //          HOTELS TAB
  // ═══════════════════════════════════

  Widget _buildHotelTab() {
    final nights = _checkOut.difference(_checkIn).inDays;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 16),

        // Nights badge
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.nights_stay, color: AppColors.primary, size: 16),
              const SizedBox(width: 4),
              Text('$nights ${nights == 1 ? 'Night' : 'Nights'}',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),

        _label('Where do you want to stay?'),
        const SizedBox(height: 10),
        _buildTextInput(_hotelDestController, 'Type any place — Jibhi, Kasol, Manali...', Icons.location_on, _hasHotelDest),
        const SizedBox(height: 14),

        _label('Quick Picks'),
        const SizedBox(height: 10),
        _buildHotelQuickPicks(),
        const SizedBox(height: 20),

        _label('When are you going?'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _dateCard('Check-in', _checkIn, () => _pickHotelDate(true), Icons.calendar_today)),
          const SizedBox(width: 12),
          Expanded(child: _dateCard('Check-out', _checkOut, () => _pickHotelDate(false), Icons.calendar_month)),
        ]),
        const SizedBox(height: 20),

        _label('Guests & Rooms'),
        const SizedBox(height: 10),
        _buildGuestsCard(),
        const SizedBox(height: 28),

        // Hotel booking buttons
        _bookBtn('Search on Booking.com', Icons.search, const Color(0xFF003580), _hasHotelDest, () => _openUrl(_bookingUrl())),
        const SizedBox(height: 10),
        _bookBtn('Find on MakeMyTrip', Icons.flight_takeoff, const Color(0xFFE23744), _hasHotelDest, () => _openUrl(_mmtUrl())),
        const SizedBox(height: 10),
        _bookBtn('Find on Goibibo', Icons.hotel_class, const Color(0xFFEE5B24), _hasHotelDest, () => _openUrl(_goibiboUrl())),
        const SizedBox(height: 24),
        _buildInfoFooter(),
        const SizedBox(height: 100),
      ]),
    );
  }

  // ═══════════════════════════════════
  //            BUS TAB
  // ═══════════════════════════════════

  Widget _buildBusTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 16),

        // From - To with swap button
        _label('From'),
        const SizedBox(height: 8),
        _buildTextInput(_fromController, 'Departure city — Delhi, Chandigarh...', Icons.trip_origin, _busFrom.isNotEmpty),
        const SizedBox(height: 8),

        // Swap button
        Center(
          child: GestureDetector(
            onTap: () {
              final temp = _fromController.text;
              _fromController.text = _toController.text;
              _toController.text = temp;
              setState(() {});
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.swap_vert, color: AppColors.primary, size: 22),
            ),
          ),
        ),
        const SizedBox(height: 8),

        _label('To'),
        const SizedBox(height: 8),
        _buildTextInput(_toController, 'Destination — Manali, Shimla, Rishikesh...', Icons.location_on, _busTo.isNotEmpty),
        const SizedBox(height: 16),

        // Popular routes
        _label('Popular Routes'),
        const SizedBox(height: 10),
        _buildBusRouteChips(),
        const SizedBox(height: 20),

        // Travel date
        _label('Travel Date'),
        const SizedBox(height: 10),
        _dateCard('Journey Date', _busDate, _pickBusDate, Icons.calendar_today),
        const SizedBox(height: 20),

        // Passengers
        _label('Passengers'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.card(context), borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border(context))),
          child: _counter('Passengers', '', _busPassengers, 1, 10, Icons.person, (v) => setState(() => _busPassengers = v)),
        ),
        const SizedBox(height: 28),

        // RedBus button
        _bookBtn('Search on RedBus', Icons.directions_bus, const Color(0xFFD82128), _hasBusRoute, () => _openUrl(_redBusUrl())),
        const SizedBox(height: 24),
        _buildInfoFooter(),
        const SizedBox(height: 100),
      ]),
    );
  }

  // ═══════════════════════════════════
  //        SHARED WIDGETS
  // ═══════════════════════════════════

  Widget _label(String t) => Text(t, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)));

  Widget _buildTextInput(TextEditingController ctrl, String hint, IconData icon, bool hasValue) {
    return TextField(
      controller: ctrl,
      onChanged: (_) => setState(() {}),
      style: TextStyle(color: AppColors.textPrimary(context), fontSize: 16),
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textHint(context)),
        prefixIcon: Icon(icon, color: hasValue ? AppColors.primary : AppColors.textHint(context)),
        suffixIcon: hasValue
          ? IconButton(icon: Icon(Icons.clear, color: AppColors.textHint(context)),
              onPressed: () { ctrl.clear(); setState(() {}); })
          : null,
        filled: true, fillColor: AppColors.card(context),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: hasValue ? AppColors.primary : AppColors.border(context), width: hasValue ? 1.5 : 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  Widget _buildHotelQuickPicks() {
    return Wrap(spacing: 8, runSpacing: 8, children: _hotelPicks.map((p) {
      final c = Color(p['color'] as int);
      final selected = _hotelDest.toLowerCase() == (p['name'] as String).toLowerCase();
      return GestureDetector(
        onTap: () { _hotelDestController.text = p['name'] as String; setState(() {}); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.15) : c.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? AppColors.primary : c.withValues(alpha: 0.3), width: selected ? 1.5 : 1)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(p['icon'] as String, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 5),
            Text(p['name'] as String, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.primary : AppColors.textPrimary(context))),
          ]),
        ),
      );
    }).toList());
  }

  Widget _buildBusRouteChips() {
    return Wrap(spacing: 8, runSpacing: 8, children: _busRoutes.map((r) {
      final from = r['from'] as String;
      final to = r['to'] as String;
      final selected = _busFrom.toLowerCase() == from.toLowerCase() && _busTo.toLowerCase() == to.toLowerCase();
      return GestureDetector(
        onTap: () { _fromController.text = from; _toController.text = to; setState(() {}); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.15) : const Color(0xFFD82128).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? AppColors.primary : const Color(0xFFD82128).withValues(alpha: 0.3), width: selected ? 1.5 : 1)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(r['icon'] as String, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 5),
            Text('$from → $to', style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.primary : AppColors.textPrimary(context))),
          ]),
        ),
      );
    }).toList());
  }

  Widget _dateCard(String label, DateTime date, VoidCallback onTap, IconData icon) {
    return GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card(context), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context))),
      child: Row(children: [
        Icon(icon, color: AppColors.primary, size: 20), const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: AppColors.textHint(context), fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(_fmtDDMMM(date), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
          Text(_fmtDay(date), style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context))),
        ]),
      ])));
  }

  Widget _buildGuestsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card(context), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context))),
      child: Column(children: [
        _counter('Adults', 'Ages 13+', _adults, 1, 10, Icons.person, (v) => setState(() => _adults = v)),
        Divider(color: AppColors.border(context), height: 24),
        _counter('Children', 'Ages 0-12', _children, 0, 6, Icons.child_care, (v) => setState(() => _children = v)),
        Divider(color: AppColors.border(context), height: 24),
        _counter('Rooms', '', _rooms, 1, 5, Icons.king_bed, (v) => setState(() => _rooms = v)),
      ]));
  }

  Widget _counter(String label, String sub, int val, int min, int max, IconData icon, Function(int) cb) {
    return Row(children: [
      Icon(icon, color: AppColors.primary, size: 22), const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))),
        if (sub.isNotEmpty) Text(sub, style: TextStyle(fontSize: 11, color: AppColors.textHint(context))),
      ])),
      _ctrlBtn(Icons.remove, val > min, () => cb(val - 1)),
      SizedBox(width: 40, child: Text('$val', textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)))),
      _ctrlBtn(Icons.add, val < max, () => cb(val + 1)),
    ]);
  }

  Widget _ctrlBtn(IconData icon, bool active, VoidCallback onTap) {
    return GestureDetector(onTap: active ? onTap : null, child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: active ? AppColors.primary.withValues(alpha: 0.1) : AppColors.border(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 18, color: active ? AppColors.primary : AppColors.textHint(context))));
  }

  Widget _bookBtn(String label, IconData icon, Color bg, bool enabled, VoidCallback onTap) {
    return SizedBox(width: double.infinity, child: ElevatedButton(
      onPressed: enabled ? onTap : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        disabledBackgroundColor: bg.withValues(alpha: 0.3),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
      ]),
    ));
  }

  Widget _buildInfoFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline, color: AppColors.primary, size: 20), const SizedBox(width: 12),
        Expanded(child: Text(
          'You\'ll be redirected to the booking platform. GoVista does not process payments or handle cancellations.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context), height: 1.5))),
      ]));
  }
}