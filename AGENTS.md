# AGENTS.md

- Use yarn as the package manager
- Only install packages outside of the container, rebuild the container after modifying packages
- Rebuild the container with `docker compose build gayfurcity`
- Use the `tests` docker compose service to run tests, `docker compose run --rm tests`
- To run a specific test, directly append the path, `docker compose run --rm tests <path>`
- After any ruby code changes, run `docker compose run --rm rubocop -a`
- After any javascript code changes, run `docker compose run --rm linter --fix`
