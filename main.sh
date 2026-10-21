#!/usr/bin/env bash
set -u
source "$(dirname "$0")/functions.sh"
usage() {
    cat <<'HELP'
Команды:
  main.sh groups
  main.sh worst ГРУППА
  main.sh failed ПРЕДМЕТ(1/2) ТЕСТ(1-4) ГРУППА [ПОПЫТКА(0=все)]
  main.sh rank ГРУППА [ПРЕДМЕТ(0=оба,1/2)]
  main.sh average ГРУППА [ГРУППА ...]
  main.sh average --year ГОД(23/2023)
  main.sh average --number НОМЕР(06/Ae-21)
  main.sh help
HELP
}
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
            if [[ "${1:-}" == --year ]]; then shift; average_attendance_mode year "$@"
            elif [[ "${1:-}" == --number ]]; then shift; average_attendance_mode number "$@"
            else average_attendance "$@"; fi ;;
        help|--help|-h) usage ;;
        *) usage; exit 2 ;;
    esac
    exit $?
fi
while true; do
    printf '\n1. Худшая посещаемость\n2. Не сдавшие тест\n3. Рейтинг успеваемости\n4. Средняя посещаемость групп\n5. Список групп\n0. Выход\nВыбор: '
    read -r choice || break
    case "$choice" in
        1)
            read -r -p 'Группа (например A-06-21, 06-21 или 0621): ' group || break
            worst_attendance "$group"
            ;;
        2)
            read -r -p 'Предмет (1 — Цирковое_Дело, 2 — Пересдачеведение): ' subject || break
            read -r -p 'Тест (1-4): ' test || break
            read -r -p 'Группа (например A-09-23, 09-23 или 0923): ' group || break
            read -r -p 'Попытка (0 — все попытки, N — первые N по дате): ' attempt || break
            not_passed "$subject" "$test" "$group" "${attempt:-0}"
            ;;
        3)
            read -r -p 'Предмет (0 — оба, 1 — Цирковое_Дело, 2 — Пересдачеведение): ' subject || break
            read -r -p 'Группа: ' group || break
            ranking "$group" "${subject:-0}"
            ;;
        4)
            printf 'Режим (1 — точные группы, 2 — по году, 3 — номер независимо от года): '
            read -r mode || break
            case "$mode" in
                1)
                    read -r -p 'Группы через пробел: ' input || break
                    read -r -a groups <<< "$input"
                    average_attendance "${groups[@]}" ;;
                2)
                    read -r -p 'Год группы (например 23 или 2023): ' year || break
                    average_attendance_mode year "$year" ;;
                3)
                    read -r -p 'Номер группы (например 06, A-09, Аэ21): ' number || break
                    average_attendance_mode number "$number" ;;
                *) echo 'Неизвестный режим.' ;;
            esac
            ;;
        5) list_groups ;;
        0) break ;;
        *) echo 'Неизвестная команда.' ;;
    esac
done
