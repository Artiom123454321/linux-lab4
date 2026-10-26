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

check 'Формат: группа в первой строке' 'Группа: A-06-21' bash main.sh worst A-06-21
check 'Формат: имя студента' 'ФИО студента: DenisovSemA' bash main.sh worst 0621
check 'Формат: минимум посещений' 'Минимум посещений: 22 из 36' bash main.sh worst a-06-21
check 'Номера занятий' '1,4,5,6,12,16,18' bash main.sh worst A-06-21
check 'Латинская строчная а в группе' 'Группа: A-09-23' bash main.sh worst a-09-23
check 'Кириллическая заглавная А' 'Группа: A-09-23' bash main.sh worst А-09-23
check 'Кириллическая строчная а' 'Группа: A-09-23' bash main.sh worst а-09-23
check 'Сокращение 0923' 'Группа: A-09-23' bash main.sh worst 0923
check 'Сокращение 09-23' 'Группа: A-09-23' bash main.sh worst 09-23
check 'Латинский Ae' 'Группа: Ae-21-23' bash main.sh worst ae2123
check 'Кириллический Аэ' 'Группа: Ae-21-23' bash main.sh worst Аэ-21-23
check 'Список групп' 'Ae-21-23' bash main.sh groups
check 'Тест с оценкой 4+ засчитан' 'Всего не сдали: 0' bash main.sh failed 1 1 A-09-23
check 'Тест с 3+ тоже засчитан' 'Всего не сдали: 0' bash main.sh failed 1 1 A-06-23
check 'Первая попытка неудачна' 'KaraliusDD' bash main.sh failed 1 1 A-09-23 1
check 'Проверка N попыток возвращает успешный код' 'На момент попытки №2' bash main.sh failed 1 3 A-06-12 2
check_line_absent 'После второй попытки KaraliusDD сдал' 'KaraliusDD' bash main.sh failed 1 1 A-09-23 2
check 'Остался несдавший после всех попыток' 'SazonovAD' bash main.sh failed 1 4 A-06-22 0
check 'Рейтинг по двум предметам: новая средняя' 'SaponGM                     3.60             10' bash main.sh rank A-06-23 0
check 'Рейтинг по первому предмету: новая средняя' 'IvashutaYA                  3.67             6' bash main.sh rank A-09-23 1
check 'Рейтинг по второму предмету: новая средняя' 'GorbenkoKY                  3.83             6' bash main.sh rank Ae-21-23 2
check 'Шапка рейтинга: студент' 'Студент' bash main.sh rank A-06-23 0
check 'Шапка рейтинга: средняя оценка и попытки' 'Средняя оценка   Попытки' bash main.sh rank A-06-23 0
check 'Заголовок рейтинга с ровными колонками' 'Студент                     Средняя оценка   Попытки' bash main.sh rank A-06-23 0
check 'По двум предметам: среднее всех попыток' 'UsovPA                      3.43             14' bash main.sh rank A-06-23 0
check 'Оценки с + и - включены в среднюю' 'NaimanAM                    3.10             10' bash main.sh rank A-09-23 1
check 'Средняя по точным группам' 'A-06-21: 282 из 396 (71.21%)' bash main.sh average 0621 A-06-23
check 'Средняя по году группы' 'ИТОГО (3 групп): 1065 из 1404 (75.85%)' bash main.sh average --year 2023
check 'Средняя по номеру за все годы' 'ИТОГО (20 групп): 8984 из 12024 (74.71%)' bash main.sh average --number 06
check 'Средняя по кириллическому Аэ21' 'ИТОГО (3 групп): 1205 из 1584 (76.07%)' bash main.sh average --number Аэ21
check 'Средняя для первого предмета' 'A-06-21: 133 из 198 (67.17%)' bash main.sh average --subject 1 A-06-21
check 'Средняя для второго предмета' 'A-06-21: 149 из 198 (75.25%)' bash main.sh average --subject 2 A-06-21
check 'Средняя для второго по году' 'ИТОГО (3 групп): 520 из 702 (74.07%)' bash main.sh average --subject 2 --year 2023
check 'Средняя для первого по номеру' 'ИТОГО (3 групп): 603 из 792 (76.13%)' bash main.sh average --subject 1 --number Аэ21

