import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// ════════════════════════════════════════════════════════════════════════════
/// Reusable components mirroring the website's recipes (index.css +
/// dashboard-shared.jsx). Screens must compose these instead of hand-rolling
/// colors, radii and paddings.
/// ════════════════════════════════════════════════════════════════════════════

/// `.uber-card` — #1F1F1F, hairline #333, 12px radius, 20/24 padding.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.emphasis = false,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.lg,
    ),
    this.margin,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Active/emphasis card (site: `border-black dark:border-white`).
  final bool emphasis;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final decoration = emphasis ? AppDecor.cardEmphasis() : AppDecor.card();
    final content = Padding(padding: padding, child: child);

    return Container(
      margin: margin,
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(onTap: onTap, child: content),
            ),
    );
  }
}

enum AppButtonVariant { primary, secondary, ghost }

/// 48–52px action, radius 8, website weights and colors.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.height = 52,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final double height;

  /// Ghost/outline actions rendered in the error color (e.g. Cancel).
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = loading ? null : onPressed;
    final child = _content(context);

    final button = switch (variant) {
      AppButtonVariant.primary => ElevatedButton(
        onPressed: effectiveOnPressed,
        style: ElevatedButton.styleFrom(minimumSize: Size(0, height)),
        child: child,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: effectiveOnPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: Size(0, height),
          foregroundColor: destructive ? AppColors.error : AppColors.paper,
        ),
        child: child,
      ),
      AppButtonVariant.ghost => TextButton(
        onPressed: effectiveOnPressed,
        style: TextButton.styleFrom(
          minimumSize: Size(0, height - 8),
          foregroundColor: destructive ? AppColors.error : AppColors.paper,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        ),
        child: child,
      ),
    };

    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }

  Widget _content(BuildContext context) {
    if (loading) {
      // Matches the site's inline spinner + label pattern.
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: variant == AppButtonVariant.primary
                  ? AppColors.ink
                  : AppColors.paper,
            ),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.xs),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ],
      );
    }
    if (icon == null) return Text(label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: AppSpacing.xs),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

/// Labeled input on the website's field recipe: 13px semibold label, 52px
/// control, 8px radius, hairline #333, white focus border.
class AppField extends StatelessWidget {
  const AppField({
    super.key,
    this.label,
    this.controller,
    this.hint,
    this.icon,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLength,
    this.onSubmitted,
    this.onChanged,
    this.error,
    this.helper,
    this.autofocus = false,
    this.enabled = true,
    this.textAlign = TextAlign.start,
    this.fontSize = 15,
    this.letterSpacing,
    this.trailing,
    this.focusNode,
  });

  final String? label;
  final TextEditingController? controller;
  final String? hint;
  final IconData? icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLength;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final String? error;
  final String? helper;
  final bool autofocus;
  final bool enabled;
  final TextAlign textAlign;
  final double fontSize;
  final double? letterSpacing;
  final Widget? trailing;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppType.label.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          autofocus: autofocus,
          obscureText: obscure,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          maxLength: maxLength,
          onSubmitted: onSubmitted,
          onChanged: onChanged,
          textAlign: textAlign,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: fontSize,
            letterSpacing: letterSpacing,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md + 1,
            ),
            prefixIcon: icon == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.md,
                      right: AppSpacing.sm,
                    ),
                    child: Icon(icon, size: 18, color: AppColors.textSecondary),
                  ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0),
            suffixIcon: trailing,
            errorText: error,
          ),
        ),
        if (helper != null && error == null) ...[
          const SizedBox(height: AppSpacing.xxs + 2),
          Text(
            helper!,
            style: AppType.caption.copyWith(color: AppColors.textSubtle),
          ),
        ],
      ],
    );
  }
}

