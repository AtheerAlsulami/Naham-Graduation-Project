import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/services/backend/admin_user_types.dart';
import 'package:naham_app/services/backend/backend_admin_user_service.dart';

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  final BackendAdminUserService _adminUserService = BackendAdminUserService();
  _AdminUserFilter _selectedFilter = _AdminUserFilter.cooks;
  late final Map<_AdminUserFilter, List<_ManagedUser>> _usersByFilter;
  bool _isLoadingUsers = false;
  bool _isSavingUser = false;
  final Set<String> _deletingUserIds = <String>{};

  @override
  void initState() {
    super.initState();
    _usersByFilter = _buildEmptyUserMap();
    _loadUsersFromBackend();
  }

  @override
  Widget build(BuildContext context) {
    final users = _usersByFilter[_selectedFilter] ?? const <_ManagedUser>[];
    final totalUsers = _usersByFilter.values.fold<int>(
      0,
      (total, list) => total + list.length,
    );
    final counts = <_AdminUserFilter, int>{
      for (final filter in _AdminUserFilter.values)
        filter: (_usersByFilter[filter] ?? const <_ManagedUser>[]).length,
    };
    final Widget usersContent;
    if (_isLoadingUsers && users.isEmpty) {
      usersContent = const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF735FEF),
        ),
      );
    } else if (users.isEmpty) {
      usersContent = _EmptyUsersState(filter: _selectedFilter);
    } else {
      usersContent = ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 104),
        itemCount: users.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final user = users[index];
          return _UserCard(
            user: user,
            isDeleting: _deletingUserIds.contains(user.id),
            onDelete: () => _deleteUser(user),
          );
        },
      );
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6F8),
        body: Column(
          children: [
            _Header(
              totalUsers: totalUsers,
              counts: counts,
              selectedFilter: _selectedFilter,
              onFilterChanged: (filter) {
                setState(() => _selectedFilter = filter);
              },
            ),
            Expanded(
              child: usersContent,
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: _AddUserFab(
          selectedFilter: _selectedFilter,
          isBusy: _isSavingUser,
          onPressed: _isSavingUser ? null : _openCreateUserScreen,
        ),
      ),
    );
  }

  Future<void> _openCreateUserScreen() async {
    final created = await Navigator.of(context).push<_ManagedUser>(
      MaterialPageRoute<_ManagedUser>(
        builder: (_) => _CreateUserScreen(initialFilter: _selectedFilter),
      ),
    );
    if (!mounted || created == null) return;

    try {
      final persisted = await _persistUser(created);
      if (!mounted) return;

      setState(() {
        _usersByFilter[persisted.type]?.insert(0, persisted);
        _selectedFilter = persisted.type;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            '${persisted.name} added as ${persisted.type.singularTitle}.',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Failed to save user: ${error.toString()}',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
        ),
      );
    }
  }

  Map<_AdminUserFilter, List<_ManagedUser>> _buildEmptyUserMap() {
    return {
      _AdminUserFilter.cooks: <_ManagedUser>[],
      _AdminUserFilter.customers: <_ManagedUser>[],
      _AdminUserFilter.admins: <_ManagedUser>[],
    };
  }

  _AdminUserFilter _roleToFilter(String role) {
    switch (role.trim().toLowerCase()) {
      case AppConstants.roleCook:
        return _AdminUserFilter.cooks;
      case AppConstants.roleAdmin:
        return _AdminUserFilter.admins;
      case AppConstants.roleCustomer:
      default:
        return _AdminUserFilter.customers;
    }
  }

  String _normalizeStatusLabel({
    required _AdminUserFilter filter,
    required String status,
    String? cookStatus,
  }) {
    final normalizedStatus = status.trim().toLowerCase();
    final normalizedCookStatus = (cookStatus ?? '').trim().toLowerCase();

    if (normalizedStatus == 'active') return 'Active';
    if (normalizedStatus == 'frozen') return 'Frozen';
    if (normalizedStatus == 'warning') return 'Warning';
    if (normalizedStatus == 'suspended') return 'Suspended';

    if (filter == _AdminUserFilter.cooks) {
      if (normalizedCookStatus == AppConstants.cookApproved) return 'Active';
      if (normalizedCookStatus == AppConstants.cookFrozen) return 'Frozen';
      if (normalizedCookStatus == AppConstants.cookBlocked ||
          normalizedCookStatus == AppConstants.cookRejected) {
        return 'Warning';
      }
      if (normalizedCookStatus == AppConstants.cookPendingVerification) {
        return 'Warning';
      }
    }

    if (normalizedStatus.isEmpty) return filter.defaultStatus;
    return '${normalizedStatus[0].toUpperCase()}${normalizedStatus.substring(1)}';
  }

  _ManagedUser _toManagedUser(AdminUserRecord user) {
    final filter = _roleToFilter(user.role);
    final statusLabel = _normalizeStatusLabel(
      filter: filter,
      status: user.status,
      cookStatus: user.cookStatus,
    );
    final statusStyle = _statusStyleFromValue(statusLabel);
    return _ManagedUser(
      id: user.id,
      type: filter,
      name: user.name,
      email: user.email,
      phone: user.phone,
      roleIcon: filter.icon,
      roleIconColor: filter.iconColor,
      statusLabel: statusLabel,
      statusBadgeBackground: statusStyle.background,
      statusLabelColor: statusStyle.textColor,
      rating: user.rating,
      orders: user.orders,
      complaints: filter == _AdminUserFilter.customers ? user.complaints : null,
    );
  }

  Future<void> _loadUsersFromBackend() async {
    if (_isLoadingUsers) return;

    setState(() => _isLoadingUsers = true);
    try {
      final records = await _adminUserService.listUsers(limit: 1000);
      final grouped = _buildEmptyUserMap();
      for (final record in records) {
        final mapped = _toManagedUser(record);
        grouped[mapped.type]?.add(mapped);
      }

      if (!mounted) return;
      setState(() {
        _usersByFilter
          ..clear()
          ..addAll(grouped);
        if ((_usersByFilter[_selectedFilter] ?? const <_ManagedUser>[])
            .isEmpty) {
          for (final filter in _AdminUserFilter.values) {
            if ((_usersByFilter[filter] ?? const <_ManagedUser>[]).isNotEmpty) {
              _selectedFilter = filter;
              break;
            }
          }
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Failed to load users: ${error.toString().replaceFirst('Exception: ', '')}',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
        ),
      );
    } finally {
      // ignore: control_flow_in_finally
      if (!mounted) return;
      setState(() => _isLoadingUsers = false);
    }
  }

  Future<_ManagedUser> _persistUser(_ManagedUser user) async {
    setState(() => _isSavingUser = true);
    try {
      final created = await _adminUserService.createUser(
        CreateAdminUserRequest(
          name: user.name,
          email: user.email,
          phone: user.phone,
          password: user.password,
          role: user.type.roleValue,
          status: user.statusLabel,
          rating: user.rating,
          orders: user.orders,
          complaints: user.complaints,
        ),
      );
      return _toManagedUser(created);
    } finally {
      if (mounted) {
        setState(() => _isSavingUser = false);
      }
    }
  }

  Future<void> _deleteUser(_ManagedUser user) async {
    if (user.id.isEmpty || _deletingUserIds.contains(user.id)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Delete User',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Are you sure you want to delete ${user.name}?',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Color(0xFFE2525A)),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingUserIds.add(user.id));
    try {
      await _adminUserService.deleteUser(user.id);
      if (!mounted) return;

      setState(() {
        for (final entry in _usersByFilter.entries) {
          entry.value.removeWhere((element) => element.id == user.id);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            '${user.name} deleted.',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Failed to delete user: ${error.toString().replaceFirst('Exception: ', '')}',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
        ),
      );
    } finally {
      // ignore: control_flow_in_finally
      if (!mounted) return;
      setState(() => _deletingUserIds.remove(user.id));
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.totalUsers,
    required this.counts,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  final int totalUsers;
  final Map<_AdminUserFilter, int> counts;
  final _AdminUserFilter selectedFilter;
  final ValueChanged<_AdminUserFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12, topPadding + 8, 12, 12),
      decoration: const BoxDecoration(
        color: AppColors.homeChrome,
        boxShadow: [
          BoxShadow(
            color: Color(0x16000000),
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
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User Management',
                        style: GoogleFonts.poppins(
                          fontSize: 32 / 1.35,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          height: 1.05,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$totalUsers total users',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFFE9E4FF),
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFE9ECF1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE4E7EC)),
            ),
            child: Row(
              children: [
                for (int i = 0; i < _AdminUserFilter.values.length; i++) ...[
                  Expanded(
                    child: _FilterChip(
                      label:
                          '${_AdminUserFilter.values[i].title} (${counts[_AdminUserFilter.values[i]] ?? 0})',
                      isSelected: selectedFilter == _AdminUserFilter.values[i],
                      onTap: () => onFilterChanged(_AdminUserFilter.values[i]),
                    ),
                  ),
                  if (i != _AdminUserFilter.values.length - 1)
                    const SizedBox(width: 4),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : const Color(0x00FFFFFF),
            borderRadius: BorderRadius.circular(999),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x0D000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ]
                : const [],
            border: Border.all(
              color: isSelected ? const Color(0xFFE2E6EC) : Colors.transparent,
            ),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13.2,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF444C5B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.onDelete,
    required this.isDeleting,
  });

  final _ManagedUser user;
  final VoidCallback onDelete;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E6EC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  user.name,
                  style: GoogleFonts.poppins(
                    fontSize: 17 / 1.25,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF343B49),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(
                Icons.star_rounded,
                color: Color(0xFFFFBC11),
                size: 20,
              ),
              const SizedBox(width: 2),
              Text(
                user.rating.toStringAsFixed(1),
                style: GoogleFonts.poppins(
                  fontSize: 17 / 1.3,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF5C6474),
                ),
              ),
              const SizedBox(width: 2),
              IconButton(
                onPressed: isDeleting ? null : onDelete,
                splashRadius: 18,
                icon: isDeleting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFE2525A),
                        ),
                      )
                    : const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFE2525A),
                        size: 20,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                user.roleIcon,
                size: 16,
                color: user.roleIconColor,
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: user.statusBadgeBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  user.statusLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: user.statusLabelColor,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final hasComplaints = user.complaints != null;
              final boxWidth = hasComplaints
                  ? (constraints.maxWidth - 8) / 2
                  : constraints.maxWidth * 0.49;
              return Row(
                children: [
                  SizedBox(
                    width: boxWidth,
                    child: _MetricBox(
                      title: 'Orders',
                      value: '${user.orders}',
                    ),
                  ),
                  if (hasComplaints) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: boxWidth,
                      child: _MetricBox(
                        title: 'Complaints',
                        value: '${user.complaints}',
                        background: const Color(0xFFFFF2F4),
                        valueColor: const Color(0xFFE25158),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({
    required this.title,
    required this.value,
    this.background = const Color(0xFFF6F7FA),
    this.valueColor = const Color(0xFF3E4656),
  });

  final String title;
  final String value;
  final Color background;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF9DA4B2),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 24 / 1.35,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddUserFab extends StatelessWidget {
  const _AddUserFab({
    required this.selectedFilter,
    required this.isBusy,
    required this.onPressed,
  });

  final _AdminUserFilter selectedFilter;
  final bool isBusy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final width = math.min(MediaQuery.of(context).size.width - 28, 300.0);
    return SafeArea(
      top: false,
      child: SizedBox(
        width: width,
        child: FloatingActionButton.extended(
          onPressed: onPressed,
          backgroundColor: const Color(0xFF735FEF),
          foregroundColor: Colors.white,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          icon: isBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.person_add_alt_1_rounded, size: 20),
          label: Text(
            'Add ${selectedFilter.singularTitle}',
            style: GoogleFonts.poppins(
              fontSize: 14.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateUserScreen extends StatefulWidget {
  const _CreateUserScreen({required this.initialFilter});

  final _AdminUserFilter initialFilter;

  @override
  State<_CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<_CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ordersController = TextEditingController(text: '0');
  final _complaintsController = TextEditingController(text: '0');

  late String _status;
  double _rating = 4.5;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _status = widget.initialFilter.defaultStatus;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _ordersController.dispose();
    _complaintsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.initialFilter;
    final statusOptions = role.statusOptions;
    final topPadding = MediaQuery.of(context).padding.top;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6F8),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(12, topPadding + 8, 12, 12),
              decoration: const BoxDecoration(
                color: AppColors.homeChrome,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x15000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
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
                      'Create ${role.singularTitle}',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FieldLabel('User Type'),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F5F8),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFE2E6EC),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    role.icon,
                                    size: 18,
                                    color: role.iconColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    role.singularTitle,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF3B4352),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _FieldLabel('Full Name'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _nameController,
                              decoration: _inputDecoration(
                                hint: 'Enter full name',
                                icon: Icons.person_outline_rounded,
                              ),
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Name is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            _FieldLabel('Email'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _inputDecoration(
                                hint: 'name@example.com',
                                icon: Icons.email_outlined,
                              ),
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Email is required';
                                }
                                if (!value.contains('@')) {
                                  return 'Invalid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            _FieldLabel('Phone'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: _inputDecoration(
                                hint: '+966 5X XXX XXXX',
                                icon: Icons.phone_outlined,
                              ),
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Phone is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            _FieldLabel('Password'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: _inputDecoration(
                                hint: 'At least 6 characters',
                                icon: Icons.lock_outline_rounded,
                              ).copyWith(
                                suffixIcon: IconButton(
                                  splashRadius: 20,
                                  onPressed: () {
                                    setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    );
                                  },
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 18,
                                    color: const Color(0xFF9AA2B1),
                                  ),
                                ),
                              ),
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                final password = (value ?? '').trim();
                                if (password.isEmpty) {
                                  return 'Password is required';
                                }
                                if (password.length < 6) {
                                  return 'Minimum 6 characters';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _FormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FieldLabel('Status'),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _status,
                              isExpanded: true,
                              decoration: _inputDecoration(
                                hint: '',
                                icon: Icons.verified_user_outlined,
                              ),
                              items: statusOptions
                                  .map(
                                    (value) => DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _status = value);
                              },
                            ),
                            const SizedBox(height: 10),
                            _FieldLabel(
                                'Rating (${_rating.toStringAsFixed(1)})'),
                            Slider(
                              value: _rating,
                              min: 0,
                              max: 5,
                              divisions: 50,
                              activeColor: const Color(0xFFFFBC11),
                              label: _rating.toStringAsFixed(1),
                              onChanged: (value) {
                                setState(() => _rating = value);
                              },
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _FieldLabel('Orders'),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: _ordersController,
                                        keyboardType: TextInputType.number,
                                        decoration: _inputDecoration(
                                          hint: '0',
                                          icon: Icons.receipt_long_outlined,
                                        ),
                                        validator: _numberValidator,
                                      ),
                                    ],
                                  ),
                                ),
                                if (role == _AdminUserFilter.customers) ...[
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _FieldLabel('Complaints'),
                                        const SizedBox(height: 6),
                                        TextFormField(
                                          controller: _complaintsController,
                                          keyboardType: TextInputType.number,
                                          decoration: _inputDecoration(
                                            hint: '0',
                                            icon: Icons.report_outlined,
                                          ),
                                          validator: _numberValidator,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 64,
                              child: ElevatedButton.icon(
                                onPressed: _submit,
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  backgroundColor: const Color(0xFF735FEF),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.person_add_alt_1_rounded,
                                  size: 20,
                                ),
                                label: Text(
                                  'Create ${role.singularTitle}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _numberValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final number = int.tryParse(value);
    if (number == null || number < 0) return 'Invalid number';
    return null;
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(
        fontSize: 13.2,
        color: const Color(0xFFA1A9B8),
      ),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF9AA2B1)),
      filled: true,
      fillColor: const Color(0xFFF8F9FC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE3E7ED)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF9786F6)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE55C5C)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE55C5C)),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final role = widget.initialFilter;
    final statusStyle = _statusStyleFromValue(_status);
    final user = _ManagedUser(
      id: '',
      type: role,
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      password: _passwordController.text.trim(),
      roleIcon: role.icon,
      roleIconColor: role.iconColor,
      statusLabel: _status,
      statusBadgeBackground: statusStyle.background,
      statusLabelColor: statusStyle.textColor,
      rating: _rating,
      orders: int.tryParse(_ordersController.text.trim()) ?? 0,
      complaints: role == _AdminUserFilter.customers
          ? (int.tryParse(_complaintsController.text.trim()) ?? 0)
          : null,
    );

    Navigator.of(context).pop(user);
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E6EC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 13.2,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF525A69),
      ),
    );
  }
}

