// Subscription and billing models — hand-written fromJson (no build_runner needed).
//
// Backend billing routes: /api/v1/billing/...
// Only org admins / super admins can access billing. Regular staff get 403.

// ── Plan ─────────────────────────────────────────────────────────────────────

class SubscriptionPlanModel {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String billingCycle; // 'monthly' | 'annual'
  final Map<String, double> prices; // {usd, eur, cad, ngn}
  final Map<String, dynamic> limits; // {max_facilities, max_staff, max_patients}
  final List<String> features;
  final bool isActive;
  final bool isPublic;

  const SubscriptionPlanModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.billingCycle,
    required this.prices,
    required this.limits,
    required this.features,
    required this.isActive,
    required this.isPublic,
  });

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    final rawPrices = json['prices'] as Map<String, dynamic>? ?? {};
    return SubscriptionPlanModel(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      billingCycle: json['billing_cycle'] as String? ?? 'monthly',
      prices: rawPrices.map((k, v) => MapEntry(k, (v as num).toDouble())),
      limits: Map<String, dynamic>.from(json['limits'] as Map? ?? {}),
      features: (json['features'] as List? ?? []).map((e) => e.toString()).toList(),
      isActive: json['is_active'] as bool? ?? true,
      isPublic: json['is_public'] as bool? ?? true,
    );
  }
}

// ── Subscription ──────────────────────────────────────────────────────────────

class SubscriptionModel {
  final String id;
  final String organizationId;
  final String planId;
  final SubscriptionPlanModel? plan;
  final String status; // 'trial' | 'active' | 'past_due' | 'cancelled' | 'suspended'
  final String currency;
  final int amount; // in smallest currency unit (kobo / cents)
  final String billingCycle; // 'monthly' | 'annual'
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final DateTime? trialEndsAt;
  final bool cancelAtPeriodEnd;
  final DateTime? cancelledAt;
  final DateTime? endsAt;
  final DateTime? createdAt;