run_menu() { printf '%s' "$1" | bash main.sh; }
check 'Интерактивный ввод группы: ошибка и повтор' 'Группа: A-06-21' run_menu $'1\nA-06-99\nA-06-21\n0\n'
check 'Ошибка в выборе предмета и повтор без потери значений' 'Всего не сдали: 0' run_menu $'2\n9\n1\n1\nA-09-23\n0\n0\n'
check 'Ошибка теста и повтор' 'Всего не сдали: 0' run_menu $'2\n1\n9\n1\nA-09-23\n0\n0\n'
check 'Ошибка попытки и повтор' 'Всего не сдали: 0' run_menu $'2\n1\n1\nA-09-23\n-1\n0\n0\n'
check 'Отмена ввода предмета через q' 'Возврат в меню.' run_menu $'2\nq\n0\n'
check 'Отмена ввода группы через назад' 'Возврат в меню.' run_menu $'1\nназад\n0\n'
check 'Отмена в середине команды' 'Возврат в меню.' run_menu $'2\n1\n1\nq\n0\n'
check 'После отмены можно снова запустить команду' 'Группа: A-06-21' run_menu $'2\n1\nq\n1\nA-06-21\n0\n'
check 'Неверная смешанная команда а1п отклоняется' 'Неизвестная команда.' run_menu $'а1п\n0\n'
check 'Повтор выбора режима посещаемости' 'A-06-21: 133 из 198 (67.17%)' run_menu $'4\n1\n8\n1\nA-06-21\n0\n'
check 'Повтор неверного номера группы для посещаемости' 'ИТОГО (3 групп): 603 из 792 (76.13%)' run_menu $'4\n1\n3\n99\nАэ21\n0\n'
check 'ИТОГО для нескольких точных групп' 'ИТОГО (2 групп): 630 из 864 (72.91%)' bash main.sh average 0621 A-06-23

# Невозможные год и номер проверяются сразу при вводе, до других параметров.
check 'Сразу повторить год без групп' 'ИТОГО (3 групп): 1065 из 1404 (75.85%)' \
    run_menu $'4\n0\n2\n30\n23\n0\n'
check 'Сразу повторить отсутствующий A-99' 'ИТОГО (20 групп): 8984 из 12024 (74.71%)' \
    run_menu $'4\n0\n3\nA99\nA06\n0\n'
check_error 'Несуществующий год отклоняет resolve_year' bash main.sh average --year 2030
check_error 'Несуществующий префиксный номер A99' bash main.sh average --number A99

# Отдельная КОПИЯ входных данных: испорченные файлы не затрагивают данные преподавателя.
# cp -L важен, когда при локальном запуске ../data является символьной ссылкой.
corrupt_dir=$(mktemp -d) || exit 1
trap 'rm -rf "$corrupt_dir"' EXIT
cp -rL ../data "$corrupt_dir/data" || exit 1
check_bad_data() {
    local label="$1" expected="$2" output; shift 2
    if output=$(env LAB4_DATA="$corrupt_dir/data" "$@" 2>&1); then
        printf 'FAIL %s\n  программа завершилась без ошибки: %s\n' "$label" "$output"
        ((bad+=1))
    elif [[ "$output" == *"$expected"* ]]; then
        printf 'PASS %s\n' "$label"; ((ok+=1))
    else
        printf 'FAIL %s\n  ожидалось: %s\n  вывод: %s\n' "$label" "$expected" "$output"
        ((bad+=1))
    fi
}

