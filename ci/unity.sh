#!/bin/bash
# Runs the Unity editor (native arm64) with a watchdog so a hung editor cannot stall the job.
#   ci/unity.sh <log file> <timeout seconds> <done regex or ""> <unity args...>
# Returns Unity's exit code; 0 if the done regex appeared in the log (Unity is then killed if it lingers);
# 124 on timeout. This repo is PUBLIC: the Unity log is never echoed here (it can name the private
# project's files); it is uploaded to the private repo instead. Only progress counters are printed.
LOG="$1"; LIMIT="$2"; DONE="$3"; shift 3
UNITY="${UNITY_ROOT:?UNITY_ROOT not set}/Unity.app/Contents/MacOS/Unity"
rm -f "$LOG"; touch "$LOG"
"$UNITY" -batchmode -nographics -logFile "$LOG" "$@" &
PID=$!
start=$SECONDS; rc=""; last=0
while kill -0 $PID 2>/dev/null; do
  if [ -n "$DONE" ] && grep -qE "$DONE" "$LOG"; then
    echo "[unity.sh] done marker seen after $((SECONDS-start))s"
    for i in $(seq 1 30); do kill -0 $PID 2>/dev/null || break; sleep 1; done
    kill -9 $PID 2>/dev/null; rc=0; break
  fi
  if [ $((SECONDS-start)) -ge "$LIMIT" ]; then
    echo "[unity.sh] TIMEOUT after ${LIMIT}s - killing Unity"; kill -9 $PID 2>/dev/null; rc=124; break
  fi
  if [ $((SECONDS-last)) -ge 60 ]; then
    last=$SECONDS; echo "[unity.sh] running $((SECONDS-start))s, log $(wc -l < "$LOG") lines"
  fi
  sleep 5
done
if [ -z "$rc" ]; then wait $PID; rc=$?; fi
if [ -n "$DONE" ] && [ "$rc" != 0 ] && grep -qE "$DONE" "$LOG"; then rc=0; fi
echo "[unity.sh] exit $rc after $((SECONDS-start))s, $(grep -ciE 'error' "$LOG") lines mention 'error'"
exit $rc
