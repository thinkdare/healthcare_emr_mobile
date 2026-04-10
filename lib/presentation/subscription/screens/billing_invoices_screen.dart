import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/subscription_provider.dart';
import '../../../data/models/subscription_models.dart';
import '../../../config/theme.dart';

class BillingInvoicesScreen extends StatefulWidget {
  const BillingInvoicesScreen({super.key});

  @override
  State<BillingInvoicesScreen> createState() => _BillingInvoicesScreenState();
}

class _BillingInvoicesScreenState extends State<BillingInvoicesScreen> {
  String? _orgId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _orgId = context.read<AuthProvider>().organizationId;
      if (_orgId != null) {
        context.read<SubscriptionProvider>().loadInvoices(_orgId!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing & Invoices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_orgId != null) {
                context.read<SubscriptionProvider>().loadInvoices(_orgId!);
              }
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<SubscriptionProvider>(
        builder: (context, subscriptionProvider, child) {
          if (subscriptionProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final invoices = subscriptionProvider.invoices;

          if (invoices.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 80,
                    color: AppTheme.gray600.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Invoices Yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.gray900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your billing history will appear here',
                    style: TextStyle(color: AppTheme.gray600),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => _orgId != null
              ? subscriptionProvider.loadInvoices(_orgId!)
              : Future.value(),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isWeb ? 32 : 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isWeb ? 900 : double.infinity),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Stats
                      if (isWeb) _buildStatsCards(invoices),
                      if (isWeb) const SizedBox(height: 24),

                      // Invoices List
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: invoices.length,
                        itemBuilder: (context, index) {
                          return _buildInvoiceCard(invoices[index]);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsCards(List<InvoiceModel> invoices) {
    final totalPaid = invoices
        .where((i) => i.status == 'paid')
        .fold(0, (sum, i) => sum + i.totalAmount);
    
    final paidCount = invoices.where((i) => i.status == 'paid').length;
    final pendingCount = invoices.where((i) =>
        i.status == 'sent' || i.status == 'viewed' || i.status == 'partially_paid').length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Paid',
            '₦${(totalPaid / 100).toStringAsFixed(2)}',
            Icons.payment,
            AppTheme.successColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Paid Invoices',
            paidCount.toString(),
            Icons.check_circle,
            AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Pending',
            pendingCount.toString(),
            Icons.pending,
            AppTheme.warningColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.gray600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceCard(InvoiceModel invoice) {
    Color statusColor = AppTheme.gray600;
    IconData statusIcon = Icons.help_outline;
    
    switch (invoice.status) {
      case 'paid':
        statusColor = AppTheme.successColor;
        statusIcon = Icons.check_circle;
        break;
      case 'sent':
      case 'viewed':
        statusColor = AppTheme.warningColor;
        statusIcon = Icons.mail_outline;
        break;
      case 'partially_paid':
        statusColor = AppTheme.warningColor;
        statusIcon = Icons.pending;
        break;
      case 'overdue':
        statusColor = AppTheme.errorColor;
        statusIcon = Icons.error;
        break;
      case 'cancelled':
      case 'refunded':
        statusColor = AppTheme.gray600;
        statusIcon = Icons.cancel;
        break;
      case 'draft':
      default:
        statusColor = AppTheme.gray600;
        statusIcon = Icons.draft_outlined;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          _showInvoiceDetails(invoice);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Invoice Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.receipt, color: statusColor),
                  ),
                  const SizedBox(width: 16),
                  
                  // Invoice Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoice.invoiceNumber,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(invoice.invoiceDate ?? invoice.dueDate ?? DateTime.now()),
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.gray600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Amount & Status
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        invoice.formattedTotal,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 14, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              invoice.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              // Due Date (if applicable)
              if (invoice.status == 'sent' || invoice.status == 'viewed' ||
                  invoice.status == 'partially_paid' || invoice.status == 'overdue') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: invoice.isOverdue
                        ? AppTheme.errorColor.withValues(alpha: 0.1)
                        : AppTheme.gray50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color: invoice.isOverdue
                            ? AppTheme.errorColor
                            : AppTheme.gray600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Due: ${invoice.dueDate != null ? _formatDate(invoice.dueDate!) : 'N/A'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: invoice.isOverdue
                              ? AppTheme.errorColor
                              : AppTheme.gray600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showInvoiceDetails(InvoiceModel invoice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.gray600.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Invoice Details',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          invoice.invoiceNumber,
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.gray600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 32),

              // Details
              _buildDetailRow('Invoice Number', invoice.invoiceNumber),
              _buildDetailRow('Amount', invoice.formattedTotal),
              _buildDetailRow('Currency', invoice.currency),
              _buildDetailRow('Status', invoice.status.toUpperCase()),
              _buildDetailRow('Invoice Date', invoice.invoiceDate != null ? _formatDate(invoice.invoiceDate!) : '—'),
              _buildDetailRow('Due Date', invoice.dueDate != null ? _formatDate(invoice.dueDate!) : '—'),
              if (invoice.paidAt != null)
                _buildDetailRow('Paid On', _formatDate(invoice.paidAt!)),

              const SizedBox(height: 24),

              // Actions
              if (invoice.status == 'sent' || invoice.status == 'overdue' ||
                  invoice.status == 'partially_paid') ...[
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Implement payment
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Payment feature coming soon'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.payment),
                    label: const Text('Pay Now'),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: Implement download
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Download feature coming soon'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Download PDF'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}