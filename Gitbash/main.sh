#!/usr/bin/env bash
set -u
# Единая UTF-8 локаль: кириллические имена папок и ввод «назад» одинаково
# обрабатываются в Linux и в Git Bash (Windows).
export LC_ALL=C.UTF-8
source "$(dirname "$0")/functions.sh"

usage() {
    cat <<'HELP'
Команды:
  main.sh groups
  main.sh worst ГРУППА
  main.sh failed ПРЕДМЕТ(1/2) ТЕСТ(1-4) ГРУППА [ПОПЫТКА(0=все)]
  main.sh rank ГРУППА [ПРЕДМЕТ(0=оба,1/2)]
  main.sh average [--subject ПРЕДМЕТ(0=оба,1/2)] ГРУППА [ГРУППА ...]
  main.sh average [--subject ПРЕДМЕТ] --year ГОД(23/2023)
  main.sh average [--subject ПРЕДМЕТ] --number НОМЕР(06/Ae-21)
  main.sh help
Запись группы: A-09-23, а-09-23, 0923, 09-23; Ae-21-23, Аэ2123 (А/Аэ — латиницей или кириллицей).
Несколько групп — через пробел: A-09-23 A-09-22.
Год группы: 23 или 2023. Номер группы: 09, A-09, Ae-21.
В интерактивном меню: q или «назад» — прервать ввод и вернуться в меню.
HELP
}

# Неинтерактивный интерфейс: неверные аргументы возвращают код ошибки.
if (($#)); then
    command="$1"; shift
    case "$command" in
        groups) (($#==0)) || { usage; exit 2; }; list_groups ;;
        worst) (($#==1)) || { usage; exit 2; }; worst_attendance "$1" ;;
        failed)
            (($#==3 || $#==4)) || { usage; exit 2; }
            not_passed "$1" "$2" "$3" "${4:-0}" ;;
        rank) (($#==1 || $#==2)) || { usage; exit 2; }; ranking "$1" "${2:-0}" ;;
        average)
            subject_id=0
            if [[ "${1:-}" == --subject ]]; then
                (($#>=2)) || { usage; exit 2; }
                subject_id="$2"; shift 2
            fi
            validate_rank_subject "$subject_id" || exit 2
            if [[ "${1:-}" == --year ]]; then
                shift; average_attendance_mode year "$subject_id" "$@"
            elif [[ "${1:-}" == --number ]]; then
                shift; average_attendance_mode number "$subject_id" "$@"
            else
                average_attendance_mode exact "$subject_id" "$@"
            fi ;;
        help|--help|-h) usage ;;
        *) usage; exit 2 ;;
    esac
    exit $?
fi

# Настройка Linux-терминала: стирание кириллической буквы одной клавишей Backspace.
# Не выкидываем символы из значения: "а1п" по-прежнему неверная команда.
if [[ -t 0 && -t 1 ]]; then
    saved_tty=$(stty -g 2>/dev/null) || saved_tty=''
    if [[ -n "$saved_tty" ]]; then
        stty iutf8 2>/dev/null || :
        trap 'stty "$saved_tty" 2>/dev/null || :' EXIT
    fi
fi

# Возвращает 0 при корректном вводе; 1 при отмене (q / назад / EOF).
# Результат в PROMPT_VALUE: вызов через командную подстановку теряет переменную.
PROMPT_VALUE=''
prompt_value() {
    local label="$1" validator="$2" value
    while true; do
        if ! IFS= read -r -p "$label" value; then
            printf '\nВвод прерван. Возврат в меню.\n'
            return 1
        fi
        case "${value,,}" in
            q|quit|назад) echo 'Возврат в меню.'; return 1 ;;
        esac
        if "$validator" "$value"; then
            PROMPT_VALUE="$value"
            return 0
        fi
        echo 'Попробуйте ещё раз или введите q для возврата в меню.'
    done
}
valid_group() { resolve_group "$1" >/dev/null; }
valid_year() { resolve_year "$1" >/dev/null; }
valid_number() { resolve_group_number "$1" >/dev/null; }
valid_mode() {
    [[ "$1" =~ ^[123]$ ]] || { echo 'Ошибка: выберите 1, 2 или 3.' >&2; return 1; }
}
valid_groups() {
    local input="$1" item
    local -a parsed=()
    read -r -a parsed <<< "$input"
    ((${#parsed[@]}>0)) || { echo 'Ошибка: введите хотя бы одну группу.' >&2; return 1; }
    for item in "${parsed[@]}"; do
        resolve_group "$item" >/dev/null || return 1
    done
}

while true; do
    printf '\n1. Худшая посещаемость\n2. Не сдавшие тест\n3. Рейтинг успеваемости\n4. Средняя посещаемость групп\n5. Список групп\n0. Выход\nВыбор: '
    IFS= read -r choice || break
    case "$choice" in
        1)
            prompt_value 'Группа: ' valid_group || continue
            worst_attendance "$PROMPT_VALUE"
            ;;
        2)
            prompt_value 'Предмет (1 — Цирковое_Дело, 2 — Пересдачеведение): ' validate_subject || continue
            subject="$PROMPT_VALUE"
            prompt_value 'Тест (1-4): ' validate_test || continue
            test="$PROMPT_VALUE"
            prompt_value 'Группа: ' valid_group || continue
            group="$PROMPT_VALUE"
            prompt_value 'Попытка (0 — все попытки, N — первые N по дате): ' validate_attempts || continue
            not_passed "$subject" "$test" "$group" "$PROMPT_VALUE"
            ;;
        3)
            prompt_value 'Предмет (0 — оба, 1 — Цирковое_Дело, 2 — Пересдачеведение): ' validate_rank_subject || continue
            subject="$PROMPT_VALUE"
            prompt_value 'Группа: ' valid_group || continue
            ranking "$PROMPT_VALUE" "$subject"
            ;;
        4)
            prompt_value 'Предмет (0 — оба, 1 — Цирковое_Дело, 2 — Пересдачеведение): ' validate_rank_subject || continue
            subject="$PROMPT_VALUE"
            prompt_value 'Режим (1 — точные группы, 2 — по году, 3 — номер независимо от года): ' valid_mode || continue
            mode="$PROMPT_VALUE"
            case "$mode" in
                1)
                    prompt_value 'Группы: ' valid_groups || continue
                    read -r -a groups <<< "$PROMPT_VALUE"
                    average_attendance_mode exact "$subject" "${groups[@]}" ;;
                2)
                    prompt_value 'Год группы: ' valid_year || continue
                    average_attendance_mode year "$subject" "$PROMPT_VALUE" ;;
                3)
                    prompt_value 'Номер группы: ' valid_number || continue
                    average_attendance_mode number "$subject" "$PROMPT_VALUE" ;;
            esac
            ;;
        5) list_groups ;;
        0) break ;;
        *) echo 'Неизвестная команда. Укажите одну цифру от 0 до 5.' ;;
    esac
done
