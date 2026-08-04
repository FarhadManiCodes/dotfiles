#!/bin/sh
case $1/$2 in
  pre/*)
    modprobe -r ath11k_pci
    ;;
  post/*)
    modprobe ath11k_pci
    ;;
esac
