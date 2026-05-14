import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class CookWorkingHoursScreen extends StatefulWidget {
  const CookWorkingHoursScreen({super.key});

  @override
  State<CookWorkingHoursScreen> createState() => _CookWorkingHoursScreenState();
}

class _CookWorkingHoursScreenState extends State<CookWorkingHoursScreen> {
  final List<_DayWorkingSlot> _weekSlots = [
    const _DayWorkingSlot(
      day: 'Sunday',
      isActive: true,
      startMinutes: 16 * 60,
      endMinutes: 22 * 60,
    ),
    const _DayWorkingSlot(
      day: 'Monday',
      isActive: true,
      startMinutes: 16 * 60,
      endMinutes: 22 * 60,
    ),
    const _DayWorkingSlot(
      day: 'Tuesday',
      isActive: true,
      startMinutes: 16 * 60,
      endMinutes: 22 * 60,
    ),
    const _DayWorkingSlot(
      day: 'Wednesday',
      isActive: true,
      startMinutes: 16 * 60,
      endMinutes: 21 * 60,
    ),
    const _DayWorkingSlot(
      day: 'Thursday',
      isActive: true,
      startMinutes: 16 * 60,
      endMinutes: 21 * 60,
    ),
    const _DayWorkingSlot(
      day: 'Friday',
      isActive: true,
      startMinutes: 17 * 60,
      endMinutes: 22 * 60,
    ),
    const _DayWorkingSlot(
      day: 'Saturday',
      isActive: true,
      startMinutes: 17 * 60,
      endMinutes: 22 * 60,
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user?.workingHours != null) {
      _loadFromMap(user!.workingHours!);
    }
  }

  void _loadFromMap(Map<String, dynamic> map) {
    for (int i = 0; i < _weekSlots.length; i++) {
      final slot = _weekSlots[i];
      if (map.containsKey(slot.day)) {
        final data = map[slot.day] as Map<String, dynamic>;
        _weekSlots[i] = slot.copyWith(
          isActive: data['isActive'] as bool? ?? slot.isActive,
          startMinutes: data['start'] as int? ?? slot.startMinutes,
          endMinutes: data['end'] as int? ?? slot.endMinutes,
        );
      }
    }
  }

  Future<void> _saveWorkingHours() async {
    final Map<String, dynamic> map = {};
    for (final slot in _weekSlots) {
      map[slot.day] = {
        'isActive': slot.isActive,
        'start': slot.startMinutes,
        'end': slot.endMinutes,
      };
    }
    final auth = context.read<AuthProvider>();
    await auth.updateCookSettings(workingHours: map);
  }

  double get _totalWeeklyHours {
    var totalMinutes = 0;
    for (final slot in _weekSlots) {
      if (!slot.isActive) continue;
      totalMinutes +=
          (slot.endMinutes - slot.startMinutes).clamp(0, 24 * 60).toInt();
    }
    return totalMinutes / 60;
  }

