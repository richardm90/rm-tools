# pase/ has no build-time dependency on helpers/ - RMFORK.rpgle only
# references the compiled native binary at RUNTIME, via a fixed absolute
# path - so its position here doesn't matter.
SUBDIRS = helpers pase
