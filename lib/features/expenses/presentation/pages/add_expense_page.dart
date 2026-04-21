import 'package:flutter/material.dart';

import '../../../../core/state/app_state.dart';
import '../../../../domain/entities/expense.dart';
import '../../../../domain/entities/group.dart';
import '../../../../domain/entities/group_member.dart';

class AddExpensePage extends StatefulWidget {
  const AddExpensePage({super.key});

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _totalController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  SplitMethod _splitMethod = SplitMethod.equal;
  final Set<String> _selectedPayerIds = <String>{};
  final Set<String> _selectedParticipantIds = <String>{};
  final Map<String, TextEditingController> _payerAmountControllers =
      <String, TextEditingController>{};
  final Map<String, TextEditingController> _shareControllers =
      <String, TextEditingController>{};

  String? _validationMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _totalController.dispose();
    for (final TextEditingController controller in _payerAmountControllers.values) {
      controller.dispose();
    }
    for (final TextEditingController controller in _shareControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppStateController appState = AppStateScope.of(context);
    final ExpenseGroup? group = appState.activeGroup;

    if (group == null) {
      return const Center(child: Text('Create a group from Manage before adding expenses.'));
    }

    _ensureControllers(group.members);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text('Add Expense', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text('Active group: ${group.name}'),
        const SizedBox(height: 16),
        _InputField(
          label: 'Title *',
          hint: 'Dinner, Fuel, Rent...',
          controller: _titleController,
        ),
        _InputField(
          label: 'Total amount *',
          hint: '0.00',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          controller: _totalController,
        ),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          tileColor: const Color(0xFFF6F8FC),
          title: const Text('Date *'),
          subtitle: Text(
            '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
          ),
          trailing: const Icon(Icons.calendar_today_outlined),
          onTap: _selectDate,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<SplitMethod>(
          initialValue: _splitMethod,
          decoration: const InputDecoration(
            labelText: 'Split method *',
            border: OutlineInputBorder(),
          ),
          items: const <DropdownMenuItem<SplitMethod>>[
            DropdownMenuItem(value: SplitMethod.equal, child: Text('Equal split')),
            DropdownMenuItem(value: SplitMethod.fixedAmount, child: Text('Fixed amount split')),
            DropdownMenuItem(value: SplitMethod.percentage, child: Text('Percentage split')),
          ],
          onChanged: (SplitMethod? method) {
            if (method == null) {
              return;
            }
            setState(() {
              _splitMethod = method;
            });
          },
        ),
        const SizedBox(height: 18),
        Text('Payers *', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        ...group.members.map((GroupMember member) {
          final bool selected = _selectedPayerIds.contains(member.id);
          return Card(
            child: CheckboxListTile(
              value: selected,
              title: Text(member.name),
              subtitle: selected
                  ? TextField(
                      controller: _payerAmountControllers[member.id],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Paid amount',
                        hintText: '0.00',
                      ),
                    )
                  : const Text('Not selected as payer'),
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    _selectedPayerIds.add(member.id);
                  } else {
                    _selectedPayerIds.remove(member.id);
                  }
                });
              },
            ),
          );
        }),
        const SizedBox(height: 14),
        Text('Participants *', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        ...group.members.map((GroupMember member) {
          final bool selected = _selectedParticipantIds.contains(member.id);
          return Card(
            child: CheckboxListTile(
              value: selected,
              title: Text(member.name),
              subtitle: _splitMethod == SplitMethod.equal || !selected
                  ? null
                  : TextField(
                      controller: _shareControllers[member.id],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: _splitMethod == SplitMethod.fixedAmount
                            ? 'Amount share'
                            : 'Percentage share',
                        hintText: _splitMethod == SplitMethod.fixedAmount ? '0.00' : '0-100',
                      ),
                    ),
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    _selectedParticipantIds.add(member.id);
                  } else {
                    _selectedParticipantIds.remove(member.id);
                  }
                });
              },
            ),
          );
        }),
        if (_validationMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _validationMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _submit(appState, group),
          icon: const Icon(Icons.save_outlined),
          label: const Text('Create Expense'),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final DateTime initialDate = _selectedDate;
    final DateTime firstDate = DateTime(2020);
    final DateTime lastDate = DateTime(2100);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _submit(AppStateController appState, ExpenseGroup group) {
    final String title = _titleController.text.trim();
    final double? total = double.tryParse(_totalController.text.trim());

    if (title.isEmpty) {
      _setValidation('Title is required.');
      return;
    }
    if (total == null || total <= 0) {
      _setValidation('Total amount must be greater than 0.');
      return;
    }
    if (_selectedPayerIds.isEmpty) {
      _setValidation('At least one payer is required.');
      return;
    }
    if (_selectedParticipantIds.isEmpty) {
      _setValidation('At least one participant is required.');
      return;
    }

    final List<ExpensePayer> payers = <ExpensePayer>[];
    double payerSum = 0;
    for (final String payerId in _selectedPayerIds) {
      final double? amount = double.tryParse(_payerAmountControllers[payerId]!.text.trim());
      if (amount == null || amount < 0) {
        _setValidation('Each payer amount must be a valid non-negative number.');
        return;
      }
      payers.add(ExpensePayer(memberId: payerId, amount: amount));
      payerSum += amount;
    }

    if (!_isClose(payerSum, total)) {
      _setValidation('Sum of payer amounts must equal total amount.');
      return;
    }

    final List<ExpenseParticipantShare> shares = <ExpenseParticipantShare>[];
    if (_splitMethod == SplitMethod.equal) {
      final double equalShare = total / _selectedParticipantIds.length;
      for (final String participantId in _selectedParticipantIds) {
        shares.add(ExpenseParticipantShare(memberId: participantId, value: equalShare));
      }
    } else if (_splitMethod == SplitMethod.fixedAmount) {
      double shareSum = 0;
      for (final String participantId in _selectedParticipantIds) {
        final double? value = double.tryParse(_shareControllers[participantId]!.text.trim());
        if (value == null || value < 0) {
          _setValidation('Each participant fixed amount must be valid and non-negative.');
          return;
        }
        shareSum += value;
        shares.add(ExpenseParticipantShare(memberId: participantId, value: value));
      }
      if (!_isClose(shareSum, total)) {
        _setValidation('For amount split, participant shares must equal total amount.');
        return;
      }
    } else {
      double percentageSum = 0;
      for (final String participantId in _selectedParticipantIds) {
        final double? value = double.tryParse(_shareControllers[participantId]!.text.trim());
        if (value == null || value < 0) {
          _setValidation('Each participant percentage must be valid and non-negative.');
          return;
        }
        percentageSum += value;
        shares.add(ExpenseParticipantShare(memberId: participantId, value: value));
      }
      if (!_isClose(percentageSum, 100)) {
        _setValidation('For percentage split, participant shares must equal 100%.');
        return;
      }
    }

    final String? error = appState.createExpense(
      title: title,
      totalAmount: total,
      date: _selectedDate,
      splitMethod: _splitMethod,
      payers: payers,
      participants: _selectedParticipantIds.toList(),
      shares: shares,
    );

    if (error != null) {
      _setValidation(error);
      return;
    }

    setState(() {
      _validationMessage = null;
      _titleController.clear();
      _totalController.clear();
      _selectedPayerIds.clear();
      _selectedParticipantIds.clear();
      for (final TextEditingController controller in _payerAmountControllers.values) {
        controller.clear();
      }
      for (final TextEditingController controller in _shareControllers.values) {
        controller.clear();
      }
      _selectedDate = DateTime.now();
      _splitMethod = SplitMethod.equal;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Expense created in ${group.name}.')),
    );
  }

  void _ensureControllers(List<GroupMember> members) {
    for (final GroupMember member in members) {
      _payerAmountControllers.putIfAbsent(member.id, () => TextEditingController());
      _shareControllers.putIfAbsent(member.id, () => TextEditingController());
    }
  }

  void _setValidation(String message) {
    setState(() {
      _validationMessage = message;
    });
  }

  bool _isClose(double a, double b, {double tolerance = 0.01}) {
    return (a - b).abs() <= tolerance;
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
