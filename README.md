# cron-flock-rsync

a script to easily run rsync cron job with logging

# usage

Syntax is `scriptname id src dst`

id allows for parallel rsync for different sources/destinations

src and dst are rsync sources and destination

# how does it work

- ensure that only one rsync per id runs at a given time (protects cron jobs)
- upon success or failure, `*.last` gives the status
- upon failure, a detailed log is appended to `*.log`
- upon success **and something was actually sync'ed**, a detailed log is appended to `*.log`
