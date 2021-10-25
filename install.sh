#!/bin/bash

sudo -v

GITHUB_URL="https://codeload.github.com/itsRiver/ohmyiterm2/zip/main"

chomp() {
  printf "%s" "${1/"$'\n'"/}"
}

have_sudo_access() {
  if [[ -z "${HAVE_SUDO_ACCESS-}" ]]; then
    /usr/bin/sudo -l mkdir &>/dev/null
    HAVE_SUDO_ACCESS="$?"
  fi

  if [[ -z "${HOMEBREW_ON_LINUX-}" ]] && [[ "$HAVE_SUDO_ACCESS" -ne 0 ]]; then
    abort "Need sudo access on macOS!"
  fi

  return "$HAVE_SUDO_ACCESS"
}

execute_sudo() {
  local -a args=("$@")
  if [[ -n "${SUDO_ASKPASS-}" ]]; then
    args=("-A" "${args[@]}")
  fi
  if have_sudo_access; then
    execute "/usr/bin/sudo" "${args[@]}"
  else
    execute "${args[@]}"
  fi
}

execute() {
  if ! "$@"; then
    abort "$(printf "Failed during: %s" "$(shell_join "$@")")"
  fi
}

function jsonValue() {
  KEY=$1
  num=$2
  awk -F"[,:}]" '{for(i=1;i<=NF;i++){if($i~/'$KEY'\042/){print $(i+1)}}}' | tr -d '"' | sed -n ${num}p
}

function getTagNameOfLatestRelease() {
  user_repo=$1
  echo $(curl -s -X GET https://api.github.com/repos/$user_repo/releases/latest | jsonValue tag_name 1 | grep -o "[^ ]\+\( \+[^ ]\+\)*")
}

function clearAll() {
  echo "正在清理临时文件..."
  sudo rm -rf ~/ohmyiterm2
}

echo "创建/usr/local/bin"
sudo mkdir -p /usr/local/bin

echo "(1/9) 正在下载配置文件..."
curl -# --location --request GET "$GITHUB_URL" --output "$HOME/ohmyiterm2.zip"
unzip -o -q ~/ohmyiterm2.zip -d ~/
rm -rf ~/ohmyiterm2.zip
mv ~/ohmyiterm2* ~/ohmyiterm2
cd ~/ohmyiterm2

echo "(2/9) 正在下载iTerm2..."
curl -# -O -J $(curl -s -X GET https://raw.githubusercontent.com/gnachman/iterm2-website/master/source/appcasts/final_modern.xml | grep -Eo "(https://iterm2.com/downloads/stable/iTerm2).*(.zip)")
echo "(3/9) 正在下载ohmyzsh..."
curl -# -O -J "https://codeload.github.com/ohmyzsh/ohmyzsh/zip/master"
echo "(4/9) 正在下载git-open..."
curl -# -O -J "https://codeload.github.com/paulirish/git-open/tar.gz/master"
echo "(5/9) 正在下载zsh-autosuggestions..."
curl -# -O -J "https://codeload.github.com/zsh-users/zsh-autosuggestions/tar.gz/master"
echo "(6/9) 正在下载zsh-syntax-highlighting..."
curl -# -O -J "https://codeload.github.com/zsh-users/zsh-syntax-highlighting/tar.gz/master"
echo "(7/9) 正在下载autojump..."
curl -# -O -J "https://codeload.github.com/wting/autojump/tar.gz/master"
echo "(8/9) 正在下载starship..."
starship_latest_tag=`getTagNameOfLatestRelease starship/starship`
curl -# -O -J -L "https://github.com/starship/starship/releases/download/${starship_latest_tag}/starship-x86_64-apple-darwin.tar.gz"
echo "(9/9) 正在下载JetBrains Mono Patched Font..."
jetBrains_mono_font_latest_tag=`getTagNameOfLatestRelease ryanoasis/nerd-fonts`
curl -# -O -J -L "https://github.com/ryanoasis/nerd-fonts/releases/download/${jetBrains_mono_font_latest_tag}/JetBrainsMono.zip"

echo "开始安装ohmyzsh..."
unzip -o -q ~/ohmyiterm2/ohmyzsh-master.zip
rsync -a ~/ohmyiterm2/ohmyzsh-master/ ~/.oh-my-zsh/
cat ~/.oh-my-zsh/tools/install.sh | sed -e 's/setup_ohmyzsh$//g' | sed -e 's/-d "$ZSH"/-d "NULL"/g' | bash

#安装插件
echo "正在安装ohmyzsh插件git-open..."
tar -zxf ~/ohmyiterm2/git-open-*.tar.gz -C ~/.oh-my-zsh/plugins/
echo "正在安装ohmyzsh插件zsh-autosuggestions..."
tar -zxf ~/ohmyiterm2/zsh-autosuggestions-*.tar.gz -C ~/.oh-my-zsh/plugins/
echo "正在安装ohmyzsh插件zsh-syntax-highlighting..."
tar -zxf ~/ohmyiterm2/zsh-syntax-highlighting-*.tar.gz -C ~/.oh-my-zsh/plugins/
echo "正在安装ohmyzsh插件autojump..."
tar -zxf ~/ohmyiterm2/autojump-*.tar.gz -C ~/ohmyiterm2/
cd ~/ohmyiterm2/autojump-*/ && python install.py > /dev/null
echo "[[ -s $HOME/.autojump/etc/profile.d/autojump.sh ]] && source $HOME/.autojump/etc/profile.d/autojump.sh" >> ~/.zshrc
echo "autoload -U compinit && compinit -u" >> ~/.zshrc

cd ~/.oh-my-zsh/plugins/
rm -rf git-open
rm -rf zsh-autosuggestions
rm -rf zsh-syntax-highlighting
mv git-open* git-open
mv zsh-autosuggestions* zsh-autosuggestions
mv zsh-syntax-highlighting* zsh-syntax-highlighting
echo "正在开启ohmyzsh插件..."
sed -i "" 's/^plugins.*$/plugins=(git cp git-open autojump extract zsh-syntax-highlighting zsh-autosuggestions)/g' ~/.zshrc

echo "正在安装starship..."
sudo tar -zxf ~/ohmyiterm2/starship-x86_64-apple-darwin*.tar.gz -C /usr/local/bin
echo "eval \"\$(starship init zsh)\"" >>~/.zshrc

echo "正在配置iTerm2..."
cp ~/ohmyiterm2/com.googlecode.iterm2.plist ~/Library/Preferences/com.googlecode.iterm2.plist

echo "正在安装字体..."
sudo unzip -o -q ~/ohmyiterm2/JetBrainsMono.zip -x "*Compatible.ttf" -d /Library/Fonts

echo "正在安装iTerm2..."
sudo unzip -o -q ~/ohmyiterm2/iTerm2*.zip -d /Applications

clearAll

echo "刷新环境变量..."
source ~/.zshrc >/dev/null 2>&1
