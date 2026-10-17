#!/usr/bin/env bash
set -u
source "$(dirname "$0")/functions.sh"
if (($#)); then
    case "$1" in
        worst) shift; (($#==1)) || { echo 'Формат: main.sh worst ГРУППА'; exit 2; }; worst_attendance "$1" ;;
        failed) shift; (($#==3)) || { echo 'Формат: main.sh failed ГРУППА ТЕСТ ПРЕДМЕТ(1/2)'; exit 2; }; not_passed "$1" "$2" "$3" ;;
        rank) shift; (($#==1)) || { echo 'Формат: main.sh rank ГРУППА'; exit 2; }; ranking "$1" ;;
        average) shift; average_attendance "$@" ;;
        *) echo 'Команды: worst ГРУППА | failed ГРУППА ТЕСТ ПРЕДМЕТ | rank ГРУППА | average ГРУППА...'; exit 2 ;;
    esac
    exit $?
fi
while true; do
    printf '\n1. Худшая посещаемость\n2. Не сдавшие тест\n3. Рейтинг успеваемости\n4. Средняя посещаемость групп\n0. Выход\nВыбор: '
    read -r choice || break
    case "$choice" in
      1) read -r -p 'Группа (например A-06-21): ' group; worst_attendance "$group" ;;
      2) read -r -p 'Группа: ' group; read -r -p 'Тест (1-4): ' test; read -r -p 'Предмет (1 — Цирковое_Дело, 2 — Пересдачеведение): ' subject; not_passed "$group" "$test" "$subject" ;;
      3) read -r -p 'Группа: ' group; ranking "$group" ;;
      4) read -r -p 'Группы через пробел: ' input; read -r -a groups <<< "$input"; average_attendance "${groups[@]}" ;;
      0) break ;;
      *) echo 'Неизвестная команда' ;;
    esac
done
