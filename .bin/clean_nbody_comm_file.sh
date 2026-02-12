#!/bin/bash

# 默认值
SIM_DIR=""
KEEP_EVERY=20
DRY_RUN=false
TOLERANCE=0.001 # 浮点数比较容差

function usage() {
    echo "Usage: $0 --sim-dir=<directory> --keep-every=<number> [--dry-run]"
    exit 1
}

# 参数解析
for arg in "$@"; do
    case $arg in
        --sim-dir=*)
        SIM_DIR="${arg#*=}"
        ;;
        --keep-every=*)
        KEEP_EVERY="${arg#*=}"
        ;;
        --dry-run)
        DRY_RUN=true
        ;;
        *)
        echo "Unknown argument: $arg"
        usage
        ;;
    esac
done

if [ -z "$SIM_DIR" ]; then
    echo "Error: --sim-dir is required."
    usage
fi

if [ ! -d "$SIM_DIR" ]; then
    echo "Error: Directory $SIM_DIR does not exist."
    exit 1
fi

echo "Scanning directory: $SIM_DIR"
echo "Keep interval: $KEEP_EVERY"
echo "Dry run: $DRY_RUN"
echo "----------------------------------------"

# 临时文件用于排序和处理
TMP_FILE_LIST=$(mktemp)
declare -A FILES_BY_TIME

# 查找所有相关文件
echo "Finding files..."
find "$SIM_DIR" -type f -name 'comm.*_*' > "$TMP_FILE_LIST"
TOTAL_FILES=$(wc -l < "$TMP_FILE_LIST")

echo "Processing file list..."
PROCESSED_COUNT=0
TO_DELETE=()
TO_KEEP=()
SKIPPED=()

while IFS= read -r file; do
    ((PROCESSED_COUNT++))
    if (( PROCESSED_COUNT % 100 == 0 )); then
        printf "\rReading files %d / %d ..." "$PROCESSED_COUNT" "$TOTAL_FILES"
    fi

    filename=$(basename "$file")
    
    # 提取 n 和 X (comm.n_X)
    # 假设格式严格为 comm.[prefix]_[time]
    if [[ "$filename" =~ comm\.([0-9]+)_([0-9]+(\.[0-9]+)?) ]]; then
        prefix="${BASH_REMATCH[1]}"
        time_val="${BASH_REMATCH[2]}"
        
        # 将相同时间的文件分为一组
        # 键值为 time_val，值为 "prefix|filepath"
        FILES_BY_TIME["$time_val"]+="$prefix|$file "
    else
        SKIPPED+=("$file (Format unknown)")
    fi
done < "$TMP_FILE_LIST"
echo -e "\rReading files $TOTAL_FILES / $TOTAL_FILES ... Done."

# 处理每个时间点
TOTAL_TIMES="${#FILES_BY_TIME[@]}"
CURRENT_TIME_IDX=0
echo "Analyzing time points..."

for time_val in "${!FILES_BY_TIME[@]}"; do
    ((CURRENT_TIME_IDX++))
    if (( CURRENT_TIME_IDX % 10 == 0 )); then
        printf "\rAnalyzing time points %d / %d ..." "$CURRENT_TIME_IDX" "$TOTAL_TIMES"
    fi

    # 检查是否为 keep-every 的整数倍
    # 使用 awk 进行浮点数取模检查
    is_keep=$(awk -v t="$time_val" -v k="$KEEP_EVERY" -v tol="$TOLERANCE" 'BEGIN {
        rem = t % k;
        if (rem < tol || k - rem < tol) print 1; else print 0;
    }')

    entries=(${FILES_BY_TIME["$time_val"]})
    
    if [ "$is_keep" -eq 1 ]; then
        # 这是一个保留时间点，需要检查版本 (1 vs 2)
        best_file=""
        best_prefix=-1
        
        # 找出优先级最高的文件保留 (comm.2 > comm.1)
        for entry in "${entries[@]}"; do
            prefix="${entry%%|*}"
            fpath="${entry#*|}"
            
            if [ "$prefix" -gt "$best_prefix" ]; then
                # 如果此时best_file已经有值，说明那个被淘汰了，加入删除列表
                if [ -n "$best_file" ]; then
                     TO_DELETE+=("$best_file")
                fi
                best_file="$fpath"
                best_prefix="$prefix"
            else
                # 当前文件不如 best_file 优先，删除
                TO_DELETE+=("$fpath")
            fi
        done
        
        if [ -n "$best_file" ]; then
            TO_KEEP+=("$best_file")
        fi
    else
        # 不是保留时间点，全部删除
        for entry in "${entries[@]}"; do
            fpath="${entry#*|}"
            TO_DELETE+=("$fpath")
        done
    fi
