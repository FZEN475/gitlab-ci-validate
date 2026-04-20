# gitlab-ci-validate

## Description

Образ для быстрого тестирования .gitlab-ci.yml  
Для проверки требуется доступ к `$CI_API_V4_URL/projects/$CI_PROJECT_ID/ci/lint`  

## ENV

| Name            | Description                         | Defaults           | Notes              |
|-----------------|-------------------------------------|--------------------|--------------------|
| SCHEME          | Схема подключения к gitlab          | https              |                    |
| CI_SERVER_HOST  | Адрес сервера                       | example.gitlab.com | .env               |
| GITLAB_TOKEN    | Токен с правами на репозиторий      |                    | .env               |
| CI_PROJECT_ID   | ID проекта                          | 0                  | .env               |
| CUSTOM_CA_FILE  | CA частного gitlab                  |                    | docker-compose.yml |
| GITLAB_CI_FILES | Файлы для тестирования через пробел | .gitlab-ci.yml     |                    |

## Использование

```yaml
services:
  gitlab-ci-validate:
    image: ghcr.io/fzen475/gitlab-ci-validate:latest
    container_name: gitlab-ci-validate-example
    env_file: ./.env
    environment:
      TRACE: false

      CI_SERVER_HOST: ${CI_SERVER_HOST}
      GITLAB_TOKEN: ${GITLAB_PASSWORD}
      CI_PROJECT_ID: ${CI_PROJECT_ID}
      CUSTOM_CA_FILE: "/run/secrets/ca.crt"

    volumes:
      - /tmp/example:/source
    secrets:
      - ca.crt

secrets:
  ca.crt:
    file: /etc/ssl/certs/ca.crt
```