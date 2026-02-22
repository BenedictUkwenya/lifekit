import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/lifekit_loader.dart';

class GroupSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> group;
  const GroupSettingsScreen({super.key, required this.group});

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> members = [];
  bool isLoading = true;
  bool anyoneCanPost = true;

  @override
  void initState() {
    super.initState();
    anyoneCanPost = widget.group['anyone_can_post'] ?? true;
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final data = await _apiService.getGroupMembers(widget.group['id']);
      if (mounted) {
        setState(() {
          members = data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showErrorSnackBar("Failed to load members");
      }
    }
  }

  void _togglePostingPermission(bool val) async {
    setState(() => anyoneCanPost = val);
    try {
      await _apiService.updateGroupSettings(widget.group['id'], val);
      _showSuccessSnackBar("Permissions updated");
    } catch (e) {
      setState(() => anyoneCanPost = !val); // Revert UI
      _showErrorSnackBar("Failed to update settings");
    }
  }

  void _handleMemberAction(dynamic member) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                member['is_admin']
                    ? Icons.remove_moderator
                    : Icons.shield_outlined,
              ),
              title: Text(member['is_admin'] ? "Remove Admin" : "Make Admin"),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await _apiService.toggleGroupAdmin(
                    widget.group['id'],
                    member['user_id'],
                    !member['is_admin'],
                  );
                  _showSuccessSnackBar("Role updated");
                  _loadMembers();
                } catch (e) {
                  _showErrorSnackBar("Failed to update role");
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.person_remove_outlined,
                color: Colors.red,
              ),
              title: const Text(
                "Remove from Group",
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await _apiService.kickMember(
                    widget.group['id'],
                    member['user_id'],
                  );
                  _showSuccessSnackBar("Member removed");
                  _loadMembers();
                } catch (e) {
                  _showErrorSnackBar("Failed to remove member");
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "Group Settings",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        leading: const BackButton(color: Colors.black),
      ),
      body: isLoading
          ? const Center(child: LifeKitLoader())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader("Permissions"),
                  Container(
                    color: Colors.white,
                    child: SwitchListTile(
                      activeColor: AppColors.primary,
                      title: Text(
                        "Anyone can post",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: const Text(
                        "If disabled, only admins can post content",
                        style: TextStyle(fontSize: 12),
                      ),
                      value: anyoneCanPost,
                      onChanged: _togglePostingPermission,
                    ),
                  ),
                  _buildSectionHeader("Members (${members.length})"),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: members.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, indent: 70),
                    itemBuilder: (context, index) {
                      final m = members[index];
                      final profile = m['profiles'];
                      return ListTile(
                        tileColor: Colors.white,
                        leading: CircleAvatar(
                          backgroundImage:
                              profile['profile_picture_url'] != null
                              ? CachedNetworkImageProvider(
                                  profile['profile_picture_url'],
                                )
                              : null,
                          child: profile['profile_picture_url'] == null
                              ? const Icon(Icons.person, color: Colors.grey)
                              : null,
                        ),
                        title: Text(
                          profile['full_name'],
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          "@${profile['username'] ?? 'user'}",
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: m['is_admin']
                            ? _buildAdminBadge()
                            : IconButton(
                                icon: const Icon(Icons.more_horiz),
                                onPressed: () => _handleMemberAction(m),
                              ),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  Center(
                    child: TextButton(
                      onPressed: _showDeleteConfirm, // Corrected to call helper
                      child: const Text(
                        "Delete Group",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildAdminBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        "Admin",
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // --- MERGED DELETE LOGIC ---
  void _showDeleteConfirm() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Group?"),
        content: const Text(
          "This will permanently remove all posts and members. This action is permanent and cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.deleteGroup(widget.group['id']);
        if (mounted) {
          _showSuccessSnackBar("Group deleted");
          // Pop twice: First for settings, second for group detail
          Navigator.pop(context);
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) _showErrorSnackBar("Failed to delete group: $e");
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