class _EmptyUsersState extends StatelessWidget {
  const _EmptyUsersState({required this.filter});

  final _AdminUserFilter filter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          'No ${filter.title.toLowerCase()} available.\nUse the add button below to create one.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13.8,
            color: const Color(0xFF8B93A2),
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

enum _AdminUserFilter {
  cooks,
  customers,
  admins;

  String get title {
    switch (this) {
      case _AdminUserFilter.cooks:
        return 'Cooks';
      case _AdminUserFilter.customers:
        return 'Customers';
      case _AdminUserFilter.admins:
        return 'Admins';
    }
  }

  String get singularTitle {
    switch (this) {
      case _AdminUserFilter.cooks:
        return 'Cook';
      case _AdminUserFilter.customers:
        return 'Customer';
      case _AdminUserFilter.admins:
        return 'Admin';
    }
  }

  String get roleValue {
    switch (this) {
      case _AdminUserFilter.cooks:
        return AppConstants.roleCook;
      case _AdminUserFilter.customers:
        return AppConstants.roleCustomer;
      case _AdminUserFilter.admins:
        return AppConstants.roleAdmin;
    }
  }

  IconData get icon {
    switch (this) {
      case _AdminUserFilter.cooks:
        return Icons.restaurant_menu_rounded;
      case _AdminUserFilter.customers:
        return Icons.person_rounded;
      case _AdminUserFilter.admins:
        return Icons.security_rounded;
    }
  }

