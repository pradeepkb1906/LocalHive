/// Template for the payment worker.
///
/// Copy to lib/payment_config.dart and set baseUrl to the deployed
/// localhive-payments Worker, e.g. https://localhive-payments.<sub>.workers.dev
///
/// Notice what is NOT here: there is no Stripe key of any kind. The secret
/// key lives only as a Worker secret. Even Stripe's *publishable* key is
/// absent, because this app uses hosted Checkout — the customer is sent to
/// Stripe's own page, so the app needs no Stripe SDK and no Stripe
/// credentials at all.
///
/// Leave baseUrl empty and card payment is simply switched off: orders fall
/// back to paying the shop in person, exactly as they do today.
library;

class PaymentConfig {
  static const baseUrl = '';

  /// Card payment only turns on once a worker URL is configured.
  static bool get enabled => baseUrl.isNotEmpty;
}
