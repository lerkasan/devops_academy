#!/bin/bash
set +x
LOG_FILE="/var/log/auth.log"
OUTPUT_FILE="output.txt"
SUCCESSFUL_LOGIN_MARKER="session opened for user"
FAILED_LOGIN_MARKER="Connection closed by authenticating user|Connection closed by invalid user"
FAILED_PASSWORD_MARKER="Failed password for"
MESSAGE_REPEATED_MARKER="message repeated"
SUCCESSFUL_SUDO_MARKER="session opened for user root by"

function count_login_attempts_by_criteria {
	last_minute_ssh_logs=$(awk -v d1="$(date --date="-1 min" "+%b %_d %H:%M")" -v d2="$(date "+%b %_d %H:%M")" '$0 > d1 && $0 <= d2' "${LOG_FILE}" | grep sshd)
	last_minute_ssh_attempts_by_criteria=$(echo "${last_minute_ssh_logs}" | grep -ciE "$1")
	total_ssh_attempts_by_criteria=$(grep sshd "${LOG_FILE}" | grep -ciE "$1")
	printf 'last minute: %s\t total: %s\n' "${last_minute_ssh_attempts_by_criteria}" "${total_ssh_attempts_by_criteria}"
}

function count_login_attempts_by_user_by_criteria {
	declare -A attempts_by_user=()
	login_attempts=$(grep sshd "${LOG_FILE}" | grep -iE "$1" | cut -d' ' -f5-)
	if [[ "$1" == "${FAILED_PASSWORD_MARKER}" ]]; then
		users=$(echo "${login_attempts}" | awk '{print $5=="invalid" ? $7 : $5=="times:" ? $10 : $7=="Failed" ? $10 : $5}' | sort -u)
	else
		users=$(echo "${login_attempts}" | awk '{print $7}' | sort -u)
	fi
	for user in ${users}; do
		user_attempts_logs=$(echo "${login_attempts}" | grep -i "${user} ")
		user_message_repetitions=$(echo "${user_attempts_logs}" | grep -i "${MESSAGE_REPEATED_MARKER}" | awk '{SUM+=$4} END {print SUM-NR}')
    	attempts_by_user[$user]=$(( $(echo "${user_attempts_logs}" | wc -l) + user_message_repetitions))
	done
	for user in "${!attempts_by_user[@]}"; do
    	printf '%s - %s times\n' "${user}" "${attempts_by_user[$user]}"
	done
}

function count_failed_passwords_by_user {
	printf "Number of invalid password attempts per user:\n";
	count_login_attempts_by_user_by_criteria "${FAILED_PASSWORD_MARKER}"
	repeated_messages_failed_passwords=$(echo "${login_attempts}" | grep -i "${MESSAGE_REPEATED_MARKER}" | awk '{SUM+=$4} END {print SUM-NR}')
	total_failed_passwords=$(echo "${login_attempts}" | wc -l)
	printf 'Total number of invalid password attempts: %s\n' $((total_failed_passwords + repeated_messages_failed_passwords))
}

function count_sudo_access_by_user {
	declare -A sudos_by_user=()
	sudo_logs=$(grep sudo "${LOG_FILE}" | grep -i "${SUCCESSFUL_SUDO_MARKER}" | cut -d' ' -f5-)
	users=$(echo "${sudo_logs}" | awk '{print $9}' | cut -d'(' -f1 | sort -u)
	for user in ${users}; do
    	sudos_by_user[$user]=$(echo "${sudo_logs}" | grep -ci "${user}")
	done
	printf "Times root privileges were gained by user:\n";
	for user in "${!sudos_by_user[@]}"; do
    	printf '%s - %s times\n' "${user}" "${sudos_by_user[$user]}"
	done
}

{
	printf "\n"
	date
	printf "Number of successful SSH logins:\n"
	count_login_attempts_by_criteria "${SUCCESSFUL_LOGIN_MARKER}"
	count_login_attempts_by_user_by_criteria "${SUCCESSFUL_LOGIN_MARKER}"
} >> "${OUTPUT_FILE}"

{
	printf "Number of failed SSH logins:\n"
	count_login_attempts_by_criteria "${FAILED_LOGIN_MARKER}"
	count_login_attempts_by_user_by_criteria "${FAILED_LOGIN_MARKER}"
} >> "${OUTPUT_FILE}"

{
	count_failed_passwords_by_user
	count_sudo_access_by_user
} >> "${OUTPUT_FILE}"

