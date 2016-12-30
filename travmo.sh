#!/bin/bash
#
# TRAVMO - Travis Service Monitoring
# Copyright (C) 2016 Lukas Matt <lukas@zauberstuhl.de>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# commit results to
branch="monitoring"

starting_time=$(date +%s)
# the build should take at least 5 minutes
# otherwise we trigger the rebuild too often
min_duration=$(( 5 * 60 ))

function log {
  echo -ne "\n$@"
}

# print a very important banner
head -n 11 README.md

error=()
tests=$(find test/ -name '*.test' | sort)
tests_cnt=$(echo $tests |grep -o ' ' |wc -l)
# add one since last file has no blank
((tests_cnt+=1))

for test in $tests; do
  { # try executing test script if test
    # starts with 01-09 it will be sourced
    # adding the ability to create new
    # runtime environment variables
    basename=$(basename $test)
    if [ ${basename:0:2} -lt 10 ]; then
      output=$(source $test 2>&1)
    else
      output=$(bash $test 2>&1)
    fi
    log "[+] $test"
  } || {
    # add to error messages if execution failed
    error+=("$test: $output") && log "[-] $test"
  }
done

ending_time=$(date +%s)
diff_time=$(($ending_time - $starting_time))

if [ $diff_time -lt $min_duration ]; then
  sleep_time=$(($min_duration - $diff_time))
  log "Sleeping for $sleep_time more seconds\n" && \
    sleep $sleep_time
fi

unsuccessful=${#error[@]}
successful=$(($tests_cnt - $unsuccessful))

log "Tests: $tests_cnt Successful: $successful Failed: $unsuccessful\n"

if [[ "$unsuccessful" != "0" ]]; then
  # switch from detach mode
  git branch -D $branch || log "No master branch found!\n"
  git checkout -b $branch
  # commit results with all error messages
  git commit --allow-empty \
    -m "Tests: $tests_cnt Successful: $successful Failed: $unsuccessful

$error"
  # merge from upstream first
  git pull origin $branch
  # push to upstream
  git push origin $branch && \
    log "$(git log -1)\n"
fi
