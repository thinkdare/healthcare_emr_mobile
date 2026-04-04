// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SubscriptionModel _$SubscriptionModelFromJson(Map<String, dynamic> json) =>
    SubscriptionModel(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      planType: json['plan_type'] as String,
      status: json['status'] as String,
      billingCycle: json['billing_cycle'] as String,
      amount: (json['amount'] as num).toInt(),
      currency: json['currency'] as String,
      currentPeriodStart: DateTime.parse(
        json['current_period_start'] as String,
      ),
      currentPeriodEnd: DateTime.parse(json['current_period_end'] as String),
      autoRenew: json['auto_renew'] as bool,
      trialEndsAt: json['trial_ends_at'] == null
          ? null
          : DateTime.parse(json['trial_ends_at'] as String),
      cancelledAt: json['cancelled_at'] == null
          ? null
          : DateTime.parse(json['cancelled_at'] as String),
      endsAt: json['ends_at'] == null
          ? null
          : DateTime.parse(json['ends_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$SubscriptionModelToJson(SubscriptionModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'organization_id': instance.organizationId,
      'plan_type': instance.planType,
      'status': instance.status,
      'billing_cycle': instance.billingCycle,
      'amount': instance.amount,
      'currency': instance.currency,
      'current_period_start': instance.currentPeriodStart.toIso8601String(),
      'current_period_end': instance.currentPeriodEnd.toIso8601String(),
      'auto_renew': instance.autoRenew,
      'trial_ends_at': instance.trialEndsAt?.toIso8601String(),
      'cancelled_at': instance.cancelledAt?.toIso8601String(),
      'ends_at': instance.endsAt?.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };

TrialStatusModel _$TrialStatusModelFromJson(Map<String, dynamic> json) =>
    TrialStatusModel(
      subscriptionStatus: json['subscription_status'] as String,
      isActive: json['is_active'] as bool,
      onTrial: json['on_trial'] as bool,
      trialEndsAt: json['trial_ends_at'] == null
          ? null
          : DateTime.parse(json['trial_ends_at'] as String),
      trialDaysRemaining: (json['trial_days_remaining'] as num).toInt(),
      maxFacilities: (json['max_facilities'] as num).toInt(),
      maxProviders: (json['max_providers'] as num).toInt(),
      currentFacilities: (json['current_facilities'] as num).toInt(),
      currentProviders: (json['current_providers'] as num).toInt(),
      canAddFacility: json['can_add_facility'] as bool,
      canAddProvider: json['can_add_provider'] as bool,
    );

Map<String, dynamic> _$TrialStatusModelToJson(TrialStatusModel instance) =>
    <String, dynamic>{
      'subscription_status': instance.subscriptionStatus,
      'is_active': instance.isActive,
      'on_trial': instance.onTrial,
      'trial_ends_at': instance.trialEndsAt?.toIso8601String(),
      'trial_days_remaining': instance.trialDaysRemaining,
      'max_facilities': instance.maxFacilities,
      'max_providers': instance.maxProviders,
      'current_facilities': instance.currentFacilities,
      'current_providers': instance.currentProviders,
      'can_add_facility': instance.canAddFacility,
      'can_add_provider': instance.canAddProvider,
    };

PricingTierModel _$PricingTierModelFromJson(Map<String, dynamic> json) =>
    PricingTierModel(
      name: json['name'] as String,
      organizationFee: json['organization_fee'] as String,
      facilityFee: json['facility_fee'] as String,
      providerFee: json['provider_fee'] as String,
      maxProviders: json['max_providers'],
    );

Map<String, dynamic> _$PricingTierModelToJson(PricingTierModel instance) =>
    <String, dynamic>{
      'name': instance.name,
      'organization_fee': instance.organizationFee,
      'facility_fee': instance.facilityFee,
      'provider_fee': instance.providerFee,
      'max_providers': instance.maxProviders,
    };

PricingDisplayModel _$PricingDisplayModelFromJson(Map<String, dynamic> json) =>
    PricingDisplayModel(
      small: PricingTierModel.fromJson(json['small'] as Map<String, dynamic>),
      medium: PricingTierModel.fromJson(json['medium'] as Map<String, dynamic>),
      large: PricingTierModel.fromJson(json['large'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PricingDisplayModelToJson(
  PricingDisplayModel instance,
) => <String, dynamic>{
  'small': instance.small,
  'medium': instance.medium,
  'large': instance.large,
};

QuoteModel _$QuoteModelFromJson(Map<String, dynamic> json) => QuoteModel(
  tier: json['tier'] as String,
  currency: json['currency'] as String,
  breakdown: Map<String, int>.from(json['breakdown'] as Map),
  totalAnnualKobo: (json['total_annual_kobo'] as num).toInt(),
  totalAnnualNaira: (json['total_annual_naira'] as num).toDouble(),
  totalMonthlyKobo: (json['total_monthly_kobo'] as num).toInt(),
  totalMonthlyNaira: (json['total_monthly_naira'] as num).toDouble(),
  numFacilities: (json['num_facilities'] as num).toInt(),
  numProviders: (json['num_providers'] as num).toInt(),
  billingCycle: json['billing_cycle'] as String?,
  trialDays: (json['trial_days'] as num?)?.toInt(),
);

Map<String, dynamic> _$QuoteModelToJson(QuoteModel instance) =>
    <String, dynamic>{
      'tier': instance.tier,
      'currency': instance.currency,
      'breakdown': instance.breakdown,
      'total_annual_kobo': instance.totalAnnualKobo,
      'total_annual_naira': instance.totalAnnualNaira,
      'total_monthly_kobo': instance.totalMonthlyKobo,
      'total_monthly_naira': instance.totalMonthlyNaira,
      'num_facilities': instance.numFacilities,
      'num_providers': instance.numProviders,
      'billing_cycle': instance.billingCycle,
      'trial_days': instance.trialDays,
    };

OrganizationRegistrationResponseModel
_$OrganizationRegistrationResponseModelFromJson(Map<String, dynamic> json) =>
    OrganizationRegistrationResponseModel(
      organization: OrganizationEnhancedModel.fromJson(
        json['organization'] as Map<String, dynamic>,
      ),
      adminUser: json['admin_user'] as Map<String, dynamic>,
      token: json['token'] as String,
      tokenType: json['token_type'] as String,
      trialEndsAt: DateTime.parse(json['trial_ends_at'] as String),
      trialDaysRemaining: (json['trial_days_remaining'] as num).toInt(),
      pricing: QuoteModel.fromJson(json['pricing'] as Map<String, dynamic>),
      nextStep: json['next_step'] as String,
    );

Map<String, dynamic> _$OrganizationRegistrationResponseModelToJson(
  OrganizationRegistrationResponseModel instance,
) => <String, dynamic>{
  'organization': instance.organization,
  'admin_user': instance.adminUser,
  'token': instance.token,
  'token_type': instance.tokenType,
  'trial_ends_at': instance.trialEndsAt.toIso8601String(),
  'trial_days_remaining': instance.trialDaysRemaining,
  'pricing': instance.pricing,
  'next_step': instance.nextStep,
};

InvoiceModel _$InvoiceModelFromJson(Map<String, dynamic> json) => InvoiceModel(
  id: json['id'] as String,
  organizationId: json['organization_id'] as String,
  invoiceNumber: json['invoice_number'] as String,
  amount: (json['amount'] as num).toInt(),
  currency: json['currency'] as String,
  status: json['status'] as String,
  dueDate: DateTime.parse(json['due_date'] as String),
  paidAt: json['paid_at'] == null
      ? null
      : DateTime.parse(json['paid_at'] as String),
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$InvoiceModelToJson(InvoiceModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'organization_id': instance.organizationId,
      'invoice_number': instance.invoiceNumber,
      'amount': instance.amount,
      'currency': instance.currency,
      'status': instance.status,
      'due_date': instance.dueDate.toIso8601String(),
      'paid_at': instance.paidAt?.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
    };
