import 'package:json_annotation/json_annotation.dart';
import 'organization_models_enhanced.dart';

part 'subscription_models.g.dart';

// Subscription Model
@JsonSerializable()
class SubscriptionModel {
  final String id;
  
  @JsonKey(name: 'organization_id')
  final String organizationId;
  
  @JsonKey(name: 'plan_type')
  final String planType;
  
  final String status; // 'trial', 'active', 'past_due', 'cancelled', 'suspended'
  
  @JsonKey(name: 'billing_cycle')
  final String billingCycle; // 'monthly', 'annual'
  
  final int amount; // in kobo
  final String currency;
  
  @JsonKey(name: 'current_period_start')
  final DateTime currentPeriodStart;
  
  @JsonKey(name: 'current_period_end')
  final DateTime currentPeriodEnd;
  
  @JsonKey(name: 'auto_renew')
  final bool autoRenew;
  
  @JsonKey(name: 'trial_ends_at')
  final DateTime? trialEndsAt;
  
  @JsonKey(name: 'cancelled_at')
  final DateTime? cancelledAt;
  
  @JsonKey(name: 'ends_at')
  final DateTime? endsAt;
  
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  SubscriptionModel({
    required this.id,
    required this.organizationId,
    required this.planType,
    required this.status,
    required this.billingCycle,
    required this.amount,
    required this.currency,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    required this.autoRenew,
    this.trialEndsAt,
    this.cancelledAt,
    this.endsAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionModelFromJson(json);

  Map<String, dynamic> toJson() => _$SubscriptionModelToJson(this);

  bool get isActive => status == 'active' || status == 'trial';
  bool get isTrial => status == 'trial';
  bool get isPastDue => status == 'past_due';
  bool get isCancelled => status == 'cancelled';
  
  int? get daysRemaining {
    if (status == 'trial' && trialEndsAt != null) {
      return trialEndsAt!.difference(DateTime.now()).inDays;
    }
    return null;
  }
  
  String get formattedAmount {
    final naira = amount / 100;
    return '₦${naira.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }
}

// Trial Status Model
@JsonSerializable()
class TrialStatusModel {
  @JsonKey(name: 'subscription_status')
  final String subscriptionStatus;
  
  @JsonKey(name: 'is_active')
  final bool isActive;
  
  @JsonKey(name: 'on_trial')
  final bool onTrial;
  
  @JsonKey(name: 'trial_ends_at')
  final DateTime? trialEndsAt;
  
  @JsonKey(name: 'trial_days_remaining')
  final int trialDaysRemaining;
  
  @JsonKey(name: 'max_facilities')
  final int maxFacilities;
  
  @JsonKey(name: 'max_providers')
  final int maxProviders;
  
  @JsonKey(name: 'current_facilities')
  final int currentFacilities;
  
  @JsonKey(name: 'current_providers')
  final int currentProviders;
  
  @JsonKey(name: 'can_add_facility')
  final bool canAddFacility;
  
  @JsonKey(name: 'can_add_provider')
  final bool canAddProvider;

  TrialStatusModel({
    required this.subscriptionStatus,
    required this.isActive,
    required this.onTrial,
    this.trialEndsAt,
    required this.trialDaysRemaining,
    required this.maxFacilities,
    required this.maxProviders,
    required this.currentFacilities,
    required this.currentProviders,
    required this.canAddFacility,
    required this.canAddProvider,
  });

  factory TrialStatusModel.fromJson(Map<String, dynamic> json) =>
      _$TrialStatusModelFromJson(json);

  Map<String, dynamic> toJson() => _$TrialStatusModelToJson(this);
}

// Pricing Tier Model
@JsonSerializable()
class PricingTierModel {
  final String name;
  
  @JsonKey(name: 'organization_fee')
  final String organizationFee;
  
  @JsonKey(name: 'facility_fee')
  final String facilityFee;
  
  @JsonKey(name: 'provider_fee')
  final String providerFee;
  
  @JsonKey(name: 'max_providers')
  final dynamic maxProviders; // can be int or string like "50+"

  PricingTierModel({
    required this.name,
    required this.organizationFee,
    required this.facilityFee,
    required this.providerFee,
    required this.maxProviders,
  });

  factory PricingTierModel.fromJson(Map<String, dynamic> json) =>
      _$PricingTierModelFromJson(json);

  Map<String, dynamic> toJson() => _$PricingTierModelToJson(this);
}

// Pricing Display Model
@JsonSerializable()
class PricingDisplayModel {
  final PricingTierModel small;
  final PricingTierModel medium;
  final PricingTierModel large;

  PricingDisplayModel({
    required this.small,
    required this.medium,
    required this.large,
  });

  factory PricingDisplayModel.fromJson(Map<String, dynamic> json) =>
      _$PricingDisplayModelFromJson(json);

  Map<String, dynamic> toJson() => _$PricingDisplayModelToJson(this);
}

// Quote Model
@JsonSerializable()
class QuoteModel {
  final String tier;
  final String currency;
  
  final Map<String, int> breakdown;
  
  @JsonKey(name: 'total_annual_kobo')
  final int totalAnnualKobo;
  
  @JsonKey(name: 'total_annual_naira')
  final double totalAnnualNaira;
  
  @JsonKey(name: 'total_monthly_kobo')
  final int totalMonthlyKobo;
  
  @JsonKey(name: 'total_monthly_naira')
  final double totalMonthlyNaira;
  
  @JsonKey(name: 'num_facilities')
  final int numFacilities;
  
  @JsonKey(name: 'num_providers')
  final int numProviders;
  
  @JsonKey(name: 'billing_cycle')
  final String? billingCycle;
  
  @JsonKey(name: 'trial_days')
  final int? trialDays;

  QuoteModel({
    required this.tier,
    required this.currency,
    required this.breakdown,
    required this.totalAnnualKobo,
    required this.totalAnnualNaira,
    required this.totalMonthlyKobo,
    required this.totalMonthlyNaira,
    required this.numFacilities,
    required this.numProviders,
    this.billingCycle,
    this.trialDays,
  });

  factory QuoteModel.fromJson(Map<String, dynamic> json) =>
      _$QuoteModelFromJson(json);

  Map<String, dynamic> toJson() => _$QuoteModelToJson(this);
  
  String get formattedTotal {
    final amount = billingCycle == 'annual' ? totalAnnualNaira : totalMonthlyNaira;
    return '₦${amount.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }
}

// Organization Registration Response Model
@JsonSerializable()
class OrganizationRegistrationResponseModel {
  final OrganizationEnhancedModel organization;
  
  @JsonKey(name: 'admin_user')
  final Map<String, dynamic> adminUser;
  
  final String token;
  
  @JsonKey(name: 'token_type')
  final String tokenType;
  
  @JsonKey(name: 'trial_ends_at')
  final DateTime trialEndsAt;
  
  @JsonKey(name: 'trial_days_remaining')
  final int trialDaysRemaining;
  
  final QuoteModel pricing;
  
  @JsonKey(name: 'next_step')
  final String nextStep;

  OrganizationRegistrationResponseModel({
    required this.organization,
    required this.adminUser,
    required this.token,
    required this.tokenType,
    required this.trialEndsAt,
    required this.trialDaysRemaining,
    required this.pricing,
    required this.nextStep,
  });

  factory OrganizationRegistrationResponseModel.fromJson(
          Map<String, dynamic> json) =>
      _$OrganizationRegistrationResponseModelFromJson(json);

  Map<String, dynamic> toJson() =>
      _$OrganizationRegistrationResponseModelToJson(this);
}

// Invoice Model
@JsonSerializable()
class InvoiceModel {
  final String id;
  
  @JsonKey(name: 'organization_id')
  final String organizationId;
  
  @JsonKey(name: 'invoice_number')
  final String invoiceNumber;
  
  final int amount;
  final String currency;
  final String status; // 'pending', 'paid', 'overdue', 'cancelled'
  
  @JsonKey(name: 'due_date')
  final DateTime dueDate;
  
  @JsonKey(name: 'paid_at')
  final DateTime? paidAt;
  
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  InvoiceModel({
    required this.id,
    required this.organizationId,
    required this.invoiceNumber,
    required this.amount,
    required this.currency,
    required this.status,
    required this.dueDate,
    this.paidAt,
    required this.createdAt,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) =>
      _$InvoiceModelFromJson(json);

  Map<String, dynamic> toJson() => _$InvoiceModelToJson(this);
  
  String get formattedAmount {
    final naira = amount / 100;
    return '₦${naira.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }
}