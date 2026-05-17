#!/usr/bin/env bash
# Resolve account alias to email. Sourced by other scripts.

resolve_account() {
  case "$1" in
    personal|p) echo "buiquangvinh720@gmail.com" ;;
    work|w)     echo "vinhbui@physicalrobotics.com" ;;
    study|s)    echo "vinh.buiquangvinh@hcmut.edu.vn" ;;
    all)        echo "ALL" ;;
    *@*)        echo "$1" ;;
    *)          echo "ERROR: unknown account alias '$1' (use personal|work|study|all)" >&2; return 1 ;;
  esac
}

iter_accounts() {
  if [ "$1" = "all" ]; then
    echo "buiquangvinh720@gmail.com"
    echo "vinhbui@physicalrobotics.com"
    echo "vinh.buiquangvinh@hcmut.edu.vn"
  else
    resolve_account "$1"
  fi
}

label_for() {
  case "$1" in
    buiquangvinh720@gmail.com)        echo "personal" ;;
    vinhbui@physicalrobotics.com)     echo "work" ;;
    vinh.buiquangvinh@hcmut.edu.vn)   echo "study" ;;
    *)                                 echo "$1" ;;
  esac
}
