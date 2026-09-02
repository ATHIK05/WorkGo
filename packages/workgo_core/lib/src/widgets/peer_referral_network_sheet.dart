import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/worker.dart';
import '../services/worker_service.dart';

void showPeerReferralNetworkSheet(BuildContext context, {required Worker worker}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => PeerReferralNetworkSheet(worker: worker),
  );
}

class PeerReferralNetworkSheet extends StatefulWidget {
  const PeerReferralNetworkSheet({
    super.key,
    required this.worker,
  });

  final Worker worker;

  @override
  State<PeerReferralNetworkSheet> createState() => _PeerReferralNetworkSheetState();
}

class _PeerReferralNetworkSheetState extends State<PeerReferralNetworkSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _expCtrl = TextEditingController(text: "3");
  String _selectedSkill = "Plumbing";
  bool _isLoading = false;
  bool _showAddForm = false;

  final List<String> _skills = [
    "Plumbing",
    "Electrical",
    "Carpentry",
    "Cleaning",
    "Painting",
    "Air Conditioner",
    "Appliance Repair",
    "Masonry",
  ];

  @override
  void initState() {
    super.initState();
    if (widget.worker.skills.isNotEmpty) {
      _selectedSkill = widget.worker.skills.first;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _expCtrl.dispose();
    super.dispose();
  }

  String get _referralCode {
    final cleanName = widget.worker.name.replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();
    final prefix = cleanName.isNotEmpty ? (cleanName.length > 5 ? cleanName.substring(0, 5) : cleanName) : "KARYA";
    final suffix = widget.worker.id.length > 4 ? widget.worker.id.substring(0, 4).toUpperCase() : "7799";
    return "$prefix-$suffix";
  }

  Future<void> _submitPeerOnboarding() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final workerService = WorkerService();
      await workerService.referProxyWorker(
        name: _nameCtrl.text.trim(),
        phoneForCalling: _phoneCtrl.text.trim(),
        primarySkill: _selectedSkill,
        experienceYears: int.tryParse(_expCtrl.text.trim()) ?? 2,
        referrerId: widget.worker.id,
        referrerRole: "worker",
      );

      // Increment worker's local stats
      final updated = widget.worker.copyWith(
        referralCount: widget.worker.referralCount + 1,
        referralEarnings: widget.worker.referralEarnings + 100.0,
      );
      await workerService.upsertWorkerProfile(updated);

      if (mounted) {
        setState(() {
          _showAddForm = false;
          _nameCtrl.clear();
          _phoneCtrl.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Peer artisan onboarded! ₹100 referral bonus credited to ledger."),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Onboarding error: $e"),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      margin: const EdgeInsets.only(top: 40),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFBF2),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Handle Bar
              Center(
                child: Container(
                  width: 40,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E0D8),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Header Title & Icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE0A3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.groups_rounded, color: Color(0xFF92400E), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Peer Referral Guild",
                          style: TextStyle(
                            color: Color(0xFF141416),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 1),
                        const Text(
                          "Earn 2% lifetime bonus on peer dispatches",
                          style: TextStyle(color: Color(0xFF6B6B6B), fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF6B6B6B)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Unique Invite Code Banner (Obsidian Luxury Card)
              _buildInviteCodeCard(),
              const SizedBox(height: 14),

              // ── 3 Network Performance Bento Chips
              _buildStatsRow(),
              const SizedBox(height: 18),

              // ── Action Section: Direct Onboard vs Guild Benefits
              if (!_showAddForm) ...[
                // Onboard Peer Button
                ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _showAddForm = true);
                  },
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text("Directly Onboard Peer Artisan", style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF141416),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
                const SizedBox(height: 16),

                // Co-op Network Benefits Card
                _buildGuildBenefitsCard(),
              ] else ...[
                // Onboard Form
                _buildOnboardForm(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInviteCodeCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2B000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "YOUR ARTISAN INVITE CODE",
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "ACTIVE",
                  style: TextStyle(color: Color(0xFF34D399), fontSize: 9.5, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _referralCode,
                style: const TextStyle(
                  color: Color(0xFFFFB800),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _referralCode));
                      HapticFeedback.selectionClick();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Invite code '$_referralCode' copied!"),
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF26262B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF3F3F46)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.copy_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text("Copy", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _statPill(
            "Artisans",
            "${widget.worker.referralCount}",
            const Color(0xFFD1FAE5),
            const Color(0xFF065F46),
            Icons.people_alt_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statPill(
            "Earnings",
            "₹${widget.worker.referralEarnings.toStringAsFixed(0)}",
            const Color(0xFFD6EBFF),
            const Color(0xFF1E3A8A),
            Icons.account_balance_wallet_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statPill(
            "Guild Cut",
            "2% Tier",
            const Color(0xFFFFE0A3),
            const Color(0xFF92400E),
            Icons.bolt_rounded,
          ),
        ),
      ],
    );
  }

  Widget _statPill(String label, String value, Color bg, Color textCol, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textCol.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: textCol, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(color: textCol, fontSize: 13, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: textCol.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildGuildBenefitsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0EDE6), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "How Peer Referral Works",
            style: TextStyle(color: Color(0xFF141416), fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _benefitRow(
            icon: Icons.card_giftcard_rounded,
            title: "₹100 Onboarding Bounty",
            desc: "Instantly credited to your ledger when your referred peer completes 3 jobs.",
          ),
          const SizedBox(height: 10),
          _benefitRow(
            icon: Icons.trending_up_rounded,
            title: "2% Passive Guild Revenue",
            desc: "Earn 2% of the gross ticket on every job completed by your network.",
          ),
          const SizedBox(height: 10),
          _benefitRow(
            icon: Icons.swap_horiz_rounded,
            title: "Seamless 1-Tap Job Transfers",
            desc: "When busy or traveling, hand off live dispatches to your trusted peers.",
          ),
        ],
      ),
    );
  }

  Widget _benefitRow({required IconData icon, required String title, required String desc}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF141416)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Color(0xFF141416), fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(color: Color(0xFF6B6B6B), fontSize: 11, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOnboardForm() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0EDE6), width: 1.2),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Onboard Peer Artisan",
                  style: TextStyle(color: Color(0xFF141416), fontSize: 15, fontWeight: FontWeight.w800),
                ),
                IconButton(
                  onPressed: () => setState(() => _showAddForm = false),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Name
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: "Peer's Full Name",
                hintText: "e.g. Ramesh Kumar",
                filled: true,
                fillColor: const Color(0xFFF9F6EE),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFF0EDE6))),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? "Enter peer's name" : null,
            ),
            const SizedBox(height: 10),

            // Phone
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: "Mobile Phone Number",
                hintText: "+91 98765 43210",
                filled: true,
                fillColor: const Color(0xFFF9F6EE),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFF0EDE6))),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? "Enter valid phone number" : null,
            ),
            const SizedBox(height: 12),

            // Trade skill dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedSkill,
              decoration: InputDecoration(
                labelText: "Primary Trade",
                filled: true,
                fillColor: const Color(0xFFF9F6EE),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFF0EDE6))),
              ),
              items: _skills.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedSkill = val);
              },
            ),
            const SizedBox(height: 16),

            // Submit Button
            ElevatedButton(
              onPressed: _isLoading ? null : _submitPeerOnboarding,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF141416),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text("Register Peer & Claim ₹100 Bonus", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}
