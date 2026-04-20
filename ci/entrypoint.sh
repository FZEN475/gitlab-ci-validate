#!/usr/bin/env ash

export CI_API_V4_URL="${SCHEME}://${CI_SERVER_HOST}/api/v4"

source /ci/tbc/tbc-gitlab-ci.sh

run_subprocess() {
    local script="$1"
    ash -c "source /tmp/current_env.sh; source $script"
}
export -p > /tmp/current_env.sh
install_ca_certs "$([[ -f "$CUSTOM_CA_FILE" ]] && cat "$CUSTOM_CA_FILE")"

log_info "---> ci_lint <---"
run_subprocess /ci/ci_lint.sh

log_info "---> tbc-check <---"
run_subprocess /ci/tbc-check.sh