  const SubscriptionModel({
    required this.id,
    required this.organizationId,
    required this.planId,
    this.plan,
    required this.status,
    required this.currency,
    required this.amount,
    required this.billingCycle,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.trialEndsAt,
    required this.cancelAtPeriodEnd,
    this.cancelledAt,
    this.endsAt,
    this.createdAt,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      planId: json['plan_id'] as String,
      plan: json['plan'] != null
          ? SubscriptionPlanModel.fromJson(
              Map<String, dynamic>.from(json['plan'] as Map))
          : null,
      status: json['status'] as String? ?? 'active',
      currency: json['currency'] as String? ?? 'NGN',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      billingCycle: json['billing_cycle'] as String? ?? 'monthly',
      currentPeriodStart: json['current_period_start'] != null
          ? DateTime.tryParse(json['current_period_start'] as String)
          : null,
      currentPeriodEnd: json['current_period_end'] != null
          ? DateTime.tryParse(json['current_period_end'] as String)
          : null,
      trialEndsAt: json['trial_ends_at'] != null
          ? DateTime.tryParse(json['trial_ends_at'] as String)
          : null,
      cancelAtPeriodEnd: json['cancel_at_period_end'] as bool? ?? false,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.tryParse(json['cancelled_at'] as String)
          : null,
      endsAt: json['ends_at'] != null
          ? DateTime.tryParse(json['ends_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  bool get isActive => status == 'active' || status == 'trial';
  bool get isTrial => status == 'trial';
  bool get isPastDue => status == 'past_due';
  bool get isCancelled => status == 'cancelled';

  int? get trialDaysRemaining {
    if (isTrial && trialEndsAt != null) {
      final days = trialEndsAt!.difference(DateTime.now()).inDays;
      return days < 0 ? 0 : days;
    }
    return null;
  }

  /// Display the amount in a human-readable format.
  /// Assumes NGN amounts are in kobo (divide by 100); USD/EUR in cents.
  String get formattedAmount {
    final major = amount / 100;
    final symbol = currency == 'NGN' ? '₦' : (currency == 'USD' ? '\$' : currency);
    return '$symbol${major.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    )}';
  }
}

// ── Invoice ───────────────────────────────────────────────────────────────────

class InvoiceItemModel {
  final String id;
  final String itemType;
  final String description;
  final int quantity;
  final int unitPrice;
  final int lineTotal;
  final String currency;

  const InvoiceItemModel({
    required this.id,
    required this.itemType,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.currency,
  });

  factory InvoiceItemModel.fromJson(Map<String, dynamic> json) {
    return InvoiceItemModel(
      id: json['id'] as String,
      itemType: json['item_type'] as String? ?? '',
      description: json['description'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (json['unit_price'] as num?)?.toInt() ?? 0,
      lineTotal: (json['line_total'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'NGN',
    );
  }
}

class InvoiceModel {
  final String id;
  final String organizationId;
  final String? subscriptionId;
  final String invoiceNumber;
  final String currency;
  final int subtotal;
  final int taxAmount;
  final int discountAmount;
  final int totalAmount;
  final int amountPaid;
  final int balanceDue;
  final String status; // 'draft'|'sent'|'viewed'|'partially_paid'|'paid'|'overdue'|'cancelled'|'refunded'
  final DateTime? invoiceDate;
  final DateTime? dueDate;
  final DateTime? servicePeriodStart;
  final DateTime? servicePeriodEnd;
  final bool isOverdue;
  final DateTime? sentAt;
  final DateTime? paidAt;
  final List<InvoiceItemModel> items;

  const InvoiceModel({
    required this.id,
    required this.organizationId,
    this.subscriptionId,
    required this.invoiceNumber,
    required this.currency,
    required this.subtotal,
    required this.taxAmount,
    required this.discountAmount,
    required this.totalAmount,
    required this.amountPaid,
    required this.balanceDue,
    required this.status,
    this.invoiceDate,
    this.dueDate,
    this.servicePeriodStart,
    this.servicePeriodEnd,
    required this.isOverdue,
    this.sentAt,
    this.paidAt,
    this.items = const [],
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? [];
    return InvoiceModel(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      subscriptionId: json['subscription_id'] as String?,
      invoiceNumber: json['invoice_number'] as String? ?? '',
      currency: json['currency'] as String? ?? 'NGN',
      subtotal: (json['subtotal'] as num?)?.toInt() ?? 0,
      taxAmount: (json['tax_amount'] as num?)?.toInt() ?? 0,
      discountAmount: (json['discount_amount'] as num?)?.toInt() ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toInt() ?? 0,
      amountPaid: (json['amount_paid'] as num?)?.toInt() ?? 0,
      balanceDue: (json['balance_due'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'draft',
      invoiceDate: json['invoice_date'] != null
          ? DateTime.tryParse(json['invoice_date'] as String)
          : null,
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'] as String)
          : null,
      servicePeriodStart: json['service_period_start'] != null
          ? DateTime.tryParse(json['service_period_start'] as String)
          : null,
      servicePeriodEnd: json['service_period_end'] != null
          ? DateTime.tryParse(json['service_period_end'] as String)
          : null,
      isOverdue: json['is_overdue'] as bool? ?? false,
      sentAt: json['sent_at'] != null
          ? DateTime.tryParse(json['sent_at'] as String)
          : null,
      paidAt: json['paid_at'] != null
          ? DateTime.tryParse(json['paid_at'] as String)
          : null,
      items: rawItems
          .map((e) =>
              InvoiceItemModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  bool get isPaid => status == 'paid';

  String get formattedTotal {
    final major = totalAmount / 100;
    final symbol = currency == 'NGN' ? '₦' : (currency == 'USD' ? '\$' : currency);
    return '$symbol${major.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    )}';
  }
}
