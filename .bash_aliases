type emulate >/dev/null 2>/dev/null || alias emulate=true
# sync: 
# download once with wget -O ~/.bash_aliases https://gitee.com/kaiwu-astro/linux_configs/raw/main/.bash_aliases && source ~/.bash_aliases
# if not working, add source ~/.bash_aliases to ~/.profile
# inner network machine: (ping -c 1 silk3 &> /dev/null && rsync silk3:~/.kai_config/ ~/ &> /dev/null &) 

do_upgrade_bash_aliases() {
    emulate -L ksh
    if [[ $ZSH_VERSION ]]; then
        setopt localoptions rmstarsilent
    fi
    if ping -c 1 gitee.com &> ~/.update_log; then 
        mkdir -p ~/.kai_config
        cd ~/.kai_config || { echo "Failed to change directory to ~/.kai_config" >> ~/.update_log 2>&1; return; }
        rm -rf * >> ~/.update_log 2>&1 
        wget -O ~/.kai_config/kai_config.zip https://gitee.com/kaiwu-astro/linux_configs/repository/archive/main.zip >> ~/.update_log 2>&1 
        unzip -o kai_config.zip >> ~/.update_log 2>&1 
        rsync -a linux_configs-main/ ~ >> ~/.update_log 2>&1 
        cd linux_configs-main 
        if [ -f /usr/share/bash-completion/completions/git ]; then
            cp --preserve=timestamps /usr/share/bash-completion/completions/git .git-completion.bash >> ~/.update_log 2>&1
        fi
        if [ -f /etc/bash_completion.d/git-prompt ]; then
            cp --preserve=timestamps /etc/bash_completion.d/git-prompt .git-prompt.sh >> ~/.update_log 2>&1
        fi
        cd ..
        rsync -a linux_configs-main/ ~ >> ~/.update_log 2>&1 
    fi
}

((do_upgrade_bash_aliases &> /dev/null &) &)

if [ -f ~/.bash_aliases_local ]; then
    . ~/.bash_aliases_local
fi

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias dir='dir --color=auto'
    alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
alias ll='ls -alFh'
alias la='ls -A'
# alias l='ls -CF'
alias l='ll'
alias lt='ll -tr'
alias lS='ll -Sr'

