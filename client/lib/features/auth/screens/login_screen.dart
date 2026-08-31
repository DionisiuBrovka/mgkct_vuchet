import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../injection.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';
import '../repository/auth_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  String? _selectedProfileId;
  List<LoginUser> _users = [];
  String? _loadError;
  bool _loadingNames = true;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _loadNames();
  }

  Future<void> _loadNames() async {
    setState(() {
      _loadingNames = true;
      _loadError = null;
    });
    try {
      final names = await getIt<AuthRepository>().getUsers();
      if (mounted) {
        setState(() {
          _users = names;
          _loadingNames = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadingNames = false;
          _loadError = error.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(fit: StackFit.expand, children: [
        Image.asset(
          'assets/images/back.png',
          fit: BoxFit.cover,
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: BlocConsumer<AuthCubit, AuthState>(
                  listener: (ctx, state) {
                    if (state is AuthError) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(state.message)),
                      );
                    }
                  },
                  builder: (ctx, state) {
                    final loading = state is AuthLoading;
                    return Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Вычитка',
                              style: TextStyle(
                                  fontSize: 28, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const Text('Учёт учебной нагрузки',
                              style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 32),
                          if (_loadError != null) ...[
                            Text(_loadError!),
                            TextButton(
                                onPressed: _loadNames,
                                child: const Text('Повторить'))
                          ],
                          if (_loadingNames)
                            const LinearProgressIndicator()
                          else
                            DropdownButtonFormField<String>(
                              initialValue: _selectedProfileId,
                              decoration:
                                  const InputDecoration(labelText: 'ФИО'),
                              items: _users
                                  .map((n) => DropdownMenuItem(
                                        value: n.id,
                                        child: Text(
                                            _users
                                                        .where((u) =>
                                                            u.name == n.name)
                                                        .length >
                                                    1
                                                ? '${n.name} (${n.id.substring(n.id.length - 4)})'
                                                : n.name,
                                            overflow: TextOverflow.ellipsis),
                                      ))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedProfileId = v),
                              validator: (v) =>
                                  v == null ? 'Выберите ФИО' : null,
                            ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordCtrl,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: 'Пароль',
                              suffixIcon: IconButton(
                                icon: Icon(_obscure
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Введите пароль'
                                : null,
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: loading
                                ? null
                                : () {
                                    if (_formKey.currentState!.validate()) {
                                      ctx.read<AuthCubit>().login(
                                            _selectedProfileId!,
                                            _passwordCtrl.text,
                                          );
                                    }
                                  },
                            child: loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('Войти'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