/// Status pill (site STATUS_STYLES): uppercase 10px, tinted or solid.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final key = status.toLowerCase();
    final label = status.replaceAll('_', ' ').toUpperCase();

    // Solid black-on-white for in-motion states (site: assigned/arriving/
    // in_progress/en_route).
    const solid = {'assigned', 'arriving', 'in_progress', 'en_route'};
    final completed = {
      'completed',
      'solved',
      'active',
      'paid',
      'success',
      'paid_out',
    };
    final failed = {'cancelled', 'canceled', 'offline', 'failed', 'rejected'};

    late final Color bg;
    late final Color fg;
    late final Color borderColor;

    if (solid.contains(key)) {
      bg = AppColors.paper;
      fg = AppColors.ink;
      borderColor = Colors.transparent;
    } else if (completed.contains(key)) {
      bg = AppColors.tint(AppColors.accent, 0.10);
      fg = AppColors.accent;
      borderColor = AppColors.tint(AppColors.accent, 0.25);
    } else if (failed.contains(key)) {
      bg = AppColors.tint(AppColors.error, 0.10);
      fg = AppColors.error;
      borderColor = AppColors.tint(AppColors.error, 0.25);
    } else if (key == 'pending' || key == 'clustered') {
      bg = AppColors.surfaceAlt;
      fg = AppColors.gray200;
      borderColor = AppColors.border;
    } else {
      bg = Colors.transparent;
      fg = AppColors.textSecondary;
      borderColor = AppColors.border;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs + 1,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.all(AppRadius.sm),
        border: Border.all(color: borderColor),
      ),
      child: Text(label, style: AppType.badge.copyWith(color: fg)),
    );
  }
}

/// `.uber-eyebrow` / `.mob-section-label` — 11px uppercase, wide tracking.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppType.eyebrow.copyWith(color: color ?? AppColors.textSubtle),
    );
  }
}

/// `PageHeader` — back action, title, description (site component).
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.description,
    this.onBack,
    this.backLabel = 'Back',
    this.actions,
  });

  final String title;
  final String? description;
  final VoidCallback? onBack;
  final String backLabel;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onBack != null) ...[
          TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 16),
            label: Text(backLabel),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xxs,
              ),
              minimumSize: const Size(0, 36),
              foregroundColor: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppType.pageTitle),
                  if (description != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      description!,
                      style: AppType.small.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ?actions,
          ],
        ),
      ],
    );
  }
}

/// `DashboardEmptyState` — dashed hairline card, icon tile, title, hint.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? hint;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: compact ? AppSpacing.xl : AppSpacing.xxl,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: AppColors.paper),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: AppType.title, textAlign: TextAlign.center),
          if (hint != null) ...[
            const SizedBox(height: AppSpacing.xxs + 2),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: AppType.caption.copyWith(color: AppColors.textSecondary),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: AppSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}

/// `LoadingRows` — skeleton blocks (#2A2A2A, radius 12) instead of spinners.
class SkeletonRows extends StatelessWidget {
  const SkeletonRows({
    super.key,
    this.count = 3,
    this.height = 64,
    this.gap = AppSpacing.xs,
  });

  final int count;
  final double height;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (i) => Padding(
          padding: EdgeInsets.only(bottom: i == count - 1 ? 0 : gap),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: AppRadius.all(AppRadius.lg),
            ),
          ),
        ),
      ),
    );
  }
}

/// Route-estimate style row: `rounded-xl border bg-[#2A2A2A] px-4 py-3`.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    this.icon,
    required this.label,
    this.value,
    this.trailing,
  });

  final IconData? icon;
  final String label;
  final String? value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 1,
      ),
      decoration: AppDecor.infoRow(),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(height: 0),
            const SizedBox(width: AppSpacing.xs),
          ],
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: AppType.caption.copyWith(color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (value != null)
            Expanded(
              flex: 3,
              child: Text(
                value!,
                style: AppType.data.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Inline error banner (site: `border-error/25 bg-error/10 text-error`).
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.tint(AppColors.error, 0.10),
        borderRadius: AppRadius.all(AppRadius.md),
        border: Border.all(color: AppColors.tint(AppColors.error, 0.25)),
      ),
      child: Text(
        message,
        style: AppType.caption.copyWith(color: AppColors.error),
      ),
    );
  }
}

/// ════════════════════════════════════════════════════════════════════════════
/// Map-first primitives
///
/// The website's signature layout is a full-bleed map with a floating booking
/// panel (site: `.map-surface` + `.booking-panel`). On mobile that panel is a
/// draggable bottom sheet. These widgets keep that structure identical on every
/// screen so the map always stays the dominant surface.
/// ════════════════════════════════════════════════════════════════════════════

/// Sheet grabber — 40×4 hairline handle (site: `bg-[#D6D6D6]`).
class SheetGrabber extends StatelessWidget {
  const SheetGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.gray300,
        borderRadius: AppRadius.all(AppRadius.pill),
      ),
    );
  }
}