# Д-10: пустой состав группы.
: > "$corrupt_dir/data/students/groups/A-06-21"
check_bad_data 'Д-10: пустая группа, пункт 1' 'в группе A-06-21 нет студентов' bash main.sh worst A-06-21
check_bad_data 'Д-10: пустая группа, пункт 2' 'в группе A-06-21 нет студентов' bash main.sh failed 1 1 A-06-21
check_bad_data 'Д-10: пустая группа, пункт 3' 'в группе A-06-21 нет студентов' bash main.sh rank A-06-21 1
check_bad_data 'Д-10: пустая группа, пункт 4' 'в группе A-06-21 нет студентов' bash main.sh average A-06-21
cp ../data/students/groups/A-06-21 "$corrupt_dir/data/students/groups/A-06-21"

# Д-11: одному студенту сократили строку посещаемости 18 -> 4 занятия.
sed -i 's/^ArkhipovDanG .*/ArkhipovDanG 0101/' "$corrupt_dir/data/Цирковое_Дело/A-06-21-attendance"
check_bad_data 'Д-11: разная длина посещаемости, пункт 1' 'у студентов разное число занятий' bash main.sh worst A-06-21
check_bad_data 'Д-11: разная длина посещаемости, пункт 4' 'у студентов разное число занятий' bash main.sh average --subject 1 A-06-21
cp ../data/Цирковое_Дело/A-06-21-attendance "$corrupt_dir/data/Цирковое_Дело/A-06-21-attendance"

# Д-12: заменяем оценку в одной строке, проверяем ОБЕ команды чтения оценок.
for invalid in 6 '' 'отл'; do
    cp ../data/Цирковое_Дело/tests/TEST-1 "$corrupt_dir/data/Цирковое_Дело/tests/TEST-1"
    sed -i "s|^\(A-06-21;ArkhipovDanG;[^;]*;[^;]*;\).*$|\1$invalid|" \
        "$corrupt_dir/data/Цирковое_Дело/tests/TEST-1"
    shown="${invalid:-(пусто)}"
    check_bad_data "Д-12: оценка [$shown], пункт 2" 'некорректная оценка' bash main.sh failed 1 1 A-06-21 0
    check_bad_data "Д-12: оценка [$shown], пункт 2 (N попыток)" 'некорректная оценка' bash main.sh failed 1 1 A-06-21 1
    check_bad_data "Д-12: оценка [$shown], пункт 3" 'некорректная оценка' bash main.sh rank A-06-21 1
done
rm -rf "$corrupt_dir"
trap - EXIT

# Данные с переносами строк Windows (CRLF), как после git clone в Git Bash.
crlf_dir=$(mktemp -d)
cp -rL ../data "$crlf_dir/"
find "$crlf_dir/data" -type f -exec sed -i 's/\r*$/\r/' {} +
check 'CRLF: худшая посещаемость' 'Минимум посещений: 22 из 36' env LAB4_DATA="$crlf_dir/data" bash main.sh worst A-06-21
check 'CRLF: несдавшие тест' 'Всего не сдали: 0' env LAB4_DATA="$crlf_dir/data" bash main.sh failed 1 1 A-09-23
check 'CRLF: рейтинг' 'IvashutaYA                  3.67             6' env LAB4_DATA="$crlf_dir/data" bash main.sh rank A-09-23 1
check 'CRLF: средняя посещаемость' 'A-06-21: 133 из 198 (67.17%)' env LAB4_DATA="$crlf_dir/data" bash main.sh average --subject 1 A-06-21
rm -rf "$crlf_dir"

check_error 'Несуществующая группа' bash main.sh worst A-06-99
check_error 'Некорректный тест' bash main.sh failed 1 5 A-06-21
check_error 'Некорректный предмет' bash main.sh failed 3 1 A-06-21
check_error 'Некорректная попытка' bash main.sh failed 1 1 A-09-23 -1
check_error 'Некорректный предмет для средней посещаемости' bash main.sh average --subject 9 A-06-21
check_error 'Некорректный предмет для рейтинга' bash main.sh rank A-09-23 3
check_error 'Нет групп для расчёта среднего' bash main.sh average
check_error 'Год, в котором нет групп' bash main.sh average --year 2030
check_error 'Несуществующий номер группы' bash main.sh average --number 99

printf '\nИТОГО: %s пройдено, %s ошибок\n' "$ok" "$bad"
((bad==0))
