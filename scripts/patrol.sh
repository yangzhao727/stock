#!/usr/bin/env bash
# patrol.sh — 自动巡查：全池行情 + 触发位核对（防守信号 + 开火信号）
# 输出1：TRIGGER/WARN/INFO 行（供 Claude 对话读取）
# 输出2：写入 patrol_status.js（供 dashboard.html / GitHub 公开页展示）
# 末尾自动推送 patrol_status.js 到 GitHub Pages
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$SCRIPT_DIR/../patrol_status.js"

codes="sz002403,sz002029,sz002969,sz002242,sz002297,sz002241,sh600936,sh603660,sz000995,sh603319,sz300006"
data=$(curl -s --max-time 15 "https://qt.gtimg.cn/q=$codes&r=$RANDOM$(date +%H%M%S)" | iconv -f GBK -t UTF-8//IGNORE)

raw=$(echo "$data" | tr ';' '\n' | grep '^v_' | sed 's/^v_[a-z]*="//' | awk -F'~' '
{
  nm=$2; sym=$3; p=$4+0
  # —— 歌尔：11-27 已 23.04 全清（+5,982），转观察池（再上车看三信号）——
  if (sym=="002241") {
    if (p>=22.13 && p<=23.14) printf "INFO|歌尔股份|在22.13~23.14再上车观察区：缩量回踩守22.13→三信号确认可接回\n"
    else if (p<=21.00)        printf "WARN|歌尔股份|跌破21.00结构线：趋势再坏，放弃观察\n"
    else if (p>=23.14)        printf "INFO|歌尔股份|放量过23.14：看23.42/24.40压力\n"
  }
  # —— 观察池（📝预案亮灯≠开火令；换仓需 A 级门槛+用户确认）——
  else if (sym=="002242") {
    if (p<=37.66)      printf "WARN|九阳股份|跌破11-26低点37.66：妖王见顶确认\n"
  }
  else if (sym=="002403") {
    if (p<=8.75)       printf "WARN|爱仕达|跌破11-26低点8.75：深冻继续\n"
  }
  else if (sym=="002969") {
    if (p<=7.50)       printf "WARN|嘉美包装|冷冻线7.50跌破：更弱\n"
    else if (p>=8.00)  printf "INFO|嘉美包装|缩量站稳8.00：反抽确认\n"
  }
  else if (sym=="002297") {
    if (p<=11.60)      printf "WARN|博云新材|跌破11-26新低11.60：冷冻加深\n"
    else if (p>=13.00) printf "INFO|博云新材|缩量站稳13.00：解冻观察\n"
  }
  else if (sym=="600936") {
    if (p<=3.20)       printf "TRIGGER|北投科技|除名线3.20跌破：彻底除名\n"
    else if (p>=4.20)  printf "INFO|北投科技|收复4.20：解冻观察\n"
  }
  else if (sym=="000995") {
    if (p<=13.68)      printf "WARN|皇台酒业|跌破11-26低点13.68：继续看戏\n"
  }
  else if (sym=="603319") {
    if (p<=16.70)      printf "WARN|美湖股份|跌破11-26低点16.70：阴跌继续\n"
    else if (p>=18.50) printf "INFO|美湖股份|收复18.5：解禁信号\n"
  }
  else if (sym=="002029") {
    if (p<=6.18)       printf "TRIGGER防守|七匹狼|止损线6.18跌破：清仓3100股\n"
    else if (p>=6.85)  printf "TRIGGER止盈|七匹狼|到出货区6.85~7.0：全清3100股（套牢区逃命口）\n"
  }
  else if (sym=="300006") {
    if (p<=8.00)       printf "WARN|莱美药业|跌破8.00整数关：崩塌继续（利空未查明）\n"
    else if (p>=8.49)  printf "INFO|莱美药业|过11-26高点8.49：止跌信号+1\n"
  }
}')

now=$(date '+%Y-%m-%d %H:%M:%S')

# 写 patrol_status.js（仪表盘 + GitHub 公开页展示）
if [ -n "$raw" ]; then
  alerts=$(echo "$raw" | awk -F'|' '{
    gsub(/"/,"",$2); gsub(/"/,"",$3); gsub(/"/,"",$4)
    printf "{\"level\":\"%s\",\"name\":\"%s\",\"msg\":\"%s\"},", $1, $2, $3
  }')
  printf 'window.PATROL = { time: "%s", alerts: [%s] };\n' "$now" "$alerts" > "$OUT"
  echo "$raw"
else
  printf 'window.PATROL = { time: "%s", alerts: [] };\n' "$now" > "$OUT"
  echo "OK $now 无触发"
fi

# 自动推送到 GitHub Pages（公开网页巡查面板实时更新）
cd "$SCRIPT_DIR/.."
if git rev-parse --git-dir >/dev/null 2>&1; then
  git add -f patrol_status.js 2>/dev/null || true
  if ! git diff --cached --quiet patrol_status.js 2>/dev/null; then
    git commit -m "patrol $(date +%H:%M)" >/dev/null 2>&1 || true
    git push origin main >/dev/null 2>&1 || true
  fi
fi
