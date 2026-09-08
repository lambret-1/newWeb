import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/services/password_service.dart';

/// 主密码验证页：访问密码本前验证身份。
class MasterPasswordPage extends StatefulWidget {
  final bool isSetup; // true=设置主密码，false=验证主密码
  const MasterPasswordPage({super.key, this.isSetup = false});

  @override
  State<MasterPasswordPage> createState() => _MasterPasswordPageState();
}

class _MasterPasswordPageState extends State<MasterPasswordPage> {
  final _controller = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pwd = _controller.text.trim();
    if (pwd.isEmpty) {
      setState(() => _error = '请输入主密码');
      return;
    }
    if (pwd.length < 4) {
      setState(() => _error = '主密码至少 4 位');
      return;
    }

    if (widget.isSetup) {
      final confirm = _confirmController.text.trim();
      if (pwd != confirm) {
        setState(() => _error = '两次输入不一致');
        return;
      }
      await PasswordService.instance.setMasterPassword(pwd);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } else {
      final ok = await PasswordService.instance.verifyMasterPassword(pwd);
      if (!ok) {
        setState(() => _error = '主密码错误');
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F7),
        elevation: 0,
        title: Text(widget.isSetup ? '设置主密码' : '验证主密码',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(false),
          child: const Icon(Icons.arrow_back_ios, size: 20, color: Color(0xFF007AFF)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            Icon(Icons.lock_outline, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              widget.isSetup
                  ? '设置主密码以保护密码本\n主密码仅保存在本设备'
                  : '请输入主密码以访问密码本',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 32),
            _buildInput(
              controller: _controller,
              placeholder: widget.isSetup ? '设置主密码' : '输入主密码',
            ),
            if (widget.isSetup) ...[
              const SizedBox(height: 12),
              _buildInput(
                controller: _confirmController,
                placeholder: '确认主密码',
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
            const SizedBox(height: 24),
            CupertinoButton(
              color: const Color(0xFF007AFF),
              borderRadius: BorderRadius.circular(12),
              onPressed: _submit,
              child: Text(widget.isSetup ? '确认设置' : '验证',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String placeholder,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: _obscure,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: placeholder,
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
              ),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            onPressed: () => setState(() => _obscure = !_obscure),
            child: Icon(
              _obscure ? Icons.visibility_off : Icons.visibility,
              size: 20,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}
