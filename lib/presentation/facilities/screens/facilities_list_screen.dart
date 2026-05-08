import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/platform.dart';
import 'package:provider/provider.dart';
import '../../../data/models/organization_models_enhanced.dart';
import '../../../data/repositories/facility_repository.dart';
import '../../../core/api/api_client.dart';
import '../../../config/theme.dart';

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
    _repository = FacilityRepository(
      apiClient: context.read<ApiClient>(),
    );
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
      message: 'Are you sure you want to delete "${facility.name}"? This action cannot be undone.',
      destructiveLabel: 'Delete',
      onConfirm: () => confirmed = true,
    );

    if (confirmed) {
      try {
        await _repository.deleteFacility(facility.id);

        if (mounted) {
          showAdaptiveToast(context, 'Facility deleted successfully', type: ToastType.success);
          _loadFacilities();
        }
      } catch (e) {
        if (mounted) {
          showAdaptiveToast(context, 'Failed to delete facility: $e', type: ToastType.error);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: kIsIOS
          ? CupertinoNavigationBar(
              middle: const Text('Facilities'),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _loadFacilities,
                child: const Icon(CupertinoIcons.refresh),
              ),
            )
          : AppBar(
              title: const Text('Facilities'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadFacilities,
                  tooltip: 'Refresh',
                ),
              ],
            ),
      body: _buildBody(isWeb),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).pushNamed(
            '/facilities/add',
          );
          if (result == true) {
            _loadFacilities();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Facility'),
      ),
    );
  }

  Widget _buildBody(bool isWeb) {
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
                color: AppTheme.gray900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: AppTheme.gray600),
              textAlign: TextAlign.center,
            ),
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
            Icon(Icons.business, size: 80, color: AppTheme.gray600.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No facilities yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.gray900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first facility to get started',
              style: TextStyle(color: AppTheme.gray600),
            ),
            const SizedBox(height: 24),
            AdaptiveFilledButton(
              onPressed: () async {
                final result = await Navigator.of(context).pushNamed(
                  '/facilities/add',
                );
                if (result == true) {
                  _loadFacilities();
                }
              },
              icon: const Icon(Icons.add),
              child: const Text('Add Facility'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFacilities,
      child: isWeb
          ? _buildGridView()
          : _buildListView(),
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
      itemBuilder: (context, index) {
        return _buildFacilityCard(_facilities[index], isGrid: true);
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _facilities.length,
      itemBuilder: (context, index) {
        return _buildFacilityCard(_facilities[index], isGrid: false);
      },
    );
  }

  Widget _buildFacilityCard(FacilityModel facility, {required bool isGrid}) {
    final facilityTypes = {
      'main_hospital': 'Main Hospital',
      'branch': 'Branch',
      'pharmacy': 'Pharmacy',
      'lab': 'Laboratory',
      'diagnostic_center': 'Diagnostic Center',
    };

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed(
            '/facilities/edit',
            arguments: facility,
          ).then((result) {
            if (result == true) {
              _loadFacilities();
            }
          });
        },
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
                      _getFacilityIcon(facility.type),
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
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          facilityTypes[facility.type] ?? facility.type,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.gray600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        Navigator.of(context).pushNamed(
                          '/facilities/edit',
                          arguments: facility,
                        ).then((result) {
                          if (result == true) {
                            _loadFacilities();
                          }
                        });
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
                            Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: facility.isActive
                          ? AppTheme.successColor.withValues(alpha: 0.1)
                          : AppTheme.errorColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          facility.isActive ? Icons.check_circle : Icons.cancel,
                          size: 14,
                          color: facility.isActive
                              ? AppTheme.successColor
                              : AppTheme.errorColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          facility.isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: facility.isActive
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (facility.supportsEmergencyAccess) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.emergency,
                            size: 14,
                            color: AppTheme.warningColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Emergency',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.warningColor,
                            ),
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

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.gray600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.gray600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  IconData _getFacilityIcon(String type) {
    switch (type) {
      case 'main_hospital':
        return Icons.local_hospital;
      case 'branch':
        return Icons.business;
      case 'pharmacy':
        return Icons.medication;
      case 'lab':
      case 'diagnostic_center':
        return Icons.science;
      default:
        return Icons.location_city;
    }
  }
}