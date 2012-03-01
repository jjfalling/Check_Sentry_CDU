#!/usr/bin/env perl -w
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

#/******************************************************************************
# *
# * CHECK_SENTRY_CDU (3 phase, 2 tower models)
# *
# * Developed on the following models: Sentry cw-24vy-l30m, cx-24vyl30m
# *
# *****************************************************************************/
#
# CHANGELOG:
#
# 3-1-12: Jeremy Falling: First version.
#
# *****************************************************************************/
#Planned thresholds, will be definded in nagios tho
#if amps over 15, warn
#if amps over 18, crit
#if fuse error, crit
#if temp 95, warn
#if temp 105, crit


