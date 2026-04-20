import 'package:flutter/material.dart';

class DayPickerSheet extends StatefulWidget {
  final String cityName;
  final int? suggestedDays;
  final void Function(int days) onDaysSelected;

  const DayPickerSheet({
    super.key,
    required this.cityName,
    this.suggestedDays,
    required this.onDaysSelected,
  });

  static void show({
    required BuildContext context,
    required String cityName,
    int? suggestedDays,
    required void Function(int days) onDaysSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DayPickerSheet(
        cityName: cityName,
        suggestedDays: suggestedDays,
        onDaysSelected: onDaysSelected,
      ),
    );
  }

  @override
  State<DayPickerSheet> createState() => _DayPickerSheetState();
}

class _DayPickerSheetState extends State<DayPickerSheet> {
  late int _selectedDays;

  @override
  void initState() {
    super.initState();
    _selectedDays = widget.suggestedDays ?? 3;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Row(children: [
            const SizedBox(width: 56),
            const Expanded(child: Text('GOVISTA', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2),
            )),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ]),
          const SizedBox(height: 20),
          const Text('How many days?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w300)),
          const SizedBox(height: 8),
          Text('Select the length of your trip to\npersonalize your itinerary.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey[500], height: 1.5),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 1.1,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final day = index + 1;
                final isSelected = day == _selectedDays;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDays = day),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF108C65).withAlpha(20) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF108C65) : Colors.transparent, width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text('$day',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
                          color: isSelected ? const Color(0xFF108C65) : Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onDaysSelected(_selectedDays);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A2A3A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Create My Vista', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
