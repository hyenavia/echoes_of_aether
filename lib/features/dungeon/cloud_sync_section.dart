import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../application/services/account_service.dart';
import '../../application/services/cloud_sync_service.dart';
import '../../domain/repositories/cloud_save_repository.dart';
import '../shared/widgets/shared_widgets.dart';

typedef EmailAuthAction = Future<EmailAuthOutcome> Function({
  required String email,
  required String password,
});

typedef PasswordResetAction = Future<PasswordResetOutcome> Function({
  required String email,
});

enum _EmailAuthMode { link, signIn }

/// Bagian UI minimal untuk Cloud Save & Akun pada Pengaturan (`DESIGN §1.4`).
///
/// Seluruh logika sinkronisasi, autentikasi, dan pemulihan berada di layer
/// aplikasi (`CloudSyncService` / `AccountService`); widget ini hanya membaca
/// [CloudSyncStatusSnapshot] dan meneruskan niat pengguna lewat callback.
class CloudSyncSection extends StatefulWidget {
  const CloudSyncSection({
    super.key,
    required this.status,
    required this.isDungeonRunActive,
    this.onSectionOpened,
    this.onLinkEmail,
    this.onSignInEmail,
    this.onResetPassword,
    this.onAccountSwitchConflict,
    this.onSignOut,
    this.onSyncNow,
    this.onConfirmRestore,
  });

  final CloudSyncStatusSnapshot status;
  final bool isDungeonRunActive;
  final VoidCallback? onSectionOpened;
  final EmailAuthAction? onLinkEmail;
  final EmailAuthAction? onSignInEmail;
  final PasswordResetAction? onResetPassword;
  final Future<void> Function()? onAccountSwitchConflict;
  final Future<void> Function()? onSignOut;
  final Future<void> Function()? onSyncNow;
  final Future<void> Function()? onConfirmRestore;

  @override
  State<CloudSyncSection> createState() => _CloudSyncSectionState();
}

class _CloudSyncSectionState extends State<CloudSyncSection> {
  bool _busy = false;
  String? _localWarning;

