import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/platform.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/patient_provider.dart';
import '../../../config/theme.dart';
import '../widgets/patient_card.dart';
import 'patient_form_screen.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showSearchBar = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<PatientProvider>().loadPatients(providerId: auth.currentUserId);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Infinite scroll — load more when near the bottom
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final auth = context.read<AuthProvider>();
      context
          .read<PatientProvider>()
          .loadMore(providerId: auth.currentUserId);
    }
  }

  Future<void> _onRefresh() async {
    final auth = context.read<AuthProvider>();
    context.read<PatientProvider>().clearSearch();
    _searchController.clear();
    await context.read<PatientProvider>().loadPatients(
          providerId: auth.currentUserId,
          forceRefresh: true,
        );
  }

  void _onSearchChanged(String query) {
    final auth = context.read<AuthProvider>();
    context.read<PatientProvider>().search(
          query,
          providerId: auth.currentUserId,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            kIsIOS
                ? CupertinoPageRoute(
                    builder: (_) => const PatientFormScreen())
                : MaterialPageRoute(
                    builder: (_) => const PatientFormScreen()),
          );
          if (result != null && mounted) {
            showAdaptiveToast(context, 'Patient registered', type: ToastType.success);
          }
        },
        tooltip: 'New Patient',
        child: const Icon(Icons.person_add),
      ),
      appBar: kIsIOS
          ? CupertinoNavigationBar(
              middle: const Text('Patients'),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  setState(() => _showSearchBar = !_showSearchBar);
                  if (!_showSearchBar) {
                    _searchController.clear();
                    context.read<PatientProvider>().clearSearch();
                  }
                },
                child: Icon(_showSearchBar
                    ? CupertinoIcons.xmark
                    : CupertinoIcons.search),
              ),
            )
          : AppBar(
              title: _showSearchBar
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      cursorColor: Colors.white,
                      decoration: const InputDecoration(
                        hintText: 'Search by name, MRN, phone or email…',
                        hintStyle: TextStyle(color: Colors.white70),
                        border: InputBorder.none,
                        filled: false,
                      ),
                      onChanged: _onSearchChanged,
                    )
                  : const Text('Patients'),
              actions: [
                IconButton(
                  icon:
                      Icon(_showSearchBar ? Icons.close : Icons.search),
                  tooltip: _showSearchBar ? 'Close search' : 'Search',
                  onPressed: () {
                    setState(() => _showSearchBar = !_showSearchBar);
                    if (!_showSearchBar) {
                      _searchController.clear();
                      context.read<PatientProvider>().clearSearch();
                    }
                  },
                ),
              ],
            ),
      body: Consumer<PatientProvider>(
        builder: (context, patientProvider, _) {
          final isLoading = patientProvider.isLoading;
          final isSearching = patientProvider.isSearching;
          final error = patientProvider.error;
          final patients = patientProvider.displayList;
          final fromCache = patientProvider.patientsFromCache;
          final stats = patientProvider.stats;

          return Column(
            children: [
              // ── iOS search field ───────────────────────────────────────────
              if (kIsIOS && _showSearchBar)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: CupertinoSearchTextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    placeholder: 'Search by name, MRN, phone or email…',
                  ),
                ),

              // ── Offline/cache indicator ────────────────────────────────────
              if (fromCache && !isLoading)
                _CacheBanner(
                  lastRefreshed: stats.lastRefreshed,
                  onRefresh: _onRefresh,
                ),

              // ── Error banner ───────────────────────────────────────────────
              if (error != null)
                _ErrorBanner(
                  message: error,
                  onDismiss: () => patientProvider.clearError(),
                ),

              // ── Body ───────────────────────────────────────────────────────
              Expanded(
                child: isLoading && patients.isEmpty
                    ? Center(
                        child: kIsIOS
                            ? const CupertinoActivityIndicator()
                            : const CircularProgressIndicator(),
                      )
                    : isSearching
                        ? Center(
                            child: kIsIOS
                                ? const CupertinoActivityIndicator()
                                : const CircularProgressIndicator(),
                          )
                        : patients.isEmpty
                            ? _EmptyState(
                                isSearching: _showSearchBar &&
                                    _searchController.text.isNotEmpty,
                                searchQuery: _searchController.text,
                              )
                            : RefreshIndicator(
                                onRefresh: _onRefresh,
                                child: ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8),
                                  itemCount: patients.length +
                                      (patientProvider.isLoadingMore
                                          ? 1
                                          : 0),
                                  itemBuilder: (_, index) {
                                    if (index == patients.length) {
                                      return Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Center(
                                          child: kIsIOS
                                              ? const CupertinoActivityIndicator()
                                              : const CircularProgressIndicator(),
                                        ),
                                      );
                                    }
                                    return PatientCard(
                                      patient: patients[index],
                                    );
                                  },
                                ),
                              ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Cache indicator banner ────────────────────────────────────────────────────

class _CacheBanner extends StatelessWidget {
  final DateTime? lastRefreshed;
  final VoidCallback onRefresh;

  const _CacheBanner({this.lastRefreshed, required this.onRefresh});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.warningColor.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.offline_bolt,
              size: 16, color: AppTheme.warningColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              lastRefreshed != null
                  ? 'Showing cached data · last updated ${_timeAgo(lastRefreshed!)}'
                  : 'Showing cached data',
              style: TextStyle(
                  fontSize: 12, color: AppTheme.warningColor),
            ),
          ),
          AdaptiveTextButton(
            onPressed: onRefresh,
            child: const Text('Refresh',
                style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.errorColor.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              size: 16, color: AppTheme.errorColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.errorColor)),
          ),
          IconButton(
            icon: const Icon(Icons.close,
                size: 16, color: AppTheme.errorColor),
            onPressed: onDismiss,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isSearching;
  final String searchQuery;

  const _EmptyState(
      {required this.isSearching, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSearching ? Icons.search_off : Icons.people_outline,
              size: 64,
              color: AppTheme.gray600,
            ),
            const SizedBox(height: 16),
            Text(
              isSearching
                  ? 'No patients matching "$searchQuery"'
                  : 'No patients yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.gray600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'Try a different name, MRN, phone or email'
                  : 'Add your first patient to get started',
              style: TextStyle(fontSize: 13, color: AppTheme.gray600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}