/// The sheet surface itself: 16px top radius, hairline top border, lift shadow,
/// safe-area padding. Use directly for non-draggable sheets (menus, details).
class SheetPanel extends StatelessWidget {
  const SheetPanel({
    super.key,
    required this.child,
    this.showHandle = true,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.gutter,
      AppSpacing.xxs,
      AppSpacing.gutter,
      AppSpacing.gutter,
    ),
    this.safeArea = true,
  });

  final Widget child;
  final bool showHandle;
  final EdgeInsetsGeometry padding;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return DecoratedBox(
      decoration: AppDecor.floating(topOnly: true),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHandle) const SheetGrabber(),
          content,
          if (safeArea) SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}

/// Draggable sheet over a full-bleed map.
///
/// Three snap points keep the interaction predictable: collapsed (map stays
/// dominant), initial (booking form visible), and expanded (full panel scroll).
/// The map is never covered while collapsed — the site's behaviour on phones.
class AppDraggableSheet extends StatelessWidget {
  const AppDraggableSheet({
    super.key,
    required this.builder,
    this.initialSize = 0.55,
    this.minSize = 0.22,
    this.maxSize = AppMotion.sheetMax,
  });

  final Widget Function(BuildContext context, ScrollController controller)
  builder;
  final double initialSize;
  final double minSize;
  final double maxSize;

  @override
  Widget build(BuildContext context) {
    final snaps = <double>{
      minSize,
      initialSize,
      maxSize,
    }.where((s) => s >= minSize && s <= maxSize).toList()..sort();

    return DraggableScrollableSheet(
      initialChildSize: initialSize,
      minChildSize: minSize,
      maxChildSize: maxSize,
      snap: true,
      snapSizes: snaps,
      builder: (context, controller) => DecoratedBox(
        decoration: AppDecor.floating(topOnly: true),
        child: Column(
          children: [
            const SheetGrabber(),
            Expanded(child: builder(context, controller)),
          ],
        ),
      ),
    );
  }
}

/// Full-bleed map screen: map dominant, floating top bar, sheet at the bottom.
/// Every map-first screen (home, location picker, live tracking) uses this so
/// the layout hierarchy never shifts between screens.
class MapFirstScaffold extends StatelessWidget {
  const MapFirstScaffold({
    super.key,
    required this.map,
    this.topBar,
    this.banner,
    this.sheet,
  });

  /// Fills the available space edge to edge.
  final Widget map;

  /// Floats above the map inside the safe area.
  final Widget? topBar;

  /// Centred pill over the map (e.g. "Tap the map to choose pickup").
  final Widget? banner;

  /// Bottom sheet — typically [AppDraggableSheet].
  final Widget? sheet;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: map),
        if (topBar != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: topBar!,
              ),
            ),
          ),
        if (banner != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxxl),
                child: Center(child: banner!),
              ),
            ),
          ),
        ?sheet,
      ],
    );
  }
}

/// Sheet header: eyebrow, title, optional subtitle + trailing action.
/// Every sheet opens with the same hierarchy so the user always knows
/// "what is this, and what do I do next".
class SheetHeader extends StatelessWidget {
  const SheetHeader({
    super.key,
    this.eyebrow,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onLeadingTap,
    this.leadingIcon,
  });

  final String? eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final IconData? leadingIcon;
  final VoidCallback? onLeadingTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leadingIcon != null) ...[
          IconSquareButton(
            icon: leadingIcon!,
            onTap: onLeadingTap ?? () => Navigator.maybePop(context),
            tooltip: 'Back',
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                SectionLabel(eyebrow!),
                const SizedBox(height: AppSpacing.xxs),
              ],
              Text(
                title,
                style: AppType.sectionTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle!,
                  style: AppType.small.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.sm),
          trailing!,
        ],
      ],
    );
  }
}

