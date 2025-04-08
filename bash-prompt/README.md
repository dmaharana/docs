## Add below text in bash profile
`
PROMPT_COMMAND='update_prompt'
update_prompt() {
  if [ -d ".git" ]; then
    PS1="\[\033[1;32m\]\u@\h:\[\033[1;34m\]\w\[\033[0m\] \[\033[1;33m\][$(git rev-parse --abbrev-ref HEAD)]\[\033[0m\] \[\033[1;37m\]$(date +"%Y-%m-%d %H:%M:%S")\[\033[0m\] \n\$ "
  else
    PS1="\[\033[1;32m\]\u@\h:\[\033[1;34m\]\w\[\033[0m\] \[\033[1;37m\]$(date +"%Y-%m-%d %H:%M:%S")\[\033[0m\] \n\$ "
  fi
}
`
