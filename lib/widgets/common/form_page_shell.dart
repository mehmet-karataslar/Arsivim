import 'package:flutter/material.dart';
import '../app_navigation_bar.dart';
import '../document_editor/editor_navigation.dart';
import 'app_sidebar.dart';

/// Shared navigation frame for full-page forms; leaving is owned by the form.
class FormPageShell extends StatelessWidget {
  const FormPageShell({
    super.key,
    required this.title,
    required this.child,
    required this.selectedIndex,
    required this.onLeave,
    this.navigation,
  });
  final String title;
  final Widget child;
  final int selectedIndex;
  final EditorNavigation? navigation;
  final void Function([VoidCallback? action]) onLeave;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final desktop =
        MediaQuery.sizeOf(context).width >= 1100 &&
        MediaQuery.textScalerOf(context).scale(14) <= 20;
    final nav = navigation;
    return Scaffold(
      appBar:
          desktop
              ? null
              : AppBar(
                centerTitle: true,
                title: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                leading: BackButton(onPressed: () => onLeave()),
              ),
      bottomNavigationBar:
          !desktop &&
                  nav != null &&
                  MediaQuery.viewInsetsOf(context).bottom == 0
              ? AppNavigationBar(
                selectedIndex: selectedIndex,
                onSelected: (index) => onLeave(() => nav.onSelected(index)),
              )
              : null,
      body: SafeArea(
        child: Row(
          children: [
            if (desktop && nav != null)
              AppSidebar(
                selectedIndex: selectedIndex,
                summary: nav.summary,
                onSelected: (index) => onLeave(() => nav.onSelected(index)),
                onStorage: nav.onStorage,
                onLogout: () => onLeave(nav.onLogout),
              ),
            Expanded(
              child: Column(
                children: [
                  if (desktop)
                    Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        border: Border(
                          bottom: BorderSide(color: colors.outlineVariant),
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Geri dön',
                            onPressed: () => onLeave(),
                            icon: const Icon(Icons.arrow_back),
                          ),
                          Text(
                            'Arşivim',
                            style: TextStyle(
                              color: colors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                            ),
                          ),
                          const Spacer(),
                          if (nav != null)
                            OutlinedButton.icon(
                              onPressed: () => onLeave(() => nav.onSelected(1)),
                              icon: const Icon(Icons.search),
                              label: const Text('Belgelerde ara'),
                            ),
                        ],
                      ),
                    ),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