  Color get iconColor {
    switch (this) {
      case _AdminUserFilter.cooks:
        return const Color(0xFF8D92A1);
      case _AdminUserFilter.customers:
        return const Color(0xFF7A87A3);
      case _AdminUserFilter.admins:
        return const Color(0xFF7C69EE);
    }
  }

  List<String> get statusOptions {
    switch (this) {
      case _AdminUserFilter.cooks:
      case _AdminUserFilter.customers:
        return const ['Active', 'Frozen', 'Warning'];
      case _AdminUserFilter.admins:
        return const ['Active', 'Suspended'];
    }
  }

  String get defaultStatus {
    return statusOptions.first;
  }
}

class _ManagedUser {
  const _ManagedUser({
    this.id = '',
    required this.type,
    required this.name,
    this.email = '',
    this.phone = '',
    this.password = '',
    required this.roleIcon,
    required this.roleIconColor,
    required this.statusLabel,
    required this.statusBadgeBackground,
    required this.statusLabelColor,
    required this.rating,
    required this.orders,
    this.complaints,
  });

  final String id;
  final _AdminUserFilter type;
  final String name;
  final String email;
  final String phone;
  final String password;
  final IconData roleIcon;
  final Color roleIconColor;
  final String statusLabel;
  final Color statusBadgeBackground;
  final Color statusLabelColor;
  final double rating;
  final int orders;
  final int? complaints;
}

class _StatusStyle {
  const _StatusStyle({
    required this.textColor,
    required this.background,
  });

