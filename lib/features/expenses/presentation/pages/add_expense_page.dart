import 'package:flutter/material.dart';

import '../../../../core/state/app_state.dart';
import '../../../../domain/entities/expense.dart';
import '../../../../domain/entities/group.dart';
import '../../../../domain/entities/group_member.dart';

class AddExpensePage extends StatefulWidget {
  const AddExpensePage({super.key, this.editExpenseId});

  final String? editExpenseId;

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _totalController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  SplitMethod _splitMethod = SplitMethod.equal;
  
  // Paid by dynamic entries
  final List<String> _payerMemberIds = <String>[];
  final Map<String, TextEditingController> _payerAmountControllers = <String, TextEditingController>{};

  final Set<String> _selectedParticipantIds = <String>{};
  final Map<String, TextEditingController> _shareControllers = <String, TextEditingController>{};

  String? _validationMessage;
  bool _initialized = false;

  @override
  void dispose() {
    _titleController.dispose();
    _totalController.dispose();
    for (final TextEditingController c in _payerAmountControllers.values) {
      c.dispose();
    }
    for (final TextEditingController c in _shareControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initForm(ExpenseGroup group, AppStateController appState) {
    if (_initialized) return;

    for (final GroupMember m in group.members) {
      _shareControllers[m.id] = TextEditingController();
    }

    if (widget.editExpenseId != null) {
      final ExpenseItem? expense = appState.activeGroupExpenses.where((ExpenseItem e) => e.id == widget.editExpenseId).firstOrNull;
      if (expense != null) {
        _titleController.text = expense.title;
        _totalController.text = expense.totalAmount.toString();
        _selectedDate = expense.date;
        _splitMethod = expense.splitMethod;
        
        for (final ExpensePayer ep in expense.payers) {
          _payerMemberIds.add(ep.memberId);
          _payerAmountControllers[ep.memberId] = TextEditingController(text: ep.amount.toString());
        }
        
        for (final String pid in expense.participants) {
          _selectedParticipantIds.add(pid);
        }
        for (final ExpenseParticipantShare es in expense.splitShares) {
          _shareControllers[es.memberId]?.text = es.value.toString();
        }
      }
    } else {
      final String meId = appState.localProfileUserId ?? group.members.first.id;
      _payerMemberIds.add(meId);
      _payerAmountControllers[meId] = TextEditingController();
      for (final GroupMember m in group.members) {
        _selectedParticipantIds.add(m.id);
      }
    }
    
    _totalController.addListener(_onTotalChanged);
    _initialized = true;
  }

  void _onTotalChanged() {
    if (_payerMemberIds.length == 1 && widget.editExpenseId == null) {
       _payerAmountControllers[_payerMemberIds.first]?.text = _totalController.text;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final AppStateController appState = AppStateScope.of(context);
    final ExpenseGroup? group = appState.activeGroup;

    if (group == null) {
      return const Center(child: Text('Create a group from Manage before adding expenses.'));
    }

    _initForm(group, appState);

    final double totalParsed = double.tryParse(_totalController.text) ?? 0.0;
    double currentPayerSum = 0;
    for (final String pid in _payerMemberIds) {
      currentPayerSum += double.tryParse(_payerAmountControllers[pid]?.text ?? '0') ?? 0;
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: Text(widget.editExpenseId != null ? 'Edit Expense' : 'Add Expense')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        children: <Widget>[
          Text(widget.editExpenseId != null ? 'Edit Expense' : 'Add Expense', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(hintText: 'Expense Title'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _totalController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'Total Amount', prefixText: '₹ '),
          ),
          
          const SizedBox(height: 32),
          Text('Paid By', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          
          ..._payerMemberIds.asMap().entries.map((MapEntry<int, String> entry) {
            final int index = entry.key;
            final String memberId = entry.value;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: memberId,
                      items: group.members.map((GroupMember m) {
                        return DropdownMenuItem<String>(
                          value: m.id,
                          child: Text(m.name),
                        );
                      }).toList(),
                      onChanged: (String? val) {
                        if (val != null) {
                          setState(() {
                            final TextEditingController oldC = _payerAmountControllers.remove(memberId)!;
                            _payerMemberIds[index] = val;
                            _payerAmountControllers[val] = oldC;
                          });
                        }
                      },
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _payerAmountControllers[memberId],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(hintText: 'Amount', contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                      onChanged: (_) => setState((){}),
                    ),
                  ),
                  if (_payerMemberIds.length > 1)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey),
                      onPressed: () {
                        setState(() {
                          _payerMemberIds.removeAt(index);
                          _payerAmountControllers.remove(memberId)?.dispose();
                        });
                      },
                    )
                ],
              ),
            );
          }),
          
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  final String newId = group.members.first.id; 
                  // allow duplicate dropdowns for multiple payments by same person or default
                  _payerMemberIds.add(newId);
                  _payerAmountControllers[newId] = TextEditingController();
                });
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Payer'),
            ),
          ),
          
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Total Paid: ₹${currentPayerSum.toStringAsFixed(2)} / ₹${totalParsed.toStringAsFixed(2)}',
              style: TextStyle(
                color: (currentPayerSum - totalParsed).abs() < 0.01 ? Colors.green : Colors.orange,
              ),
            ),
          ),

          const SizedBox(height: 32),
          Text('Split amongst', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                setState(() {
                  if (_selectedParticipantIds.length == group.members.length) {
                    _selectedParticipantIds.clear();
                  } else {
                    _selectedParticipantIds.addAll(group.members.map((GroupMember m) => m.id));
                  }
                });
              },
              child: Text(_selectedParticipantIds.length == group.members.length ? 'Deselect All' : 'Select All'),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: group.members.map((GroupMember m) {
              final bool selected = _selectedParticipantIds.contains(m.id);
              return ChoiceChip(
                label: Text(m.name),
                selected: selected,
                onSelected: (bool val) {
                  setState(() {
                    if (val) {
                      _selectedParticipantIds.add(m.id);
                    } else {
                      _selectedParticipantIds.remove(m.id);
                    }
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 32),
          Text('Split method', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SegmentedButton<SplitMethod>(
            segments: const <ButtonSegment<SplitMethod>>[
              ButtonSegment<SplitMethod>(value: SplitMethod.equal, label: Text('Equal')),
              ButtonSegment<SplitMethod>(value: SplitMethod.fixedAmount, label: Text('Amount')),
              ButtonSegment<SplitMethod>(value: SplitMethod.percentage, label: Text('Percentage')),
            ],
            selected: <SplitMethod>{_splitMethod},
            onSelectionChanged: (Set<SplitMethod> method) {
              setState(() {
                _splitMethod = method.first;
              });
            },
            showSelectedIcon: false,
          ),
          
          if (_splitMethod != SplitMethod.equal) ...<Widget>[
            const SizedBox(height: 16),
            ...group.members.where((GroupMember m) => _selectedParticipantIds.contains(m.id)).map((GroupMember m) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: <Widget>[
                    Expanded(flex: 1, child: Text(m.name)),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _shareControllers[m.id],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: _splitMethod == SplitMethod.percentage ? 'Percentage %' : 'Amount',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onChanged: (_) => setState((){}),
                      ),
                    ),
                  ],
                ),
              );
            }),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _splitMethod == SplitMethod.percentage
                    ? 'Total: ${_calculateCurrentShareSum().toStringAsFixed(2)} %'
                    : 'Total: ₹${_calculateCurrentShareSum().toStringAsFixed(2)}',
              ),
            ),
          ],
          
          if (_validationMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  _validationMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                ),
              ),
            ),

          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => _submit(appState, group),
            icon: const Icon(Icons.add),
            label: const Text('Add Expense'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  double _calculateCurrentShareSum() {
    double sum = 0;
    for (final String pid in _selectedParticipantIds) {
      sum += double.tryParse(_shareControllers[pid]?.text ?? '0') ?? 0;
    }
    return sum;
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
    if (_payerMemberIds.isEmpty) {
      _setValidation('At least one payer is required.');
      return;
    }
    if (_selectedParticipantIds.isEmpty) {
      _setValidation('At least one participant is required.');
      return;
    }

    final List<ExpensePayer> payers = <ExpensePayer>[];
    double payerSum = 0;
    for (final String pid in _payerMemberIds) {
      final double? amount = double.tryParse(_payerAmountControllers[pid]!.text.trim());
      if (amount == null || amount < 0) {
        _setValidation('Each payer amount must be a valid non-negative number.');
        return;
      }
      payers.add(ExpensePayer(memberId: pid, amount: amount));
      payerSum += amount;
    }

    if (!_isClose(payerSum, total)) {
      _setValidation('Sum of payer amounts must equal total amount.');
      return;
    }

    final List<ExpenseParticipantShare> shares = <ExpenseParticipantShare>[];
    if (_splitMethod == SplitMethod.equal) {
      final double equalShare = total / _selectedParticipantIds.length;
      for (final String pid in _selectedParticipantIds) {
        shares.add(ExpenseParticipantShare(memberId: pid, value: equalShare));
      }
    } else {
      final double shareSum = _calculateCurrentShareSum();
      final double expectedSum = _splitMethod == SplitMethod.percentage ? 100.0 : total;
      
      if (!_isClose(shareSum, expectedSum)) {
        _setValidation('Participant shares must sum to ${expectedSum.toStringAsFixed(2)} for this split method.');
        return;
      }

      for (final String pid in _selectedParticipantIds) {
        final double value = double.tryParse(_shareControllers[pid]!.text.trim()) ?? 0;
        shares.add(ExpenseParticipantShare(memberId: pid, value: value));
      }
    }

    String? error;
    if (widget.editExpenseId != null) {
      error = appState.updateExpense(
        id: widget.editExpenseId!,
        title: title,
        totalAmount: total,
        date: _selectedDate,
        splitMethod: _splitMethod,
        payers: payers,
        participants: _selectedParticipantIds.toList(),
        shares: shares,
      );
    } else {
      error = appState.createExpense(
        title: title,
        totalAmount: total,
        date: _selectedDate,
        splitMethod: _splitMethod,
        payers: payers,
        participants: _selectedParticipantIds.toList(),
        shares: shares,
      );
    }

    if (error != null) {
      _setValidation(error);
      return;
    }

    setState(() {
      _validationMessage = null;
      _titleController.clear();
      _totalController.clear();
      _payerMemberIds.clear();
      
      final String meId = appState.localProfileUserId ?? group.members.first.id;
      _payerMemberIds.add(meId);
      _payerAmountControllers[meId]?.clear();
      
      _selectedParticipantIds.addAll(group.members.map((GroupMember m) => m.id));
      for (final TextEditingController c in _shareControllers.values) {
        c.clear();
      }
      _selectedDate = DateTime.now();
      _splitMethod = SplitMethod.equal;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.editExpenseId != null ? 'Expense updated.' : 'Expense added successfully.')),
    );
    Navigator.of(context).pop();
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
