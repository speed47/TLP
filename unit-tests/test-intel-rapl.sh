#!/bin/sh
# Test: Intel RAPL power limits
#
# Tested parameters:
# - INTEL_RAPL_POWER_LIMIT_PL1_ON_AC/BAT/SAV
# - INTEL_RAPL_POWER_LIMIT_PL2_ON_AC/BAT/SAV
#
# Copyright (c) 2026 Thomas Koch <linrunner at gmx.net> and others.
# SPDX-License-Identifier: GPL-2.0-or-later

# --- Constants
readonly TLP="tlp"
readonly SUDO="sudo"

readonly INTEL_RAPL_BASE="/sys/class/powercap/intel-rapl"
readonly INTEL_RAPL_PKG0="${INTEL_RAPL_BASE}/intel-rapl:0"
readonly INTEL_RAPL_PL1="${INTEL_RAPL_PKG0}/constraint_0_power_limit_uw"
readonly INTEL_RAPL_PL2="${INTEL_RAPL_PKG0}/constraint_1_power_limit_uw"

# --- Functions

check_intel_rapl_power_limits () {
    # Test intel-rapl power limit setting for all profiles
    # global param: $_testcnt, $_failcnt
    # retval: $_testcnt++, $_failcnt++

    local errcnt=0
    local prof
    local pl1_val pl2_val
    local pl1_init pl2_init
    local rc

    printf_msg "check_intel_rapl_power_limits {{{\n"

    # check if intel-rapl is available
    if [ ! -d "$INTEL_RAPL_PKG0" ]; then
        printf_msg " intel-rapl not available, skipping test\n"
        printf_msg "}}} skipped\n\n"
        return 0
    fi

    if [ ! -f "$INTEL_RAPL_PL1" ] || [ ! -f "$INTEL_RAPL_PL2" ]; then
        printf_msg " intel-rapl constraint files not available, skipping test\n"
        printf_msg "}}} skipped\n\n"
        return 0
    fi

    # save initial values
    pl1_init="$(read_sysf "$INTEL_RAPL_PL1")"
    pl2_init="$(read_sysf "$INTEL_RAPL_PL2")"
    printf_msg " initial(%s): PL1=%s PL2=%s\n" "$prof_save" "$pl1_init" "$pl2_init"

    for prof in $prof_seq; do
        printf_msg " %s:" "$prof"

        # test different power limit values for each profile
        case "$prof" in
            performance)
                pl1_val="30000000"  # 30W in microwatts
                pl2_val="40000000"  # 40W in microwatts
                ${SUDO} ${TLP} "$prof" -- TLP_AUTO_SWITCH=2 TLP_DEFAULT_MODE="" \
                    INTEL_RAPL_POWER_LIMIT_PL1_ON_AC="30" \
                    INTEL_RAPL_POWER_LIMIT_PL2_ON_AC="40" \
                    INTEL_RAPL_POWER_LIMIT_PL1_ON_BAT="" \
                    INTEL_RAPL_POWER_LIMIT_PL2_ON_BAT="" \
                    INTEL_RAPL_POWER_LIMIT_PL1_ON_SAV="" \
                    INTEL_RAPL_POWER_LIMIT_PL2_ON_SAV="" \
                    > /dev/null 2>&1
                ;;
            balanced)
                pl1_val="20000000"  # 20W in microwatts
                pl2_val="25000000"  # 25W in microwatts
                ${SUDO} ${TLP} "$prof" -- TLP_AUTO_SWITCH=2 TLP_DEFAULT_MODE="" \
                    INTEL_RAPL_POWER_LIMIT_PL1_ON_BAT="20" \
                    INTEL_RAPL_POWER_LIMIT_PL2_ON_BAT="25" \
                    INTEL_RAPL_POWER_LIMIT_PL1_ON_AC="" \
                    INTEL_RAPL_POWER_LIMIT_PL2_ON_AC="" \
                    INTEL_RAPL_POWER_LIMIT_PL1_ON_SAV="" \
                    INTEL_RAPL_POWER_LIMIT_PL2_ON_SAV="" \
                    > /dev/null 2>&1
                ;;
            power-saver)
                pl1_val="15000000"  # 15W in microwatts
                pl2_val="18000000"  # 18W in microwatts
                ${SUDO} ${TLP} "$prof" -- TLP_AUTO_SWITCH=2 TLP_DEFAULT_MODE="" \
                    INTEL_RAPL_POWER_LIMIT_PL1_ON_SAV="15" \
                    INTEL_RAPL_POWER_LIMIT_PL2_ON_SAV="18" \
                    INTEL_RAPL_POWER_LIMIT_PL1_ON_AC="" \
                    INTEL_RAPL_POWER_LIMIT_PL2_ON_AC="" \
                    INTEL_RAPL_POWER_LIMIT_PL1_ON_BAT="" \
                    INTEL_RAPL_POWER_LIMIT_PL2_ON_BAT="" \
                    > /dev/null 2>&1
                ;;
        esac

        # check PL1
        compare_sysf "$pl1_val" "$INTEL_RAPL_PL1"
        rc=$?
        if [ "$rc" -eq 0 ]; then
            printf_msg " PL1=ok"
        else
            printf_msg " PL1=err(%s)" "$rc"
            errcnt=$((errcnt + 1))
        fi

        # check PL2
        compare_sysf "$pl2_val" "$INTEL_RAPL_PL2"
        rc=$?
        if [ "$rc" -eq 0 ]; then
            printf_msg " PL2=ok"
        else
            printf_msg " PL2=err(%s)" "$rc"
            errcnt=$((errcnt + 1))
        fi

        printf_msg "\n"
    done

    # restore initial profile
    ${SUDO} ${TLP} "$prof_save" > /dev/null 2>&1

    printf_msg " result(%s): PL1=%s PL2=%s\n" "$prof_save" "$(read_sysf "$INTEL_RAPL_PL1")" "$(read_sysf "$INTEL_RAPL_PL2")"

    # print summary
    printf_msg "}}} errcnt=%s\n\n" "$errcnt"
    _testcnt=$((_testcnt + 1))
    [ "$errcnt" -gt 0 ] && _failcnt=$((_failcnt + 1))
    return $errcnt
}

