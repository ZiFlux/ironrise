import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../avatar/avatar_look.dart';
import '../avatar/avatar_view.dart';
import '../game/body_part.dart';
import '../game/program.dart';
import '../game/training_format.dart';
import '../state/hero.dart';
import '../state/program_state.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/logo_mark.dart';

/// Онбординг: 18+ → герой и цель → формат тренировок → комплекция (необязательно).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  int _step = 0;
  static const _stepCount = 5;

  bool _isAdult = false;
  final _nickname = TextEditingController();
  AvatarSex _avatarSex = AvatarSex.male;
  Goal? _goal;
  TrainingFormat _format = TrainingFormat.fullBody;
  Set<int> _days = TrainingFormat.fullBody.defaultDays.toSet();
  Sex? _sex;
  final _height = TextEditingController();
  final _weight = TextEditingController();
  Experience? _experience;
  Equipment _equipment = Equipment.gym;

  /// Ответы на вопросы о здоровье (docs/TRAINING_SYSTEM.md, раздел 2).
  final _healthRisks = <int>{};
  bool _healthAcknowledged = false;

  @override
  void dispose() {
    _pages.dispose();
    _nickname.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  bool get _canContinue => switch (_step) {
        0 => _isAdult,
        1 => _nickname.text.trim().length >= 2 && _goal != null,
        2 => _days.length >= minTrainingDaysPerWeek,
        3 => _healthRisks.isEmpty || _healthAcknowledged,
        _ => true,
      };

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    if (_step < _stepCount - 1) {
      setState(() => _step++);
      await _pages.animateToPage(_step,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      return;
    }
    final hero = HeroProfile.create(
      nickname: _nickname.text.trim(),
      goal: _goal!,
      format: _format,
      trainingDays: _days.toList()..sort(),
      body: BodyStats(
        sex: _sex,
        heightCm: int.tryParse(_height.text),
        weightKg: double.tryParse(_weight.text.replaceAll(',', '.')),
        experience: _experience,
      ),
      avatarSex: _avatarSex,
    );
    await ref.read(programProvider.notifier).setEquipment(_equipment);
    await ref.read(heroProvider.notifier).save(hero);
    if (mounted) context.go('/');
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
    _pages.animateToPage(_step,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  if (_step > 0)
                    IconButton(
                      onPressed: _back,
                      tooltip: 'Назад',
                      icon: const Icon(LucideIcons.chevronLeft, size: 20),
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_step + 1) / _stepCount,
                        minHeight: 6,
                        backgroundColor: AppColors.raised,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [_ageStep(), _heroStep(), _formatStep(), _healthStep(), _bodyStep()],
                ),
              ),
              FilledButton(
                onPressed: _canContinue ? _next : null,
                child: Text(_step == _stepCount - 1 ? 'Создать героя' : 'Дальше'),
              ),
              if (_step == _stepCount - 1)
                TextButton(onPressed: _next, child: const Text('Пропустить')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _title(String title, String subtitle) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 15)),
          ],
        ),
      );

  Widget _ageStep() => ListView(
        children: [
          const SizedBox(height: 40),
          const Align(alignment: Alignment.centerLeft, child: LogoMark(size: 72)),
          _title('IronRise',
              'Каждая тренировка делает твоего героя сильнее. Пропустишь ноги — герой тоже'),
          CheckboxListTile(
            value: _isAdult,
            onChanged: (v) => setState(() => _isAdult = v ?? false),
            title: const Text('Мне исполнилось 18 лет'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          const Text(
            'Продолжая, вы соглашаетесь с обработкой данных о тренировках и пульсе '
            'по политике конфиденциальности',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () => context.push('/privacy'),
              child: const Text('Политика конфиденциальности'),
            ),
          ),
        ],
      );

  Widget _heroStep() => ListView(
        children: [
          _title('Твой герой', 'Как его зовут и к чему он идёт'),
          Row(
            children: [
              for (final sex in AvatarSex.values) ...[
                Expanded(
                  child: _AvatarChoice(
                    sex: sex,
                    selected: _avatarSex == sex,
                    onTap: () => setState(() => _avatarSex = sex),
                  ),
                ),
                if (sex != AvatarSex.values.last) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nickname,
            maxLength: 20,
            decoration: const InputDecoration(labelText: 'Ник'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          for (final g in Goal.values)
            _ChoiceTile(
              selected: _goal == g,
              title: g.label,
              onTap: () => setState(() => _goal = g),
            ),
        ],
      );

  Widget _formatStep() => ListView(
        children: [
          const Text('Где тренируешься', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          SegmentedButton<Equipment>(
            segments: [
              for (final e in Equipment.values) ButtonSegment(value: e, label: Text(e.label)),
            ],
            selected: {_equipment},
            onSelectionChanged: (v) => setState(() => _equipment = v.first),
          ),
          _title('Как будешь тренироваться?',
              'Отдых по графику не сбрасывает серию. Новичкам лучше начать с 3 тренировок в неделю.'),
          for (final f in TrainingFormat.values)
            _ChoiceTile(
              selected: _format == f,
              title: f.label,
              subtitle: f.description,
              onTap: () => setState(() {
                _format = f;
                _days = f.defaultDays.toSet();
              }),
            ),
          const SizedBox(height: 16),
          const Text('Дни тренировок', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < 7; i++)
                FilterChip(
                  label: Text(weekdayShort[i]),
                  selected: _days.contains(i),
                  onSelected: (on) => setState(() {
                    on ? _days.add(i) : _days.remove(i);
                    if (_format != TrainingFormat.custom &&
                        !_setEquals(_days, _format.defaultDays.toSet())) {
                      // Сдвиг дней сохраняет формат, если число тренировок не изменилось.
                      if (_days.length != _format.defaultDays.length) {
                        _format = TrainingFormat.custom;
                      }
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _days.length < minTrainingDaysPerWeek
                ? 'Выберите минимум $minTrainingDaysPerWeek дня'
                : 'Тренировок в неделю: ${_days.length}. Отдыхать подряд можно до ${maxRestDaysInRow(_days.toList())} дн.',
            style: TextStyle(
              color: _days.length < minTrainingDaysPerWeek
                  ? Theme.of(context).colorScheme.error
                  : AppColors.textSecondary,
            ),
          ),
        ],
      );

  static const _healthQuestions = [
    'Бывает боль или давление в груди при нагрузке',
    'Бывают головокружения или потери сознания',
    'За последний год были травмы суставов или спины',
  ];

  /// Проверка в духе PAR-Q: при любом «да» — совет поговорить с врачом.
  Widget _healthStep() => ListView(
        children: [
          _title('Пара вопросов о здоровье',
              'Чтобы нагрузка была безопасной. Ответы остаются на телефоне'),
          for (final (i, question) in _healthQuestions.indexed)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(question),
              value: _healthRisks.contains(i),
              onChanged: (on) => setState(() {
                on ? _healthRisks.add(i) : _healthRisks.remove(i);
                if (_healthRisks.isEmpty) _healthAcknowledged = false;
              }),
            ),
          if (_healthRisks.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Перед тренировками лучше обсудить нагрузку с врачом. IronRise не заменяет '
              'медицинскую консультацию',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _healthAcknowledged,
              onChanged: (v) => setState(() => _healthAcknowledged = v ?? false),
              title: const Text('Врач разрешил или я понимаю риск'),
            ),
          ],
        ],
      );

  Widget _bodyStep() => ListView(
        children: [
          _title('Немного о тебе',
              'Поможет подобрать нагрузку по силам. Можно заполнить позже.'),
          SegmentedButton<Sex>(
            segments: [
              for (final s in Sex.values) ButtonSegment(value: s, label: Text(s.label)),
            ],
            selected: {?_sex},
            emptySelectionAllowed: true,
            onSelectionChanged: (v) => setState(() => _sex = v.isEmpty ? null : v.first),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _height,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Рост, см'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _weight,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Вес, кг'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Опыт тренировок', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          for (final e in Experience.values)
            _ChoiceTile(
              selected: _experience == e,
              title: e.label,
              onTap: () => setState(() => _experience = e),
            ),
        ],
      );
}

bool _setEquals(Set<int> a, Set<int> b) => a.length == b.length && a.containsAll(b);

class _AvatarChoice extends StatelessWidget {
  const _AvatarChoice({required this.sex, required this.selected, required this.onTap});

  final AvatarSex sex;
  final bool selected;
  final VoidCallback onTap;

  static final _starterLevels = {for (final p in BodyPart.values) p: 1};

  @override
  Widget build(BuildContext context) {
    final label = sex == AvatarSex.male ? 'Герой' : 'Героиня';
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? AppColors.raised : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? Theme.of(context).colorScheme.primary : AppColors.hairline,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                SizedBox(
                  height: 148,
                  child: AvatarView(levels: _starterLevels, look: AvatarLook.starter(sex)),
                ),
                const SizedBox(height: 8),
                Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.selected,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final bool selected;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? AppColors.raised : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? accent : AppColors.hairline),
        ),
        child: ListTile(
          onTap: onTap,
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: subtitle == null
              ? null
              : Text(subtitle!, style: const TextStyle(color: AppColors.textSecondary)),
          trailing: selected ? Icon(LucideIcons.check, size: 18, color: accent) : null,
        ),
      ),
    );
  }
}
