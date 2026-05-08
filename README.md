<div align="center">
  <img src="public/images/github-logo.png" width="150" height="150" align="left">
  <div align="left">
    <h3>GayFur City</h3>
    <a href="https://github.com/GayFurCity/GayFurCity/releases">
      <img src="https://img.shields.io/github/v/release/GayFurCity/GayFurCity?label=version&style=flat-square" alt="Releases" />
    </a><br />
    <a href="https://github.com/GayFurCity/GayFurCity/issues">
      <img src="https://img.shields.io/github/issues/GayFurCity/GayFurCity?label=open issues&style=flat-square" alt="Issues" />
    </a><br />
    <a href="https://github.com/GayFurCity/GayFurCity/pulls">
      <img src="https://img.shields.io/github/issues-pr/GayFurCity/GayFurCity?style=flat-square" alt="Pull Requests" />
    </a><br />
    <a href="https://github.com/GayFurCity/GayFurCity/commits/master/">
      <img src="https://img.shields.io/github/check-runs/GayFurCity/GayFurCity/master?style=flat-square" alt="GitHub branch check runs" />
    </a><br />
  </div>
</div>
<br />


## Installation (Easy mode - For development environments)

### Prerequisites

 * Latest version of Docker ([download](https://docs.docker.com/get-docker)).
 * Latest version of Docker Compose ([download](https://docs.docker.com/compose/install))
 * Git ([download](https://git-scm.com/downloads))

 If you are on Windows Docker Compose is already included, you do not need to install it yourself.
 If you are on Linux/MacOS you can probably use your package manager.

### Installation

1. Download and install the [prerequisites](#prerequisites).
2. Clone the repo with `git clone https://github.com/GayFurCity/GayFurCity.git`.
3. `cd` into the repo.
4. Copy the sample environment file with `cp .env.sample .env`.
5. Run the following commands:
    ```
    docker compose run --rm --no-deps gayfurcity /app/bin/presetup
    docker compose run --rm -e SEED_POST_COUNT=100 gayfurcity /app/bin/setup
    docker compose run --rm reports npm run migrate
    docker compose up
    ```
    After running the commands once only `docker compose up` is needed to bring up the containers.
6. To confirm the installation worked, open the web browser of your choice and enter `http://localhost:4000` into the address bar and see if the website loads correctly. Create an account via http://localhost:4000/users/new. The first created user will automatically be promoted to the "Owner" level.

Note: When gems or js packages are updated you need to execute `docker compose build` to reflect them in the container.

#### <a id="docker-troubleshooting"></a>I followed the above instructions but it doesn't work, what should I do?

Try this:

1. `docker compose down -v` to remove all volumes.
2. `docker compose build --no-cache` to rebuild the image from scratch.
3. Follow the [instructions](#installation) starting from step 5.

#### <a id="windows-executable-bit"></a>Why are there a bunch of changes I can't revert?

You're most likely using Windows. Give this a shot, it tells Git to stop tracking file mode changes:

`git config core.fileMode false`

#### <a id="development-tools"></a>Things to aid you during development

`docker compose run --rm tests` to execute the test suite.

`docker compose run --rm rubocop` to run the linter.

The postgres server accepts outside connections which you can use to access it with a local client. Use `localhost:34518` to connect to a database named `gayfurcity_development` with the user `gayfurcity`. Leave the password blank, anything will work.

## Production Setup

Installation follows the same steps as the docker compose file. Ubuntu 20.04 is the current installation target.
There is no script that performs these steps for you, as you need to split them up to match your infrastructure.
Running a single machine install in production is possible, but is likely to be somewhat sluggish due to contention in disk between postgresql and elasticsearch.
Minimum RAM is 4GB. You will need to adjust values in config files to match how much RAM is available.
If you are targeting more than a hundred thousand posts and reasonable user volumes, you probably want to procure yourself a database server. See tuning guides for postgresql and elasticsearch for help planning these requirements.

### Help & Wiki Pages
These wik/help pages are expected to exist, as they are linked to or used in various places.
#### Wiki Pages
* help:contact
* help:home
* help:privacy_policy
* help:staff
* help:takedown
* help:takedown_verification
* help:terms_of_service
* internal:rules_body
* internal:flag_notice
* internal:replacement_notice
* internal:avoid_posting_notice
* internal:discord_notice
* internal:ban_notice (sub: %BAN_REASON%, %BAN_USER%)
* internal:restricted_notice
* internal:rejected_notice
* internal:user_approved (sub: %USER_ID%, %USER_NAME%)
* internal:user_rejected (sub: %USER_ID%, %USER_NAME%)
* howto:sites_and_sources
* howto:tag_genders

#### Help Pages
* accounts
* api
* artists
* avoid_posting
* blacklisting
* blocking
* cheatsheet
* commenting
* dmails
* flagging
* forums
* global_blacklist
* modqueue
* notes
* pools
* post_relationships
* posts
* privacy_policy
* replacements
* reporting
* sets
* staff
* tag_aliases
* tag_implications
* tagging_checklist
* tags
* terms_of_service
* uploading
* upload_whitelist
* uploading_guidelines
* user_name_change_requests
* wiki

### Production Troubleshooting
These instructions won't work for everyone. If your setup is not
working, here are the steps I usually recommend to people:

1) Test the database. Make sure you can connect to it using psql. Make
sure the tables exist. If this fails, you need to work on correctly
installing PostgreSQL, importing the initial schema, and running the
migrations.

2) Test the Rails database connection by using rails console. Run
Post.count to make sure Rails can connect to the database. If this
fails, you need to make sure your configuration files are
correct.

3) Test Nginx to make sure it's working correctly.  You may need to
debug your Nginx configuration file.

4) Check all log files.

### Recommender
To have recommendations, a user must have at least 50 favorites. A post must have at least 5 favorites to have recommendations.
There are some scripts in `db/seeds` to generate both users and favorites.

To train the model, simply run:
`docker compose run --rm recommender python -m poetry run python train`
