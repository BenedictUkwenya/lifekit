import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/services/api_service.dart';
import '../admin_strings.dart';
import '../widgets/admin_ui.dart';

/// Events, feed posts and communities (web: Events, Feeds, Groups pages).
class AdminContentScreen extends StatelessWidget {
  const AdminContentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AdminStrings.of(context);
    return DefaultTabController(
      length: 3,
      child: AdminScaffold(
        title: t('content'),
        bottom: TabBar(
          labelColor: AdminPalette.primary,
          unselectedLabelColor: AdminPalette.textMuted,
          indicatorColor: AdminPalette.primary,
          labelStyle: adminText(14, weight: FontWeight.w600),
          tabs: [Tab(text: t('events')), Tab(text: t('posts')), Tab(text: t('communities'))],
        ),
        body: const TabBarView(children: [_EventsTab(), _PostsTab(), _GroupsTab()]),
      ),
    );
  }
}

Widget _thumb(String? url, IconData fallback, {double size = 56}) {
  final valid = url != null && url.startsWith('http');
  return ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: SizedBox(
      width: size,
      height: size,
      child: valid
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => Container(color: AdminPalette.tintRose),
            )
          : Container(
              color: AdminPalette.tintRose,
              child: Icon(fallback, color: AdminPalette.primary),
            ),
    ),
  );
}

Widget _fab(String label, VoidCallback onPressed) => Positioned(
  right: 16,
  bottom: 16,
  child: FloatingActionButton.extended(
    heroTag: label,
    backgroundColor: AdminPalette.primary,
    foregroundColor: Colors.white,
    onPressed: onPressed,
    icon: const Icon(Icons.add_rounded),
    label: Text(label, style: adminText(13, weight: FontWeight.w600, color: Colors.white)),
  ),
);

/// Image picker tile used by the create sheets.
class _ImagePickTile extends StatelessWidget {
  final File? file;
  final VoidCallback onTap;

  const _ImagePickTile({required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 150,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          image: file == null
              ? null
              : DecorationImage(image: FileImage(file!), fit: BoxFit.cover),
        ),
        child: file != null
            ? null
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_photo_alternate_outlined, color: AdminPalette.textFaint, size: 32),
                  const SizedBox(height: 6),
                  Text(
                    AdminStrings.of(context)('addCoverImage'),
                    style: adminText(12, color: AdminPalette.textMuted),
                  ),
                ],
              ),
      ),
    );
  }
}

Future<File?> _pickImage() async {
  final x = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1600,
    imageQuality: 85,
  );
  return x == null ? null : File(x.path);
}

// ── Events ──────────────────────────────────────────────────────────────────
class _EventsTab extends StatefulWidget {
  const _EventsTab();

