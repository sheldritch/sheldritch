#!/bin/bash

alias test_init='
trap "STACKTRACE=1; error FAILED" ERR
'
