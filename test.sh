#!/usr/bin/env bash
# Тесты решения. Проверяем реальные исходные данные и ошибки ввода.
set -u
cd "$(dirname "$0")" || exit 1
ok=0; bad=0
check() {
    local label="$1" expected="$2"; shift 2
    local result
    if result=$("$@" 2>&1) && [[ "$result" == *"$expected"* ]]; then
        printf 'PASS %s\n' "$label"; ((ok+=1))
    else
        printf 'FAIL %s\n  ожидалось: %s\n  вывод: %s\n' "$label" "$expected" "$result"
        ((bad+=1))
    fi
}
check_line_absent() {
    local label="$1" line="$2"; shift 2
    local result
    if result=$("$@" 2>&1) && ! grep -Fxq -- "$line" <<< "$result"; then
        printf 'PASS %s\n' "$label"; ((ok+=1))
    else
        printf 'FAIL %s\n  строка не должна присутствовать: %s\n  вывод: %s\n' "$label" "$line" "$result"
        ((bad+=1))
    fi
}
check_error() {
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then
        printf 'FAIL %s\n' "$label"; ((bad+=1))
    else
        printf 'PASS %s\n' "$label"; ((ok+=1))
    fi
}

check 'Формат: группа в первой строке' 'Группа: A-06-21' ./main.sh worst A-06-21
check 'Формат: имя студента' 'ФИО студента: DenisovSemA' ./main.sh worst 0621
check 'Формат: минимум посещений' 'Минимум посещений: 22 из 36' ./main.sh worst a-06-21
check 'Номера занятий' '1,4,5,6,12,16,18' ./main.sh worst A-06-21
check 'Латинская строчная а в группе' 'Группа: A-09-23' ./main.sh worst a-09-23
check 'Кириллическая заглавная А' 'Группа: A-09-23' ./main.sh worst А-09-23
check 'Кириллическая строчная а' 'Группа: A-09-23' ./main.sh worst а-09-23
check 'Сокращение 0923' 'Группа: A-09-23' ./main.sh worst 0923
check 'Сокращение 09-23' 'Группа: A-09-23' ./main.sh worst 09-23
check 'Латинский Ae' 'Группа: Ae-21-23' ./main.sh worst ae2123
check 'Кириллический Аэ' 'Группа: Ae-21-23' ./main.sh worst Аэ-21-23
check 'Список групп' 'Ae-21-23' ./main.sh groups
check 'Тест с оценкой 4+ засчитан' 'Всего не сдали: 0' ./main.sh failed 1 1 A-09-23
check 'Тест с 3+ тоже засчитан' 'Всего не сдали: 0' ./main.sh failed 1 1 A-06-23
check 'Первая попытка неудачна' 'KaraliusDD' ./main.sh failed 1 1 A-09-23 1
check 'Проверка N попыток возвращает успешный код' 'На момент попытки №2' ./main.sh failed 1 3 A-06-12 2
check_line_absent 'После второй попытки KaraliusDD сдал' 'KaraliusDD' ./main.sh failed 1 1 A-09-23 2
check 'Остался несдавший после всех попыток' 'SazonovAD' ./main.sh failed 1 4 A-06-22 0
check 'Рейтинг по двум предметам' '36 / 40' ./main.sh rank A-06-23 0
check 'Рейтинг по первому предмету' '19 / 20' ./main.sh rank A-09-23 1
check 'Рейтинг по второму предмету' '20 / 20' ./main.sh rank Ae-21-23 2
check 'Средняя по точным группам' 'A-06-21: 282 из 396 (71.21%)' ./main.sh average 0621 A-06-23
check 'Средняя по году группы' 'ИТОГО (3 групп): 1065 из 1404 (75.85%)' ./main.sh average --year 2023
check 'Средняя по номеру за все годы' 'ИТОГО (20 групп): 8984 из 12024 (74.71%)' ./main.sh average --number 06
check 'Средняя по кириллическому Аэ21' 'ИТОГО (3 групп): 1205 из 1584 (76.07%)' ./main.sh average --number Аэ21
check_error 'Несуществующая группа' ./main.sh worst A-06-99
check_error 'Некорректный тест' ./main.sh failed 1 5 A-06-21
check_error 'Некорректный предмет' ./main.sh failed 3 1 A-06-21
check_error 'Некорректная попытка' ./main.sh failed 1 1 A-09-23 -1
check_error 'Некорректный предмет для рейтинга' ./main.sh rank A-09-23 3
check_error 'Нет групп для расчёта среднего' ./main.sh average
check_error 'Год, в котором нет групп' ./main.sh average --year 2030
check_error 'Несуществующий номер группы' ./main.sh average --number 99

printf '\nИТОГО: %s пройдено, %s ошибок\n' "$ok" "$bad"
((bad==0))
