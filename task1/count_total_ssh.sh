#!/bin/bash
set +x
LOG_FILE="/var/log/auth.log"
OUTPUT_FILE="output.txt"
SUCCESSFUL_LOGIN_MARKER="session opened for user"
FAILED_LOGIN_MARKER="Connection closed by authenticating user|Connection closed by invalid user"

function count_ssh_login_attempts_by_criteria() {
  last_minute_ssh_logs=$(awk -v d1="$(date --date="-1 min" "+%b %_d %H:%M")" -v d2="$(date "+%b %_d %H:%M")" '$0 > d1 && $0 <= d2' "${LOG_FILE}" | grep sshd)
  last_minute_ssh_attempts_by_criteria=$(echo "${last_minute_ssh_logs}" | grep -ciE "$1")
  total_ssh_attempts_by_criteria=$(grep sshd "${LOG_FILE}" | grep -ciE "$1")
  printf 'last minute: %s\t total: %s\n' "${last_minute_ssh_attempts_by_criteria}" "${total_ssh_attempts_by_criteria}"
}

function main() {
  {
    printf "\n"
    date
    printf "Number of successful SSH logins:\n"
    count_ssh_login_attempts_by_criteria "${SUCCESSFUL_LOGIN_MARKER}"
  } >>"${OUTPUT_FILE}"

  {
    printf "Number of failed SSH logins:\n"
    count_ssh_login_attempts_by_criteria "${FAILED_LOGIN_MARKER}"
  } >>"${OUTPUT_FILE}"
}

if (( "${#BASH_SOURCE[@]}" == 1 )); then
    main "$@"
fi