  String get _weeklyHoursLabel {
    final total = _totalWeeklyHours;
    if ((total - total.round()).abs() < 0.01) {
      return total.toStringAsFixed(0);
    }
    return total.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        body: Column(
          children: [
            _WorkingHoursTopBar(
              topPadding: topPadding,
              onBackTap: () => context.pop(),
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
                children: [
                  _WeeklyHoursSummaryCard(hoursLabel: _weeklyHoursLabel),
                  const SizedBox(height: 12),
                  Center(
                    child: _ExtendHoursCard(onTap: _extendTodayHours),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Weekly Schedule',
                    style: GoogleFonts.poppins(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._weekSlots.asMap().entries.map(
                    (entry) {
                      final index = entry.key;
                      final slot = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DayScheduleCard(
                          slot: slot,
                          onToggle: (value) => _setDayActive(index, value),
                          onEditTap: () => _editDayHours(index),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setDayActive(int index, bool value) {
    setState(() {
      _weekSlots[index] = _weekSlots[index].copyWith(isActive: value);
    });
    _saveWorkingHours();
  }

  Future<void> _editDayHours(int index) async {
    final current = _weekSlots[index];
    final selectedStart = await showTimePicker(
      context: context,
      initialTime: _toTimeOfDay(current.startMinutes),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.homeChrome,
                ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (!mounted || selectedStart == null) return;

    final selectedEnd = await showTimePicker(
      context: context,
      initialTime: _toTimeOfDay(current.endMinutes),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.homeChrome,
                ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (!mounted || selectedEnd == null) return;

    final startMinutes = _toMinutes(selectedStart);
    final endMinutes = _toMinutes(selectedEnd);
    if (endMinutes <= startMinutes) {
      _showSnack('End time must be after start time');
      return;
    }

    setState(() {
      _weekSlots[index] = current.copyWith(
        isActive: true,
        startMinutes: startMinutes,
        endMinutes: endMinutes,
      );
    });
    _showSnack('${current.day} hours updated');
    _saveWorkingHours();
  }

  void _extendTodayHours() {
    final todayIndex = DateTime.now().weekday % 7;
    final current = _weekSlots[todayIndex];
    final nextEnd = (current.endMinutes + 60)
        .clamp(
          current.startMinutes + 30,
          (23 * 60) + 59,
        )
        .toInt();

    setState(() {
      _weekSlots[todayIndex] = current.copyWith(
        isActive: true,
        endMinutes: nextEnd,
      );
    });

    _showSnack('Added extra hour for ${current.day}');
    _saveWorkingHours();
  }

  TimeOfDay _toTimeOfDay(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    return TimeOfDay(hour: hour, minute: minute);
  }

  int _toMinutes(TimeOfDay time) {
    return (time.hour * 60) + time.minute;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _WorkingHoursTopBar extends StatelessWidget {
  const _WorkingHoursTopBar({
    required this.topPadding,
    required this.onBackTap,
  });

  final double topPadding;
  final VoidCallback onBackTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12, topPadding + 10, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.homeChrome,
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBackTap,
                splashRadius: 22,
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Working Hours',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 34,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Manage your weekly schedule',
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFEEF1FD),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyHoursSummaryCard extends StatelessWidget {
  const _WeeklyHoursSummaryCard({required this.hoursLabel});

  final String hoursLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF08BE49),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2204A53F),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Hours This Week',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFDEF6E4),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hoursLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 42,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 0.95,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.access_time_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtendHoursCard extends StatelessWidget {
  const _ExtendHoursCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          width: 175,
          height: 104,
          decoration: BoxDecoration(
            color: const Color(0xFFF9F6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE7DDFB), width: 1.3),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFFECDFFF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  size: 24,
                  color: Color(0xFFAF76FF),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Extend Hours',
                style: GoogleFonts.poppins(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4E4A57),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'Add extra time today',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFFA6A4AC),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayScheduleCard extends StatelessWidget {
  const _DayScheduleCard({
    required this.slot,
    required this.onToggle,
    required this.onEditTap,
  });

  final _DayWorkingSlot slot;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEditTap;

  @override
  Widget build(BuildContext context) {
    final hoursLabel = slot.isActive ? slot.hoursLabel : '0 hours';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              slot.isActive ? const Color(0xFF26CC69) : const Color(0xFFE5E9F0),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Transform.scale(
                scale: 0.86,
                child: Switch(
                  value: slot.isActive,
                  onChanged: onToggle,
                  activeThumbColor: Colors.white,
                  activeTrackColor: const Color(0xFF16B95C),
                  inactiveThumbColor: const Color(0xFFCDD4DF),
                  inactiveTrackColor: const Color(0xFFE6EAF0),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.day,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF525B67),
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hoursLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 13.2,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF959FAA),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: slot.isActive
                      ? const Color(0xFFDCF6E6)
                      : const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  slot.isActive ? 'Active' : 'Inactive',
                  style: GoogleFonts.poppins(
                    fontSize: 11.2,
                    fontWeight: FontWeight.w600,
                    color: slot.isActive
                        ? const Color(0xFF31B86F)
                        : const Color(0xFF99A1AB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 16,
                color: Color(0xFFB570FF),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  slot.isActive ? slot.formattedRange : 'Closed',
                  style: GoogleFonts.poppins(
                    fontSize: 14.2,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF737B86),
                  ),
                ),
              ),
              GestureDetector(
                onTap: onEditTap,
                child: Text(
                  'Edit',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFAB63FF),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayWorkingSlot {
  const _DayWorkingSlot({
    required this.day,
    required this.isActive,
    required this.startMinutes,
    required this.endMinutes,
  });

  final String day;
  final bool isActive;
  final int startMinutes;
  final int endMinutes;

  _DayWorkingSlot copyWith({
    String? day,
    bool? isActive,
    int? startMinutes,
    int? endMinutes,
  }) {
    return _DayWorkingSlot(
      day: day ?? this.day,
      isActive: isActive ?? this.isActive,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
    );
  }

  int get totalMinutes => (endMinutes - startMinutes).clamp(0, 24 * 60).toInt();

  String get hoursLabel {
    final hours = totalMinutes / 60;
    if ((hours - hours.round()).abs() < 0.01) {
      final value = hours.toStringAsFixed(0);
      return '$value hours';
    }
    return '${hours.toStringAsFixed(1)} hours';
  }

  String get formattedRange {
    return '${_formatMinute(startMinutes)} - ${_formatMinute(endMinutes)}';
  }

  static String _formatMinute(int minuteOfDay) {
    final hours24 = minuteOfDay ~/ 60;
    final minutes = minuteOfDay % 60;
    final isPm = hours24 >= 12;
    final hours12 = hours24 % 12 == 0 ? 12 : hours24 % 12;
    final minuteLabel = minutes.toString().padLeft(2, '0');
    final period = isPm ? 'PM' : 'AM';
    return '$hours12.$minuteLabel $period';
  }
}