/// 44px square icon button — the site's top-bar action (hairline, radius 8).
/// Used for back, inbox, locate and map actions on every screen.
class IconSquareButton extends StatelessWidget {
  const IconSquareButton({
    super.key,
    required this.icon,
    this.onTap,
    this.badgeCount = 0,
    this.tooltip,
    this.size = 44,
    this.solid = false,
    this.loading = false,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final int badgeCount;
  final String? tooltip;
  final double size;

  /// Solid white tile with black icon (primary map action).
  final bool solid;
  final bool loading;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = solid ? AppColors.ink : (color ?? AppColors.textPrimary);

    final button = PressableScale(
      onTap: loading ? null : onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: solid ? AppColors.paper : AppColors.bg,
          borderRadius: AppRadius.all(AppRadius.md),
          border: solid ? null : Border.all(color: AppColors.border),
          boxShadow: solid ? AppShadows.sm : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (loading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            else
              Icon(icon, size: size * 0.44, color: fg),
            if (badgeCount > 0)
              Positioned(
                top: size * 0.17,
                right: size * 0.19,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.paper,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Press feedback: 97% scale over 120ms. Subtle, fast, used on every tappable
/// surface that isn't a plain list row (those keep the ink ripple).
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  void _set(bool value) {
    if (!mounted || _down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: AppMotion.fast,
        curve: AppMotion.enter,
        child: widget.child,
      ),
    );
  }
}

/// The website's pickup / drop-off identity: a white dot and a white square,
/// connected by a hairline. Reproduced everywhere places are listed so the
/// two ends of a trip are instantly recognisable.
enum PlaceMarker { dot, square }

/// 52px place field row — leading marker, inline input, trailing action.
/// Matches the site's pickup/destination fields (`min-h-[52px]`, radius 8).
class PlaceField extends StatelessWidget {
  const PlaceField({
    super.key,
    this.marker = PlaceMarker.dot,
    this.controller,
    this.hint,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.focusNode,
    this.readOnly = false,
    this.autofocus = false,
    this.trailing,
    this.label,
  });

  final PlaceMarker marker;
  final TextEditingController? controller;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final bool readOnly;
  final bool autofocus;
  final Widget? trailing;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final field = Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: AppDecor.field(),
      child: Row(
        children: [
          PlaceMark(marker: marker),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: controller == null
                ? Text(
                    hint ?? '',
                    style: AppType.small.copyWith(
                      color: AppColors.textDisabled,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : TextField(
                    controller: controller,
                    focusNode: focusNode,
                    readOnly: readOnly || onTap != null,
                    autofocus: autofocus,
                    onTap: onTap,
                    onChanged: onChanged,
                    onSubmitted: onSubmitted,
                    style: AppType.small.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      hintText: hint,
                      hintStyle: AppType.small.copyWith(
                        color: AppColors.textDisabled,
                      ),
                    ),
                  ),
          ),
          ?trailing,
        ],
      ),
    );

    if (label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label!, style: AppType.label),
        const SizedBox(height: AppSpacing.xs),
        field,
      ],
    );
  }
}

/// The pickup dot / drop-off square itself.
class PlaceMark extends StatelessWidget {
  const PlaceMark({super.key, this.marker = PlaceMarker.dot, this.size = 16});

  final PlaceMarker marker;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (marker == PlaceMarker.dot) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Container(
            width: size * 0.62,
            height: size * 0.62,
            decoration: BoxDecoration(
              color: AppColors.paper,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.bg, width: 2),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Container(
          width: size * 0.66,
          height: size * 0.66,
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: AppRadius.all(AppRadius.sm - 4),
            border: Border.all(color: AppColors.bg, width: 2),
          ),
        ),
      ),
    );
  }
}

/// Pickup → drop-off pair with the connector line (site `InfoCard` pairing),
/// used in trip rows, trip sheets and the active-ride summary.
class RouteLeg extends StatelessWidget {
  const RouteLeg({
    super.key,
    required this.pickup,
    required this.destination,
    this.trailing,
    this.onTap,
  });

  final String pickup;
  final String destination;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const SizedBox(height: 3),
            const PlaceMark(marker: PlaceMarker.dot, size: 14),
            Container(width: 1, height: 26, color: AppColors.borderStrong),
            const PlaceMark(marker: PlaceMarker.square, size: 14),
          ],
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                pickup,
                style: AppType.small.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                destination,
                style: AppType.small.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );

    if (onTap == null) return row;
    return PressableScale(onTap: onTap, child: row);
  }
}

