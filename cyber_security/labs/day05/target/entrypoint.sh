#!/bin/sh
# Starts root's cron daemon (needed for Vector 3 to actually fire every
# minute, for real, exactly like it would on a real box) and then keeps
# the container alive with no other long-running service -- same "no
# ports published, exec-only" pattern every earlier day-lab target uses.
cron
exec tail -f /dev/null
