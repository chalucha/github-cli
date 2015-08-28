github-cli
==========
Simple console application to execute basic commands on Github API.

Currently works only with repository stars.

**Depends on:** [std_data_json](https://github.com/s-ludwig/std_data_json) - future replacement of std.json in phobos

**Status:** Early beta - will change frequently

[![Build Status](https://travis-ci.org/chalucha/github-cli.svg?branch=master)](https://travis-ci.org/chalucha/github-cli)

# How to build
Application can be build using [dub](https://github.com/D-Programming-Language/dub)

Use: ```dub build```

# Usage

Basic usage is:
```github-cli comman_group [subcommand] [command_options] [params]```

# Authentication
Basic authentication scheme can be used.
All commands can be provided with common options:
- **-u** = user name
- **-p** = user password

Without it, it will work too but GitHub API has limited request rate (60 requests per hour).

# Examples

Get stars count for each month:
```
github-cli repository stars --count=month D-Programming-Language/phobos
```

Same as above but count is not zeroed each month, so it continuously grows:
```
github-cli repository stars --count=month -s D-Programming-Language/phobos
```

Get basic information from all stars in CSV format:
```
github-cli repository stars --csv D-Programming-Language/phobos
```
