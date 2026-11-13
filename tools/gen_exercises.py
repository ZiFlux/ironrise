"""База упражнений: shared/exercises.json -> код приложения и сервера.

Запуск из корня репозитория: py -I tools/gen_exercises.py
"""
import json
import pathlib
import shutil
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / 'shared' / 'exercises.json'
DART = ROOT / 'app' / 'lib' / 'game' / 'exercise_data.dart'
TS = ROOT / 'server' / 'src' / 'game' / 'exercise-data.ts'

HEADER = 'Сгенерировано tools/gen_exercises.py из shared/exercises.json — руками не править.'
PARTS = {'chest', 'back', 'arms', 'legs', 'core', 'cardio'}
MUSCLES = {'pecs', 'delts', 'biceps', 'triceps', 'forearms', 'lats', 'traps', 'lowerBack',
           'abs', 'obliques', 'quads', 'hamstrings', 'glutes', 'calves'}
MUSCLE_PART = {'pecs': 'chest', 'delts': 'arms', 'biceps': 'arms', 'triceps': 'arms', 'forearms': 'arms',
               'lats': 'back', 'traps': 'back', 'lowerBack': 'back', 'abs': 'core', 'obliques': 'core',
               'quads': 'legs', 'hamstrings': 'legs', 'glutes': 'legs', 'calves': 'legs'}
JOINTS = {'shoulder', 'elbowWrist', 'lowerBack', 'knee'}
GEAR = {'none', 'dumbbells', 'gym'}


def check(data):
    ids = set()
    for e in data['strength'] + data['warmup']:
        assert e['id'] not in ids, f"повтор id {e['id']}"
        ids.add(e['id'])
        assert e['equipment'] in GEAR, e['id']
        assert e['steps'] and e['mistake'], e['id']
    for e in data['strength']:
        assert set(e['shares']) <= PARTS, e['id']
        assert abs(sum(e['shares'].values()) - 1) < 1e-6, f"доли частей {e['id']}"
        assert set(e['muscles']) <= MUSCLES, e['id']
        for m in e['muscles']:
            assert MUSCLE_PART[m] in e['shares'], f"{e['id']}: мышца {m} вне частей тела упражнения"
        assert abs(sum(e['muscles'].values()) - 1) < 1e-6, f"доли мышц {e['id']}"
        assert e['difficulty'] in (1, 2, 3), e['id']
        assert set(e.get('joints', [])) <= JOINTS, e['id']
    for e in data['warmup']:
        assert set(e['targets']) <= PARTS, e['id']


def dstr(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$') + "'"


def num(x):
    return repr(float(x)) if isinstance(x, float) or isinstance(x, int) else x


def dart(data):
    out = [f'// {HEADER}', '// ignore_for_file: lines_longer_than_80_chars', '',
           "import 'body_part.dart';", "import 'exercise_catalog.dart';",
           "import 'exercise_guide.dart';", "import 'muscles.dart';", '',
           'const generatedExercises = <Exercise>[']
    for e in data['strength']:
        shares = ', '.join(f'BodyPart.{p}: {num(v)}' for p, v in e['shares'].items())
        fields = [f"id: {dstr(e['id'])}", f"name: {dstr(e['name'])}",
                  f"pattern: {dstr(e['pattern'])}", f"difficulty: {e['difficulty']}",
                  f"gear: ExerciseGear.{e['equipment']}", f'shares: {{{shares}}}']
        if e.get('usesWeight') is False:
            fields.append('usesWeight: false')
        if e.get('unit') == 'seconds':
            fields.append('unit: ExerciseUnit.seconds')
        if 'defaultWeight' in e:
            fields.append(f"defaultWeight: {num(e['defaultWeight'])}")
        if 'defaultReps' in e:
            fields.append(f"defaultReps: {e['defaultReps']}")
        if e.get('joints'):
            fields.append('joints: {' + ', '.join(dstr(j) for j in e['joints']) + '}')
        out.append('  Exercise(' + ', '.join(fields) + '),')
    out += ['];', '', 'const generatedWarmups = <WarmupMove>[']
    for e in data['warmup']:
        targets = ', '.join(f'BodyPart.{p}' for p in e['targets'])
        seconds = ', seconds: true' if e.get('unit') == 'seconds' else ''
        out.append(f"  WarmupMove(id: {dstr(e['id'])}, name: {dstr(e['name'])}, "
                   f"gear: ExerciseGear.{e['equipment']}, amount: {e['defaultReps']}{seconds}, "
                   f'targets: {{{targets}}}),')
    out += ['];', '', 'const generatedMuscles = <String, Map<Muscle, double>>{']
    for e in data['strength']:
        m = ', '.join(f'Muscle.{k}: {num(v)}' for k, v in e['muscles'].items())
        out.append(f"  {dstr(e['id'])}: {{{m}}},")
    out += ['};', '', 'const generatedGuides = <String, ExerciseGuide>{']
    for e in data['strength'] + data['warmup']:
        steps = ', '.join(dstr(s) for s in e['steps'])
        out.append(f"  {dstr(e['id'])}: ExerciseGuide([{steps}], {dstr(e['mistake'])}),")
    out += ['};', '']
    return '\n'.join(out)


def ts(data):
    out = [f'/** {HEADER} */', "import type { BodyPart } from './body-part';", '',
           'export const EXERCISE_DATA: readonly { id: string; name: string; '
           'shares: Partial<Record<BodyPart, number>> }[] = [']
    for e in data['strength']:
        out.append('  ' + json.dumps({'id': e['id'], 'name': e['name'], 'shares': e['shares']},
                                     ensure_ascii=False) + ',')
    out += ['];', '', 'export const EXERCISE_MUSCLE_DATA: Readonly<Record<string, Record<string, number>>> = {']
    for e in data['strength']:
        out.append(f"  {e['id']}: " + json.dumps(e['muscles'], ensure_ascii=False) + ',')
    out += ['};', '']
    return '\n'.join(out)


def main():
    data = json.loads(SRC.read_text(encoding='utf-8'))
    check(data)
    DART.write_text(dart(data), encoding='utf-8', newline='\n')
    TS.write_text(ts(data), encoding='utf-8', newline='\n')
    print(f"{len(data['strength'])} упражнений, {len(data['warmup'])} разминочных")


main()
