# General system aliases

# Copy, move, remove
alias cp='cp -i'
alias mv='mv -i'
alias mkdir='mkdir -p'

# Neovim
alias vi='nvim'
alias vim='nvim'
export EDITOR='nvim'


if command -v nvim &>/dev/null; then
  export EDITOR=nvim
  export VISUAL=nvim
export MANPAGER="nvim +Man!"
  alias vim='nvim'
  alias vi='nvim'
  alias svi='sudo nvim'
  alias vis='nvim "+set si"'
else
  export EDITOR=vim
  export VISUAL=vim
fi


# Directory listing
alias la='ls -Alh'
alias ls='ls -Fh --color=always'
alias ll='ls -Fls'

# For Ubuntu, fd is installed as fdfind, so alias fd to fdfind
if command -v fdfind &>/dev/null; then
  alias fd="fdfind"
fi

# Overriding df with dysk if installed
df() {
    if type dysk >/dev/null 2>&1; then
        echo "Using /usr/bin/dysk, use /bin/df to use df command"
	command dysk
    else
        command df "$@"
    fi
}

# Extracts any archive
extract() {
  for archive in "$@"; do
    if [ -f "$archive" ]; then
      case $archive in
      *.tar.bz2) tar xvjf $archive ;;
      *.tar.gz) tar xvzf $archive ;;
      *.bz2) bunzip2 $archive ;;
      *.rar) rar x $archive ;;
      *.gz) gunzip $archive ;;
      *.tar) tar xvf $archive ;;
      *.tbz2) tar xvjf $archive ;;
      *.tgz) tar xvzf $archive ;;
      *.zip) unzip $archive ;;
      *.Z) uncompress $archive ;;
      *.7z) 7z x $archive ;;
      *) echo "don't know how to extract '$archive'..." ;;
      esac
    else
      echo "'$archive' is not a valid file!"
    fi
  done
}

# Date

printf_tz() {
  local t="$1"
  read -r d day time ampm tz <<< "$(TZ="$t" date '+%Y-%m-%d %A %I:%M:%S %p %Z')"
  printf "%-10s %-9s %-8s %-2s %-3s %s\n" "$d" "$day" "$time" "$ampm" "$tz" "$t"
}

function dates () {
  printf_tz "America/Los_Angeles"
  printf_tz "America/Denver"
  printf_tz "Europe/London"
  printf_tz "Europe/Warsaw"
  printf_tz "Asia/Kolkata"
}