  @override
  State<_EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<_EventsTab> with AutomaticKeepAliveClientMixin {
  final _api = ApiService();
  static const _categories = ['Theatre', 'Sport', 'Festival', 'Tourism', 'Music', 'Food'];

  @override
  bool get wantKeepAlive => true;

  Future<void> _create(Future<void> Function() reload) async {
    final t = AdminStrings.of(context);
    final title = TextEditingController();
    final about = TextEditingController();
    final price = TextEditingController(text: '0');
    final location = TextEditingController();
    final address = TextEditingController();
    DateTime? date;
    TimeOfDay? time;
    String? category;
    bool featured = false;
    File? image;
    bool saving = false;

    await showAdminSheet<void>(
      context,
      title: t('newEvent'),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> submit() async {
            final p = double.tryParse(price.text.replaceAll(',', '.'));
            if (title.text.trim().isEmpty || location.text.trim().isEmpty || date == null || p == null) {
              adminToast(ctx, t('eventFieldsRequired'), error: true);
              return;
            }
            setSheet(() => saving = true);
            final ok = await adminRun(ctx, () async {
              final imageUrl = image == null ? null : await _api.uploadServiceImage(image!);
              await _api.adminCreateEvent({
                'title': title.text.trim(),
                'description': about.text.trim(),
                'image_url': imageUrl,
                'event_date': DateFormat('yyyy-MM-dd').format(date!),
                'event_time': time == null
                    ? null
                    : '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}',
                'price': p,
                'location': location.text.trim(),
                'address': address.text.trim().isEmpty ? null : address.text.trim(),
                'category': category,
                'is_featured': featured,
              });
            }, success: t('eventPublished'));
            if (!ctx.mounted) return;
            setSheet(() => saving = false);
            if (ok) Navigator.pop(ctx);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ImagePickTile(
                file: image,
                onTap: () async {
                  final f = await _pickImage();
                  if (f != null) setSheet(() => image = f);
                },
              ),
              AdminTextInput(controller: title, label: t('title')),
              AdminTextInput(controller: about, label: t('description'), maxLines: 3),
              Row(
                children: [
                  Expanded(
                    child: _PickerField(
                      icon: Icons.calendar_today_outlined,
                      label: date == null ? t('date') : adminDate(ctx, date!.toIso8601String()),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 730)),
                          initialDate: date ?? DateTime.now(),
                        );
                        if (d != null) setSheet(() => date = d);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PickerField(
                      icon: Icons.access_time_rounded,
                      label: time == null ? t('time') : time!.format(ctx),
                      onTap: () async {
                        final tm = await showTimePicker(
                          context: ctx,
                          initialTime: time ?? const TimeOfDay(hour: 19, minute: 0),
                        );
                        if (tm != null) setSheet(() => time = tm);
                      },
                    ),
                  ),
                ],
              ),
              AdminTextInput(
                controller: price,
                label: t('ticketPrice'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              AdminTextInput(controller: location, label: t('venue')),
              AdminTextInput(controller: address, label: t('address')),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in _categories)
                    ChoiceChip(
                      label: Text(c),
                      selected: category == c,
                      showCheckmark: false,
                      selectedColor: AdminPalette.primary,
                      backgroundColor: Colors.white,
                      labelStyle: adminText(
                        12,
                        weight: FontWeight.w600,
                        color: category == c ? Colors.white : AdminPalette.textMuted,
                      ),
                      onSelected: (s) => setSheet(() => category = s ? c : null),
                    ),
                ],
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: featured,
                activeTrackColor: AdminPalette.primary,
                title: Text(t('featureInCarousel'), style: adminText(14)),
                onChanged: (v) => setSheet(() => featured = v),
              ),
              const SizedBox(height: 8),
              AdminButton(label: t('publishEvent'), busy: saving, onPressed: submit),
            ],
          );
        },
      ),
    );
    for (final c in [title, about, price, location, address]) {
      c.dispose();
    }
    if (mounted) await reload();
  }

  Future<void> _action(Map e, String action, Future<void> Function() reload) async {
    final t = AdminStrings.of(context);
    final id = '${e['id']}';
    if (action == 'delete') {
      final ok = await adminConfirm(
        context,
        title: t('deleteEvent'),
        message: t('deleteConfirm', {'name': '${e['title']}'}),
        confirmLabel: t('delete'),
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    final done = await adminRun(
      context,
      () => switch (action) {
        'toggle' => _api.adminSetEventActive(id, e['is_active'] != true),
        'feature' => _api.adminSetEventFeatured(id, e['is_featured'] != true),
        _ => _api.adminDeleteEvent(id),
      },
      success: t('saved'),
    );
    if (done) await reload();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = AdminStrings.of(context);
    return AdminLoader<List<dynamic>>(
      load: _api.adminEvents,
      builder: (context, all, reload) {
        final events = all.whereType<Map>().toList();
        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                if (events.isEmpty)
                  AdminEmptyState(icon: Icons.event_outlined, message: t('noEvents')),
                for (final e in events)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AdminCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          _thumb(e['image_url'], Icons.event_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${e['title'] ?? '—'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: adminText(14, weight: FontWeight.w600),
                                ),
                                Text(
                                  '${adminDate(context, e['event_date'])} · ${e['location'] ?? ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: adminText(12, color: AdminPalette.textMuted),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    AdminStatusPill('${e['status'] ?? 'inactive'}'.toLowerCase()),
                                    if (e['is_featured'] == true) ...[
                                      const SizedBox(width: 6),
                                      const AdminStatusPill('featured'),
                                    ],
                                    const Spacer(),
                                    Text(
                                      adminMoney(e['price']),
                                      style: adminText(12, weight: FontWeight.w700, color: AdminPalette.primary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, color: AdminPalette.textMuted),
                            onSelected: (a) => _action(e, a, reload),
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'toggle',
                                child: Text(e['is_active'] == true ? t('deactivate') : t('activate')),
                              ),
                              PopupMenuItem(
                                value: 'feature',
                                child: Text(e['is_featured'] == true ? t('unfeature') : t('feature')),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(t('delete'), style: const TextStyle(color: AdminPalette.danger)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            _fab(t('newEvent'), () => _create(reload)),
          ],
        );
      },
    );
  }
}

class _PickerField extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerField({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AdminPalette.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, overflow: TextOverflow.ellipsis, style: adminText(13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Posts ───────────────────────────────────────────────────────────────────
class _PostsTab extends StatefulWidget {
  const _PostsTab();

  @override
  State<_PostsTab> createState() => _PostsTabState();
}

class _PostsTabState extends State<_PostsTab> with AutomaticKeepAliveClientMixin {
  final _api = ApiService();
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  Future<void> _announce(Future<void> Function() reload) async {
    final t = AdminStrings.of(context);
    final title = TextEditingController();
    final content = TextEditingController();
    File? image;
    bool saving = false;
    await showAdminSheet<void>(
      context,
      title: t('newAnnouncement'),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ImagePickTile(
              file: image,
              onTap: () async {
                final f = await _pickImage();
                if (f != null) setSheet(() => image = f);
              },
            ),
            AdminTextInput(controller: title, label: t('titleOptional')),
            AdminTextInput(controller: content, label: t('message'), maxLines: 5),
            AdminButton(
              label: t('publish'),
              busy: saving,
              onPressed: () async {
                if (content.text.trim().isEmpty) {
                  adminToast(ctx, t('messageRequired'), error: true);
                  return;
                }
                setSheet(() => saving = true);
                final ok = await adminRun(ctx, () async {
                  final url = image == null ? null : await _api.uploadPostImage(image!);
                  await _api.createPost(
                    content: content.text.trim(),
                    title: title.text.trim(),
                    imageUrls: url == null ? null : [url],
                  );
                }, success: t('postPublished'));
                if (!ctx.mounted) return;
                setSheet(() => saving = false);
                if (ok) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
    title.dispose();
    content.dispose();
    if (mounted) await reload();
  }

  Future<void> _delete(Map p, Future<void> Function() reload) async {
    final t = AdminStrings.of(context);
    final ok = await adminConfirm(
      context,
      title: t('deletePost'),
      message: t('deletePostMessage'),
      confirmLabel: t('delete'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    final done = await adminRun(context, () => _api.adminDeletePost('${p['id']}'), success: t('postDeleted'));
    if (done) await reload();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = AdminStrings.of(context);
    return AdminLoader<List<dynamic>>(
      load: _api.adminPosts,
      builder: (context, all, reload) {
        final q = _query.toLowerCase();
        final posts = all.whereType<Map>().where((p) {
          return q.isEmpty ||
              '${p['title']} ${p['content']} ${p['profiles']?['full_name']}'.toLowerCase().contains(q);
        }).toList();
        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                AdminSearchField(hint: t('searchPosts'), onChanged: (v) => setState(() => _query = v)),
                const SizedBox(height: 12),
                if (posts.isEmpty) AdminEmptyState(icon: Icons.dynamic_feed_rounded, message: t('noResults')),
                for (final p in posts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AdminCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              AdminAvatar(
                                url: p['profiles']?['profile_picture_url'],
                                name: p['profiles']?['full_name'],
                                radius: 16,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${p['profiles']?['full_name'] ?? t('unknown')}',
                                      style: adminText(13, weight: FontWeight.w600),
                                    ),
                                    Text(
                                      adminDate(context, p['created_at'], withTime: true),
                                      style: adminText(10, color: AdminPalette.textFaint),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded),
                                color: AdminPalette.danger,
                                tooltip: t('delete'),
                                onPressed: () => _delete(p, reload),
                              ),
                            ],
                          ),
                          if ('${p['title'] ?? ''}'.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text('${p['title']}', style: adminText(14, weight: FontWeight.w600)),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            '${p['content'] ?? ''}',
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: adminText(13, height: 1.4),
                          ),
                          if ('${p['image_url'] ?? ''}'.startsWith('http')) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: CachedNetworkImage(
                                imageUrl: p['image_url'],
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) => const SizedBox.shrink(),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.favorite_border_rounded, size: 16, color: AdminPalette.textFaint),
                              const SizedBox(width: 4),
                              Text('${p['likes_count'] ?? 0}', style: adminText(12, color: AdminPalette.textMuted)),
                              const SizedBox(width: 14),
                              const Icon(Icons.chat_bubble_outline_rounded, size: 15, color: AdminPalette.textFaint),
                              const SizedBox(width: 4),
                              Text('${p['comments_count'] ?? 0}', style: adminText(12, color: AdminPalette.textMuted)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            _fab(t('announce'), () => _announce(reload)),
          ],
        );
      },
    );
  }
}

// ── Groups ──────────────────────────────────────────────────────────────────
class _GroupsTab extends StatefulWidget {
  const _GroupsTab();

  @override
  State<_GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<_GroupsTab> with AutomaticKeepAliveClientMixin {
  final _api = ApiService();
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  Future<void> _delete(Map g, Future<void> Function() reload) async {
    final t = AdminStrings.of(context);
    final ok = await adminConfirm(
      context,
      title: t('deleteCommunity'),
      message: t('deleteConfirm', {'name': '${g['name']}'}),
      confirmLabel: t('delete'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    final done = await adminRun(context, () => _api.adminDeleteGroup('${g['id']}'), success: t('communityDeleted'));
    if (done) await reload();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = AdminStrings.of(context);
    return AdminLoader<List<dynamic>>(
      load: _api.adminGroups,
      builder: (context, all, reload) {
        final q = _query.toLowerCase();
        final groups = all.whereType<Map>().where((g) {
          return q.isEmpty || '${g['name']} ${g['description']}'.toLowerCase().contains(q);
        }).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            AdminSearchField(hint: t('searchCommunities'), onChanged: (v) => setState(() => _query = v)),
            const SizedBox(height: 12),
            if (groups.isEmpty) AdminEmptyState(icon: Icons.groups_outlined, message: t('noResults')),
            for (final g in groups)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AdminCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      _thumb(g['image_url'], Icons.groups_outlined, size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${g['name'] ?? '—'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: adminText(14, weight: FontWeight.w600),
                            ),
                            Text(
                              '${t('membersCount', {'n': '${g['members_count'] ?? 0}'})} · ${g['creator']?['full_name'] ?? t('unknown')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: adminText(12, color: AdminPalette.textMuted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        color: AdminPalette.danger,
                        tooltip: t('delete'),
                        onPressed: () => _delete(g, reload),
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
