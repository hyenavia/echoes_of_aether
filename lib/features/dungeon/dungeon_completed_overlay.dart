import 'dart:ui' show ImageFilter;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/echoes_theme.dart';
import '../../core/utils/number_formatter.dart';
import '../../domain/services/reward_processor.dart';
import '../../theme/app_theme.dart';
import '../../widgets/game_button.dart';
import '../../widgets/game_panel.dart';
import '../shared/widgets/shared_widgets.dart';

/// Ditampilkan saat seluruh room dungeon berhasil diselesaikan (Tahap 4 Visual Overhaul).
///
/// Fitur:
/// - BackdropFilter (blur) pada latar belakang agar pemain fokus ke pop-up.
/// - Kotak pop-up menggunakan GamePanel dengan desain emas mewah (9-slice ornate).
/// - Hadiah EXP & Gold berupa Item Card kecil dengan ikon kristal/koin bercahaya.
/// - Animasi pop-in (membesar dengan efek pantul / bounce) menggunakan Curves.easeOutBack.
/// - Tombol "Run baru" kustom GameButton dengan animasi pulse (berdenyut pelan).
/// - Partikel confetti di belakang pop-up menggunakan package confetti.
class DungeonCompletedOverlay extends StatefulWidget {
  const DungeonCompletedOverlay({
    super.key,
    required this.dungeonName,
    required this.clearedRoomsCount,
    this.isFinalBoss = false,
    this.isAscension = false,
    this.previousAscensionRank,
    this.newAscensionRank,
    this.completionReward,
    this.bossQuestMessage,
    this.onRetry,
    this.onNextFloor,
    this.nextFloorLabel,
    required this.onReturnToTown,
  });

  final String dungeonName;
  final int clearedRoomsCount;
  final bool isFinalBoss;
  final bool isAscension;
  final int? previousAscensionRank;
  final int? newAscensionRank;
  final GrantedReward? completionReward;
  final String? bossQuestMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onNextFloor;
  final String? nextFloorLabel;
  final VoidCallback onReturnToTown;

  @override
  State<DungeonCompletedOverlay> createState() =>
      _DungeonCompletedOverlayState();
}

