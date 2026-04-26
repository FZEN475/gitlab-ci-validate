  # BEGSCRIPT
  set -eo pipefail

  function log_info() {
    echo -e "[\e[1;94mINFO\e[0m] $*"
  }

  function log_warn() {
    echo -e "[\\e[1;93mWARN\\e[0m] $*"
  }

  function log_error() {
    echo -e "[\e[1;91mERROR\e[0m] $*" >&2
  }

  function fail() {
    log_error "$*"
    exit 1
  }

  function as_content() {
    file_or_content=$1
    if [[ -f "${file_or_content}" ]]; then
      cat "${file_or_content}"
    else
      echo "${file_or_content}"
    fi
  }

  function install_ca_certs() {
    certs=$1
    if [[ -z "$certs" ]]
    then
      return
    fi

    # import in system
    if as_content "$certs" >> /etc/ssl/certs/ca-certificates.crt
    then
      log_info "CA certificates imported in \\e[33;1m/etc/ssl/certs/ca-certificates.crt\\e[0m"
    fi
    if as_content "$certs" >> /etc/ssl/cert.pem
    then
      log_info "CA certificates imported in \\e[33;1m/etc/ssl/cert.pem\\e[0m"
    fi
  }

  function unscope_variables() {
    _scoped_vars=$(env | awk -F '=' "/^scoped__[a-zA-Z0-9_]+=/ {print \$1}" | sort)
    if [[ -z "$_scoped_vars" ]]; then return; fi
    log_info "Processing scoped variables..."
    for _scoped_var in $_scoped_vars
    do
      _fields=${_scoped_var//__/:}
      _condition=$(echo "$_fields" | cut -d: -f3)
      case "$_condition" in
      if) _not="";;
      ifnot) _not=1;;
      *)
        log_warn "... unrecognized condition \\e[1;91m$_condition\\e[0m in \\e[33;1m${_scoped_var}\\e[0m"
        continue
      ;;
      esac
      _target_var=$(echo "$_fields" | cut -d: -f2)
      _cond_var=$(echo "$_fields" | cut -d: -f4)
      _cond_val=$(eval echo "\$${_cond_var}")
      _test_op=$(echo "$_fields" | cut -d: -f5)
      case "$_test_op" in
      defined)
        if [[ -z "$_not" ]] && [[ -z "$_cond_val" ]]; then continue;
        elif [[ "$_not" ]] && [[ "$_cond_val" ]]; then continue;
        fi
        ;;
      equals|startswith|endswith|contains|in|equals_ic|startswith_ic|endswith_ic|contains_ic|in_ic)
        # comparison operator
        # sluggify actual value
        _cond_val=$(echo "$_cond_val" | tr '[:punct:]' '_')
        # retrieve comparison value
        _cmp_val_prefix="scoped__${_target_var}__${_condition}__${_cond_var}__${_test_op}__"
        _cmp_val=${_scoped_var#"$_cmp_val_prefix"}
        # manage 'ignore case'
        if [[ "$_test_op" =~ _ic$ ]]
        then
          # lowercase everything
          _cond_val=$(echo "$_cond_val" | tr '[:upper:]' '[:lower:]')
          _cmp_val=$(echo "$_cmp_val" | tr '[:upper:]' '[:lower:]')
        fi
        case "$_test_op" in
        equals*)
          if [[ -z "$_not" ]] && [[ "$_cond_val" != "$_cmp_val" ]]; then continue;
          elif [[ "$_not" ]] && [[ "$_cond_val" == "$_cmp_val" ]]; then continue;
          fi
          ;;
        startswith*)
          if [[ -z "$_not" ]] && [[ ! "$_cond_val" =~ ^"$_cmp_val" ]]; then continue;
          elif [[ "$_not" ]] && [[ "$_cond_val" =~ ^"$_cmp_val" ]]; then continue;
          fi
          ;;
        endswith*)
          if [[ -z "$_not" ]] && [[ ! "$_cond_val" =~ "$_cmp_val"$ ]]; then continue;
          elif [[ "$_not" ]] && [[ "$_cond_val" =~ "$_cmp_val"$ ]]; then continue;
          fi
          ;;
        contains*)
          # shellcheck disable=SC2076
          if [[ -z "$_not" ]] && [[ ! "$_cond_val" =~ "$_cmp_val" ]]; then continue;
          elif [[ "$_not" ]] && [[ "$_cond_val" =~ "$_cmp_val" ]]; then continue;
          fi
          ;;
        in*)
          if [[ -z "$_not" ]] && [[ ! __"$_cmp_val"__ =~ __"$_cond_val"__ ]]; then continue;
          elif [[ "$_not" ]] && [[ __"$_cmp_val"__ =~ __"$_cond_val"__ ]]; then continue;
          fi
          ;;
        esac
        ;;
      *)
        log_warn "... unrecognized test operator \\e[1;91m${_test_op}\\e[0m in \\e[33;1m${_scoped_var}\\e[0m"
        continue
        ;;
      esac
      # matches
      _val=$(eval echo "\$${_target_var}")
      log_info "... apply \\e[32m${_target_var}\\e[0m from \\e[32m\$${_scoped_var}\\e[0m"
      _val=$(eval echo "\$${_scoped_var}")
      export "${_target_var}"="${_val}"
    done
    log_info "... done"
  }

  # evaluate and export a secret
  # - $1: secret variable name
  function eval_secret() {
    name=$1
    value=$(eval echo "\$${name}")
    case "$value" in
    @b64@*)
      decoded=$(mktemp)
      errors=$(mktemp)
      if echo "$value" | cut -c6- | base64 -d > "${decoded}" 2> "${errors}"
      then
        # shellcheck disable=SC2086
        export ${name}="$(cat ${decoded})"
        log_info "Successfully decoded base64 secret \\e[33;1m${name}\\e[0m"
      else
        fail "Failed decoding base64 secret \\e[33;1m${name}\\e[0m:\\n$(sed 's/^/... /g' "${errors}")"
      fi
      ;;
    @hex@*)
      decoded=$(mktemp)
      errors=$(mktemp)
      if echo "$value" | cut -c6- | sed 's/\([0-9A-F]\{2\}\)/\\\\x\1/gI' | xargs printf > "${decoded}" 2> "${errors}"
      then
        # shellcheck disable=SC2086
        export ${name}="$(cat ${decoded})"
        log_info "Successfully decoded hexadecimal secret \\e[33;1m${name}\\e[0m"
      else
        fail "Failed decoding hexadecimal secret \\e[33;1m${name}\\e[0m:\\n$(sed 's/^/... /g' "${errors}")"
      fi
      ;;
    @url@*)
      url=$(echo "$value" | cut -c6-)
      if command -v curl > /dev/null
      then
        decoded=$(mktemp)
        errors=$(mktemp)
        if curl -s -S -f --connect-timeout "${TBC_SECRET_URL_TIMEOUT:-5}" -o "${decoded}" "$url" 2> "${errors}"
        then
          # shellcheck disable=SC2086
          export ${name}="$(cat ${decoded})"
          log_info "Successfully curl'd secret \\e[33;1m${name}\\e[0m"
        else
          log_warn "Failed getting secret \\e[33;1m${name}\\e[0m:\\n$(sed 's/^/... /g' "${errors}")"
        fi
      elif command -v wget > /dev/null
      then
        decoded=$(mktemp)
        errors=$(mktemp)
        if wget -T "${TBC_SECRET_URL_TIMEOUT:-5}" -O "${decoded}" "$url" 2> "${errors}"
        then
          # shellcheck disable=SC2086
          export ${name}="$(cat ${decoded})"
          log_info "Successfully wget'd secret \\e[33;1m${name}\\e[0m"
        else
          log_warn "Failed getting secret \\e[33;1m${name}\\e[0m:\\n$(sed 's/^/... /g' "${errors}")"
        fi
      else
        log_warn "Couldn't get secret \\e[33;1m${name}\\e[0m: no http client found"
      fi
      ;;
    esac
  }

  function eval_all_secrets() {
    encoded_vars=$(env | grep -Ev '(^|.*_ENV_)scoped__' | awk -F '=' '/^[a-zA-Z0-9_]*=@(b64|hex|url)@/ {print $1}')
    for var in $encoded_vars
    do
      eval_secret "$var"
    done
  }

  # validates an input GitLab CI YAML file
  function ci_lint() {
    rc=0
    for file in $(eval "ls -1 $GITLAB_CI_FILES")
    do
      log_info "Validating: $file..."
      cilint_req="{\"content\": $(jq --raw-input --slurp '.'  < "${file:-/dev/stdin}")}"
      cilint_resp=$(curl -s --header "Content-Type: application/json" --header "PRIVATE-TOKEN: ${GITLAB_TOKEN:-$GITLAB_CI_LINT_TOKEN}" $CI_API_V4_URL/projects/$CI_PROJECT_ID/ci/lint --data "$cilint_req")

      echo "=== RAW RESPONSE ==="
      echo "$cilint_resp" | jq . | tee reports/gitlab-ci-validate.json

      echo "=== MERGED YAML ==="
      jq -r '.merged_yaml' reports/gitlab-ci-validate.json \
        | yq eval -P - | tee reports/merged.yaml

      if [ "$(echo "$cilint_resp" | jq -r '.valid')" == "true" ]
      then
        log_info " ... valid"
      else
        log_error " ... invalid"
        rc=1
      fi
    done
    exit $rc
  }

  unscope_variables
  eval_all_secrets


  # ENDSCRIPT