  @override
  void initState() {
    super.initState();
    if (widget.onSectionOpened != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onSectionOpened?.call();
        }
      });
    }
  }

  Future<void> _runGuarded(Future<void> Function()? action) async {
    if (_busy || action == null) return;
    setState(() {
      _busy = true;
      _localWarning = null;
    });
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _handleEmailAuthPressed() async {
    if (_busy) return;
    final outcome = await showEmailAuthDialog(
      context,
      onLinkEmail: widget.onLinkEmail,
      onSignInEmail: widget.onSignInEmail,
      onResetPassword: widget.onResetPassword,
      preferLink: widget.status.account.kind == CloudAccountKind.anonymous,
    );
    if (!mounted) return;
    if (outcome is EmailAuthSwitchedAccountConflict) {
      if (widget.onAccountSwitchConflict != null) {
        await widget.onAccountSwitchConflict!();
      } else if (widget.onConfirmRestore != null) {
        final confirmed = await showCloudConflictDialog(
          context,
          kind: CloudConflictKind.accountSwitch,
          cloudMeta: widget.status.pendingCloudMeta,
          isDungeonRunActive: widget.isDungeonRunActive,
        );
        if (confirmed && mounted) {
          await _runGuarded(widget.onConfirmRestore);
        }
      }
    }
  }

  Future<void> _handleRestorePressed() async {
    if (_busy) return;
    if (widget.isDungeonRunActive) {
      setState(() {
        _localWarning = 'Pemulihan diblokir saat dungeon run aktif. Selesaikan atau keluar ke Town terlebih dahulu.';
      });
      return;
    }
    final confirmed = await showCloudRestoreConfirmDialog(
      context,
      cloudMeta: widget.status.pendingCloudMeta,
      isDungeonRunActive: widget.isDungeonRunActive,
    );
    if (!confirmed || !mounted) return;
    await _runGuarded(widget.onConfirmRestore);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.status;
    final account = s.account;
    final isUnavailable = s.phase == CloudSyncPhase.unavailable;
    final isSyncing = _busy || s.phase == CloudSyncPhase.syncing;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Cloud Save & Akun', useSerif: true),
        const SizedBox(height: AppSpacing.xs),
        PanelFrame(
          backgroundColor: AppColors.surfaceDark,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(
                label: 'Akun',
                value: formatCloudAccountLabel(account),
                valueKey: const Key('cloud_account_label'),
              ),
              if (account.kind == CloudAccountKind.anonymous) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Tautkan email agar save cloud tidak hilang jika aplikasi dihapus.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              _InfoRow(
                label: 'Status',
                value: formatCloudSyncStatusLabel(s),
                valueKey: const Key('cloud_sync_status_label'),
                valueColor: _statusColor(theme, s.phase),
              ),
              if (s.lastSyncAtMs != null) ...[
                const SizedBox(height: AppSpacing.xs),
                _InfoRow(
                  label: 'Sinkron terakhir',
                  value:
                      '${formatEpochMs(s.lastSyncAtMs!)} (Rev ${s.lastSyncedRevision})',
                  valueKey: const Key('cloud_last_sync_label'),
                ),
              ],
              if (s.lastRejectMessage != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Penolakan terakhir: ${s.lastRejectMessage}',
                  key: const Key('cloud_last_reject_label'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              if (s.infoMessage != null &&
                  s.lastRejectMessage == null &&
                  s.phase != CloudSyncPhase.unavailable) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  s.infoMessage!,
                  key: const Key('cloud_info_message_label'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              if (_localWarning != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _localWarning!,
                  key: const Key('cloud_restore_blocked_label'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              if (!isUnavailable) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    if (!account.isEmailLinked &&
                        (widget.onLinkEmail != null ||
                            widget.onSignInEmail != null))
                      SecondaryButton(
                        key: const Key('cloud_link_email_btn'),
                        label: account.kind == CloudAccountKind.anonymous
                            ? 'Tautkan Email'
                            : 'Masuk / Tautkan Email',
                        icon: Icons.email_outlined,
                        onPressed: isSyncing ? null : _handleEmailAuthPressed,
                      ),
                    if (account.isSignedIn && widget.onSignOut != null)
                      SecondaryButton(
                        key: const Key('cloud_sign_out_btn'),
                        label: 'Keluar',
                        icon: Icons.logout,
                        onPressed: isSyncing
                            ? null
                            : () => _runGuarded(widget.onSignOut),
                      ),
                    if (widget.onSyncNow != null)
                      PrimaryButton(
                        key: const Key('cloud_sync_now_btn'),
                        label: isSyncing
                            ? 'Menyinkronkan...'
                            : 'Sinkronkan sekarang',
                        icon: Icons.cloud_upload_outlined,
                        onPressed: isSyncing
                            ? null
                            : () => _runGuarded(widget.onSyncNow),
                      ),
                    if (widget.onConfirmRestore != null)
                      SecondaryButton(
                        key: const Key('cloud_restore_btn'),
                        label: 'Pulihkan dari cloud',
                        icon: Icons.cloud_download_outlined,
                        onPressed: isSyncing ? null : _handleRestorePressed,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Color _statusColor(ThemeData theme, CloudSyncPhase phase) {
    return switch (phase) {
      CloudSyncPhase.synced => AppColors.success,
      CloudSyncPhase.rejected ||
      CloudSyncPhase.conflict => theme.colorScheme.error,
      CloudSyncPhase.unavailable => AppColors.textMuted,
      CloudSyncPhase.offline => AppColors.campAmber,
      CloudSyncPhase.syncing ||
      CloudSyncPhase.pendingChanges => AppColors.antiqueGold,
      CloudSyncPhase.unauthenticated => AppColors.textSecondary,
    };
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueKey,
    this.valueColor,
  });

  final String label;
  final String value;
  final Key? valueKey;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            key: valueKey,
            style: theme.textTheme.bodySmall?.copyWith(
              color: valueColor ?? AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

String formatCloudAccountLabel(CloudAccountSnapshot account) {
  switch (account.kind) {
    case CloudAccountKind.unavailable:
      final reason = account.unavailableReason;
      return reason == null || reason.isEmpty
          ? 'Layanan cloud tidak tersedia'
          : reason;
    case CloudAccountKind.unauthenticated:
      return 'Belum masuk akun';
    case CloudAccountKind.anonymous:
      final uid = account.uid ?? '';
      final shortUid = uid.length > 8 ? '${uid.substring(0, 8)}...' : uid;
      return shortUid.isEmpty ? 'Akun Anonim' : 'Akun Anonim ($shortUid)';
    case CloudAccountKind.emailLinked:
      final id = account.email ?? account.displayName ?? account.uid ?? 'Email';
      return 'Email terhubung ($id)';
  }
}

String formatCloudSyncStatusLabel(CloudSyncStatusSnapshot status) {
  switch (status.phase) {
    case CloudSyncPhase.unavailable:
      return 'Layanan cloud tidak tersedia';
    case CloudSyncPhase.unauthenticated:
      return 'Belum masuk akun';
    case CloudSyncPhase.syncing:
      return 'Menyinkronkan...';
    case CloudSyncPhase.synced:
      final ts = status.lastSyncAtMs;
      return ts == null ? 'Tersinkron' : 'Tersinkron (${formatEpochMs(ts)})';
    case CloudSyncPhase.pendingChanges:
      return 'Ada perubahan belum tersinkron';
    case CloudSyncPhase.offline:
      return 'Offline';
    case CloudSyncPhase.rejected:
      final reason =
          status.lastRejectMessage ?? status.lastRejectCode ?? 'Aturan batas';
      return 'Ditolak: $reason';
    case CloudSyncPhase.conflict:
      return 'Konflik';
  }
}

String formatEpochMs(int epochMs) {
  final dt = DateTime.fromMillisecondsSinceEpoch(epochMs).toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
}

/// Dialog konfirmasi pemulihan manual dari cloud dengan peringatan permanen
/// bahwa progres lokal diganti dan cadangan lokal dibuat terlebih dahulu.
Future<bool> showCloudRestoreConfirmDialog(
  BuildContext context, {
  CloudSaveMeta? cloudMeta,
  required bool isDungeonRunActive,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => EchoesDialog(
      key: const Key('cloud_restore_confirm_dialog'),
      title: 'Pulihkan Save dari Cloud?',
      icon: Icons.warning_amber_rounded,
      accentColor: AppColors.campAmber,
      secondaryLabel: 'Batal',
      onSecondary: () => Navigator.of(dialogContext).pop(false),
      primaryLabel: isDungeonRunActive ? null : 'Pulihkan dari cloud',
      onPrimary: isDungeonRunActive
          ? null
          : () => Navigator.of(dialogContext).pop(true),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progres lokal saat ini akan diganti seluruhnya oleh data cloud. '
            'Cadangan lokal akan disimpan terlebih dahulu sebelum pemulihan.',
          ),
          if (cloudMeta != null) ...[
            const SizedBox(height: AppSpacing.md),
            _CloudMetaSummary(meta: cloudMeta),
          ],
          if (isDungeonRunActive) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Tidak dapat memulihkan saat dungeon run sedang aktif. '
              'Selesaikan atau keluar ke Town terlebih dahulu.',
              key: const Key('cloud_restore_dialog_blocked_text'),
              style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                color: Theme.of(dialogContext).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    ),
  );
  return result ?? false;
}

/// Dialog konflik atau tawaran pemulihan save cloud (`DESIGN §1.5`).
///
/// Mengembalikan `true` jika pemain memilih **Pulihkan dari cloud**,
/// atau `false` jika **Batal** (lanjut bermain lokal tanpa sinkronisasi).
Future<bool> showCloudConflictDialog(
  BuildContext context, {
  required CloudConflictKind kind,
  CloudSaveMeta? cloudMeta,
  required bool isDungeonRunActive,
}) async {
  final title = switch (kind) {
    CloudConflictKind.cloudAheadUnchanged => 'Save Cloud Lebih Baru Tersedia',
    CloudConflictKind.divergedSave => 'Konflik Save Lokal & Cloud',
    CloudConflictKind.accountSwitch =>
      'Akun Email Sudah Terhubung ke Save Lain',
  };

  final body = switch (kind) {
    CloudConflictKind.cloudAheadUnchanged =>
      'Ditemukan save cloud yang lebih baru daripada sinkronisasi terakhir di perangkat ini. '
          'Apakah Anda ingin memulihkannya? Cadangan save lokal akan dibuat terlebih dahulu.',
    CloudConflictKind.divergedSave =>
      'Progres lokal dan cloud sama-sama berubah sejak sinkronisasi terakhir. '
          'Pilih "Pulihkan dari cloud" untuk memakai data cloud (progres lokal diganti setelah dicadangkan), '
          'atau "Batal" untuk tetap bermain lokal tanpa sinkronisasi.',
    CloudConflictKind.accountSwitch =>
      'Akun email ini sudah memiliki progres cloud sendiri. Aplikasi tidak menggabungkan maupun menimpa save cloud secara otomatis. '
          'Pilih "Pulihkan dari cloud" untuk memakai progres akun email (progres lokal dicadangkan lebih dulu), '
          'atau "Batal" untuk melanjutkan secara lokal tanpa sinkronisasi.',
  };

  final cancelLabel = kind == CloudConflictKind.cloudAheadUnchanged
      ? 'Nanti'
      : 'Batal';

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => EchoesDialog(
      key: const Key('cloud_conflict_dialog'),
      title: title,
      icon: kind == CloudConflictKind.cloudAheadUnchanged
          ? Icons.cloud_download_outlined
          : Icons.sync_problem_outlined,
      accentColor: kind == CloudConflictKind.cloudAheadUnchanged
          ? AppColors.antiqueGold
          : AppColors.campAmber,
      secondaryLabel: cancelLabel,
      onSecondary: () => Navigator.of(dialogContext).pop(false),
      primaryLabel: isDungeonRunActive ? null : 'Pulihkan dari cloud',
      onPrimary: isDungeonRunActive
          ? null
          : () => Navigator.of(dialogContext).pop(true),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(body),
          if (cloudMeta != null) ...[
            const SizedBox(height: AppSpacing.md),
            _CloudMetaSummary(meta: cloudMeta),
          ],
          if (isDungeonRunActive) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Pemulihan diblokir selama dungeon run aktif.',
              style: Theme.of(dialogContext).textTheme.bodySmall
                  ?.copyWith(color: Theme.of(dialogContext).colorScheme.error),
            ),
          ],
        ],
      ),
    ),
  );
  return result ?? false;
}

class _CloudMetaSummary extends StatelessWidget {
  const _CloudMetaSummary({required this.meta});

  final CloudSaveMeta meta;

  @override
  Widget build(BuildContext context) {
    final m = meta.metrics;
    final savedText = meta.savedAtServerMs > 0
        ? formatEpochMs(meta.savedAtServerMs)
        : '-';
    return PanelFrame(
      backgroundColor: AppColors.surfaceDark,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Save Cloud (Revisi ${meta.revision})',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.antiqueGold,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Lv ${m.level} • Rank Ascension ${m.highestAscensionRank} • Gold ${m.gold}',
            style: AppTypography.numeric(Theme.of(context).textTheme.bodySmall),
          ),
          Text(
            'Disimpan: $savedText',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Dialog autentikasi Email & Password (Tautkan akun lokal atau Masuk akun lama).
Future<EmailAuthOutcome?> showEmailAuthDialog(
  BuildContext context, {
  EmailAuthAction? onLinkEmail,
  EmailAuthAction? onSignInEmail,
  PasswordResetAction? onResetPassword,
  bool preferLink = true,
}) {
  return showDialog<EmailAuthOutcome>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => _EmailAuthDialog(
      onLinkEmail: onLinkEmail,
      onSignInEmail: onSignInEmail,
      onResetPassword: onResetPassword,
      initialMode: preferLink || onSignInEmail == null
          ? _EmailAuthMode.link
          : _EmailAuthMode.signIn,
    ),
  );
}

class _EmailAuthDialog extends StatefulWidget {
  const _EmailAuthDialog({
    required this.initialMode,
    this.onLinkEmail,
    this.onSignInEmail,
    this.onResetPassword,
  });

  final _EmailAuthMode initialMode;
  final EmailAuthAction? onLinkEmail;
  final EmailAuthAction? onSignInEmail;
  final PasswordResetAction? onResetPassword;

  @override
  State<_EmailAuthDialog> createState() => _EmailAuthDialogState();
}

class _EmailAuthDialogState extends State<_EmailAuthDialog> {
  late _EmailAuthMode _mode = widget.initialMode;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _errorText;
  String? _infoText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final action = _mode == _EmailAuthMode.link
        ? (widget.onLinkEmail ?? widget.onSignInEmail)
        : (widget.onSignInEmail ?? widget.onLinkEmail);
    if (action == null) return;

    setState(() {
      _submitting = true;
      _errorText = null;
      _infoText = null;
    });

    final outcome = await action(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (!mounted) return;

    switch (outcome) {
      case EmailAuthSuccess():
      case EmailAuthSwitchedAccountConflict():
        Navigator.of(context).pop(outcome);
      case EmailAuthFailed(:final message):
        setState(() {
          _submitting = false;
          _errorText = message;
        });
    }
  }

  Future<void> _resetPassword() async {
    final resetAction = widget.onResetPassword;
    if (_submitting || resetAction == null) return;

    setState(() {
      _submitting = true;
      _errorText = null;
      _infoText = null;
    });

    final outcome = await resetAction(email: _emailController.text);
    if (!mounted) return;

    setState(() {
      _submitting = false;
      switch (outcome) {
        case PasswordResetSent(:final email):
          _infoText = 'Tautan reset kata sandi dikirim ke $email.';
        case PasswordResetFailed(:final message):
          _errorText = message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLink = _mode == _EmailAuthMode.link;
    final canSwitchMode =
        widget.onLinkEmail != null && widget.onSignInEmail != null;

    return EchoesDialog(
      key: const Key('cloud_email_auth_dialog'),
      title: isLink ? 'Tautkan Akun Email' : 'Masuk Akun Email',
      icon: Icons.email_outlined,
      accentColor: AppColors.antiqueGold,
      secondaryLabel: 'Batal',
      onSecondary: _submitting ? null : () => Navigator.of(context).pop(),
      primaryLabel: _submitting
          ? 'Memproses...'
          : (isLink ? 'Tautkan Akun' : 'Masuk'),
      onPrimary: _submitting ? null : _submit,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canSwitchMode) ...[
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    key: const Key('cloud_mode_link_chip'),
                    label: const Text('Tautkan Baru'),
                    selected: isLink,
                    onSelected: _submitting
                        ? null
                        : (_) => setState(() {
                            _mode = _EmailAuthMode.link;
                            _errorText = null;
                            _infoText = null;
                          }),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: ChoiceChip(
                    key: const Key('cloud_mode_signin_chip'),
                    label: const Text('Masuk Akun Lama'),
                    selected: !isLink,
                    onSelected: _submitting
                        ? null
                        : (_) => setState(() {
                            _mode = _EmailAuthMode.signIn;
                            _errorText = null;
                            _infoText = null;
                          }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(
            isLink
                ? 'Simpan progres cloud dengan email & kata sandi agar dapat dipulihkan di perangkat lain.'
                : 'Masuk dengan email & kata sandi yang pernah ditautkan untuk memulihkan save cloud.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('cloud_email_field'),
            controller: _emailController,
            enabled: !_submitting,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'petualang@contoh.com',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('cloud_password_field'),
            controller: _passwordController,
            enabled: !_submitting,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Kata Sandi',
              hintText: 'Minimal 6 karakter',
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: IconButton(
                onPressed: _submitting
                    ? null
                    : () => setState(() {
                        _obscurePassword = !_obscurePassword;
                      }),
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
          ),
          if (!isLink && widget.onResetPassword != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('cloud_reset_password_btn'),
                onPressed: _submitting ? null : _resetPassword,
                child: const Text('Lupa kata sandi?'),
              ),
            ),
          ],
          if (_errorText != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              _errorText!,
              key: const Key('cloud_email_auth_error'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (_infoText != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              _infoText!,
              key: const Key('cloud_email_auth_info'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