# user-defined
alias ring='tput bel'
alias grepp='grep -P'
alias dff=$'df -BG | grepp -v "snap|run|sys|udev|tmpfs|efi" | awk \'{print $6,"\t",$4,"\t/",$2}\''
alias ddu='dutree -d1'
alias lss='ls -alh'
alias lls='lss'
alias cp='cp --preserve=timestamps'
alias cdo='cd $OLDPWD'
alias tail1='tail -n 1'
alias sl='ls'
mymem() {
    emulate -L ksh
    
    # 默认刷新间隔为2秒
    local interval=2
    local live=false
    
    # 手动解析参数，避免getopts的限制
    if [[ "$1" == "-l" ]]; then
        live=true
        # 检查是否有第二个参数，并且是数字
        if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
            interval=$2
        fi
    elif [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "用法: mymem [-l [X]]，其中X是刷新间隔(默认为2秒)"
        return 0
    fi
    
    # 如果启用了实时更新，则使用watch命令
    if $live; then
        watch -n $interval "ps -u $USER -o rss= | awk '{sum+=\$1} END {printf \"%.2f GB\\n\", sum/1024/1024}'"
    else
        ps -u $USER -o rss= | awk '{sum+=$1} END {printf "%.2f GB\n", sum/1024/1024}'
    fi
}
cdd() {
    local dir="$1"
    local dir="${dir:=$HOME}"
    if [[ -d "$dir" ]]; then
            cd "$dir" >/dev/null; ls --color=auto
    else
            echo "bash: cdls: $dir: Directory not found"
    fi
}

pyclean () {
    find . -type f -name '*.py[co]' -delete -o -type d -name __pycache__ -delete
}

duu() {
    emulate -L ksh
    if [ $# == 0 ]; then
        du . -h --max-depth=0 | sort -h
    else
        du . -h --max-depth=$1 | sort -h
    fi
}

tmuxa() {
    emulate -L ksh
    if [ $# == 0 ]; then
        tmux a
    else
        tmux attach-session -t $1
    fi
}
alias tmuxaa='tmux attach-session -t'
alias tmuxn='tmux new-session -s'
alias tmuxls='tmux ls'

compress() {
    emulate -L ksh
    if [ $# == 0 ] || [ $# -gt 3 ]; then
        echo "Usage: compress src dst nthread (dst defaults to src.tgz ; nthread defaults to max)"
    fi
    src="$1"
    dst="$src".tgz
    # nthread = number of total CPU threads
    if [ -e /proc/cpuinfo ]; then
        nthread=$(grep -c ^processor /proc/cpuinfo)
    elif command -v systemctl >/dev/null 2>&1; then
        nthread=$(sysctl -n hw.physicalcpu)
    else
        nthread=1
    fi
    if [ $# -gt 1 ]; then dst="$2"; fi
    if [ $# == 3 ]; then nthread="$3"; fi

    if [[ "$(uname -s)" == Darwin ]]; then
        du='gdu'
    fi

    if command -v pv >/dev/null 2>&1; then 
        tar c $src | pv -s $(du -sb $src | awk '{print $1}') | pigz -6 -p $nthread > $dst
    else 
        tar c $src --totals --checkpoint-action=echo="#%u: %T %t" --checkpoint=100000 | pigz -6 -p $nthread > $dst
    fi
}


extracttgz() {
    emulate -L ksh
    pigz -dc "$1" | tar xf -
}

# sgpt() {
#     emulate -L ksh
#     sgpt '"'"$*"'"'
# }

ss() {
    emulate -L ksh
    sgpt -s '"'"$*"'"'
}
path() {
    emulate -L ksh
    [ -e "$1" ] && readlink -f "$1"
}
waitpid(){
    for pid in "$@" 
    do
    	while [ -e /proc/$pid ]; do sleep 1; done
    done
}
hold() {
    emulate -L ksh
    t=0
    should_exit=false

    trap ctrl_c INT
    function ctrl_c() {
        echo ""
        should_exit=true
    }

    while true; do
        if $should_exit; then
            break
        fi
        printf "holding session...%.1f min" "$t"
        sleep 0.6
        printf "\r"
        t=$(echo "$t + 0.01" | bc)
    done
}

make_ffmpeg_list() {
    # example:
    #     many files with name like 
    #       dragon3_1m_5hb_ttot_33.375_mass.jpg 
    #       dragon3_1m_5hb_ttot_6.0_mass.jpg 
    #     number is the 5th field, then do
    #     ls *.jpg | make_ffmpeg_list -k 5 > list.txt
    # output: 
    #     stdout
    local key=2 # default value for -k
    while getopts k: flag
    do
        case "${flag}" in
            k) key=${OPTARG};;
        esac
    done
    shift $((OPTIND -1))

    sort -t_ -k${key} -n | sed "s/^/file '/" | sed "s/$/'/"
}
make_video() {
    emulate -L ksh
    if [ "$#" -eq 1 ] && [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        echo "Usage: make_video <output_filename=output.mp4> <bitrate=750k> <codec=h265>"
        return 0
    fi
    local output_filename="output.mp4"
    if [ "$#" -ge 1 ]; then
        local output_filename="$1"
    fi
    local bitrate="750k"
    if [ "$#" -ge 2 ]; then
        local bitrate="$2"
    fi
    local codec='h265'
    if [ "$#" -ge 3 ]; then
        local codec="$3"
    fi

    # 检查编码格式是否为h264或h265
    if [ "$codec" != "h264" ] && [ "$codec" != "h265" ]; then
        echo "Invalid codec. Use 'h264' or 'h265'."
        return 1
    fi

    # 根据编码格式设置FFmpeg视频编码器和视频标签
    local encoder
    local vtag
    if [ "$codec" == "h264" ]; then
        encoder="h264_nvenc"
        vtag="avc1"
    else
        encoder="hevc_nvenc"
        vtag="hvc1"
    fi

    ffmpeg -hwaccel cuda -hwaccel_output_format cuda -r 30 -f concat -safe 0 -i list.txt -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" -b:v "$bitrate" -c:v "$encoder" -an -pix_fmt yuv420p -vtag "$vtag" -preset fast -movflags +faststart "$output_filename"
}
count_latex(){
    emulate -L ksh
    if [ $# == 0 ]; then
        date >> texcount.log && texcount `find . -name '*.tex' ` | sed -n '/Total/,$p' | tee -a texcount.log | head
    else
        texcount `find . -name '*.tex' ` | sed -n '/Total/,$p' | less
    fi
}
shanxian() {
    if [ "$#" -ne 2 ]; then
        echo "Usage: shanxian <source> <target>"
        return 1
    fi
    local source="$1"
    local target="$2"
    mv "$source" "$target"
    ln -s "$target" "$source"
    ls -lh "$source" "$target"
}

##############
if [[ $ZSH_VERSION ]]; then
    bindkey \^U backward-kill-line
fi

# 共享的bashrc内容
if [[ $BASH_VERSION ]]; then
    stty -ixon # disable ctrl-s, ctrl-q, 这样ctrl+R可以用ctrl+S正向搜索
    ulimit -s unlimited
    export HISTSIZE=5000
    export HISTFILESIZE=5000
    export SAVEHIST=5000
    shopt -s histappend

    [ -d $HOME/.bookmarks ] || mkdir $HOME/.bookmarks
    if [ -d "$HOME/.bookmarks" ]; then
        ## Usage:        bookmark @xxx : save current dir as @xxx
        ##         go @xxx | goto @xxx : cd to the dir @xxx. 
        ##        Can use tab completation goto @[tab]
        export CDPATH=".:$HOME/.bookmarks"
        alias goto="cd -P"
        complete -F _cd goto
        function bookmark {
            ln -s "$(pwd)" "$HOME/.bookmarks/$1"
        }
    fi

    color_number=$(( 0x$(cat /etc/machine-id | cut -c 1-2) % 6 + 31))
    PS1='[\A]${debian_chroot:+($debian_chroot)}\[\033[01;${color_number}m\]\u@\h\[\033[00m\]:\[\033[01;${color_number}m\]\w\[\033[00m\]\$ '

    function multi_shell_share_history {

    if [[ -z "${PROMPT_COMMAND:+x}" ]]; then
        PROMPT_COMMAND="history -a; history -r"
    else
        PROMPT_COMMAND="${PROMPT_COMMAND//$'\n'/;}" # convert all new lines to semi-colons
        PROMPT_COMMAND="${PROMPT_COMMAND#\;}" # remove leading semi-colon
        PROMPT_COMMAND="${PROMPT_COMMAND%% }" # remove trailing spaces
        PROMPT_COMMAND="${PROMPT_COMMAND%\;}" # remove trailing semi-colon

        local new_entry="history -a; history -r"
        case ";${PROMPT_COMMAND};" in
        *";${new_entry};"*)
            # echo "PROMPT_COMMAND already contains: $new_entry"
            :;;
        *)
            PROMPT_COMMAND="${PROMPT_COMMAND};${new_entry}"
            # echo "PROMPT_COMMAND does not contain: $new_entry"
            ;;
        esac
    fi

    }
    multi_shell_share_history
    [ -f ~/.git-prompt.sh ] && source ~/.git-prompt.sh
    [ -f ~/.git-completion.bash ] && source ~/.git-completion.bash
    if [[ $(type __git_ps1 &> /dev/null) ]]; then 
        PROMPT_COMMAND='__git_ps1 ;'$PROMPT_COMMAND
        export GIT_PS1_SHOWDIRTYSTATE=1
        export GIT_PS1_SHOWSTASHSTATE=1
        export GIT_PS1_SHOWUNTRACKEDFILES=1
        export GIT_PS1_SHOWUPSTREAM="auto"
        export GIT_PS1_SHOWCOLORHINTS=1
        export GIT_PS1_SHOWCONFLICTSTATE=yes
    fi
    uptime | awk '/day/ { if ($3 < 10) print "系统上一次重启在 " $3 " 天前" }'
fi

export PATH="$HOME/.bin:$HOME/bin:$HOME/user-software/bin:$PATH"

##############

alias wdiff='git diff -U0 --word-diff --no-index --'
alias lastjob='squeue -u $USER -o "%i" | sort | tail -n 2 | head -n 1'
alias jobhere='ls N*.[0-9]*.out 2>/dev/null | sed -E "s/.*\.([0-9]+)\.out/\1/" | sort -n'
lastjobhere() {
    emulate -L ksh
    local n=1
    if [[ "$1" == "-n" && "$2" =~ ^[0-9]+$ ]]; then
        n=$2
    fi
    jobhere | tac | sed -n "${n}p"
}
firstjobhere() {
    emulate -L ksh
    local n=1
    if [[ "$1" == "-n" && "$2" =~ ^[0-9]+$ ]]; then
        n=$2
    fi
    jobhere | sed -n "${n}p"
}
alias lastj='lastjobhere'
alias firstj='firstjobhere'
alias ipy='ipython3'
alias ipython='ipython3'
alias rsync='rsync -a -h --info=progress2'
alias git-reignore="git rm -rf --cached . && git add ."
alias viba='vi ~/.bashrc'
alias vibashrc='vi ~/.bashrc'
alias viali='vi ~/.bash_aliases'
alias petarclean='rm data* dump* check* input* *.log log.* hard* spec_* bev.* sev.* *.lst *.mp4 fort.* *.npy stellar_*; for dir in {0..14}; do rm -rf $dir; done'
alias petarwc='wc -l data.* | sort -t . -k 2n | less'
alias ':q'=exit
alias petarls="ls | egrep '^data.[0-9]+$' | sort -n -k 1.6"
alias galevclean='rm spec_out*; rm stellar_magnitude*; rm log_GalevNB*; rm fort.13'
alias git_update='git fetch --all && git reset --hard origin/dev '
alias cls='clear'
alias nb6cp="rsync -a --exclude-from=$HOME/.nb6cleanlist"
alias nb6clean='rm -f $(tr "\n" " " < "$HOME/.nb6cleanlist")'
alias lastedit='echo "上一次输出在$(( $(date +%s) - $(stat -c %Y "$(ls -t | head -n1)") ))秒前"'
alias cpuusage='top -bn2 | grep "Cpu(s)" | tail -n1 | awk "{print 100 - \$8}"'
alias get_yazi='temp_dir=$(mktemp -d) && cd "$temp_dir" && wget https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-musl.zip && unzip yazi-x86_64-unknown-linux-musl.zip && mkdir -p ~/user-software/bin && cp -pr yazi-x86_64-unknown-linux-musl/ya* yazi-x86_64-unknown-linux-musl/completions ~/user-software/bin/ && cd - > /dev/null && rm -rf "$temp_dir"'
get_zoxide() {
    temp_dir=$(mktemp -d) && cd "$temp_dir" && \
    wget https://github.com/ajeetdsouza/zoxide/releases/download/v0.9.7/zoxide-0.9.7-x86_64-unknown-linux-musl.tar.gz && \
    tar -xvf zoxide-0.9.7-x86_64-unknown-linux-musl.tar.gz && \
    mkdir -p ~/user-software/bin && \
    cp -p zoxide ~/user-software/bin/ && \
    cd - > /dev/null && rm -rf "$temp_dir" && \
    shellname=`basename "$(readlink /proc/$$/exe)"` && \
    _cmd='eval "$(zoxide init --cmd cd '"$shellname"')"'
    echo $_cmd >> ~/.${shellname}rc
}
get_fzf() {
    temp_dir=$(mktemp -d) && cd "$temp_dir" && \
    wget https://github.com/junegunn/fzf/releases/download/v0.62.0/fzf-0.62.0-linux_amd64.tar.gz && \
    tar -xvf fzf-0.62.0-linux_amd64.tar.gz && \
    mkdir -p ~/user-software/bin && \
    cp -p fzf ~/user-software/bin/ && \
    cd - > /dev/null && rm -rf "$temp_dir" && \
    shellname=`basename "$(readlink /proc/$$/exe)"` && \
    _cmd='source <(fzf --'"$shellname"')'
    echo $_cmd >> ~/.${shellname}rc
}
get_pv() {
    _oldpwd=$(pwd)
    temp_dir=$(mktemp -d) && cd "$temp_dir" && \
    curl -O https://ivarch.com/s/pv-1.9.31.tar.gz && \
    tar xzf pv-1.9.31.tar.gz && \
    cd pv-1.9.31 && \
    mkdir -p $HOME/user-software && \
    sh ./configure --prefix=$HOME/user-software && \
    make -j 4 && make install && \
    cd $_oldpwd > /dev/null && rm -rf "$temp_dir"
}
alias cdabs='cd $(readlink -f .)'
get_btop() {
    if nvidia-smi &> /dev/null; then
        echo "Detected nvidia-smi, using btop with GPU support"
    else
        echo "No nvidia-smi detected, press enter to continue or Ctrl+C to cancel"
        read -r
        echo "Installing btop without GPU support"
    fi
    temp_dir=$(mktemp -d) && cd "$temp_dir" && \
    wget https://github.com/aristocratos/btop/releases/latest/download/btop-x86_64-linux-musl.tbz && \
    tar -xvf btop-x86_64-linux-musl.tbz && \
    cd btop && \
    mkdir -p ~/user-software && \
    make install PREFIX=$HOME/user-software && \
    cd ~ > /dev/null && rm -rf "$temp_dir"
}