  final Color textColor;
  final Color background;
}

_StatusStyle _statusStyleFromValue(String status) {
  final key = status.trim().toLowerCase();
  switch (key) {
    case 'active':
      return const _StatusStyle(
        textColor: Color(0xFF34A863),
        background: Color(0xFFDDF6E6),
      );
    case 'frozen':
      return const _StatusStyle(
        textColor: Color(0xFF4879E6),
        background: Color(0xFFE9F0FF),
      );
    case 'warning':
      return const _StatusStyle(
        textColor: Color(0xFFEB8834),
        background: Color(0xFFFFF0E5),
      );
    case 'suspended':
      return const _StatusStyle(
        textColor: Color(0xFFE2525A),
        background: Color(0xFFFFEFF2),
      );
    default:
      return const _StatusStyle(
        textColor: Color(0xFF6A7281),
        background: Color(0xFFEFF2F6),
      );
  }
}

// ignore: unused_element
const List<_ManagedUser> _initialCookUsers = [
  _ManagedUser(
    type: _AdminUserFilter.cooks,
    name: 'Fatima Al-Rashid',
    roleIcon: Icons.restaurant_menu_rounded,
    roleIconColor: Color(0xFF8D92A1),
    statusLabel: 'Active',
    statusBadgeBackground: Color(0xFFDDF6E6),
    statusLabelColor: Color(0xFF34A863),
    rating: 4.8,
    orders: 342,
  ),
  _ManagedUser(
    type: _AdminUserFilter.cooks,
    name: 'Ahmed Hassan',
    roleIcon: Icons.restaurant_menu_rounded,
    roleIconColor: Color(0xFF8D92A1),
    statusLabel: 'Active',
    statusBadgeBackground: Color(0xFFDDF6E6),
    statusLabelColor: Color(0xFF34A863),
    rating: 4.6,
    orders: 218,
  ),
  _ManagedUser(
    type: _AdminUserFilter.cooks,
    name: 'Layla Mohammed',
    roleIcon: Icons.restaurant_menu_rounded,
    roleIconColor: Color(0xFF8D92A1),
    statusLabel: 'Frozen',
    statusBadgeBackground: Color(0xFFE9F0FF),
    statusLabelColor: Color(0xFF4879E6),
    rating: 3.2,
    orders: 45,
  ),
  _ManagedUser(
    type: _AdminUserFilter.cooks,
    name: 'Mariam Saleh',
    roleIcon: Icons.restaurant_menu_rounded,
    roleIconColor: Color(0xFF8D92A1),
    statusLabel: 'Active',
    statusBadgeBackground: Color(0xFFDDF6E6),
    statusLabelColor: Color(0xFF34A863),
    rating: 4.4,
    orders: 176,
  ),
];

// ignore: unused_element
const List<_ManagedUser> _initialCustomerUsers = [
  _ManagedUser(
    type: _AdminUserFilter.customers,
    name: 'Ahmad Ali',
    roleIcon: Icons.person_rounded,
    roleIconColor: Color(0xFF7A87A3),
    statusLabel: 'Active',
    statusBadgeBackground: Color(0xFFDDF6E6),
    statusLabelColor: Color(0xFF34A863),
    rating: 4.5,
    orders: 89,
    complaints: 2,
  ),
  _ManagedUser(
    type: _AdminUserFilter.customers,
    name: 'Hassan Abdullah',
    roleIcon: Icons.person_rounded,
    roleIconColor: Color(0xFF7A87A3),
    statusLabel: 'Active',
    statusBadgeBackground: Color(0xFFDDF6E6),
    statusLabelColor: Color(0xFF34A863),
    rating: 3.8,
    orders: 145,
    complaints: 8,
  ),
  _ManagedUser(
    type: _AdminUserFilter.customers,
    name: 'Mariam Khalid',
    roleIcon: Icons.person_rounded,
    roleIconColor: Color(0xFF7A87A3),
    statusLabel: 'Active',
    statusBadgeBackground: Color(0xFFDDF6E6),
    statusLabelColor: Color(0xFF34A863),
    rating: 4.9,
    orders: 234,
    complaints: 1,
  ),
];

// ignore: unused_element
const List<_ManagedUser> _initialAdminUsers = [
  _ManagedUser(
    type: _AdminUserFilter.admins,
    name: 'System Admin',
    roleIcon: Icons.security_rounded,
    roleIconColor: Color(0xFF7C69EE),
    statusLabel: 'Active',
    statusBadgeBackground: Color(0xFFDDF6E6),
    statusLabelColor: Color(0xFF34A863),
    rating: 5.0,
    orders: 0,
  ),
  _ManagedUser(
    type: _AdminUserFilter.admins,
    name: 'Operations Lead',
    roleIcon: Icons.security_rounded,
    roleIconColor: Color(0xFF7C69EE),
    statusLabel: 'Active',
    statusBadgeBackground: Color(0xFFDDF6E6),
    statusLabelColor: Color(0xFF34A863),
    rating: 4.8,
    orders: 0,
  ),
];
