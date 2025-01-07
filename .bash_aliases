type emulate >/dev/null 2>/dev/null || alias emulate=true
# sync: 
# download once with wget -O ~/.bash_aliases https://gitee.com/kaiwu-astro/garage/raw/main/linux_config/.bash_aliases
# if not working, add source ~/.bash_aliases to ~/.profile
# inner network machine: (ping -c 1 silk3 &> /dev/null && rsync silk3:~/.kai_config/ ~/ &> /dev/null &) 

([ "$(hostname)" != "kstation" ] && ping -c 1 gitee.com &> /dev/null && for configf in ".bash_aliases" ".vimrc" ".tmux.conf" ".config/htop/htoprc"; do mkdir -p `dirname ~/.kai_config/$configf`; mkdir -p `dirname ~/$configf`; wget -O ~/.kai_config/$configf https://gitee.com/kaiwu-astro/garage/raw/main/linux_config/$configf &> /dev/null; cp -p ~/.kai_config/$configf ~/$configf; done &)

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
alias cp='cp -p'
alias cdo='cd $OLDPWD'
alias tail1='tail -n 1'
alias sl='ls'

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
    nthread=$(grep -c ^processor /proc/cpuinfo)
    if [ $# == 2 ]; then dst="$2"; fi
    if [ $# == 3 ]; then nthread="$3"; fi

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

# alias make_ffmpeg_list="ls -1 *.jpg | sort -t_ -k2 -n | sed \"s/^/file '/\" | sed \"s/$/'/\" > list.txt"
make_ffmpeg_list() {
    local key=2
    while getopts k: flag
    do
        case "${flag}" in
            k) key=${OPTARG};;
        esac
    done
    shift $((OPTIND -1))

    sort -t_ -k${key} -n | sed "s/^/file '/" | sed "s/$/'/" > list.txt
}
make_video() {
    emulate -L ksh
    # if [ "$#" -eq 0 ]; then
    # if -h or --help is passed as an argument, print usage and return
    if [ "$#" -eq 1 ] && [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        echo "Usage: make_video <output_filename> <bitrate> <codec: h264|h265>"
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

    ffmpeg -hwaccel cuda -r 30 -f concat -safe 0 -i list.txt -b:v "$bitrate" -c:v "$encoder" -an -pix_fmt yuv420p -vtag "$vtag" -preset fast -movflags +faststart "$output_filename"
}
count_latex(){
    emulate -L ksh
    if [ $# == 0 ]; then
        date >> texcount.log && texcount `find . -name '*.tex' ` | sed -n '/Total/,$p' | tee -a texcount.log | head
    else
        texcount `find . -name '*.tex' ` | sed -n '/Total/,$p' | less
    fi
}

##############
# bashrc内容
ulimit -c 0
ulimit -s unlimited
export HISTSIZE=5000
export HISTFILESIZE=5000
export SAVEHIST=5000
shopt -s histappend

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
[[ "$BASH_VERSION" ]] && multi_shell_share_history

export PATH="$HOME/bin:$HOME/user-software/bin:$PATH"

##############


alias ipy='ipython3'
alias ipython='ipython3'
alias python='python3'
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
alias nb6clean='rm -f bdat.8 roche.85 highv.29 sediag.38 comm.* hbin.39 conf.3* sev.83* bev.82* bwdat.19* bdat.9* event.35 global.30 lagr.7 binary.40* single.40* binary.40* single.40* comm.2* conf.3* sev.83* bev.82* bwdat.19* bdat.9* binary.40* single.40* comm.2* conf.3* sev.83* bev.82* bwdat.19* bdat.9* binary.40* single.40* comm.2* conf.3* sev.83* bev.82* bwdat.19* bdat.9* merger.40* histab.73 binary.40* single.40* comm.2* conf.3* sev.83* bev.82* bwdat.19* bdat.9* binary.40* single.40* comm.2* conf.3* sev.83* bev.82* bwdat.19* bdat.9* binary.40* single.40* comm.2* conf.3* sev.83* bev.82* bwdat.19* bdat.9* binary.40* single.40* comm.2* conf.3* sev.83* bev.82* bwdat.19* bdat.9* binary.40* single.40* comm.2* conf.3* sev.83* bev.82* bwdat.19* bdat.9* binary.40* single.40* comm.2* conf.3* sev.83* bev.82* bwdat.19* bdat.9* binary.40* single.40* coal.24 binev.17 cmbody.26 comm.2* conf.3* sev.83* bev.82* bwdat.19* bdat.9* cirdiag.96 wdcirc.95 bs.91 dtmin.88 cmbody.86 merger.84 chstab.81 cirdiag.71 rpmax.55 close.54 hinc.44 sediag.43 nbflow.41 status.36 bh.34 ns.33 escbin.31 sediag.25 rocdeg.22 symb.20 pbin.18 hirect.16 mix.15 shrink.14 coll.13 esc.11 degen.4 *.out *.log *.err 1* *h5part snap*'

