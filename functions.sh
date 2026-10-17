#!/usr/bin/env bash
# Функции ЛР4. Исходные файлы никогда не изменяются.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA="$ROOT/data"
SUBJECTS=('Цирковое_Дело' 'Пересдачеведение')

validate_group() {
    [[ "$1" =~ ^[A-Za-z]+-[0-9]+-[0-9]+$ && -f "$DATA/students/groups/$1" ]] || {
        printf 'Ошибка: группа «%s» отсутствует.\n' "$1" >&2; return 1;
    }
}
validate_subject() {
    [[ "$1" == "1" || "$1" == "2" ]] || { echo 'Ошибка: предмет должен быть 1 или 2.' >&2; return 1; }
}
validate_test() {
    [[ "$1" =~ ^[1-4]$ ]] || { echo 'Ошибка: номер теста — от 1 до 4.' >&2; return 1; }
}
# Строка с посещаемостью имеет вид: ФИО 010110...
# Результат: count;total;номера через запятую
attendance_stats() {
    local bits="$1" i ch count=0 nums='' total=${#1}
    for ((i=0; i<total; i++)); do
        ch=${bits:i:1}
        if [[ "$ch" == 1 ]]; then
            ((count+=1))
            if [[ -n "$nums" ]]; then nums+=','; fi
            nums+=$((i+1))
        fi
    done
    printf '%s;%s;%s\n' "$count" "$total" "${nums:--}"
}
# Выбор наихудшей посещаемости по сумме двух предметов.
# Если минимум разделяют несколько студентов, выводятся все.
worst_attendance() {
    local group="$1" student subject line bits stat n total nums
    local attended all min=-1
    local -a rows=()
    validate_group "$group" || return 1
    while IFS= read -r student || [[ -n "$student" ]]; do
        [[ -z "$student" ]] && continue
        attended=0; all=0; nums=''
        for subject in "${SUBJECTS[@]}"; do
            line=$(grep -F -m1 -e "$student " "$DATA/$subject/$group-attendance" 2>/dev/null || true)
            if [[ -z "$line" ]]; then
                echo "Ошибка: нет посещаемости: $student / $subject" >&2; return 1
            fi
            bits=${line#* }
            stat=$(attendance_stats "$bits")
            IFS=';' read -r n total _ <<< "$stat"
            ((attended+=n, all+=total))
            rows+=("$student|$subject|$n|$total|${stat##*;}")
        done
        if ((min < 0 || attended < min)); then min=$attended; fi
    done < "$DATA/students/groups/$group"
    echo "Группа $group. Минимум посещений по двум предметам: $min"
    local -A counts=()
    for line in "${rows[@]}"; do
        IFS='|' read -r student subject n total nums <<< "$line"
        ((counts["$student"]+=n)) || true
    done
    for line in "${rows[@]}"; do
        IFS='|' read -r student subject n total nums <<< "$line"
        if ((counts["$student"] == min)); then
            printf '%s — %s: %s из %s; занятия: %s\n' "$student" "$subject" "$n" "$total" "$nums"
        fi
    done
}
# Оценка за предмет и тест: максимальная успешная (3+) оценка,
# а при отсутствии успеха 0 (даже если были неудачные попытки).
# Фильтрация по номеру группы и ФИО выполняется точным сравнением полей.
passed_grade() {
    local group="$1" student="$2" subject="$3" test="$4"
    local g s date correct grade best=0
    while IFS=';' read -r g s date correct grade || [[ -n "$grade" ]]; do
        if [[ "$g" == "$group" && "$s" == "$student" && "$grade" =~ ^[0-9]+$ ]] && ((grade>=3 && grade>best)); then
            best=$grade
        fi
    done < "$DATA/$subject/tests/TEST-$test"
    printf '%s\n' "$best"
}
not_passed() {
    local group="$1" test="$2" subject_id="$3" subject student grade count=0
    validate_group "$group" && validate_test "$test" && validate_subject "$subject_id" || return 1
    subject=${SUBJECTS[subject_id-1]}
    printf 'Группа %s; предмет %s; тест %s\n' "$group" "$subject" "$test"
    while IFS= read -r student || [[ -n "$student" ]]; do
        [[ -z "$student" ]] && continue
        grade=$(passed_grade "$group" "$student" "$subject" "$test")
        if ((grade==0)); then printf '%s\n' "$student"; ((count+=1)); fi
    done < "$DATA/students/groups/$group"
    printf 'Всего не сдали: %s\n' "$count"
}
# Рейтинг: сумма максимальных успешных оценок по восьми тестам.
# Не сданный тест дает 0; порядок — по убыванию баллов.
ranking() {
    local group="$1" student subject test grade sum successful
    validate_group "$group" || return 1
    printf 'Рейтинг %s (8 тестов: сумма баллов, средний балл, сдано):\n' "$group"
    {
      while IFS= read -r student || [[ -n "$student" ]]; do
          [[ -z "$student" ]] && continue
          sum=0; successful=0
          for subject in "${SUBJECTS[@]}"; do
              for test in {1..4}; do
                  grade=$(passed_grade "$group" "$student" "$subject" "$test")
                  ((sum+=grade))
                  if ((grade>=3)); then ((successful+=1)); fi
              done
          done
          printf '%s;%s;%s\n' "$sum" "$student" "$successful"
      done < "$DATA/students/groups/$group"
    } | LC_ALL=C sort -t';' -k1,1nr -k2,2 | while IFS=';' read -r sum student successful; do
        printf '%-24s %2d / 40   %d.%02d / 5   сдано: %d/8\n' "$student" "$sum" "$((sum/8))" "$(((sum%8)*100/8))" "$successful"
    done
}
# Средняя посещаемость: все отмеченные посещения / все возможные
# для студентов каждой группы и обоих предметов (взвешенный процент).
average_attendance() {
    local group subject student line bits stat n total nums attended all
    (($#>0)) || { echo 'Ошибка: укажите хотя бы одну группу.' >&2; return 1; }
    for group in "$@"; do validate_group "$group" || return 1; done
    for group in "$@"; do
        attended=0; all=0
        for subject in "${SUBJECTS[@]}"; do
            while IFS= read -r student || [[ -n "$student" ]]; do
                [[ -z "$student" ]] && continue
                line=$(grep -F -m1 -e "$student " "$DATA/$subject/$group-attendance" 2>/dev/null || true)
                [[ -n "$line" ]] || { printf 'Ошибка: нет данных для %s, %s\n' "$group" "$student" >&2; return 1; }
                bits=${line#* };stat=$(attendance_stats "$bits")
                IFS=';' read -r n total nums <<< "$stat"
                ((attended+=n, all+=total))
            done < "$DATA/students/groups/$group"
        done
        if ((all>0)); then
            printf '%s: %d из %d (%d.%02d%%)\n' "$group" "$attended" "$all" "$((attended*100/all))" "$((attended*10000/all%100))"
        else echo "$group: нет занятий"; fi
    done
}
