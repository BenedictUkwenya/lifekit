import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/lifekit_loader.dart';

class GroupSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> group;
  final bool isAdmin;
  final String myId;

  const GroupSettingsScreen({
    super.key,
    required this.group,
    this.isAdmin = false,
    this.myId = '',
  });

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  final ApiService _api = ApiService();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  List<dynamic> _members = [];
  List<dynamic> _filteredMembers = [];

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingImage = false;

  late bool _anyoneCanPost;
  late bool _isPrivate;

  String? _currentImageUrl;
  File? _pendingImageFile;

  bool get _hasUnsavedChanges =>
      _nameCtrl.text.trim() != (widget.group['name'] ?? '') ||
      _descCtrl.text.trim() != (widget.group['description'] ?? '') ||
      _pendingImageFile != null ||
      _anyoneCanPost != (widget.group['anyone_can_post'] ?? true) ||
      _isPrivate != (widget.group['is_private'] ?? false);

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.group['name'] ?? '';
    _descCtrl.text = widget.group['description'] ?? '';
    _currentImageUrl = widget.group['image_url'];
    _anyoneCanPost = widget.group['anyone_can_post'] ?? true;
    _isPrivate = widget.group['is_private'] ?? false;
    _loadMembers();
    _searchCtrl.addListener(_applySearch);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── Data ───────────────────────────────────────────────────────

  Future<void> _loadMembers() async {
    try {
      final data = await _api.getGroupMembers(widget.group['id']);
      if (!mounted) return;
      setState(() {
        _members = data;
        _filteredMembers = data;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applySearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredMembers = q.isEmpty
          ? _members
          : _members.where((m) {
              final name = (m['profiles']?['full_name'] ?? '')
                  .toString()
                  .toLowerCase();
              final username = (m['profiles']?['username'] ?? '')
                  .toString()
                  .toLowerCase();
              return name.contains(q) || username.contains(q);
            }).toList();
    });
  }

  // ─── Image picker ────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;
    setState(() => _pendingImageFile = File(picked.path));
  }

  // ─── Save (admin only) ───────────────────────────────────────────

  Future<void> _saveChanges() async {
    if (!_hasUnsavedChanges) return;
    if (_nameCtrl.text.trim().isEmpty) {
      _toast('Group name cannot be empty', isError: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      String? uploadedUrl;
      if (_pendingImageFile != null) {
        setState(() => _isUploadingImage = true);
        uploadedUrl = await _api.uploadGroupImage(_pendingImageFile!);
        setState(() => _isUploadingImage = false);
      }
      await _api.updateGroup(
        widget.group['id'],
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        imageUrl: uploadedUrl ?? _currentImageUrl,
        anyoneCanPost: _anyoneCanPost,
        isPrivate: _isPrivate,
      );
      if (mounted) {
        setState(() {
          if (uploadedUrl != null) {
            _currentImageUrl = uploadedUrl;
            _pendingImageFile = null;
          }
          _isSaving = false;
        });
        _toast('Changes saved');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isUploadingImage = false;
        });
        _toast('Failed to save: $e', isError: true);
      }
    }
  }

  // ─── Leave group ─────────────────────────────────────────────────

  Future<void> _leaveGroup() async {
    final ok = await _confirm(
      title: 'Leave Group?',
      body: 'You will lose access to this group and its posts.',
      confirmLabel: 'Leave',
    );
    if (!ok) return;
    try {
      await _api.leaveGroup(widget.group['id']);
      if (mounted) {
        _toast('You left the group');
        Navigator.pop(context, 'left');
        Navigator.pop(context, 'left');
      }
    } catch (e) {
      _toast('Failed to leave: $e', isError: true);
    }
  }

  // ─── Delete group ────────────────────────────────────────────────

  Future<void> _deleteGroup() async {
    final ok = await _confirm(
      title: 'Delete Group?',
      body:
          'This will permanently remove all posts, members and content. Cannot be undone.',
      confirmLabel: 'Delete Forever',
    );
    if (!ok) return;
    try {
      await _api.deleteGroup(widget.group['id']);
      if (mounted) {
        _toast('Group deleted');
        Navigator.pop(context, 'deleted');
        Navigator.pop(context, 'deleted');
      }
    } catch (e) {
      _toast('Failed to delete: $e', isError: true);
    }
  }

  // ─── Member actions ──────────────────────────────────────────────

  void _showMemberActions(Map<String, dynamic> member) {
    final profile = member['profiles'] ?? {};
    final name = profile['full_name'] ?? 'Member';
    final isThisAdmin = member['is_admin'] == true;
    final isCreator = widget.group['creator_id'] == member['user_id'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      backgroundImage: profile['profile_picture_url'] != null
                          ? CachedNetworkImageProvider(
                              profile['profile_picture_url'],
                            )
                          : null,
                      child: profile['profile_picture_url'] == null
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (isCreator)
                          Text(
                            'Owner',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.primary,
                            ),
                          )
                        else if (isThisAdmin)
                          Text(
                            'Admin',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.blue,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),
              if (!isCreator) ...[
                _sheetTile(
                  icon: isThisAdmin
                      ? Icons.remove_moderator_outlined
                      : Icons.admin_panel_settings_outlined,
                  label: isThisAdmin ? 'Remove Admin' : 'Make Admin',
                  color: Colors.blue,
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _toggleAdmin(member, !isThisAdmin);
                  },
                ),
                _sheetTile(
                  icon: Icons.person_remove_outlined,
                  label: 'Remove from Group',
                  color: Colors.red,
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _kickMember(member);
                  },
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'The group owner cannot be removed.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleAdmin(Map<String, dynamic> member, bool makeAdmin) async {
    try {
      await _api.toggleGroupAdmin(
        widget.group['id'],
        member['user_id'],
        makeAdmin,
      );
      await _loadMembers();
      _toast(makeAdmin ? 'Admin role granted' : 'Admin role removed');
    } catch (_) {
      _toast('Failed to update role', isError: true);
    }
  }

  Future<void> _kickMember(Map<String, dynamic> member) async {
    final name = member['profiles']?['full_name'] ?? 'this member';
    final ok = await _confirm(
      title: 'Remove $name?',
      body: 'They will be removed from the group immediately.',
      confirmLabel: 'Remove',
    );
    if (!ok) return;
    try {
      await _api.kickMember(widget.group['id'], member['user_id']);
      await _loadMembers();
      _toast('Member removed');
    } catch (_) {
      _toast('Failed to remove member', isError: true);
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────

  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            content: Text(
              body,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  confirmLabel,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red[700] : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _copyInviteLink() {
    final link = 'https://lifekit.app/groups/${widget.group['id']}';
    Clipboard.setData(ClipboardData(text: link));
    _toast('Invite link copied!');
  }

  Widget _sheetTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) => ListTile(
    leading: Icon(icon, color: color),
    title: Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: 14,
        color: color,
        fontWeight: FontWeight.w500,
      ),
    ),
    onTap: onTap,
  );

  // ─── Build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isCreator = widget.group['creator_id'] == widget.myId;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: const BackButton(color: Colors.black87),
        title: Text(
          widget.isAdmin ? 'Group Settings' : 'Group Info',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          if (widget.isAdmin)
            _isSaving
                ? const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: _saveChanges,
                    child: Text(
                      'Save',
                      style: GoogleFonts.poppins(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
        ],
      ),
      body: _isLoading
          ? const Center(child: LifeKitLoader())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGroupProfile(),
                  if (widget.isAdmin) ...[
                    _label('Privacy & Permissions'),
                    _buildPrivacySection(),
                  ],
                  _label('Invite'),
                  _buildInviteSection(),
                  _label('Members (${_members.length})'),
                  _buildMembersSection(),
                  _label('Actions'),
                  _buildActionsSection(isCreator),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  // ── Group Profile ─────────────────────────────────────────────────

  Widget _buildGroupProfile() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          GestureDetector(
            onTap: widget.isAdmin ? _pickImage : null,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                      width: 3,
                    ),
                  ),
                  child: ClipOval(
                    child: _pendingImageFile != null
                        ? Image.file(_pendingImageFile!, fit: BoxFit.cover)
                        : _currentImageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: _currentImageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: AppColors.primary.withOpacity(0.1),
                            ),
                            errorWidget: (_, __, ___) => _groupAvatar(),
                          )
                        : _groupAvatar(),
                  ),
                ),
                if (widget.isAdmin)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                    ),
                    child: _isUploadingImage
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt,
                            size: 14,
                            color: Colors.white,
                          ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (widget.isAdmin) ...[
            _field(controller: _nameCtrl, label: 'Group Name', maxLength: 80),
            const SizedBox(height: 12),
            _field(
              controller: _descCtrl,
              label: 'Description',
              maxLines: 3,
              maxLength: 500,
            ),
          ] else ...[
            Text(
              widget.group['name'] ?? '',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if ((widget.group['description'] ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  widget.group['description'],
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _groupAvatar() => Container(
    color: AppColors.primary.withOpacity(0.12),
    child: const Icon(Icons.group, color: AppColors.primary, size: 36),
  );

  Widget _field({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    int? maxLength,
  }) => TextField(
    controller: controller,
    maxLines: maxLines,
    maxLength: maxLength,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
      filled: true,
      fillColor: const Color(0xFFF5F5F7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    style: GoogleFonts.poppins(fontSize: 14),
  );

  // ── Privacy ───────────────────────────────────────────────────────

  Widget _buildPrivacySection() => Container(
    color: Colors.white,
    child: Column(
      children: [
        _switchRow(
          icon: Icons.lock_outline,
          title: 'Private Group',
          subtitle: 'Only invited members can join',
          value: _isPrivate,
          onChanged: (v) => setState(() => _isPrivate = v),
        ),
        const Divider(height: 1, indent: 56),
        _switchRow(
          icon: Icons.edit_note_outlined,
          title: 'Anyone can post',
          subtitle: 'If off, only admins can post',
          value: _anyoneCanPost,
          onChanged: (v) => setState(() => _anyoneCanPost = v),
        ),
      ],
    ),
  );

  Widget _switchRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    leading: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: AppColors.primary, size: 20),
    ),
    title: Text(
      title,
      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
    ),
    subtitle: Text(
      subtitle,
      style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey[600]),
    ),
    trailing: Switch(
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
    ),
  );

  // ── Invite ────────────────────────────────────────────────────────

  Widget _buildInviteSection() {
    final link = 'lifekit.app/groups/${widget.group['id']}';
    return Container(
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.link, color: Colors.blue, size: 20),
        ),
        title: Text(
          'Copy Invite Link',
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          link,
          style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.copy, size: 18, color: Colors.grey),
        onTap: _copyInviteLink,
      ),
    );
  }

  // ── Members ───────────────────────────────────────────────────────

  Widget _buildMembersSection() => Container(
    color: Colors.white,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search members...',
              hintStyle: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[400],
              ),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFFF5F5F7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _filteredMembers.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
          itemBuilder: (_, i) => _memberTile(_filteredMembers[i]),
        ),
      ],
    ),
  );

  Widget _memberTile(Map<String, dynamic> member) {
    final profile = member['profiles'] ?? {};
    final name = profile['full_name'] ?? 'Unknown';
    final username = profile['username'] ?? '';
    final imageUrl = profile['profile_picture_url'];
    final isThisAdmin = member['is_admin'] == true;
    final isCreator = widget.group['creator_id'] == member['user_id'];
    final isMe = member['user_id'] == widget.myId;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.primary.withOpacity(0.1),
        backgroundImage: imageUrl != null
            ? CachedNetworkImageProvider(imageUrl)
            : null,
        child: imageUrl == null
            ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              isMe ? '$name (You)' : name,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isCreator) ...[
            const SizedBox(width: 6),
            _badge('Owner', const Color(0xFFAB47BC)),
          ] else if (isThisAdmin) ...[
            const SizedBox(width: 6),
            _badge('Admin', Colors.blue),
          ],
        ],
      ),
      subtitle: username.isNotEmpty
          ? Text(
              '@$username',
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                color: Colors.grey[500],
              ),
            )
          : null,
      trailing: widget.isAdmin && !isMe && !isCreator
          ? IconButton(
              icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
              onPressed: () => _showMemberActions(member),
            )
          : null,
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
    ),
  );

  // ── Actions ───────────────────────────────────────────────────────

  Widget _buildActionsSection(bool isCreator) => Container(
    color: Colors.white,
    child: Column(
      children: [
        if (!isCreator)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 4,
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.exit_to_app,
                color: Colors.orange,
                size: 20,
              ),
            ),
            title: Text(
              'Leave Group',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.orange,
              ),
            ),
            onTap: _leaveGroup,
          ),
        if (isCreator) ...[
          const Divider(height: 1),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 4,
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.delete_forever_outlined,
                color: Colors.red,
                size: 20,
              ),
            ),
            title: Text(
              'Delete Group',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.red,
              ),
            ),
            subtitle: Text(
              'Permanently removes all content',
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                color: Colors.grey[500],
              ),
            ),
            onTap: _deleteGroup,
          ),
        ],
      ],
    ),
  );

  // ── Misc ──────────────────────────────────────────────────────────

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
    child: Text(
      text.toUpperCase(),
      style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.grey[500],
        letterSpacing: 0.8,
      ),
    ),
  );
}
