github-cli
==========
Simple console application to execute basic commands on Github API. Mainly for reading some statistics and informations.

Currently works only with repository stars.

**Depends on:** [std_data_json](https://github.com/s-ludwig/std_data_json) - future replacement of std.json in [phobos](https://github.com/dlang/phobos/) library

**Status:** Early beta - will change frequently

[![Build Status](https://travis-ci.org/tchaloupka/github-cli.svg?branch=master)](https://travis-ci.org/tchaloupka/github-cli)

# How to build
Application can be built using [dub](https://github.com/dlang/dub)

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
github-cli repository stars --count=month dlang/phobos
```

Same as above but count is not zeroed each month, so it continuously grows:
```
github-cli repository stars --count=month -s dlang/phobos
```

Get basic information from all stars in CSV format:
```
github-cli repository stars -f csv dlang/phobos
```
Get plot with stars timeseries:
```
github-cli repository stars --count=month -f csv -s dlang/dmd | gnuplot -p -e "set size ratio 0.3; set xdata time; set timefmt \"%Y/%m\"; set format x \"%Y/%m\"; set xtics nomirror rotate by -45; p '-' u 1:2 w filledcurve x1 lt 1 lw 0 t ''"
```

Get plot with stars by year:
```
github-cli repository stars --count=year -f csv dlang/dmd | gnuplot -p -e "set size ratio 0.3; set style data histogram; set style fill solid 1.0 border -1; set xtics nomirror rotate by -45; p '-' u 2:xtic(1) t ''"
```