done
echo -e "\rAnalyzing time points $TOTAL_TIMES / $TOTAL_TIMES ... Done."

# 排序输出以方便检查（按文件名中的时间点数值排序）
IFS=$'\n'
SORTED_DELETE=($(printf "%s\n" "${TO_DELETE[@]}" | awk -F'_' '{print $NF, $0}' | sort -n | cut -d' ' -f2-))
SORTED_KEEP=($(printf "%s\n" "${TO_KEEP[@]}" | awk -F'_' '{print $NF, $0}' | sort -n | cut -d' ' -f2-))
unset IFS

# 辅助函数：按列宽打印数组
function print_files_wrapped() {
    local files=("$@")
    local line_buffer=""
    local max_width=100
    
    for f in "${files[@]}"; do
        if [ -z "$line_buffer" ]; then
            line_buffer="$f"
        else
            if [ $((${#line_buffer} + ${#f} + 3)) -le $max_width ]; then
                line_buffer="$line_buffer | $f"
            else
                echo "  $line_buffer"
                line_buffer="$f"
            fi
        fi
    done
    if [ -n "$line_buffer" ]; then
        echo "  $line_buffer"
    fi
}

if [ "${#SORTED_KEEP[@]}" -gt 100 ] || [ "${#SORTED_DELETE[@]}" -gt 100 ] || [ "${#SKIPPED[@]}" -gt 100 ]; then
    REPORT_FILE=$(mktemp)
    {
        echo "Files to be KEPT (${#SORTED_KEEP[@]}):"
        printf '  %s\n' "${SORTED_KEEP[@]}"
        echo -e "\nFiles to be DELETED (${#SORTED_DELETE[@]}):"
        printf '  %s\n' "${SORTED_DELETE[@]}"
        echo -e "\nFiles SKIPPED (${#SKIPPED[@]}):"
        printf '  [SKIP] %s\n' "${SKIPPED[@]}"
    } > "$REPORT_FILE"
    echo "Files list exceeds 100 entries. Full report written to: $REPORT_FILE"
else
    echo "Files to be KEPT (${#SORTED_KEEP[@]}):"
    print_files_wrapped "${SORTED_KEEP[@]}"

    echo ""
    echo "Files to be DELETED (${#SORTED_DELETE[@]}):"
    print_files_wrapped "${SORTED_DELETE[@]}"

    echo ""
    echo "Files SKIPPED (Not matching pattern comm.n_X):"
    for f in "${SKIPPED[@]}"; do echo "  [SKIP] $f"; done
fi

echo "----------------------------------------"
echo "Summary:"
echo "  To Keep:   ${#SORTED_KEEP[@]}"
echo "  To Delete: ${#SORTED_DELETE[@]}"
echo "  Skipped:   ${#SKIPPED[@]}"

if [ "$DRY_RUN" = true ]; then
    echo "DRY RUN MODE: No files were deleted."
    rm "$TMP_FILE_LIST"
    exit 0
fi

if [ "${#SORTED_DELETE[@]}" -eq 0 ]; then
    echo "No files to delete."
    rm "$TMP_FILE_LIST"
    exit 0
fi

echo ""
echo "!!! WARNING: You are about to DELETE ${#SORTED_DELETE[@]} files. !!!"
read -p "Type 'yes' to proceed with deletion: " CONFIRM

if [ "$CONFIRM" = "yes" ]; then
    echo "Deleting files..."
    count=0
    total_del="${#SORTED_DELETE[@]}"
    for f in "${SORTED_DELETE[@]}"; do
        rm "$f"
        ((count++))
        if (( count % 10 == 0 )); then
            printf "\rDeleting %d / %d files ..." "$count" "$total_del"
        fi
    done
    echo "" # 换行
    echo "Done. $count files deleted."
else
    echo "Operation cancelled."
fi

rm "$TMP_FILE_LIST"
