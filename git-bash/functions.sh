#!/usr/bin/env bash
# Лабораторная работа №4. Файлы в data/ используются только для чтения.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA="${LAB4_DATA:-$ROOT/../data}"   # LAB4_DATA — подмена каталога данных для тестов
GROUP_DIR="$DATA/students/groups"
SUBJECTS=('Цирковое_Дело' 'Пересдачеведение')

# A/a/А/а -> A, Ae/ae/Аэ/аэ -> Ae. Поддерживаются также 06-23 и 0623.
# Без префикса допускается только однозначно определяемая группа.
resolve_group() {
    local input="${1//[[:space:]]/}" prefix='' num year group path
    input=${input//А/A}; input=${input//а/a}; input=${input//Э/E}; input=${input//э/e}
    local -a matches=()
    if [[ "$input" =~ ^([Aa])([Ee])?-?([0-9]{2})-?([0-9]{2})$ ]]; then
        prefix='A'
        [[ -n "${BASH_REMATCH[2]}" ]] && prefix='Ae'
        num="${BASH_REMATCH[3]}"; year="${BASH_REMATCH[4]}"
        group="$prefix-$num-$year"
    elif [[ "$input" =~ ^([0-9]{2})-?([0-9]{2})$ ]]; then
        num="${BASH_REMATCH[1]}"; year="${BASH_REMATCH[2]}"
        for path in "$GROUP_DIR"/*-"$num"-"$year"; do
            [[ -f "$path" ]] && matches+=("${path##*/}")
        done
        if ((${#matches[@]} == 1)); then
            group="${matches[0]}"
        elif ((${#matches[@]} > 1)); then
            printf 'Ошибка: неоднозначная группа «%s». Введите буквы A или Ae.\n' "$1" >&2
            return 1
        fi
    fi
    if [[ -z "${group:-}" || ! -f "$GROUP_DIR/$group" ]]; then
        printf 'Ошибка: группа «%s» отсутствует или указана неверно.\n' "$1" >&2
        return 1
    fi
    printf '%s\n' "$group"
}

# Для поиска по номеру: 06, a-06, А06, Ae-21, Аэ21.
resolve_group_number() {
    local input="${1//[[:space:]]/}" prefix='' number key path
    input=${input//А/A}; input=${input//а/a}; input=${input//Э/E}; input=${input//э/e}
    local -a matches=()
    if [[ "$input" =~ ^([Aa])([Ee])?-?([0-9]{2})$ ]]; then
        prefix=A
        [[ -n "${BASH_REMATCH[2]}" ]] && prefix=Ae
        number="${BASH_REMATCH[3]}"
        key="$prefix-$number"
    elif [[ "$input" =~ ^[0-9]{2}$ ]]; then
        number="$input"
        for path in "$GROUP_DIR"/*-"$number"-??; do
            [[ -f "$path" ]] || continue
            local candidate="${path##*/}"
            candidate="${candidate%-??}"
            if [[ ! " ${matches[*]} " == *" $candidate "* ]]; then
                matches+=("$candidate")
            fi
        done
        if ((${#matches[@]} == 1)); then
            key="${matches[0]}"
        elif ((${#matches[@]} > 1)); then
            printf 'Ошибка: номер «%s» неоднозначен. Укажите A или Ae.\n' "$1" >&2
            return 1
        fi
    fi
    [[ -n "${key:-}" ]] || { printf 'Ошибка: номер группы «%s» не найден.\n' "$1" >&2; return 1; }
    printf '%s\n' "$key"
}

resolve_year() {
    local year="$1"
    if [[ "$year" =~ ^20([0-9]{2})$ ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
    elif [[ "$year" =~ ^[0-9]{2}$ ]]; then
        printf '%s\n' "$year"
    else
        printf 'Ошибка: год группы задаётся как 23 или 2023.\n' >&2
        return 1
    fi
}

validate_subject() {
    [[ "$1" == 1 || "$1" == 2 ]] || { echo 'Ошибка: предмет должен быть 1 или 2.' >&2; return 1; }
}
validate_rank_subject() {
    [[ "$1" == 0 || "$1" == 1 || "$1" == 2 ]] || { echo 'Ошибка: предмет — 0 (оба), 1 или 2.' >&2; return 1; }
}
validate_test() {
    [[ "$1" =~ ^[1-4]$ ]] || { echo 'Ошибка: тест должен быть от 1 до 4.' >&2; return 1; }
}
validate_attempts() {
    [[ "$1" =~ ^(0|[1-9][0-9]*)$ ]] || { echo 'Ошибка: номер попытки — положительное число, 0 означает все попытки.' >&2; return 1; }
}

list_groups() {
    local path name count
    local -a lines=()
    echo 'Доступные группы (полные названия):'
    for path in "$GROUP_DIR"/*; do
        [[ -f "$path" ]] || continue
        name="${path##*/}"
        mapfile -t lines < "$path"            # файл целиком в массив, без запуска grep
        count=${#lines[@]}
        printf '  %-10s (%s студентов)\n' "$name" "$count"
    done
}

# Результат в переменных ATT_COUNT (посещено), ATT_TOTAL (всего занятий),
# ATT_NUMBERS (номера посещённых занятий через запятую или «-»).
# Функция вызывается БЕЗ $(...): в Git Bash каждая подоболочка стоит десятки мс.
attendance_stats() {
    local bits="$1" rest="$1" head pos=0
    local ones="${bits//0/}"            # удалить все нули — останутся только единицы
    ATT_COUNT=${#ones}
    ATT_TOTAL=${#bits}
    ATT_NUMBERS=''
    while [[ "$rest" == *1* ]]; do      # цикл только по единицам, а не по каждому символу
        head="${rest%%1*}"              # всё, что стоит до ближайшей 1
        ((pos += ${#head} + 1))
        ATT_NUMBERS+="${ATT_NUMBERS:+,}$pos"
        rest="${rest#*1}"               # отрезать строку по эту 1 включительно
    done
    ATT_NUMBERS="${ATT_NUMBERS:--}"
}

# Печать: группа, ФИО, минимум, затем детализация по каждому предмету.
worst_attendance() {
    local group student subject bits n total numbers all min=-1 path extra
    group=$(resolve_group "$1") || return 1
    local -a students=()
    local -A roster=() attend_bits=() totals=() overall=()
    while IFS= read -r student || [[ -n "$student" ]]; do
        student="${student%$'\r'}"     # убрать CR, если файл с переносами Windows
        [[ -n "$student" ]] || continue
        students+=("$student"); roster["$student"]=1
    done < "$GROUP_DIR/$group"
    for subject in "${SUBJECTS[@]}"; do
        path="$DATA/$subject/$group-attendance"
        [[ -f "$path" ]] || { printf 'Ошибка: отсутствует файл %s\n' "$path" >&2; return 1; }
        while read -r student bits extra || [[ -n "$student" ]]; do
            bits="${bits%$'\r'}"
            [[ -v 'roster[$student]' ]] || continue
            [[ "$bits" =~ ^[01]+$ ]] || { printf 'Ошибка: некорректная посещаемость %s\n' "$student" >&2; return 1; }
            attend_bits["$subject|$student"]="$bits"
        done < "$path"
    done
    for student in "${students[@]}"; do
        all=0
        for subject in "${SUBJECTS[@]}"; do
            bits="${attend_bits["$subject|$student"]:-}"
            [[ -n "$bits" ]] || { printf 'Ошибка: нет посещаемости: %s / %s\n' "$student" "$subject" >&2; return 1; }
            attendance_stats "$bits"
            ((all+=ATT_COUNT))
            totals["$subject|$student"]="$ATT_COUNT;$ATT_TOTAL;$ATT_NUMBERS"
        done
        overall["$student"]="$all"
        if ((min < 0 || all < min)); then min=$all; fi
    done
    printf 'Группа: %s\n' "$group"
    for student in "${students[@]}"; do
        ((overall["$student"] == min)) || continue
        all=0
        for subject in "${SUBJECTS[@]}"; do
            IFS=';' read -r n total numbers <<< "${totals["$subject|$student"]}"
            ((all+=total))
        done
        printf 'ФИО студента: %s\n' "$student"
        printf 'Минимум посещений: %s из %s\n' "$min" "$all"
        echo 'Посещения по предметам:'
        for subject in "${SUBJECTS[@]}"; do
            IFS=';' read -r n total numbers <<< "${totals["$subject|$student"]}"
            printf '  %s: %s из %s; номера занятий: %s\n' "$subject" "$n" "$total" "$numbers"
        done
    done
}

# Оценка 2,2-,2++,3+,4--,5++ -> её числовая основа 2..5.
# В массивах scores_ref хранятся максимальные успешные оценки (3..5).
# limit=0 — все попытки; limit=N — только первые N по дате у каждого студента.
# Имя массива scores/attempt_counts/roster передаётся через nameref, Bash >=4.3.
scan_test() {
    local group="$1" subject="$2" test="$3" limit="$4"
    local -n scores_ref="$5" counts_ref="$6" roster_ref="$7"
    local prefix="$8" file="$DATA/$subject/tests/TEST-$test"
    local g student date correct grade base key previous
    [[ -f "$file" ]] || { printf 'Ошибка: нет файла теста %s\n' "$file" >&2; return 1; }
    if ((limit>0)); then
        # Сортировка по ФИО и дате. При одинаковых датах сохранён порядок файла.
        while IFS=';' read -r g student date correct grade || [[ -n "$grade" ]]; do
            grade="${grade%$'\r'}"
            [[ "$g" == "$group" && -v 'roster_ref[$student]' ]] || continue
            counts_ref["$student"]=$(( ${counts_ref["$student"]:-0} + 1 ))
            ((counts_ref["$student"]<=limit)) || continue
            if [[ "$grade" =~ ^([2-5])[+-]*$ ]]; then
                base="${BASH_REMATCH[1]}"; key="$prefix$student"
                previous="${scores_ref["$key"]:-0}"
                ((base>=3 && base>previous)) && scores_ref["$key"]="$base"
            fi
        done < <(LC_ALL=C sort -s -t';' -k2,2 -k3,3 "$file")
    else
        while IFS=';' read -r g student date correct grade || [[ -n "$grade" ]]; do
            grade="${grade%$'\r'}"
            [[ "$g" == "$group" && -v 'roster_ref[$student]' ]] || continue
            if [[ "$grade" =~ ^([2-5])[+-]*$ ]]; then
                base="${BASH_REMATCH[1]}"; key="$prefix$student"
                previous="${scores_ref["$key"]:-0}"
                ((base>=3 && base>previous)) && scores_ref["$key"]="$base"
            fi
        done < "$file"
    fi
    return 0
}

# Новый порядок: предмет, тест, группа, [номер попытки].
not_passed() {
    local subject_id="$1" test="$2" group="$3" limit="${4:-0}"
    local subject student count=0
    validate_subject "$subject_id" && validate_test "$test" && validate_attempts "$limit" || return 1
    group=$(resolve_group "$group") || return 1
    subject="${SUBJECTS[subject_id-1]}"
    local -a students=()
    local -A roster=() scores=() attempt_counts=()
    while IFS= read -r student || [[ -n "$student" ]]; do
        student="${student%$'\r'}"     # убрать CR, если файл с переносами Windows
        [[ -n "$student" ]] || continue
        students+=("$student"); roster["$student"]=1
    done < "$GROUP_DIR/$group"
    scan_test "$group" "$subject" "$test" "$limit" scores attempt_counts roster '' || return 1
    printf 'Предмет: %s\nТест: %s\nГруппа: %s\n' "$subject" "$test" "$group"
    if ((limit>0)); then printf 'На момент попытки №%s (по дате)\n' "$limit"; else echo 'За все попытки'; fi
    for student in "${students[@]}"; do
        if ((${scores["$student"]:-0} < 3)); then
            printf '%s\n' "$student"; ((count+=1))
        fi
    done
    printf 'Всего не сдали: %s\n' "$count"
}

# Средний балл по ВСЕМ попыткам (включая неудачные), а не лучшая/итоговая оценка.
# Один тест может содержать несколько попыток одного студента.
# Каждый файл читаем один раз, в массивы накапливаем сумму и количество попыток.
ranking() {
    local group="$1" subject_id="${2:-0}" student subject test path g date correct grade base
    local n sum rounded mean key
    validate_rank_subject "$subject_id" || return 1
    group=$(resolve_group "$group") || return 1
    local -a students=() subjects=()
    local -A roster=() sums=() counts=()
    if [[ "$subject_id" == 0 ]]; then subjects=("${SUBJECTS[@]}"); else subjects=("${SUBJECTS[subject_id-1]}"); fi
    while IFS= read -r student || [[ -n "$student" ]]; do
        student="${student%$'\r'}"     # убрать CR, если файл с переносами Windows
        [[ -n "$student" ]] || continue
        students+=("$student"); roster["$student"]=1
    done < "$GROUP_DIR/$group"
    for subject in "${subjects[@]}"; do
        for test in 1 2 3 4; do
            path="$DATA/$subject/tests/TEST-$test"
            [[ -f "$path" ]] || { printf 'Ошибка: нет файла теста %s\n' "$path" >&2; return 1; }
            while IFS=';' read -r g student date correct grade || [[ -n "$grade" ]]; do
                grade="${grade%$'\r'}"
                [[ "$g" == "$group" && -v 'roster[$student]' ]] || continue
                if [[ "$grade" =~ ^([2-5])[+-]*$ ]]; then
                    base="${BASH_REMATCH[1]}"
                    sums["$student"]=$(( ${sums["$student"]:-0} + base ))
                    counts["$student"]=$(( ${counts["$student"]:-0} + 1 ))
                fi
            done < "$path"
        done
    done
    printf 'Рейтинг группы %s; предмет: %s\n' "$group" "$(if [[ "$subject_id" == 0 ]]; then printf 'оба'; else printf '%s' "${subjects[0]}"; fi)"
    # Для заголовка используем явные пробелы: Bash printf считает ширину
    # кириллических надписей в байтах, поэтому %-26s сбивает колонки.
    # Заголовок и данные начинаются на одинаковых позициях терминала.
    printf 'Студент%19s  Средняя оценка%1s  Попытки\n' '' ''
    {
        for student in "${students[@]}"; do
            sum="${sums["$student"]:-0}"; n="${counts["$student"]:-0}"
            if ((n>0)); then
                # Среднее для сортировки с точностью до 6 знаков,
                # для отображения округляем до двух знаков.
                key=$((sum*1000000/n))
                rounded=$(((sum*100 + n/2)/n))
                printf '%d;%s;%d;%d\n' "$key" "$student" "$rounded" "$n"
            else
                printf '%d;%s;%d;%d\n' '-1' "$student" '-1' 0
            fi
        done
    } | LC_ALL=C sort -t';' -k1,1nr -k2,2 | while IFS=';' read -r key student rounded n; do
        if ((n>0)); then
            printf -v mean '%d.%02d' "$((rounded/100))" "$((rounded%100))"
            printf '%-26s  %-15s  %d\n' "$student" "$mean" "$n"
        else
            printf '%-26s  %-15s  %d\n' "$student" '-' 0
        fi
    done
}

# Считает взвешенную посещаемость одной группы, устанавливает два числа.
# Проходим файлы посещаемости один раз, учитывая только студентов из списка группы.
calculate_group_attendance() {
    local group="$1" subject_id="${2:-0}" subject student bits extra path ones
    local -a selected_subjects=()
    validate_rank_subject "$subject_id" || return 1
    if [[ "$subject_id" == 0 ]]; then selected_subjects=("${SUBJECTS[@]}"); else selected_subjects=("${SUBJECTS[subject_id-1]}"); fi
    local -A roster=() seen=()
    local roster_count=0
    AVG_ATTENDED=0; AVG_POSSIBLE=0
    while IFS= read -r student || [[ -n "$student" ]]; do
        student="${student%$'\r'}"     # убрать CR, если файл с переносами Windows
        [[ -n "$student" ]] || continue
        roster["$student"]=1; ((roster_count+=1))
    done < "$GROUP_DIR/$group"
    for subject in "${selected_subjects[@]}"; do
        path="$DATA/$subject/$group-attendance"
        [[ -f "$path" ]] || { printf 'Ошибка: отсутствует файл %s\n' "$path" >&2; return 1; }
        local count=0
        while read -r student bits extra || [[ -n "$student" ]]; do
            bits="${bits%$'\r'}"
            [[ -v 'roster[$student]' ]] || continue
            [[ "$bits" =~ ^[01]+$ ]] || { printf 'Ошибка: некорректная посещаемость %s\n' "$student" >&2; return 1; }
            [[ -v 'seen[$subject|$student]' ]] && continue
            seen["$subject|$student"]=1; ((count+=1))
            ones="${bits//0/}"          # номера занятий не нужны — только количество
            ((AVG_ATTENDED+=${#ones}, AVG_POSSIBLE+=${#bits}))
        done < "$path"
        if ((count != roster_count)); then
            printf 'Ошибка: неполные данные посещаемости для %s / %s\n' "$group" "$subject" >&2
            return 1
        fi
    done
}

average_attendance_mode() {
    local mode="$1" subject_id="$2" value group year number path
    shift 2
    validate_rank_subject "$subject_id" || return 1
    local -a selected=()
    local -A found=()
    local sum_attended=0 sum_possible=0
    case "$mode" in
        exact)
            (($#>0)) || { echo 'Ошибка: укажите хотя бы одну группу.' >&2; return 1; }
            for value in "$@"; do
                group=$(resolve_group "$value") || return 1
                if [[ ! -v 'found[$group]' ]]; then selected+=("$group"); found["$group"]=1; fi
            done
            ;;
        year)
            (($#==1)) || { echo 'Ошибка: укажите один год группы.' >&2; return 1; }
            year=$(resolve_year "$1") || return 1
            for path in "$GROUP_DIR"/*-"$year"; do
                [[ -f "$path" ]] && selected+=("${path##*/}")
            done
            ;;
        number)
            (($#==1)) || { echo 'Ошибка: укажите один номер группы.' >&2; return 1; }
            number=$(resolve_group_number "$1") || return 1
            for path in "$GROUP_DIR/$number"-??; do
                [[ -f "$path" ]] && selected+=("${path##*/}")
            done
            ;;
        *) echo 'Ошибка: неизвестный режим средней посещаемости.' >&2; return 1 ;;
    esac
    ((${#selected[@]} > 0)) || { echo 'Ошибка: для запроса нет групп.' >&2; return 1; }
    if [[ "$subject_id" == 0 ]]; then
        printf 'Предмет: оба\n'
    else
        printf 'Предмет: %s\n' "${SUBJECTS[subject_id-1]}"
    fi
    if [[ "$mode" == year ]]; then printf 'Группы года %s:\n' "$year"; fi
    if [[ "$mode" == number ]]; then printf 'Группы с номером %s (все годы):\n' "$number"; fi
    for group in "${selected[@]}"; do
        calculate_group_attendance "$group" "$subject_id" || return 1
        ((sum_attended+=AVG_ATTENDED, sum_possible+=AVG_POSSIBLE))
        if ((AVG_POSSIBLE>0)); then
            printf '%s: %d из %d (%d.%02d%%)\n' "$group" "$AVG_ATTENDED" "$AVG_POSSIBLE" \
                "$((AVG_ATTENDED*100/AVG_POSSIBLE))" "$((AVG_ATTENDED*10000/AVG_POSSIBLE%100))"
        else
            printf '%s: нет занятий\n' "$group"
        fi
    done
    if [[ "$mode" != exact ]] || ((${#selected[@]} > 1)); then
        if ((sum_possible>0)); then
            printf 'ИТОГО (%d групп): %d из %d (%d.%02d%%)\n' "${#selected[@]}" "$sum_attended" "$sum_possible" \
                "$((sum_attended*100/sum_possible))" "$((sum_attended*10000/sum_possible%100))"
        else
            echo 'ИТОГО: нет занятий'
        fi
    fi
}

average_attendance() { average_attendance_mode exact 0 "$@"; }
