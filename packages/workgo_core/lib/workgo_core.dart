/// WorkGo Core — shared library for all three WorkGo apps.
/// Import this single file to access theme, models, widgets, services.
library;

// Theme
export "src/theme/colors.dart";
export "src/theme/spacing.dart";
export "src/theme/motion.dart";
export "src/theme/app_theme.dart";
export "src/theme/typography.dart";
export "package:google_fonts/google_fonts.dart";

// Localization (easy_localization config constants & extensions)
export "src/localization/locale_config.dart";
export "src/localization/trade_localization.dart";

// Models
export "src/models/app_user.dart";
export "src/models/user_address.dart";
export "src/models/worker.dart";
export "src/models/booking.dart";
export "src/models/rating_org_demand.dart";
export "src/models/verification_audit_model.dart";
export "src/models/c2pa_manifest_model.dart";
export "src/models/symptom_catalog.dart";

// Widgets
export "src/widgets/safe_text.dart";
export "src/widgets/skeleton_loader.dart";
export "src/widgets/empty_state.dart";
export "src/widgets/glass_card.dart";
export "src/widgets/workgo_button.dart";
export "src/widgets/workgo_badge.dart";
export "src/widgets/star_rating.dart";
export "src/widgets/proxy_worker_dialog.dart";
export "src/widgets/exit_confirmation_bottom_sheet.dart";
export "src/widgets/sign_out_confirmation_bottom_sheet.dart";
export "src/widgets/delete_account_confirmation_bottom_sheet.dart";
export "src/widgets/workgo_avatar.dart";
export "src/widgets/checkout_motivation_bottom_sheet.dart";
export "src/widgets/location_prompt_dialog.dart";
export "src/widgets/address_management_sheet.dart";
export "src/widgets/peer_referral_network_sheet.dart";
export "src/widgets/workgo_splash_screen.dart";
export "src/widgets/c2pa_badge.dart";
export "src/widgets/interactive_rapido_map.dart";
export "src/widgets/live_map_view.dart";

// Auth Widgets
export "src/widgets/auth/auth_shell.dart";
export "src/widgets/auth/auth_role_badge.dart";
export "src/widgets/auth/auth_text_field.dart";
export "src/widgets/auth/sign_in_form.dart";
export "src/widgets/auth/sign_up_form.dart";
export "src/widgets/auth/forgot_password_form.dart";

// Services & Firebase
export "src/firebase_options.dart";
export "src/firebase/auth_service.dart";
export "src/services/booking_service.dart";
export "src/services/worker_service.dart";
export "src/services/pricing_engine.dart";
export "src/services/broadcast_alert_service.dart";
export "src/services/image_upload_service.dart";
export "src/services/location_service.dart";
export "src/services/c2pa_service.dart";
export "src/services/biometric_service.dart";
export "src/services/aadhaar_offline_parser.dart";
export "src/services/road_routing_service.dart";
export "src/services/face_comparison_service.dart";
export "src/services/session_manager.dart";
export "src/services/ai_diagnostic_service.dart";
export "src/models/payment_provider_model.dart";
export "src/services/payment_service.dart";
export "src/services/invoice_service.dart";
export "src/services/indic_pdf_shaper.dart";
export "src/services/push_notification_service.dart";

// API Client & External Launchers
export "src/api_client/workgo_api_client.dart";
export "package:url_launcher/url_launcher.dart";
export "package:latlong2/latlong.dart" hide Path;
export "package:geolocator/geolocator.dart";
export "src/utils/workgo_time_format.dart";
export "src/utils/phone_dialer.dart";
