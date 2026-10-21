import 'package:flutter/material.dart';

import '../../../core/services/api_service.dart';
import '../admin_strings.dart';
import '../widgets/admin_ui.dart';

/// Category requests + category tree management
/// (web: Requests page + the categories section of Settings).
class AdminCatalogScreen extends StatelessWidget {
  const AdminCatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AdminStrings.of(context);
    return DefaultTabController(
      length: 2,
      child: AdminScaffold(
        title: t('catalog'),
        bottom: TabBar(
          labelColor: AdminPalette.primary,
          unselectedLabelColor: AdminPalette.textMuted,
          indicatorColor: AdminPalette.primary,
          labelStyle: adminText(14, weight: FontWeight.w600),
          tabs: [Tab(text: t('requests')), Tab(text: t('categories'))],
        ),
        body: const TabBarView(children: [_RequestsTab(), _CategoriesTab()]),
      ),
    );
  }
}

/// Picker for an optional parent category; `null` means top level.
Widget _parentPicker(
  BuildContext context,
  List<Map> parents,
  String? value,
  ValueChanged<String?> onChanged,
) {
  final t = AdminStrings.of(context);
  return DropdownButtonFormField<String?>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: t('parentCategory'),
      labelStyle: adminText(13, color: AdminPalette.textMuted),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
    ),
    items: [
      DropdownMenuItem(value: null, child: Text(t('topLevel'), style: adminText(14))),
      for (final p in parents)
        DropdownMenuItem(
          value: '${p['id']}',
          child: Text('${p['name']}', style: adminText(14), overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: onChanged,
  );
}

class _RequestsTab extends StatefulWidget {
  const _RequestsTab();

  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab> with AutomaticKeepAliveClientMixin {
  final _api = ApiService();

  @override
  bool get wantKeepAlive => true;

  Future<(List<dynamic>, List<dynamic>)> _load() async {
    final results = await Future.wait([_api.adminCategoryRequests(), _api.adminCategories()]);
    return (results[0], results[1]);
  }

  Future<void> _approve(Map req, List<Map> parents, Future<void> Function() reload) async {
    final t = AdminStrings.of(context);
    final nameCtrl = TextEditingController(text: '${req['category_name'] ?? ''}');
    String? parentId;
    final ok = await showAdminSheet<bool>(
      context,
      title: t('approveRequest'),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminTextInput(controller: nameCtrl, label: t('categoryName')),
            _parentPicker(ctx, parents, parentId, (v) => setSheet(() => parentId = v)),
            const SizedBox(height: 16),
            AdminButton(
              label: t('createCategory'),
              icon: Icons.check_rounded,
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) {
                  adminToast(ctx, t('nameRequired'), error: true);
                } else {
                  Navigator.pop(ctx, true);
                }
              },
            ),
          ],
        ),
      ),
    );
    final name = nameCtrl.text.trim();
    nameCtrl.dispose();
    if (ok != true || !mounted) return;
    final done = await adminRun(
      context,
      () => _api.adminApproveCategoryRequest('${req['id']}', name: name, parentId: parentId),
      success: t('requestApproved'),
    );
    if (done) await reload();
  }

  Future<void> _reject(Map req, Future<void> Function() reload) async {
    final t = AdminStrings.of(context);
    final ok = await adminConfirm(
      context,
      title: t('rejectRequest'),
      message: t('rejectRequestMessage', {'name': '${req['category_name'] ?? ''}'}),
      confirmLabel: t('reject'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    final done = await adminRun(
      context,
      () => _api.adminRejectCategoryRequest('${req['id']}'),
      success: t('requestRejected'),
    );
    if (done) await reload();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = AdminStrings.of(context);
    return AdminLoader<(List<dynamic>, List<dynamic>)>(
      load: _load,
      builder: (context, data, reload) {
        final requests = data.$1.whereType<Map>().toList();
        final parents = data.$2
            .whereType<Map>()
            .where((c) => c['parent_category_id'] == null)
            .toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (requests.isEmpty)
              AdminEmptyState(icon: Icons.playlist_add_check_rounded, message: t('noRequests')),
            for (final r in requests)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AdminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r['category_name'] ?? '—'}',
                        style: adminText(15, weight: FontWeight.w600),
                      ),
                      if ('${r['description'] ?? ''}'.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${r['description']}',
                          style: adminText(13, color: AdminPalette.textMuted, height: 1.4),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        '${t('requestedBy')} ${r['profiles']?['full_name'] ?? t('unknown')} · ${adminDate(context, r['created_at'])}',
                        style: adminText(11, color: AdminPalette.textFaint),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: AdminButton(
                              label: t('reject'),
                              outlined: true,
                              destructive: true,
                              onPressed: () => _reject(r, reload),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AdminButton(
                              label: t('approve'),
                              onPressed: () => _approve(r, parents, reload),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CategoriesTab extends StatefulWidget {
  const _CategoriesTab();

  @override
  State<_CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<_CategoriesTab> with AutomaticKeepAliveClientMixin {
  final _api = ApiService();
  Map? _parent; // null = top level
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  Future<void> _add(Future<void> Function() reload) async {
    final t = AdminStrings.of(context);
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final ok = await showAdminSheet<bool>(
      context,
      title: _parent == null
          ? t('newCategory')
          : t('newSubcategoryIn', {'name': '${_parent!['name']}'}),
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminTextInput(controller: nameCtrl, label: t('categoryName')),
          AdminTextInput(controller: descCtrl, label: t('description'), maxLines: 3),
          Text(t('autoTranslateNote'), style: adminText(11, color: AdminPalette.textFaint)),
          const SizedBox(height: 14),
          AdminButton(
            label: t('createCategory'),
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) {
                adminToast(ctx, t('nameRequired'), error: true);
              } else {
                Navigator.pop(ctx, true);
              }
            },
          ),
        ],
      ),
    );
    final name = nameCtrl.text.trim();
    final desc = descCtrl.text.trim();
    nameCtrl.dispose();
    descCtrl.dispose();
    if (ok != true || !mounted) return;
    final done = await adminRun(
      context,
      () => _api.adminCreateCategory(
        name: name,
        description: desc.isEmpty ? null : desc,
        parentId: _parent == null ? null : '${_parent!['id']}',
      ),
      success: t('categoryCreated'),
    );
    if (done) await reload();
  }

  Future<void> _delete(Map c, int childCount, Future<void> Function() reload) async {
    final t = AdminStrings.of(context);
    final ok = await adminConfirm(
      context,
      title: t('deleteCategory'),
      message: childCount > 0
          ? t('deleteCategoryWithChildren', {'name': '${c['name']}', 'n': '$childCount'})
          : t('deleteCategoryMessage', {'name': '${c['name']}'}),
      confirmLabel: t('delete'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    final done = await adminRun(
      context,
      () => _api.adminDeleteCategory('${c['id']}'),
      success: t('categoryDeleted'),
    );
    if (done) await reload();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = AdminStrings.of(context);
    return AdminLoader<List<dynamic>>(
      load: _api.adminCategories,
      builder: (context, all, reload) {
        final cats = all.whereType<Map>().toList();
        int children(Map c) => cats.where((x) => x['parent_category_id'] == c['id']).length;
        final q = _query.toLowerCase();
        final level = cats.where((c) {
          final inLevel = _parent == null
              ? c['parent_category_id'] == null
              : c['parent_category_id'] == _parent!['id'];
          return inLevel && (q.isEmpty || '${c['name']}'.toLowerCase().contains(q));
        }).toList()
          ..sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));

        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                AdminSearchField(
                  hint: t('searchCategories'),
                  onChanged: (v) => setState(() => _query = v),
                ),
                if (_parent != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ActionChip(
                      avatar: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: Text('${t('allCategories')} / ${_parent!['name']}'),
                      labelStyle: adminText(12, weight: FontWeight.w600),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AdminPalette.border),
                      onPressed: () => setState(() => _parent = null),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (level.isEmpty)
                  AdminEmptyState(icon: Icons.category_outlined, message: t('noCategories')),
                if (level.isNotEmpty)
                  AdminCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < level.length; i++) ...[
                          if (i > 0) const Divider(height: 1, color: AdminPalette.border),
                          ListTile(
                            onTap: _parent == null
                                ? () => setState(() {
                                    _parent = level[i];
                                    _query = '';
                                  })
                                : null,
                            title: Text('${level[i]['name']}', style: adminText(14, weight: FontWeight.w500)),
                            subtitle: _parent == null
                                ? Text(
                                    t('subcategoriesCount', {'n': '${children(level[i])}'}),
                                    style: adminText(12, color: AdminPalette.textMuted),
                                  )
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded),
                                  color: AdminPalette.danger,
                                  tooltip: t('delete'),
                                  onPressed: () => _delete(level[i], children(level[i]), reload),
                                ),
                                if (_parent == null)
                                  const Icon(Icons.chevron_right_rounded, color: AdminPalette.textFaint),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                heroTag: 'addCategory',
                backgroundColor: AdminPalette.primary,
                foregroundColor: Colors.white,
                onPressed: () => _add(reload),
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  _parent == null ? t('newCategory') : t('newSubcategory'),
                  style: adminText(13, weight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
