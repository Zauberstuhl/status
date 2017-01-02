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

# working branch
branch="monitoring"
# https://docs.travis-ci.com/user/customizing-the-build#Build-Timeouts
max_duration=$((45 * 60))
# wait between test restarts
restart_tests=$((2 * 60))

function log {
  echo -ne "\n$@"
}

# print a very important banner
head -n 11 README.md

error=()
unsuccessful=0
successful=0
first_run=true
tests=$(find test/ -name '*.test' | sort)
tests_cnt=$(echo $tests |grep -o ' ' |wc -l)
# add one since last file has no blank
((tests_cnt+=1))

starting_time=$(date +%s)
ending_time=$(($starting_time + $max_duration))
log "Found $tests_cnt tests (+ succeeded, - failed, x skipped)"

# switch from detach mode
git checkout -b $branch > /dev/null 2>&1

while [[ $(date +%s) -lt $ending_time ]];
do
  test_nr=1
  for test in $tests; do
    { # try executing test script if test
      # starts with 01-09 it will be sourced
      # adding the ability to create new
      # runtime environment variables
      basename=$(basename $test)
      if [ ${basename:0:2} -lt 10 ]; then
        if $first_run; then
          . $test > /dev/null 2>&1 && log "[+] $test"
        else
          log "[x] $test"
        fi
      else
        output=$(bash $test 2>&1) && {
          log "[+] $test"
          if [[ "${error[$test_nr]}" -ne "" ]]; then
            send_info "$test" "$output"
            error[$test_nr]="" # remove element
          fi
        } || false
      fi
    } || {
      # add to error messages if execution failed
      log "[-] $test"
      if [[ "${error[$test_nr]}" -eq "" ]]; then
        send_crit "$test" "$output"
      fi
      error[$test_nr]="1"
    }
    ((test_nr+=1))
  done
  # setup scripts from 01-09
  # should run only once
  first_run=false

  unsuccessful=$(($unsuccessful + ${#error[@]}))
  successful=$(($successful + ($tests_cnt - $unsuccessful)))
  log "[ ] Successful: $successful Failed: $unsuccessful ($(date))\n"
  # commit results for status page
  git commit --allow-empty \
    -m "Tests: $tests_cnt Successful: $successful Failed: $unsuccessful

  ${error[@]}
  "
  # merge and push to upstream
  git pull origin $branch && git push origin $branch || {
    message="wasn't able to push results to upstream"
    log "[-] $message" && send_warn "Upstream push failed" "$message"
  }
  sleep $restart_tests
done

# start a rebuild again
curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -H "Travis-API-Version: 3" \
  -H "Authorization: token $travistoken" \
  -d "{\"request\": {\"branch\":\"${TRAVIS_BRANCH}\"}}" \
  https://api.travis-ci.org/repo/${TRAVIS_REPO_SLUG}/requests
