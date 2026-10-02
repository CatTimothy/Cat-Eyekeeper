/// Why a due reminder was held back — see core/reminder_guard.dart. The
/// dashboard/reminder UI maps this to localized text via AppLocalizations
/// rather than storing display strings here.
enum ReminderSuppressionReason { presenting, fullscreenVideo }
