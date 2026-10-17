#!/usr/bin/env bash
set -u
cd "$(dirname "$0")" || exit 1
ok=0; bad=0
check() {
 local label="$1" expected="$2"; shift 2
 local result
 if result=$("$@" 2>&1) && [[ "$result" == *"$expected"* ]]; then
   printf 'PASS %s\n' "$label"; ((ok+=1))
 else
   printf 'FAIL %s\n  output: %s\n' "$label" "$result"; ((bad+=1))
 fi
}
check_error() {
 local label="$1"; shift
 if "$@" >/dev/null 2>&1; then printf 'FAIL %s\n' "$label"; ((bad+=1)); else printf 'PASS %s\n' "$label"; ((ok+=1)); fi
}
check 'Худшая посещаемость' 'DenisovSemA' ./main.sh worst A-06-21
check 'Номера занятий' '1,4,5,6,12,16,18' ./main.sh worst A-06-21
check 'Не сдавшие тест — пустой список' 'Всего не сдали: 0' ./main.sh failed A-06-21 1 1
check 'Рейтинг группы' 'MotorinKA' ./main.sh rank A-06-21
check 'Средняя посещаемость двух групп' 'A-09-21: 325 из 432 (75.23%)' ./main.sh average A-06-21 A-09-21
check_error 'Несуществующая группа' ./main.sh worst A-06-99
check_error 'Некорректный тест' ./main.sh failed A-06-21 5 1
check_error 'Некорректный предмет' ./main.sh failed A-06-21 1 3
check_error 'Нет групп для расчета среднего' ./main.sh average
printf '\nИТОГО: %s пройдено, %s ошибок\n' "$ok" "$bad"
((bad==0))
