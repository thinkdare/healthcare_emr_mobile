import 'package:flutter/material.dart';
import '../../../data/models/subscription_models.dart';
import '../../../config/theme.dart';

class TrialWelcomeScreen extends StatelessWidget {
  final OrganizationRegistrationResponseModel response;

  const TrialWelcomeScreen({
    super.key,
    required this.response,
  });

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isWeb ? 48 : 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWeb ? 700 : double.infinity),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Success Icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Success Message
                  Text(
                    'Welcome to EMR System!',
                    style: TextStyle(
                      fontSize: isWeb ? 36 : 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.gray900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your organization has been successfully registered',
                    style: TextStyle(
                      fontSize: isWeb ? 18 : 16,
                      color: AppTheme.gray600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Trial Info Card
                  Card(
                    elevation: 2,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.successColor.withValues(alpha: 0.1),
                            AppTheme.successColor.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.celebration,
                            size: 48,
                            color: AppTheme.successColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '30-Day Free Trial Activated!',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.successColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your trial ends on ${_formatDate(response.trialEndsAt)}',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.gray600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          _buildInfoRow(
                            'Trial Days',
                            '${response.trialDaysRemaining} days',
                          ),
                          _buildInfoRow(
                            'Max Facilities',
                            '${response.organization.maxFacilities}',
                          ),
                          _buildInfoRow(
                            'Max Providers',
                            '${response.organization.maxProviders}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Organization Details Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.business, color: AppTheme.primaryColor),
                              const SizedBox(width: 8),
                              const Text(
                                'Organization Details',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          _buildDetailRow('Name', response.organization.name),
                          _buildDetailRow('Type', _getOrganizationType(response.organization.type)),
                          _buildDetailRow('Email', response.organization.email ?? '-'),
                          _buildDetailRow('Phone', response.organization.phone ?? '-'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Admin Details Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.admin_panel_settings, color: AppTheme.primaryColor),
                              const SizedBox(width: 8),
                              const Text(
                                'Administrator Account',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          _buildDetailRow(
                            'Name',
                            '${response.adminUser['first_name']} ${response.adminUser['last_name']}',
                          ),
                          _buildDetailRow('Email', response.adminUser['email']),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: AppTheme.primaryColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Use this email to login to your admin dashboard',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.primaryColor,
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
                  const SizedBox(height: 32),

                  // Next Steps Section
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.gray50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next Steps',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.gray900,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildNextStep(
                          1,
                          'Add Facilities',
                          'Set up your branches and locations',
                          Icons.location_city,
                        ),
                        const SizedBox(height: 12),
                        _buildNextStep(
                          2,
                          'Invite Providers',
                          'Add doctors, nurses, and staff members',
                          Icons.people,
                        ),
                        const SizedBox(height: 12),
                        _buildNextStep(
                          3,
                          'Explore Features',
                          'Start managing patient records',
                          Icons.explore,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),

                  // CTA Buttons
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Navigate to admin dashboard
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/admin/dashboard',
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.dashboard),
                      label: const Text('Go to Dashboard'),
                      style: ElevatedButton.styleFrom(
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Navigate to facilities
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/facilities',
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.add_business),
                      label: const Text('Add Facilities'),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Help Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.gray600.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.support_agent, color: AppTheme.gray600),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Need Help?',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Contact us at support@emrsystem.com',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.gray600,
                                ),
                              ),
                            ],
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
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getOrganizationType(String type) {
    const types = {
      'hospital': 'Hospital',
      'clinic': 'Clinic',
      'pharmacy': 'Pharmacy',
      'lab': 'Laboratory',
      'diagnostic_center': 'Diagnostic Center',
    };
    return types[type] ?? type;
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.gray600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                color: AppTheme.gray600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextStep(int step, String title, String description, IconData icon) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
          ),
          child: Center(
            child: Icon(icon, color: AppTheme.primaryColor, size: 20),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.gray600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.gray100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Step $step',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.gray600,
            ),
          ),
        ),
      ],
    );
  }
}