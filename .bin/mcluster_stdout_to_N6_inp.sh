#!/bin/bash

# 文件名作为参数传入
mcluster_stdout_file="$1"

# 检查参数个数，少于1则输出用法
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <mcluster_stdout_file_path> [nb6_input]"
    echo "  if nb6_input is provided, modify it inplace the extracted values"
    exit 1
fi

# 检查文件是否存在
if [[ ! -f "$mcluster_stdout_file" ]]; then
    echo "错误: 文件 $mcluster_stdout_file 不存在"
    exit 1
fi

# 提取 NRAND
NRAND=$(grep -m 1 "Random seed =" "$mcluster_stdout_file" | awk -F "= " '{print $2}')

# 提取 RBAR
RBAR=$(grep -m 1 "rvir =" "$mcluster_stdout_file" | awk -F "= " '{print $2}' | awk '{print $1}')

## 通过RBAR计算应设的RMIN: 1 au 以上的hard binary不应该正规化。计算方法：RMIN[NB]=1(au)*4.84813681109536e-06(au_to_pc)/RBAR(NB_to_pc)
# RMIN=$(awk "BEGIN {print 1 * 4.84813681109536e-06 / $RBAR}")
RMIN='1.0E-05' # about 5 au

# 提取 ZMET
ZMET=$(grep -m 1 "Setting up stellar population with Z =" "$mcluster_stdout_file" | awk -F "= " '{print $2}' | sed 's/\.$//')

# 提取 NBIN0
NBIN0_values=$(grep -oE "Creating [0-9]+ primordial binary systems" "$mcluster_stdout_file" | grep -oE "[0-9]+")
NBIN0_count=$(echo "$NBIN0_values" | wc -l)

if [[ $NBIN0_count -gt 1 ]]; then
    echo "Warning: multiple 'Creating [0-9]+ primordial binary systems' items found:"
    echo "$NBIN0_values"
    NBIN0=$(echo "$NBIN0_values" | head -n 1)
else
    NBIN0=$(echo "$NBIN0_values")
fi
# NBIN0=$(echo "$NBIN0_values" | awk '{sum += $1} END {print sum}')

# 提取新的 ZMBAR
total_mass=$(grep -oP "Total mass: \K[0-9]+" "$mcluster_stdout_file" | awk '{sum += $1} END {print sum}')
total_stars=$(grep -oP "Total mass: [0-9]+\s+\(\K[0-9]+" "$mcluster_stdout_file" | awk '{sum += $1} END {print sum}')
ZMBAR=$(awk "BEGIN {print $total_mass / $total_stars}")

# 打印结果
cat <<EOF
NRAND=$NRAND
RBAR=$RBAR
RMIN=$RMIN
ZMET=$ZMET
ZMBAR=$ZMBAR
NBIN0=$NBIN0
KZ(8)=2
KZ(9)=3
KZ(22)=2
EOF

# 如果有第二个参数，则调用 modify_namelist.sh
if [[ $# -eq 2 ]]; then
    nb6_input="$2"
    while IFS= read -r line; do
        if [[ $line =~ ^(.+)=(.+)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            modify_namelist.sh "$nb6_input" "*" "$key" "$value" inplace
        fi
    done < <(cat <<EOF
NRAND=$NRAND
RBAR=$RBAR
RMIN=$RMIN
ZMET=$ZMET
ZMBAR=$ZMBAR
NBIN0=$NBIN0
EOF
    )
fi

echo "Note: KZ params need to be manually adjusted: "
echo "KZ(8)=2  |  KZ(9)=3  |  KZ(22)=2"