class _DungeonCompletedOverlayState extends State<DungeonCompletedOverlay> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    final isTesting = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    if (!isTesting) {
      _confettiController.play();
    }
  }

  @override
  void dispose() {
    _confettiController.stop();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = EchoesTheme.of(context);
    final reward = widget.completionReward;
    final accentColor = widget.isAscension ? ext.rank : AppTheme.gold;
    final rankLabel = widget.newAscensionRank != null
        ? (widget.previousAscensionRank != null &&
                  widget.newAscensionRank! > widget.previousAscensionRank!
              ? 'Ascension Rank ${widget.previousAscensionRank} → Rank ${widget.newAscensionRank}'
              : 'Ascension Rank ${widget.newAscensionRank}')
        : null;

    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        // 1. BackdropFilter (blur) pada layar di belakangnya
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
            child: Container(color: Colors.black.withValues(alpha: 0.65)),
          ),
        ),

        // 2. Partikel / Confetti di belakang pop-up
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  AppTheme.gold,
                  AppTheme.arcanePurple,
                  AppTheme.cyanGlow,
                  Color(0xFFFFD700),
                  Color(0xFFE0AAFF),
                  Color(0xFF00F5D4),
                  Colors.white,
                ],
                numberOfParticles: 35,
                emissionFrequency: 0.05,
                maxBlastForce: 25,
                minBlastForce: 10,
                gravity: 0.15,
              ),
            ),
          ),
        ),

        // 3. Kotak Pop-up GamePanel Mewah dengan Animasi Pop-in (Bounce)
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.75, end: 1.0),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) {
                  return Transform.scale(scale: scale, child: child);
                },
                child: GamePanel.goldOrnate(
                  showGlow: true,
                  glowColor: accentColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Aether Symbol Crown
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              accentColor.withValues(alpha: 0.35),
                              const Color(0xFF0C101A),
                            ],
                          ),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.85),
                            width: 2.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.40),
                              blurRadius: 14,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: AetherSymbolMark(
                            variant: AetherSymbolVariant.mark,
                            size: 36,
                            glow: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Judul Fantasi
                      Text(
                        widget.isAscension
                            ? 'Ascension Selesai!'
                            : 'Dungeon Selesai!',
                        style: AppTheme.headingFantasy(
                          fontSize: 22,
                          letterSpacing: 1.2,
                          color: accentColor,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      if (widget.isFinalBoss) ...[
                        const SizedBox(height: AppSpacing.xs + 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm + 4,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: ext.hpBar.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(
                              color: ext.hpBar.withValues(alpha: 0.65),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: ext.hpBar.withValues(alpha: 0.3),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.whatshot_outlined,
                                size: 14,
                                color: ext.hpBar,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Final Boss',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: ext.hpBar,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (rankLabel != null) ...[
                        const SizedBox(height: AppSpacing.sm + 2),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: ext.rank.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: ext.rank.withValues(alpha: 0.55),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                rankLabel,
                                key: const Key('ascension_rank_result'),
                                style: AppTypography.numeric(
                                  theme.textTheme.titleMedium,
                                  color: ext.rank,
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Siklus baru dimulai — Farm Dungeon direset ke Dungeon 1.',
                                style: theme.textTheme.bodySmall,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: AppSpacing.sm + 2),
                      Text(
                        '${widget.dungeonName} ditaklukkan (${widget.clearedRoomsCount} room selesai).',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          letterSpacing: 0.2,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      // HADIAH PENYELESAIAN (Item Cards)
                      if (reward != null && !reward.alreadyClaimed) ...[
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm + 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF090D16)
                                .withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: ext.panelInnerBorder.withValues(
                                alpha: 0.75,
                              ),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'HADIAH PENYELESAIAN',
                                style: AppTheme.headingFantasy(
                                  fontSize: 11,
                                  letterSpacing: 1.0,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.sm,
                                alignment: WrapAlignment.center,
                                children: [
                                  TweenAnimationBuilder<double>(
                                    tween: Tween<double>(begin: 0.6, end: 1.0),
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutBack,
                                    builder: (context, scale, child) =>
                                        Transform.scale(
                                          scale: scale,
                                          child: child,
                                        ),
                                    child: _RewardItemCard(
                                      icon: const Icon(
                                        Icons.auto_awesome,
                                        size: 22,
                                        color: AppTheme.cyanGlow,
                                      ),
                                      valueText:
                                          '+${NumberFormatter.format(reward.expGranted)} EXP',
                                      labelText: 'Pengalaman',
                                      accentColor: AppTheme.cyanGlow,
                                    ),
                                  ),
                                  TweenAnimationBuilder<double>(
                                    tween: Tween<double>(begin: 0.6, end: 1.0),
                                    duration: const Duration(milliseconds: 380),
                                    curve: Curves.easeOutBack,
                                    builder: (context, scale, child) =>
                                        Transform.scale(
                                          scale: scale,
                                          child: child,
                                        ),
                                    child: _RewardItemCard(
                                      icon: const Icon(
                                        Icons.monetization_on,
                                        size: 22,
                                        color: AppTheme.gold,
                                      ),
                                      valueText:
                                          '+${NumberFormatter.format(reward.goldGranted)} Gold',
                                      labelText: 'Koin Emas',
                                      accentColor: AppTheme.gold,
                                    ),
                                  ),
                                  if (reward.levelsGained > 0)
                                    TweenAnimationBuilder<double>(
                                      tween: Tween<double>(
                                        begin: 0.6,
                                        end: 1.0,
                                      ),
                                      duration: const Duration(
                                        milliseconds: 440,
                                      ),
                                      curve: Curves.easeOutBack,
                                      builder: (context, scale, child) =>
                                          Transform.scale(
                                            scale: scale,
                                            child: child,
                                          ),
                                      child: _RewardItemCard(
                                        icon: const Icon(
                                          Icons.military_tech,
                                          size: 22,
                                          color: Color(0xFF10B981),
                                        ),
                                        valueText:
                                            '+${NumberFormatter.format(reward.levelsGained)} Level',
                                        labelText: 'Naik Level!',
                                        accentColor: const Color(0xFF10B981),
                                      ),
                                    ),
                                ],
                              ),
                              if (reward.displayParts.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'Hadiah Tambahan: ${reward.displayParts.join(', ')}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: ext.expBar,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

                      if (widget.bossQuestMessage != null &&
                          widget.bossQuestMessage!.trim().isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        PanelFrame(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm + 2,
                          ),
                          backgroundColor: AppColors.surfaceDark,
                          borderColor: ext.panelInnerBorder,
                          child: Column(
                            children: [
                              Text(
                                'HADIAH BOSS QUEST',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                widget.bossQuestMessage!,
                                key: const Key('boss_quest_result_message'),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: ext.gold,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: AppSpacing.lg),

                      // Action Buttons (GameButton kustom dengan pulse pada Run baru)
                      Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.sm,
                        alignment: WrapAlignment.center,
                        children: [
                          if (widget.onNextFloor != null) ...[
                            GameButton.slate(
                              text: 'Kembali ke Town',
                              icon: Icons.home_outlined,
                              onPressed: widget.onReturnToTown,
                            ),
                            GameButton.gold(
                              key: const Key(
                                'dungeon_completed_next_floor_button',
                              ),
                              text:
                                  widget.nextFloorLabel ??
                                  'Lanjut Lantai Berikutnya',
                              icon: Icons.arrow_forward,
                              pulse: true,
                              onPressed: widget.onNextFloor,
                            ),
                          ] else if (widget.onRetry == null)
                            GameButton.gold(
                              text: 'Kembali ke Town',
                              icon: Icons.home_outlined,
                              pulse: true,
                              onPressed: widget.onReturnToTown,
                            )
                          else ...[
                            GameButton.slate(
                              text: 'Kembali ke Town',
                              icon: Icons.home_outlined,
                              onPressed: widget.onReturnToTown,
                            ),
                            GameButton.gold(
                              text: 'Run baru',
                              icon: Icons.replay,
                              pulse: true,
                              onPressed: widget.onRetry,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RewardItemCard extends StatelessWidget {
  const _RewardItemCard({
    required this.icon,
    required this.valueText,
    required this.labelText,
    required this.accentColor,
  });

  final Widget icon;
  final String valueText;
  final String labelText;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 105),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0C101A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.75),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.22),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.50),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: 4),
          Text(
            valueText,
            style: AppTheme.statNumber(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 1),
          Text(
            labelText,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
