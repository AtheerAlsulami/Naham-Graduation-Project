import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/models/customer_order_model.dart';
import 'package:naham_app/services/backend/backend_order_service.dart';

class AdminOrdersManagementScreen extends StatefulWidget {
  const AdminOrdersManagementScreen({super.key});

  @override
  State<AdminOrdersManagementScreen> createState() =>
      _AdminOrdersManagementScreenState();
}

class _AdminOrdersManagementScreenState
    extends State<AdminOrdersManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  final BackendOrderService _orderService = BackendOrderService();
  _AdminOrderTab _selectedTab = _AdminOrderTab.newOrders;
  String _searchQuery = '';
  List<CustomerOrderModel> _orders = const [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
    });
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final orders = await _orderService.listOrders(limit: 1000);
      if (!mounted) return;
      setState(() {
        _orders = orders;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7FA),
        body: Column(
          children: [
            _OrdersTopHeader(
              selectedTab: _selectedTab,
              tabs: _AdminOrderTab.values,
              countForTab: _countForTab,
              onTabSelected: _onTabSelected,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Column(
                  children: [
                    _SearchOrderField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() => _searchQuery = value.trim());
                      },
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _buildContent(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFFB00020),
          ),
        ),
      );
    }

    return _OrdersTable(rows: _filteredRows);
  }

  int _countForTab(_AdminOrderTab tab) => _ordersFor(tab).length;

  List<CustomerOrderModel> _ordersFor(_AdminOrderTab tab) {
    return _orders.where((order) {
      switch (tab) {
        case _AdminOrderTab.newOrders:
          return order.status == CustomerOrderStatus.pendingReview;
        case _AdminOrderTab.active:
          return order.status == CustomerOrderStatus.preparing ||
              order.status == CustomerOrderStatus.outForDelivery ||
              order.status == CustomerOrderStatus.awaitingCustomerConfirmation ||
              order.status == CustomerOrderStatus.issueReported ||
              order.status == CustomerOrderStatus.replacementPendingCook;
        case _AdminOrderTab.canceled:
          return order.status == CustomerOrderStatus.cancelled;
        case _AdminOrderTab.completed:
          return order.status == CustomerOrderStatus.delivered;
      }
    }).toList(growable: false);
  }

  List<CustomerOrderModel> get _filteredRows {
    final currentRows = _ordersFor(_selectedTab);
    if (_searchQuery.isEmpty) return currentRows;

    final normalized = _searchQuery.replaceAll('#', '').toLowerCase();
    return currentRows.where((order) {
      final searchable = <String>[
        order.displayId,
        order.id,
        order.customerName,
        order.cookName,
      ].where((value) => value.isNotEmpty).join(' ').toLowerCase();
      return searchable.contains(normalized);
    }).toList(growable: false);
  }

  void _onTabSelected(_AdminOrderTab tab) {
    setState(() {
      _selectedTab = tab;
      _searchController.clear();
      _searchQuery = '';
    });
  }
}

class _OrdersTopHeader extends StatelessWidget {
  const _OrdersTopHeader({
    required this.selectedTab,
    required this.tabs,
    required this.countForTab,
    required this.onTabSelected,
  });

  final _AdminOrderTab selectedTab;
  final List<_AdminOrderTab> tabs;
  final int Function(_AdminOrderTab tab) countForTab;
  final ValueChanged<_AdminOrderTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14, topPadding + 8, 14, 12),
      decoration: const BoxDecoration(
        color: AppColors.homeChrome,
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                splashRadius: 22,
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              Expanded(
                child: Text(
                  'Orders Management',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (int i = 0; i < tabs.length; i++) ...[
                Expanded(
                  child: _OrderTabChip(
                    tab: tabs[i],
                    isSelected: selectedTab == tabs[i],
                    count: countForTab(tabs[i]),
                    onTap: () => onTabSelected(tabs[i]),
                  ),
                ),
                if (i != tabs.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderTabChip extends StatelessWidget {
  const _OrderTabChip({
    required this.tab,
    required this.isSelected,
    required this.count,
    required this.onTap,
  });

  final _AdminOrderTab tab;
  final bool isSelected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor =
        isSelected ? const Color(0xFF7D57E8) : const Color(0xFFEFE8FF);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          height: 66,
          decoration: BoxDecoration(
            color:
                isSelected ? Colors.white : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0x00FFFFFF)
                  : Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x1A5742C6),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ]
                : const [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(tab.icon, color: textColor, size: 16),
              const SizedBox(height: 4),
              Text(
                tab.label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                  height: 1.0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '$count',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchOrderField extends StatelessWidget {
  const _SearchOrderField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDFE3EA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: GoogleFonts.poppins(
          fontSize: 15,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          hintText: 'Search By order id',
          hintStyle: GoogleFonts.poppins(
            fontSize: 15,
            color: const Color(0xFF9CA4B3),
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF7E5CED),
            size: 22,
          ),
          suffixIcon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFFA6ADBA),
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _OrdersTable extends StatelessWidget {
  const _OrdersTable({required this.rows});

  final List<CustomerOrderModel> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E5EB)),
      ),
      child: Column(
        children: [
          Container(
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFFF5F6F8),
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: _TableHeaderText(label: 'Order ID'),
                ),
                Expanded(
                  flex: 2,
                  child: _TableHeaderText(label: 'Customer'),
                ),
                Expanded(
                  flex: 2,
                  child: _TableHeaderText(label: 'Cook'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE7E9EF)),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Text(
                      'No orders found',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF9CA4B3),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFEDEFF4),
                    ),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      final displayId =
                          row.displayId.isNotEmpty ? row.displayId : row.id;
                      return SizedBox(
                        height: 56,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: _TableCellText(text: displayId),
                              ),
                              Expanded(
                                flex: 2,
                                child: _TableCellText(text: row.customerName),
                              ),
                              Expanded(
                                flex: 2,
                                child: _TableCellText(text: row.cookName),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TableHeaderText extends StatelessWidget {
  const _TableHeaderText({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF5F6777),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _TableCellText extends StatelessWidget {
  const _TableCellText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF545C6B),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

enum _AdminOrderTab {
  newOrders,
  active,
  canceled,
  completed;

  String get label {
    switch (this) {
      case _AdminOrderTab.newOrders:
        return 'New';
      case _AdminOrderTab.active:
        return 'Active';
      case _AdminOrderTab.canceled:
        return 'Canceled';
      case _AdminOrderTab.completed:
        return 'Completed';
    }
  }

  IconData get icon {
    switch (this) {
      case _AdminOrderTab.newOrders:
        return Icons.auto_awesome_outlined;
      case _AdminOrderTab.active:
        return Icons.access_time_outlined;
      case _AdminOrderTab.canceled:
        return Icons.cancel_outlined;
      case _AdminOrderTab.completed:
        return Icons.check_circle_outline_rounded;
    }
  }
}
