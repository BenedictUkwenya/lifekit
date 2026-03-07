import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/services/api_service.dart';
import 'cart_screen.dart';

// PREMIUM POLISHED VERSION
// Features: Enhanced styling, better spacing, professional touches

class BookServiceScreen extends StatefulWidget {
  final dynamic service;
  final String providerName;

  const BookServiceScreen({
    super.key,
    required this.service,
    required this.providerName,
  });

  @override
  State<BookServiceScreen> createState() => _BookServiceScreenState();
}

class _BookServiceScreenState extends State<BookServiceScreen> {
  final ApiService _apiService = ApiService();

  // --- UI STATE ---
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  String _serviceType = "Default";
  final TextEditingController _commentController = TextEditingController();
  int _durationHours = 1;

  // --- NEW: STANDALONE OPTIONS STATE ---
  final List<dynamic> _selectedOptions = [];

  // --- DATA / LOGIC STATE ---
  List<dynamic> _relatedServices = [];
  bool _isLoadingRelated = true;

  // Availability Data
  List<dynamic> _weeklySchedule = [];
  List<Map<String, dynamic>> _existingBookings = [];

  bool _isLoadingAvailability = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _fetchRelatedServices();
    _fetchAvailability();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // 1. Fetch Related Services
  Future<void> _fetchRelatedServices() async {
    try {
      final providerId = widget.service['provider_id'];
      final data = await _apiService.getProviderServices(providerId);

      if (mounted) {
        setState(() {
          List<dynamic> allServices = data['services'] ?? [];
          _relatedServices = allServices
              .where((s) => s['id'] != widget.service['id'])
              .toList();
          _isLoadingRelated = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRelated = false);
    }
  }

  // 2. Fetch Availability
  Future<void> _fetchAvailability() async {
    try {
      final providerId = widget.service['provider_id'];
      final token = await _apiService.storage.read(key: 'jwt_token');

      final results = await Future.wait([
        http.get(
          Uri.parse('${_apiService.baseUrl}/users/schedule/$providerId'),
          headers: {'Authorization': 'Bearer $token'},
        ),
        http.get(
          Uri.parse(
            '${_apiService.baseUrl}/bookings/provider-schedule/$providerId',
          ),
          headers: {'Authorization': 'Bearer $token'},
        ),
      ]);

      if (mounted) {
        setState(() {
          _weeklySchedule = jsonDecode(results[0].body)['schedule'] ?? [];
          List rawBookings = jsonDecode(results[1].body)['bookings'] ?? [];
          _existingBookings = List<Map<String, dynamic>>.from(rawBookings);

          _isLoadingAvailability = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingAvailability = false);
    }
  }

  // --- VALIDATION ---
  bool _isDayAvailable(DateTime day) {
    String dayName = DateFormat('EEEE').format(day);
    var scheduleDay = _weeklySchedule.firstWhere(
      (d) => d['day_of_week'] == dayName,
      orElse: () => null,
    );

    debugPrint("Schedule for $dayName: $scheduleDay");

    if (scheduleDay == null || scheduleDay['is_active'] == false) {
      return false;
    }

    return true;
  }

  String? _validateSelection() {
    if (_selectedDay == null) return "Please select a date";

    String dayName = DateFormat('EEEE').format(_selectedDay!);
    var scheduleDay = _weeklySchedule.firstWhere(
      (d) => d['day_of_week'] == dayName,
      orElse: () => null,
    );

    if (scheduleDay != null) {
      if (scheduleDay['is_active'] == false) {
        return "Provider does not work on $dayName";
      }

      String startStr = scheduleDay['start_time'] ?? "09:00";
      String endStr = scheduleDay['end_time'] ?? "17:00";

      int startH = int.parse(startStr.split(":")[0]);
      int endH = int.parse(endStr.split(":")[0]);

      debugPrint("Validating scheduleDay: $scheduleDay");

      if (_selectedTime.hour < startH || _selectedTime.hour >= endH) {
        return "Available hours: $startStr - $endStr";
      }
    }

    bool isConflict = _existingBookings.any((booking) {
      if (booking['day'] == DateFormat('yyyy-MM-dd').format(_selectedDay!)) {
        if (booking['blocked'] == true) {
          return true;
        } else {
          int startH = int.parse(booking['start_time'].split(":")[0]);
          int endH = int.parse(booking['end_time'].split(":")[0]);
          return _selectedTime.hour >= startH && _selectedTime.hour < endH;
        }
      }
      return false;
    });

    if (isConflict) return "This time slot is already booked.";

    return null;
  }

  // --- HELPERS ---
  String _getSafeImage(dynamic serviceData) {
    var rawImages = serviceData['image_urls'];
    if (rawImages != null && rawImages is List && rawImages.isNotEmpty) {
      var first = rawImages.first;
      if (first is String && first.startsWith("http")) return first;
    }
    // Return empty string to trigger error widget instead of unreachable placeholder
    return "";
  }

  // --- ACTIONS ---
  void _incrementDuration() => setState(() => _durationHours++);

  void _decrementDuration() {
    if (_durationHours > 1) setState(() => _durationHours--);
  }

  void _saveComment() {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              "Comment saved!",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF43A047),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ADD TO CART
  void _addToCart() {
    String? error = _validateSelection();
    if (error != null) {
      _showModernAlert(error, true);
      return;
    }

    bool hasOptions =
        widget.service['service_options'] != null &&
        (widget.service['service_options'] as List).isNotEmpty;

    if (hasOptions && _selectedOptions.isEmpty) {
      _showModernAlert("Please select at least one service option.", true);
      return;
    }

    final cart = Provider.of<CartProvider>(context, listen: false);

    double finalPrice = 0.0;
    String finalTitle = widget.service['title'];

    if (hasOptions) {
      for (var opt in _selectedOptions) {
        finalPrice += (double.tryParse(opt['price'].toString()) ?? 0.0);
      }
      List<String> names = _selectedOptions
          .map((e) => e['name'].toString())
          .toList();
      finalTitle = "${widget.service['title']} (${names.join(', ')})";
    } else {
      String pType = widget.service['pricing_type'] ?? 'fixed';
      double base = double.tryParse(widget.service['price'].toString()) ?? 0.0;
      finalPrice = (pType == 'hourly') ? base * _durationHours : base;
      if (pType == 'hourly') finalTitle = "$finalTitle ($_durationHours hrs)";
    }

    cart.addToCart(
      CartItem(
        id: "${widget.service['id']}_${DateTime.now().millisecondsSinceEpoch}",
        serviceId: widget.service['id'],
        title: finalTitle,
        price: finalPrice,
        imageUrl: _getSafeImage(widget.service),
        providerId: widget.service['provider_id'],
        date: _selectedDay!,
        time: _selectedTime,
        serviceType: _serviceType,
        comments: _commentController.text,
        quantity: 1,
      ),
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartScreen()),
    );
  }

  // --- MODALS ---
  void _showIOSTimePicker() {
    int tempHour = _selectedTime.hour;
    int tempMinute = _selectedTime.minute;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: 320,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Cancel",
                        style: GoogleFonts.poppins(
                          color: Colors.black54,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      "Select Time",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Validate time
                        String dayName = DateFormat(
                          'EEEE',
                        ).format(_selectedDay!);
                        var scheduleDay = _weeklySchedule.firstWhere(
                          (d) => d['day_of_week'] == dayName,
                          orElse: () => null,
                        );

                        if (scheduleDay != null) {
                          int startH = int.parse(
                            scheduleDay['start_time'].split(":")[0],
                          );
                          int endH = int.parse(
                            scheduleDay['end_time'].split(":")[0],
                          );

                          if (tempHour < startH || tempHour >= endH) {
                            Navigator.pop(context);
                            _showModernAlert(
                              "Available hours: ${scheduleDay['start_time']} - ${scheduleDay['end_time']}",
                              true,
                            );
                            return;
                          }
                        }

                        setState(() {
                          _selectedTime = TimeOfDay(
                            hour: tempHour,
                            minute: tempMinute,
                          );
                        });
                        Navigator.pop(context);
                      },
                      child: Text(
                        "Done",
                        style: GoogleFonts.poppins(
                          color: AppColors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // iOS-style Time Picker
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Hours
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(
                          initialItem: tempHour,
                        ),
                        itemExtent: 40,
                        onSelectedItemChanged: (index) {
                          tempHour = index;
                        },
                        children: List.generate(24, (index) {
                          return Center(
                            child: Text(
                              index.toString().padLeft(2, '0'),
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    // Separator
                    Text(
                      ":",
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    // Minutes
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(
                          initialItem: tempMinute,
                        ),
                        itemExtent: 40,
                        onSelectedItemChanged: (index) {
                          tempMinute = index;
                        },
                        children: List.generate(60, (index) {
                          return Center(
                            child: Text(
                              index.toString().padLeft(2, '0'),
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showModernAlert(String message, bool isError) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isError ? Colors.red : Colors.green).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_rounded,
                color: isError ? Colors.red : Colors.green,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isError ? "Hold on" : "Success",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isError ? Colors.black87 : AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  "Got it",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showServiceTypeModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Service Type",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTypeOption("Default", Icons.settings),
                _buildTypeOption("Home", Icons.home_rounded),
                _buildTypeOption("Outdoor", Icons.wb_sunny_rounded),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeOption(String label, IconData icon) {
    bool isSelected = _serviceType == label;
    return GestureDetector(
      onTap: () {
        setState(() => _serviceType = label);
        Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 95,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.black54,
              size: 28,
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    String imgUrl = _getSafeImage(widget.service);
    String pricingType = widget.service['pricing_type'] ?? 'fixed';
    bool isHourly = pricingType == 'hourly';
    double basePrice =
        double.tryParse(widget.service['price'].toString()) ?? 0.0;

    bool hasOptions =
        widget.service['service_options'] != null &&
        (widget.service['service_options'] as List).isNotEmpty;

    double standardDisplayTotal = isHourly
        ? basePrice * _durationHours
        : basePrice;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        shadowColor: Colors.black.withOpacity(0.05),
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          "Book Service",
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 17,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.shopping_cart_outlined,
                  color: Colors.black87,
                  size: 24,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartScreen()),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Consumer<CartProvider>(
                  builder: (context, cart, child) => cart.items.isNotEmpty
                      ? Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            "${cart.items.length}",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : const SizedBox(),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoadingAvailability
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Loading availability...",
                    style: GoogleFonts.poppins(
                      color: Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. CALENDAR
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: TableCalendar(
                      firstDay: DateTime.now(),
                      lastDay: DateTime.now().add(const Duration(days: 365)),
                      focusedDay: _focusedDay,
                      currentDay: _selectedDay,
                      calendarFormat: CalendarFormat.month,
                      startingDayOfWeek: StartingDayOfWeek.sunday,
                      enabledDayPredicate: _isDayAvailable,
                      availableGestures: AvailableGestures.horizontalSwipe,
                      headerStyle: HeaderStyle(
                        titleCentered: true,
                        formatButtonVisible: false,
                        titleTextStyle: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                        leftChevronIcon: Icon(
                          Icons.chevron_left_rounded,
                          color: Colors.black87,
                          size: 28,
                        ),
                        rightChevronIcon: Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.black87,
                          size: 28,
                        ),
                      ),
                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                        weekendStyle: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        todayTextStyle: GoogleFonts.poppins(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        selectedDecoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        selectedTextStyle: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        defaultTextStyle: GoogleFonts.poppins(
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                        weekendTextStyle: GoogleFonts.poppins(
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                        disabledTextStyle: GoogleFonts.poppins(
                          color: Colors.grey.shade400,
                        ),
                        outsideTextStyle: GoogleFonts.poppins(
                          color: Colors.grey.shade300,
                        ),
                      ),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. SELECTED SERVICE CARD
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: imgUrl.isEmpty
                                  ? Container(
                                      height: 70,
                                      width: 70,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(
                                          0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        Icons.image_outlined,
                                        size: 32,
                                        color: AppColors.primary.withOpacity(
                                          0.5,
                                        ),
                                      ),
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: imgUrl,
                                      height: 70,
                                      width: 70,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: Colors.grey.shade200,
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                      errorWidget: (c, u, e) => Container(
                                        color: AppColors.primary.withOpacity(
                                          0.1,
                                        ),
                                        child: Icon(
                                          Icons.image_outlined,
                                          size: 32,
                                          color: AppColors.primary.withOpacity(
                                            0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.service['title'],
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (!hasOptions)
                                    Text(
                                      isHourly
                                          ? "\$$basePrice/hr  •  Total: \$$standardDisplayTotal"
                                          : "Fixed  •  \$$standardDisplayTotal",
                                      style: GoogleFonts.poppins(
                                        color: AppColors.primary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (!hasOptions) ...[
                              if (isHourly)
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: _decrementDuration,
                                      child: _buildQtyBtn(Icons.remove),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      child: Text(
                                        "$_durationHours",
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: _incrementDuration,
                                      child: _buildQtyBtn(
                                        Icons.add,
                                        isRed: true,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "Fixed",
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),

                        if (hasOptions) ...[
                          const SizedBox(height: 16),
                          Divider(height: 1, color: Colors.grey.shade200),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Select Service Options",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...(widget.service['service_options'] as List).map((
                            opt,
                          ) {
                            bool isSelected = _selectedOptions.any(
                              (e) => e['name'] == opt['name'],
                            );
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withOpacity(0.05)
                                    : const Color(0xFFF8F9FA),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary.withOpacity(0.3)
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: CheckboxListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                visualDensity: VisualDensity.compact,
                                title: Text(
                                  opt['name'],
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                                subtitle: Text(
                                  "\$${opt['price']}",
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                activeColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                value: isSelected,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedOptions.add(opt);
                                    } else {
                                      _selectedOptions.removeWhere(
                                        (e) => e['name'] == opt['name'],
                                      );
                                    }
                                  });
                                },
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. RELATED SERVICES
                  if (!_isLoadingRelated && _relatedServices.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "More Services",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          "See all",
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _relatedServices.map((service) {
                          return _buildRelatedCard(service);
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 4. SERVICE TYPE
                  GestureDetector(
                    onTap: _showServiceTypeModal,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.settings_outlined,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "Service Type",
                                style: GoogleFonts.poppins(
                                  color: Colors.black87,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                _serviceType,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 5. SERVICE TIME
                  GestureDetector(
                    onTap: () => _showIOSTimePicker(),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "Service Time",
                                style: GoogleFonts.poppins(
                                  color: Colors.black87,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                _selectedTime.format(context),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 6. COMMENT
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.comment_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            maxLines: 2,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                            decoration: InputDecoration(
                              hintText: "Add special instructions...",
                              hintStyle: GoogleFonts.poppins(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                          onPressed: _saveComment,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
      bottomSheet: Container(
        color: const Color(0xFFF8F9FA),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: Consumer<CartProvider>(
              builder: (context, cart, _) => ElevatedButton(
                onPressed: _addToCart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                  shadowColor: AppColors.primary.withOpacity(0.3),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shopping_cart_outlined, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      "Add to Cart (${cart.items.length + 1})",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, {bool isRed = false}) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isRed ? AppColors.primary : const Color(0xFFF8F9FA),
        shape: BoxShape.circle,
        border: Border.all(
          color: isRed ? AppColors.primary : Colors.grey.shade300,
        ),
      ),
      child: Icon(icon, size: 14, color: isRed ? Colors.white : Colors.black87),
    );
  }

  Widget _buildRelatedCard(dynamic service) {
    String imgUrl = _getSafeImage(service);
    String title = service['title'];
    String price = "\$${service['price']}";

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookServiceScreen(
              service: service,
              providerName: widget.providerName,
            ),
          ),
        );
      },
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imgUrl.isEmpty
                  ? Container(
                      height: 90,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.image_outlined,
                        size: 36,
                        color: AppColors.primary.withOpacity(0.5),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: imgUrl,
                      height: 90,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: Colors.grey.shade200),
                      errorWidget: (c, u, e) => Container(
                        color: AppColors.primary.withOpacity(0.1),
                        child: Icon(
                          Icons.image_outlined,
                          size: 36,
                          color: AppColors.primary.withOpacity(0.5),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: GoogleFonts.poppins(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