check_intel_rapl_unconfigured () {
    # Test that intel-rapl doesn't change values when unconfigured
    # global param: $_testcnt, $_failcnt
    # retval: $_testcnt++, $_failcnt++

    local errcnt=0
    local pl1_before pl2_before pl1_after pl2_after

    printf_msg "check_intel_rapl_unconfigured {{{\n"

    # check if intel-rapl is available
    if [ ! -d "$INTEL_RAPL_PKG0" ]; then
        printf_msg " intel-rapl not available, skipping test\n"
        printf_msg "}}} skipped\n\n"
        return 0
    fi

    if [ ! -f "$INTEL_RAPL_PL1" ] || [ ! -f "$INTEL_RAPL_PL2" ]; then
        printf_msg " intel-rapl constraint files not available, skipping test\n"
        printf_msg "}}} skipped\n\n"
        return 0
    fi

    # get values before
    pl1_before="$(read_sysf "$INTEL_RAPL_PL1")"
    pl2_before="$(read_sysf "$INTEL_RAPL_PL2")"
    printf_msg " before(%s): PL1=%s PL2=%s\n" "$prof_save" "$pl1_before" "$pl2_before"

    # apply current profile without intel-rapl config
    ${SUDO} ${TLP} "$prof_save" -- TLP_AUTO_SWITCH=2 TLP_DEFAULT_MODE="" \
        INTEL_RAPL_POWER_LIMIT_PL1_ON_AC="" \
        INTEL_RAPL_POWER_LIMIT_PL2_ON_AC="" \
        INTEL_RAPL_POWER_LIMIT_PL1_ON_BAT="" \
        INTEL_RAPL_POWER_LIMIT_PL2_ON_BAT="" \
        INTEL_RAPL_POWER_LIMIT_PL1_ON_SAV="" \
        INTEL_RAPL_POWER_LIMIT_PL2_ON_SAV="" \
        > /dev/null 2>&1

    # get values after
    pl1_after="$(read_sysf "$INTEL_RAPL_PL1")"
    pl2_after="$(read_sysf "$INTEL_RAPL_PL2")"
    printf_msg " after(%s): PL1=%s PL2=%s\n" "$prof_save" "$pl1_after" "$pl2_after"

    # values should be unchanged
    if [ "$pl1_before" = "$pl1_after" ] && [ "$pl2_before" = "$pl2_after" ]; then
        printf_msg " result: unchanged=ok\n"
    else
        printf_msg " result: values changed unexpectedly=err\n"
        errcnt=$((errcnt + 1))
    fi

    # print summary
    printf_msg "}}} errcnt=%s\n\n" "$errcnt"
    _testcnt=$((_testcnt + 1))
    [ "$errcnt" -gt 0 ] && _failcnt=$((_failcnt + 1))
    return $errcnt
}


# --- MAIN
# source library
readonly TESTLIB="test-func"
spath="${0%/*}"
# shellcheck disable=SC1090
. "$spath/$TESTLIB" || {
    printf "Error: missing library %s\n" "$spath/$TESTLIB" 1>&2
    exit 70
}

# read args
if [ $# -eq 0 ]; then
    do_power_limits="1"
    do_unconfigured="1"
else
    while [ $# -gt 0 ]; do
        case "$1" in
            power_limits)  do_power_limits="1" ;;
            unconfigured)  do_unconfigured="1" ;;
        esac

        shift # next argument
    done # while arguments
fi

# check prerequisites and initialize
check_tlp
cache_root_cred
start_report

# shellcheck disable=SC2034
_basename="${0##*/}"
# shellcheck disable=SC2034
_logfile="$(date -Iseconds)_${_basename%.*}.log"
_testcnt=0
_failcnt=0

report_test "$_basename"

# save initial profile
read_saved_profile
# shellcheck disable=SC2154
prof_save="$(pp2str "$_prof")"

# iterate supported profiles, return to initial profile
case "$prof_save" in
    performance) prof_seq="balanced power-saver performance" ;;
    balanced)    prof_seq="power-saver performance balanced" ;;
    power-saver) prof_seq="performance balanced power-saver" ;;
esac

# initialize TLP
${SUDO} "${TLP}" start > /dev/null

[ "$do_power_limits" = "1" ] && check_intel_rapl_power_limits
[ "$do_unconfigured" = "1" ] && check_intel_rapl_unconfigured

report_result "$_testcnt" "$_failcnt"

print_report

# --- Exit
exit $_failcnt
