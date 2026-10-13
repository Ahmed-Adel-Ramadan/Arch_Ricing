#!/usr/bin/env bash
# Waybar module: NVIDIA dGPU status that never wakes a sleeping GPU.

# Find the NVIDIA display/3D device from sysfs (no lspci needed).
dev=""
for d in /sys/bus/pci/devices/*; do
  [[ $(<"$d/vendor") == 0x10de ]] || continue
  [[ $(<"$d/class") == 0x03* ]] || continue
  dev=$d
  break
done

if [[ -z $dev ]]; then
  printf '{"text":"n/a","class":"offline","tooltip":"No NVIDIA GPU found"}\n'
  exit 0
fi

# Reading runtime_status from sysfs does not wake the GPU.
# Only "suspended"/"suspending" mean asleep; "unsupported" or "error"
# must fall through so we still query the card.
case $(<"$dev/power/runtime_status") in
  suspended | suspending)
    printf '{"text":"Zzz","class":"sleep","tooltip":"dGPU suspended (saving battery)"}\n'
    exit 0
    ;;
esac

out=$(timeout 3 nvidia-smi \
  --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw \
  --format=csv,noheader,nounits 2>/dev/null)

if [[ -z $out ]]; then
  printf '{"text":"off","class":"offline","tooltip":"GPU offline"}\n'
  exit 0
fi

IFS=', ' read -r util temp mem_used mem_total power <<<"$out"

# power.draw is "[N/A]" on some mobile GPUs
if [[ $power =~ ^[0-9.]+$ ]]; then power_txt="${power} W"; else power_txt="n/a"; fi

printf '{"text":"%s%%","class":"active","tooltip":"NVIDIA dGPU\\nUtilization: %s%%\\nTemperature: %s°C\\nMemory: %s / %s MiB\\nPower: %s"}\n' \
  "$util" "$util" "$temp" "$mem_used" "$mem_total" "$power_txt"
