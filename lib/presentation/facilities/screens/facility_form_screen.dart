import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/platform.dart';
import 'package:provider/provider.dart';
import '../../../data/models/organization_models_enhanced.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/repositories/facility_repository.dart';
import '../../../core/api/api_client.dart';
import '../../../config/theme.dart';

class FacilityFormScreen extends StatefulWidget {
  final FacilityModel? facility; // null for create, populated for edit

  const FacilityFormScreen({super.key, this.facility});

  @override
  State<FacilityFormScreen> createState() => _FacilityFormScreenState();
}

class _FacilityFormScreenState extends State<FacilityFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late FacilityRepository _repository;
  
  // Form controllers
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  
  String _selectedType = 'branch';
  bool _supportsEmergencyAccess = false;
  bool _isLoading = false;
  
  bool get _isEditing => widget.facility != null;

  @override
  void initState() {
    super.initState();
    _repository = FacilityRepository(
      apiClient: context.read<ApiClient>(),
    );
    
    // Populate form if editing
    if (_isEditing) {
      final facility = widget.facility!;
      _nameController.text = facility.name;
      _addressController.text = facility.address;
      _phoneController.text = facility.phone ?? '';
      _selectedType = facility.type;
      _supportsEmergencyAccess = facility.supportsEmergencyAccess;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isEditing) {
        // Update existing facility
        await _repository.updateFacility(
          id: widget.facility!.id,
          name: _nameController.text.trim(),
          type: _selectedType,
          address: _addressController.text.trim(),
          phone: _phoneController.text.trim().isEmpty 
              ? null 
              : _phoneController.text.trim(),
          supportsEmergencyAccess: _supportsEmergencyAccess,
        );
      } else {
        // Create new facility
        await _repository.createFacility(
          organizationId: context.read<AuthProvider>().organizationId ?? '',
          name: _nameController.text.trim(),
          type: _selectedType,
          address: _addressController.text.trim(),
          phone: _phoneController.text.trim().isEmpty 
              ? null 
              : _phoneController.text.trim(),
          supportsEmergencyAccess: _supportsEmergencyAccess,
        );
      }

      if (mounted) {
        showAdaptiveToast(
          context,
          _isEditing ? 'Facility updated successfully' : 'Facility created successfully',
          type: ToastType.success,
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        showAdaptiveToast(context, 'Failed to ${_isEditing ? 'update' : 'create'} facility: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: kIsIOS
          ? CupertinoNavigationBar(
              middle:
                  Text(_isEditing ? 'Edit Facility' : 'Add Facility'),
            )
          : AppBar(
              title:
                  Text(_isEditing ? 'Edit Facility' : 'Add Facility'),
            ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              isWeb ? 32 : 16, isWeb ? 32 : 16, isWeb ? 32 : 16, isWeb ? 40 : 32),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWeb ? 600 : double.infinity),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  if (isWeb) ...[
                    Text(
                      _isEditing ? 'Edit Facility Details' : 'Add New Facility',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isEditing 
                          ? 'Update the facility information below'
                          : 'Fill in the details for your new facility',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.gray600,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Form Fields Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Facility Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(height: 24),
                          
                          // Name
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Facility Name *',
                              hintText: 'e.g., Downtown Branch',
                              prefixIcon: Icon(Icons.business),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Facility name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Type
                          AdaptiveDropdown<String>(
                            value: _selectedType,
                            decoration: const InputDecoration(
                              labelText: 'Facility Type *',
                              prefixIcon: Icon(Icons.category),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'main_hospital',
                                child: Text('Main Hospital'),
                              ),
                              DropdownMenuItem(
                                value: 'branch',
                                child: Text('Branch'),
                              ),
                              DropdownMenuItem(
                                value: 'pharmacy',
                                child: Text('Pharmacy'),
                              ),
                              DropdownMenuItem(
                                value: 'lab',
                                child: Text('Laboratory'),
                              ),
                              DropdownMenuItem(
                                value: 'diagnostic_center',
                                child: Text('Diagnostic Center'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedType = value!);
                            },
                          ),
                          const SizedBox(height: 20),

                          // Address
                          TextFormField(
                            controller: _addressController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Address *',
                              hintText: 'Enter full address',
                              prefixIcon: Icon(Icons.location_on),
                              alignLabelWithHint: true,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Address is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Phone
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number (Optional)',
                              hintText: '+234...',
                              prefixIcon: Icon(Icons.phone),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Emergency Access Toggle
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.gray50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.emergency,
                                  color: AppTheme.warningColor,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Emergency Access',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Allow providers to access patient records in emergency situations',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.gray600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                kIsIOS
                                    ? CupertinoSwitch(
                                        value: _supportsEmergencyAccess,
                                        onChanged: (value) {
                                          setState(() => _supportsEmergencyAccess = value);
                                        },
                                      )
                                    : Switch(
                                        value: _supportsEmergencyAccess,
                                        onChanged: (value) {
                                          setState(() => _supportsEmergencyAccess = value);
                                        },
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    height: 56,
                    child: AdaptiveFilledButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : Icon(_isEditing ? Icons.save : Icons.add),
                      child: Text(
                        _isLoading
                            ? 'Saving...'
                            : _isEditing
                                ? 'Update Facility'
                                : 'Create Facility',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Cancel Button
                  SizedBox(
                    height: 56,
                    child: OutlinedButton(
                      onPressed: _isLoading 
                          ? null 
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),

                  // Required Fields Note
                  const SizedBox(height: 24),
                  Text(
                    '* Required fields',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.gray600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}