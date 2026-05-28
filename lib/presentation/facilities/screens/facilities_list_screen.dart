import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/platform.dart';
import 'package:provider/provider.dart';
import '../../../data/models/organization_models_enhanced.dart';
import '../../../data/repositories/facility_repository.dart';
import '../../../core/api/api_client.dart';
import '../../../config/theme.dart';
import 'facility_form_screen.dart';

class FacilitiesListScreen extends StatefulWidget {
  const FacilitiesListScreen({super.key});

  @override
  State<FacilitiesListScreen> createState() => _FacilitiesListScreenState();
}

class _FacilitiesListScreenState extends State<FacilitiesListScreen> {
  late FacilityRepository _repository;
  List<FacilityModel> _facilities = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = FacilityRepository(apiClient: context.read<ApiClient>());
    _loadFacilities();
  }

  Future<void> _loadFacilities() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final facilities = await _repository.getFacilities();
      setState(() {
        _facilities = facilities;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteFacility(FacilityModel facility) async {
    bool confirmed = false;
    await showAdaptiveActionSheet(
      context: context,
      title: 'Delete Facility',
      message:
          'Are you sure you want to delete "${facility.name}"? This action cannot be undone.',
      destructiveLabel: 'Delete',
      onConfirm: () => confirmed = true,
    );

    if (confirmed) {
      try {
        await _repository.deleteFacility(facility.id);
        if (mounted) {
          showAdaptiveToast(context, 'Facility deleted successfully',
              type: ToastType.success);
          _loadFacilities();
        }
      } catch (e) {
        if (mounted) {
          showAdaptiveToast(context, 'Failed to delete facility: $e',
              type: ToastType.error);
        }
      }
    }
  }

  Future<void> _navigateToAdd() async {
    final result = await Navigator.of(context).push(
      kIsIOS
          ? CupertinoPageRoute<bool>(
              builder: (_) => const FacilityFormScreen())
          : MaterialPageRoute<bool>(
              builder: (_) => const FacilityFormScreen()),
    );
    if (result == true) _loadFacilities();
  }

  Future<void> _navigateToEdit(FacilityModel facility) async {
    final result = await Navigator.of(context).push(
      kIsIOS
          ? CupertinoPageRoute<bool>(
              builder: (_) => FacilityFormScreen(facility: facility))
          : MaterialPageRoute<bool>(
              builder: (_) => FacilityFormScreen(facility: facility)),
    );
    if (result == true) _loadFacilities();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;

    if (kIsIOS) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('Facilities'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _loadFacilities,
                child: const Icon(CupertinoIcons.refresh),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _navigateToAdd,
                child: const Icon(CupertinoIcons.add),
              ),
            ],
          ),
        ),
        child: SafeArea(child: _buildBody(isWide)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Facilities'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFacilities,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(isWide),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAdd,
        icon: const Icon(Icons.add),
        label: const Text('Add Facility'),
      ),
    );
  }

  Widget _buildBody(bool isWide) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
            const SizedBox(height: 16),
            Text(
              'Failed to load facilities',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.gray900),
            ),
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(color: AppTheme.gray600),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            AdaptiveFilledButton(
              onPressed: _loadFacilities,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_facilities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business,
                size: 80, color: AppTheme.gray600.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No facilities yet',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.gray900),
            ),
            const SizedBox(height: 8),
            Text('Add your first facility to get started',
                style: TextStyle(color: AppTheme.gray600)),
            const SizedBox(height: 24),
            AdaptiveFilledButton(
              onPressed: _navigateToAdd,
              icon: const Icon(Icons.add),
              child: const Text('Add Facility'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFacilities,
      child: isWide ? _buildGridView() : _buildListView(),
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        childAspectRatio: 1.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _facilities.length,
      itemBuilder: (context, index) =>
          _buildFacilityCard(_facilities[index], isGrid: true),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: _facilities.length,
      itemBuilder: (context, index) =>
          _buildFacilityCard(_facilities[index], isGrid: false),
    );
  }

  static const _facilityTypeLabels = {
    'main_hospital': 'Main Hospital',
    'branch': 'Branch',
    'pharmacy': 'Pharmacy',
    'lab': 'Laboratory',
    'diagnostic_center': 'Diagnostic Center',
  };

  Widget _buildFacilityCard(FacilityModel facility, {required bool isGrid}) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _navigateToEdit(facility),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _facilityIcon(facility.type),
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          facility.name,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _facilityTypeLabels[facility.type] ?? facility.type,
                          style: TextStyle(
                              fontSize: 14, color: AppTheme.gray600),
                        ),
                      ],
                    ),
                  ),
                  _buildActionsButton(facility),
                ],
              ),
              const SizedBox(height: 16),
              _buildInfoRow(Icons.location_on, facility.address),
              if (facility.phone != null) ...[
                const SizedBox(height: 8),
                _buildInfoRow(Icons.phone, facility.phone!),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatusBadge(
                    active: facility.isActive,
                    activeLabel: 'Active',
                    inactiveLabel: 'Inactive',
                  ),
                  if (facility.supportsEmergencyAccess) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            AppTheme.warningColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.emergency,
                              size: 14, color: AppTheme.warningColor),
                          const SizedBox(width: 4),
                          Text(
                            'Emergency',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.warningColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionsButton(FacilityModel facility) {
    if (kIsIOS) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => _showIOSActions(facility),
        child: const Icon(CupertinoIcons.ellipsis_circle,
            color: CupertinoColors.systemGrey),
      );
    }
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'edit') {
          _navigateToEdit(facility);
        } else if (value == 'delete') {
          _deleteFacility(facility);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 20),
              SizedBox(width: 8),
              Text('Edit'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 20, color: AppTheme.errorColor),
              SizedBox(width: 8),
              Text('Delete',
                  style: TextStyle(color: AppTheme.errorColor)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showIOSActions(FacilityModel facility) async {
    String? choice;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text(facility.name),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              choice = 'edit';
              Navigator.of(context).pop();
            },
            child: const Text('Edit'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              choice = 'delete';
              Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (choice == 'edit') _navigateToEdit(facility);
    if (choice == 'delete') _deleteFacility(facility);
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.gray600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: AppTheme.gray600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  static IconData _facilityIcon(String type) {
    return switch (type) {
      'main_hospital' => Icons.local_hospital,
      'branch' => Icons.business,
      'pharmacy' => Icons.medication,
      'lab' || 'diagnostic_center' => Icons.science,
      _ => Icons.location_city,
    };
  }
}

class _StatusBadge extends StatelessWidget {
  final bool active;
  final String activeLabel;
  final String inactiveLabel;

  const _StatusBadge({
    required this.active,
    required this.activeLabel,
    required this.inactiveLabel,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.successColor : AppTheme.errorColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.check_circle : Icons.cancel,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            active ? activeLabel : inactiveLabel,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
