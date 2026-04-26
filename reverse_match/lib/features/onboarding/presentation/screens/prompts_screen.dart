import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../state/onboarding_state.dart';
import '../widgets/onboarding_scaffold.dart';

class PromptsScreen extends ConsumerStatefulWidget {
  const PromptsScreen({super.key});

  @override
  ConsumerState<PromptsScreen> createState() => _PromptsScreenState();
}

class _PromptsScreenState extends ConsumerState<PromptsScreen> {
  static const List<String> _allPrompts = [
    'Two truths and a lie…',
    'The way to win me over is…',
    'My simple pleasures…',
    'A random fact I love is…',
    "I'll fall for you if…",
    "Don't hate me if I…",
    "I'm looking for…",
    'My greatest strength…',
    'My love language is…',
    'The best way to ask me out is…',
    'Dating me is like…',
    'Typical Sunday…',
    'My happy place…',
    'My biggest date fail…',
    'Weirdest gift I have given…',
    'The most spontaneous thing I have done…',
    'A shower thought I recently had…',
    'I get way too excited about…',
    'I go crazy for…',
    'Unusual skills…',
    'I quote too much from…',
    'My therapist would say…',
    'My cry-in-the-car song is…',
    'Unpopular opinion…',
    'Green flags I look for…',
    'What I order for the table…',
    'All I ask is that you…',
    'Best travel story…',
    'Change my mind about…',
    "I'm a great +1 because…",
  ];

  @override
  Widget build(BuildContext context) {
    final prompts = ref.watch(onboardingProvider).prompts;
    final canProceed = prompts.length == 3;
    void next() =>
        context.push(OnboardingSteps.next('/onboarding/prompts')!);

    return OnboardingScaffold(
      title: 'Choose 3 prompts',
      subtitle:
          'Prompts are the personality of your profile. Pick the ones that feel most you.',
      progress: OnboardingSteps.progress('/onboarding/prompts'),
      onNext: canProceed ? next : null,
      child: Column(
        children: [
          for (int i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PromptSlot(
                index: i,
                prompt: i < prompts.length ? prompts[i] : null,
                allPrompts: _allPrompts,
                usedPrompts:
                    prompts.map((p) => p.question).toSet(),
                onSave: (newPrompt) {
                  final list = [...prompts];
                  if (i < list.length) {
                    list[i] = newPrompt;
                  } else {
                    list.add(newPrompt);
                  }
                  ref
                      .read(onboardingProvider.notifier)
                      .setPrompts(list);
                },
                onRemove: () {
                  final list = [...prompts]..removeAt(i);
                  ref
                      .read(onboardingProvider.notifier)
                      .setPrompts(list);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _PromptSlot extends StatelessWidget {
  final int index;
  final PromptAnswer? prompt;
  final List<String> allPrompts;
  final Set<String> usedPrompts;
  final ValueChanged<PromptAnswer> onSave;
  final VoidCallback onRemove;

  const _PromptSlot({
    required this.index,
    required this.prompt,
    required this.allPrompts,
    required this.usedPrompts,
    required this.onSave,
    required this.onRemove,
  });

  Future<void> _edit(BuildContext context) async {
    final result = await showModalBottomSheet<PromptAnswer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PromptPickerSheet(
        prompts: allPrompts,
        used: usedPrompts,
        existing: prompt,
      ),
    );
    if (result != null) onSave(result);
  }

  @override
  Widget build(BuildContext context) {
    if (prompt == null) {
      return InkWell(
        onTap: () => _edit(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding:
              const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.4),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.add, color: AppColors.primary),
              const SizedBox(width: 12),
              Text('Select a Prompt ${index + 1}',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => _edit(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    prompt!.question,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                InkWell(
                  onTap: onRemove,
                  child: const Icon(Icons.close,
                      size: 20, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              prompt!.answer,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptPickerSheet extends StatefulWidget {
  final List<String> prompts;
  final Set<String> used;
  final PromptAnswer? existing;

  const _PromptPickerSheet({
    required this.prompts,
    required this.used,
    required this.existing,
  });

  @override
  State<_PromptPickerSheet> createState() => _PromptPickerSheetState();
}

class _PromptPickerSheetState extends State<_PromptPickerSheet> {
  String? _selected;
  final _answerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = widget.existing?.question;
    _answerController.text = widget.existing?.answer ?? '';
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: kb),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (_, scroll) {
          if (_selected == null) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Choose a prompt',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: widget.prompts.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final p = widget.prompts[i];
                      final used = widget.used.contains(p) &&
                          p != widget.existing?.question;
                      return ListTile(
                        enabled: !used,
                        title: Text(
                          p,
                          style: TextStyle(
                            color: used
                                ? AppColors.textHint
                                : AppColors.textPrimary,
                          ),
                        ),
                        trailing: used
                            ? const Text('Used',
                                style: TextStyle(
                                    color: AppColors.textHint,
                                    fontSize: 12))
                            : const Icon(Icons.chevron_right,
                                color: AppColors.textHint),
                        onTap: () => setState(() => _selected = p),
                      );
                    },
                  ),
                ),
              ],
            );
          }

          return SingleChildScrollView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => setState(() => _selected = null),
                    ),
                    const Spacer(),
                  ],
                ),
                Text(
                  _selected!,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                AppTextField(
                  controller: _answerController,
                  hintText: 'Your answer',
                  maxLines: 5,
                  maxLength: 225,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    onPressed: _answerController.text.trim().isEmpty
                        ? null
                        : () => Navigator.pop(
                              context,
                              PromptAnswer(
                                question: _selected!,
                                answer: _answerController.text.trim(),
                              ),
                            ),
                    child: const Text('Done',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
