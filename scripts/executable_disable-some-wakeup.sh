#!/bin/bash

declare -a devices=(PEG1 PEG0 RP01 RP03 RP25 AWAC)
for device in "${devices[@]}"; do
    if grep -qw ^$device.*enabled /proc/acpi/wakeup; then
        sudo sh -c "echo $device > /proc/acpi/wakeup"
    fi
done
