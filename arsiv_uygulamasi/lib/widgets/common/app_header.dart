import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.onSearch,
    required this.onRefresh,
    required this.onLogout,
    this.refreshing = false,
    this.onMenu,
  });
  final VoidCallback onSearch;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;
  final bool refreshing;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final colors = Theme.of(context).colorScheme;
      final compact =
          constraints.maxWidth < 600 ||
          MediaQuery.textScalerOf(context).scale(14) > 21;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(bottom: BorderSide(color: colors.outlineVariant)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 16 : 28,
            vertical: 8,
          ),
          child: Row(
            children: [
              if (onMenu != null)
                IconButton(
                  tooltip: 'Menüyü aç',
                  onPressed: onMenu,
                  icon: const Icon(Icons.menu),
                ),
              if (!compact) ...[
                Icon(Icons.archive_outlined, color: colors.primary),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  'Arşivim',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
              ),
              if (compact)
                IconButton(
                  tooltip: 'Belgelerde ara',
                  onPressed: onSearch,
                  icon: const Icon(Icons.search),
                )
              else
                OutlinedButton.icon(
                  onPressed: onSearch,
                  icon: const Icon(Icons.search, size: 20),
                  label: const Text('Belgelerde ara'),
                ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: refreshing ? 'Yenileniyor' : 'Yenile',
                onPressed: refreshing ? null : onRefresh,
                icon: const Icon(Icons.refresh),
              ),
              PopupMenuButton<String>(
                tooltip: 'Oturum işlemleri',
                onSelected: (_) => onLogout(),
                itemBuilder:
                    (_) => [
                      const PopupMenuItem(
                        value: 'logout',
                        child: Text('Çıkış yap'),
                      ),
                    ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
