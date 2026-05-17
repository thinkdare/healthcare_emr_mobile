// lib/presentation/referrals/screens/referrals_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/platform.dart';
import '../../../data/models/referral_models.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/referral_provider.dart';
import '../widgets/referral_card.dart';

class ReferralsScreen extends StatefulWidget {
  const ReferralsScreen({super.key});

  @override
  State<ReferralsScreen> createState() => _ReferralsScreenState();
}

class _ReferralsScreenState extends State<ReferralsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tenantId = context.read<AuthProvider>().activeTenantId ?? '';
      context.read<ReferralProvider>().loadReferrals(currentTenantId: tenantId);
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final tenantId = context.read<AuthProvider>().activeTenantId ?? '';
      context.read<ReferralProvider>().loadMore(currentTenantId: tenantId);
    }
  }

  @override
  Widget build(BuildContext context) {
    const title = 'Referrals';
    return kIsIOS
        ? CupertinoPageScaffold(
            navigationBar:
                const CupertinoNavigationBar(middle: Text(title)),
            child: SafeArea(
                child: _Body(scrollController: _scrollController)),
          )
        : Scaffold(
            appBar: AppBar(title: const Text(title)),
            body: _Body(scrollController: _scrollController),
          );
  }
}

class _Body extends StatelessWidget {
  final ScrollController scrollController;
  const _Body({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReferralProvider>(
      builder: (context, provider, _) => Column(
        children: [
          _FilterChips(provider: provider),
          if (provider.error != null)
            _ErrorBanner(
              message: provider.error!,
              onDismiss: provider.clearError,
            ),
          Expanded(
            child: provider.isLoading
                ? Center(
                    child: kIsIOS
                        ? const CupertinoActivityIndicator()
                        : const CircularProgressIndicator(),
                  )
                : RefreshIndicator(
                    onRefresh: () {
                      final tenantId = context
                              .read<AuthProvider>()
                              .activeTenantId ??
                          '';
                      return provider.loadReferrals(
                          refresh: true, currentTenantId: tenantId);
                    },
                    child: provider.referrals.isEmpty
                        ? _EmptyState(filter: provider.filter)
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.only(
                                top: 8, bottom: 24),
                            itemCount: provider.referrals.length +
                                (provider.isLoadingMore ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (i == provider.referrals.length) {
                                return const Padding(
                                  padding:
                                      EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                      child:
                                          CircularProgressIndicator()),
                                );
                              }
                              return ReferralCard(
                                  referral: provider.referrals[i]);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final ReferralProvider provider;
  const _FilterChips({required this.provider});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: ReferralFilter.values.map((f) {
          final selected = provider.filter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(f.label),
              selected: selected,
              onSelected: (_) => provider.setFilter(f),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ReferralFilter filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final message = switch (filter) {
      ReferralFilter.all =>
        'No referrals yet. Refer a patient from their profile.',
      ReferralFilter.pending => 'No pending referrals.',
      ReferralFilter.active  => 'No active referrals.',
      ReferralFilter.done    => 'No completed or cancelled referrals.',
    };
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(48),
          child: Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600)),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.red.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: TextStyle(
                      fontSize: 12, color: Colors.red.shade700))),
          IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: onDismiss),
        ],
      ),
    );
  }
}