/// A place returned by the backend geocoder, rendered as a tappable row.
class PlaceSuggestionTile extends StatelessWidget {
  const PlaceSuggestionTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.icon = Icons.place_outlined,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxs,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: AppRadius.all(AppRadius.md),
              ),
              child: Icon(icon, size: 17, color: AppColors.textSecondary),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppType.smallStrong,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppType.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Flat list row with a hairline divider — the app's default for inbox,
/// settings and trip lists (no card around every row).
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.emphasised = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Unread / active emphasis (site: bolder title, brighter text).
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppType.smallStrong.copyWith(
                      fontWeight: emphasised
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: AppType.caption.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Segmented control — the website's `Tabs` recipe (`bg-[#F6F6F6] p-1
/// dark:bg-[#1F1F1F]`, active trigger white on black). Used for view switches
/// and filters so they read as one control instead of a row of buttons.
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.tabs,
    required this.activeIndex,
    required this.onChanged,
    this.expand = true,
  });

  final List<String> tabs;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  /// Fill the available width (few tabs) or scroll horizontally (many tabs).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      for (var i = 0; i < tabs.length; i++)
        _Tab(
          label: tabs[i],
          active: i == activeIndex,
          onTap: () => onChanged(i),
          expand: expand,
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadius.all(AppRadius.md),
      ),
      child: expand
          ? Row(children: [for (final item in items) Expanded(child: item)])
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: items),
            ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.active,
    required this.onTap,
    required this.expand,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.base,
        curve: AppMotion.enter,
        margin: expand ? EdgeInsets.zero : const EdgeInsets.only(right: 2),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs + 1,
        ),
        decoration: BoxDecoration(
          color: active ? AppColors.paper : Colors.transparent,
          borderRadius: AppRadius.all(AppRadius.sm),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.label.copyWith(
            color: active ? AppColors.ink : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Star input — line icons, the system's amber (`AppColors.warning`) when set,
/// hairline when empty. Used for post-ride feedback.
class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 40,
    this.enabled = true,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final double size;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          PressableScale(
            onTap: enabled ? () => onChanged(i) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: AnimatedScale(
                scale: i == value ? 1.08 : 1.0,
                duration: AppMotion.fast,
                curve: AppMotion.enter,
                child: Icon(
                  i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: size,
                  color: i <= value
                      ? AppColors.warning
                      : AppColors.borderStrong,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Selectable chip — site recipe (`rounded-full border`, selected = white on
/// black). Used for feedback tags and filters.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.base,
        curve: AppMotion.enter,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md + 2,
          vertical: AppSpacing.xs + 1,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.paper : Colors.transparent,
          borderRadius: AppRadius.all(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.paper : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppType.caption.copyWith(
            color: selected ? AppColors.ink : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Confirmation dialog on the app's surface recipe (site Dialog + hairline).
Future<bool> showAppConfirm(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(
            foregroundColor: destructive ? AppColors.error : AppColors.paper,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// The website's 6-stage ride progress: bar + numbered circles + labels.
class RideStageStepper extends StatelessWidget {
  const RideStageStepper({
    super.key,
    required this.stages,
    required this.labels,
    required this.currentIndex,
  });

  final List<String> stages;
  final List<String> labels;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final progress = ((currentIndex + 1) / stages.length)
        .clamp(0.0, 1.0)
        .toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: AppRadius.all(AppRadius.pill),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.surfaceAlt,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.paper),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: List.generate(stages.length, (i) {
            final passed = currentIndex >= i;
            final current = currentIndex == i;
            final circleColor = passed ? AppColors.paper : AppColors.surfaceAlt;
            final textColor = passed ? AppColors.ink : AppColors.textSubtle;
            return Expanded(
              child: Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: circleColor,
                      shape: BoxShape.circle,
                      border: current
                          ? Border.all(
                              color: AppColors.tint(AppColors.paper, 0.3),
                              width: 2,
                            )
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: passed && !current
                        ? const Icon(
                            Icons.check,
                            size: 12,
                            color: AppColors.ink,
                          )
                        : Text(
                            '${i + 1}',
                            style: AppType.badge.copyWith(
                              color: textColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                  const SizedBox(height: AppSpacing.xxs + 1),
                  Text(
                    labels[i],
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                      color: current
                          ? AppColors.textPrimary
                          : passed
                          ? AppColors.gray200
                          : AppColors.textSubtle,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}
