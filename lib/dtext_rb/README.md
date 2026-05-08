## About

Uses the [ragel state machine](https://github.com/adrian-thurston/ragel) to generate the dtext parsing capabilities of [GayFurCity](https://gayfur.city).

## Getting started

Most of the changes will only need to touch `dtext.rl`, the rest of the files will be generated for you by running either `rake compile` or `rake test`. Take a look at [this unofficial quickstart guide](https://github.com/calio/ragel-cheat-sheet) or the [complete official documentation](http://www.colm.net/files/ragel/ragel-guide-6.10.pdf) if you want to know more about how ragel works.

## Releasing a new version for use

Commit the changes to `dtext.cpp.rl` and the resuling changes in `dtext.cpp`. Bump the version number in `lib/dtext/version.rb`. After that is all done you can `bundle lock` in the GayFurCity repository. It should pick up on the increased version.

To test these changes locally commit them and update the `Gemfile`s dtext entry. Specifying the commit hash allows you to rebuild the container without having to also increment the version number every time. Don't forget to `bundle lock` before rebuilding.
`gem "dtext_rb", git: "https://github.com/YOUR_FORK/dtext_rb.git", ref: "YOUR_COMMIT_HASH"`

# Usage

```bash
ruby -Ilib -rdtext -e 'puts DText.parse("hello world")'
# => <p>hello world</p>
```

## Installation

```bash
sudo apt-get install ruby ruby-dev g++ libc-dev make patch xz-utils
bin/rake install
```

## Development

```bash
bin/rake compile
bin/rake test
```


To build in debug mode:

```bash
bin/rake clean
DTEXT_DEBUG=true bin/rake compile
```

To build with Clang:

```bash
MAKE="make --environment-overrides" CXX="/usr/bin/clang++" bin/rake
```
