import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/services/api_service.dart';
import 'cart_screen.dart';

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

  // Calendar State
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Booking Details State
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  String _serviceType = "Default";
  final TextEditingController _commentController = TextEditingController();

  // Logic State
  int _durationHours = 1;
  List<dynamic> _relatedServices = [];
  bool _isLoadingRelated = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _fetchRelatedServices();
  }

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

  String _getSafeImage(dynamic serviceData) {
    var rawImages = serviceData['image_urls'];
    if (rawImages != null && rawImages is List) {
      for (var item in rawImages) {
        if (item is String) return item;
        if (item is List && item.isNotEmpty && item[0] is String)
          return item[0];
      }
    }
    return "https://via.placeholder.com/150";
  }

  // --- ACTIONS ---

  void _incrementDuration() => setState(() => _durationHours++);

  void _decrementDuration() {
    if (_durationHours > 1) setState(() => _durationHours--);
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
            Container(width: 40, height: 4, color: Colors.grey[300]),
            const SizedBox(height: 20),
            Text(
              "Service type",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTypeOption("Default", Icons.fingerprint),
                _buildTypeOption("Home", Icons.storefront),
                _buildTypeOption("Outdoor", Icons.watch),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTimePickerModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                    Text(
                      "Select Time",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Done",
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: DateTime(
                    2023,
                    1,
                    1,
                    _selectedTime.hour,
                    _selectedTime.minute,
                  ),
                  onDateTimeChanged: (DateTime newTime) {
                    setState(
                      () => _selectedTime = TimeOfDay.fromDateTime(newTime),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _saveComment() {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Comment saved!"),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _addMainServiceToCartAndNavigate() {
    final cart = Provider.of<CartProvider>(context, listen: false);
    String imgUrl = _getSafeImage(widget.service);

    // --- NEW LOGIC: PRICING TYPE CHECK ---
    String pricingType = widget.service['pricing_type'] ?? 'fixed';
    double basePrice =
        double.tryParse(widget.service['price'].toString()) ?? 0.0;

    // Calculate total based on type
    double finalPrice = (pricingType == 'hourly')
        ? basePrice * _durationHours
        : basePrice;

    cart.addToCart(
      CartItem(
        id: "${widget.service['id']}_${DateTime.now().millisecondsSinceEpoch}",
        serviceId: widget.service['id'],
        // Add hours to title if hourly so user knows
        title: pricingType == 'hourly'
            ? "${widget.service['title']} ($_durationHours hrs)"
            : widget.service['title'],
        price: finalPrice,
        imageUrl: imgUrl,
        providerId: widget.service['provider_id'],
        date: _selectedDay!,
        time: _selectedTime,
        serviceType: _serviceType,
        quantity: 1,
      ),
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    String imgUrl = _getSafeImage(widget.service);

    // --- DISPLAY LOGIC ---
    String pricingType = widget.service['pricing_type'] ?? 'fixed';
    bool isHourly = pricingType == 'hourly';

    double basePrice =
        double.tryParse(widget.service['price'].toString()) ?? 0.0;
    double displayTotal = isHourly ? basePrice * _durationHours : basePrice;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        centerTitle: true,
        title: Text(
          "Book Service",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.shopping_cart_outlined,
                  color: Colors.black,
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
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            "${cart.items.length}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. CALENDAR
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.only(bottom: 10),
              child: TableCalendar(
                firstDay: DateTime.now(),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focusedDay,
                currentDay: _selectedDay,
                calendarFormat: CalendarFormat.month,
                startingDayOfWeek: StartingDayOfWeek.sunday,
                headerStyle: HeaderStyle(
                  titleCentered: true,
                  formatButtonVisible: false,
                  titleTextStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  leftChevronIcon: const Icon(
                    Icons.chevron_left,
                    color: Colors.black,
                  ),
                  rightChevronIcon: const Icon(
                    Icons.chevron_right,
                    color: Colors.black,
                  ),
                ),
                calendarStyle: const CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: TextStyle(color: Colors.white),
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
              ),
            ),

            const SizedBox(height: 20),

            // 2. SELECTED SERVICE CARD
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: imgUrl,
                      height: 60,
                      width: 60,
                      fit: BoxFit.cover,
                      errorWidget: (c, u, e) => const Icon(Icons.error),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.service['title'],
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          // Dynamic display based on hourly vs fixed
                          isHourly
                              ? "\$$basePrice/hr  •  Total: \$$displayTotal"
                              : "Fixed Price  •  Total: \$$displayTotal",
                          style: GoogleFonts.poppins(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // LOGIC: Show Counter only if Hourly
                  if (isHourly)
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _decrementDuration,
                          child: _buildQtyBtn(Icons.remove),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            "$_durationHours hrs",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _incrementDuration,
                          child: _buildQtyBtn(Icons.add, isRed: true),
                        ),
                      ],
                    )
                  else
                    // Just a static label for Fixed
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "Fixed",
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 3. RELATED SERVICES (Restored)
            if (!_isLoadingRelated && _relatedServices.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Pick your service",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    "See all",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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

            // 4. SERVICE TYPE (Restored)
            GestureDetector(
              onTap: _showServiceTypeModal,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Service Type",
                      style: GoogleFonts.poppins(color: Colors.black54),
                    ),
                    Row(
                      children: [
                        Text(
                          _serviceType,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.black54,
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
              onTap: _showTimePickerModal,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Service Time",
                      style: GoogleFonts.poppins(color: Colors.black54),
                    ),
                    Row(
                      children: [
                        Text(
                          _selectedTime.format(context),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.black54,
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
              height: 80,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _commentController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: "Additional comment...",
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey[400],
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.check_circle,
                      color: AppColors.primary,
                    ),
                    onPressed: _saveComment,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),

      bottomSheet: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: Consumer<CartProvider>(
            builder: (context, cart, _) => ElevatedButton(
              onPressed: _addMainServiceToCartAndNavigate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 5,
              ),
              child: Text(
                "View cart (${cart.items.length + 1})",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
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
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isRed ? AppColors.primary : Colors.grey[100],
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 12, color: isRed ? Colors.white : Colors.black),
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
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: imgUrl,
                height: 80,
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (c, u, e) => const Icon(Icons.error),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              price,
              style: GoogleFonts.poppins(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
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
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF9F9F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.black54),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: isSelected ? Colors.white : Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
