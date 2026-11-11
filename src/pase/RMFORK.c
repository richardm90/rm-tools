/*
 * RMFORK <jobname> <nvars> [<envvar> ...] <cmd> [<resourceid> [<keep_stdio>]]
 *
 * Publishes a list of "NAME=VALUE" environment variables into a genuinely
 * forked, explicitly-named job (not spawn()'d) and execs <cmd> in it - so
 * DSPJOB OPTION(*ENVVAR) sees them on the job the caller asked for, which
 * rm-tools' own spawn()-based PASE_run_cmd (RMPASE.rpgle) cannot give. It
 * has to be a separate native PASE binary because f_fork400() is PASE-only
 * and cannot be called from ILE RPG or ILE C. src/pase/Rules.mk explains
 * how it is built under TOBi.
 *
 * ARGV SHAPE (external, phase 1) - the exact contract src/helpers/rmbase/
 * RMFORK.rpgle's FORK_build_cmdline assembles against. Each rm-tools release
 * deploys its own copy of this binary, to /QOpenSys/opt/rm-tools/<release>/
 * bin/rmfork (FORK_NATIVE_PATH in include/RMFORK_D.rpgleinc), so a caller
 * always runs the binary from its own release. Keep this argv shape and the
 * exit codes below backward compatible anyway, so that a caller can be
 * pointed at a newer release's binary if ever needed.
 *   argv[1]            jobname. The literal "--phase2" is reserved for this
 *                       binary's own internal re-exec (below) and can never
 *                       be a valid job name (hyphen is not valid in one).
 *   argv[2]            nvars, decimal - how many of the following argv
 *                       entries are "NAME=VALUE" pairs. Passed explicitly
 *                       so a variable-length envvars list and optional
 *                       trailing arguments coexist with no ambiguity.
 *   argv[3..3+nvars-1] nvars "NAME=VALUE" strings, already fully formed -
 *                       handed to Qp2setenv_ile() as-is.
 *   argv[3+nvars]      cmd - the command the child execs, via bash -c.
 *   argv[3+nvars+1]    OPTIONAL resourceid, decimal, f_fork400()'s own
 *                       parameter - 0/absent lets the OS choose. An
 *                       out-of-range value is also the cleanest known way
 *                       to force f_fork400() to fail on demand (MEASURED:
 *                       999999999 fails reliably).
 *   argv[3+nvars+2]    OPTIONAL keep_stdio, the literal 0 or 1 (anything
 *                       else is exit 1); only valid after resourceid
 *                       (positional). Absent == 0.
 * So valid argc is exactly 4+nvars, 5+nvars or 6+nvars.
 *
 * TWO-PHASE CHILD. Qp2setenv_ile() used to be called in the PARENT before
 * f_fork400(), because calling it in the child right after the fork hangs
 * (MEASURED, matching f_fork400()'s documented warning that "application
 * data, mutexes and locks are all undefined in the child process" until
 * exec). That is only safe while the parent is a disposable process; a
 * caller that ran this in its own long-lived job would have its own
 * environment modified. A self-exec probe (MEASURED) showed
 * Qp2setenv_ile() DOES work in the child once the child has done an
 * intermediate exec, with the parent never touching it. So:
 *
 *   Phase 1 (child, immediately after f_fork400() returns 0 - the
 *   "undefined" window, so deliberately nothing but this): close the pipe
 *   read end, dup2 the pipe write end onto the fixed RMFORK_PIPE_FD, then
 *   execv() this same binary with "--phase2" as argv[1]. The phase-2 argv
 *   is built in the parent BEFORE the fork, as plain stack pointers, so
 *   the child does no allocation. (An env var as the signal was rejected:
 *   setenv/putenv is libc work in the undefined window, and it would leak
 *   into <cmd>'s environment and DSPJOB *ENVVAR.)
 *     rmfork --phase2 <jobname> <keep_stdio 0|1> <nvars> [<envvar> ...] <cmd>
 *   resourceid is not carried (consumed by f_fork400() only).
 *
 *   Phase 2 (post-exec), in this order: (1) stdio - keep_stdio 0: open
 *   /dev/null and dup2 it over 0/1/2; keep_stdio 1: leave 0/1/2 exactly as
 *   inherited; (2) Qp2setenv_ile(envp, NULL), conflict=NULL, last-write-wins
 *   (confirmed safe); (3) cmd_first_word_is_executable(); (4) FD_CLOEXEC on
 *   RMFORK_PIPE_FD; (5) execl() bash -c <cmd>.
 *
 * RMFORK_PIPE_FD is 63: not 0/1/2, above anything spawn() plausibly
 * inherited; dup2() clears FD_CLOEXEC so it survives the self-exec. It is
 * internal (both phases are this binary), not external ABI.
 *
 * KEEP_STDIO IS ONLY FOR SHORT-LIVED <cmd>. With it, the forked job holds
 * the caller's inherited fds for as long as <cmd> runs; a long-running <cmd> re-creates exactly the hang the default
 * redirect exists to prevent, and PASE_run_cmd (which reads its capture
 * pipe to EOF) blocks for <cmd>'s whole lifetime. Also, the exit status of
 * <cmd> itself is never an exit code of this binary: the parent returns as
 * soon as the final exec succeeds.
 *
 * SELF-PIPE: a pipe created before f_fork400() makes a failure in the
 * child observable to the parent, which would otherwise return before the child has done anything (f_fork400() is a
 * genuine fork). The parent closes its write end and read()s the read end:
 * zero bytes (EOF) means the write end closed by itself, i.e. the final
 * exec succeeded; an 8-byte record {int rc; int err;} means the child gave
 * up - rc is the exit code the parent returns, err is errno
 * (informational). The wait is bounded by how fast the two phases run
 * (microseconds), never by the forked job's lifetime.
 *   The parent read()s in a loop, retrying on EINTR and accumulating partial
 *   reads until 8 bytes or EOF. Full record -> return rec.rc; 0 < n < 8
 *   bytes -> 127; a non-EINTR read() error -> 127 too (outcome unknown, so
 *   never success; 2 is reserved for pipe()/f_fork400() failures before any
 *   child exists); EOF with 0 bytes -> success (0).
 *
 * ENVIRONMENT SCOPE (MEASURED): the variables published by
 * Qp2setenv_ile() are JOB-level - visible in DSPJOB OPTION(*ENVVAR) /
 * JOB_get_envvars - and are NOT passed into <cmd>'s own process environment
 * (`echo $VAR` / `env` inside <cmd> shows nothing). Same as v2.2.0.
 *
 * MEASURED, and why cmd_first_word_is_executable() exists: execl() targets
 * bash, which essentially always succeeds, and an FD_CLOEXEC write end
 * closes the INSTANT that exec succeeds - before bash has looked at <cmd>.
 * So "will <cmd> resolve to something exec-able" must be checked here, in
 * C, against <cmd>'s first word before bash is invoked. A direct execl()
 * failure (bash missing) is handled the textbook way after the call.
 *
 * EXIT CODES - PASE_run_cmd's rc reflects these back to FORK_run_cmd's
 * caller unchanged (RMPASE.rpgle):
 *   0   f_fork400() and every exec up to and including <cmd>'s succeeded.
 *   1   wrong number of arguments, nvars/resourceid/keep_stdio did not
 *       parse, or argc did not match the declared nvars (also a malformed
 *       phase-2 argv, via the record; essentially unreachable).
 *   2   pipe() or f_fork400() failed - f_fork400() returns -1 on failure,
 *       NOT 0 (the child's value); checked as pid < 0, not pid != 0, which
 *       was an actual historical bug in an earlier fork helper.
 *   3   Qp2setenv_ile() failed (distinct from 2, so the two failures can
 *       be told apart). SEMANTIC SHIFT in v2.3.0: it now happens in the
 *       child after a successful fork, so a job named <jobname> briefly
 *       existed (see TWO-PHASE CHILD above); it
 *       reaches the caller via the pipe record. Never observed failing -
 *       defensive, not confirmed behaviour.
 *   127 <cmd> could not be exec'd, bash's execl() failed, /dev/null could
 *       not be opened in phase 2, or phase 1's dup2()/execv() failed -
 *       after a successful fork: the job exists under <jobname> but never
 *       ran <cmd> (reported via the SELF-PIPE above; without it the parent
 *       would return 0 here, indistinguishable from success).
 */

#include <as400_protos.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

/* Not <stdlib.h>'s strtoul()/getenv() - MEASURED for both: <stdlib.h>'s own include
   chain conflicts with as400_protos.h's sigset_t definition on this box.
   A plain decimal parser avoids the whole header for nvars/resourceid;
   a bare prototype does the same for the one getenv() call below. */
static long
parse_decimal(const char *s, int *ok)
{
  long n = 0;
  const char *p = s;

  if (*p == '\0') {
    *ok = 0;
    return 0;
  }
  while (*p) {
    if (*p < '0' || *p > '9') {
      *ok = 0;
      return 0;
    }
    n = n * 10 + (long)(*p - '0');
    p++;
  }
  *ok = 1;
  return n;
}

extern char *getenv(const char *name);

/* Mirrors just enough of what a shell would do to resolve <cmd>'s first
   word into a real, exec-able file - a direct access(X_OK) check for
   anything containing a '/', else a manual search of $PATH - so a forced
   exec failure (e.g. a path that does not exist anywhere) can be caught and reported HERE, before bash
   is ever invoked, rather than silently inside it (see the long header
   comment above for why bash's own attempt can't be observed after the
   fact). Only the first word matters - this is a existence/permission
   check, not a parse of <cmd>'s full shell syntax; bash itself still
   does that, unchanged, once this check has passed. */
static int
cmd_first_word_is_executable(const char *cmd)
{
  char word[1024];
  size_t wlen;
  const char *sp;
  const char *path;
  const char *p;
  char candidate[1024];

  /* Latent edge cases, not exercised by any real <cmd> in this branch
     ("sleep 30" only): a LEADING space makes wlen 0 below, which is
     treated as "not executable" - a false negative for a command bash
     would actually run fine. A tab is never treated as a word separator
     at all (only a literal ' ' is), so "cmd\targ" is seen as one word.
     Neither is fixed here - just flagged for whoever extends this check
     next. */
  sp = strchr(cmd, ' ');
  wlen = sp ? (size_t)(sp - cmd) : strlen(cmd);
  if (wlen == 0 || wlen >= sizeof(word)) {
    return 0;
  }
  memcpy(word, cmd, wlen);
  word[wlen] = '\0';

  if (strchr(word, '/') != NULL) {
    return access(word, X_OK) == 0;
  }

  path = getenv("PATH");
  if (path == NULL || *path == '\0') {
    return 0;
  }

  p = path;
  while (*p != '\0') {
    const char *colon = strchr(p, ':');
    size_t dlen = colon ? (size_t)(colon - p) : strlen(p);

    if (dlen == 0) {
      /* an empty PATH component conventionally means "current directory" -
         not a meaningful thing to guess at for a forked, detached job, so
         skip it rather than assume one. */
      p = colon ? colon + 1 : p + strlen(p);
      continue;
    }

    if (dlen + 1 + wlen + 1 <= sizeof(candidate)) {
      memcpy(candidate, p, dlen);
      candidate[dlen] = '/';
      memcpy(candidate + dlen + 1, word, wlen);
      candidate[dlen + 1 + wlen] = '\0';

      if (access(candidate, X_OK) == 0) {
        return 1;
      }
    }

    p = colon ? colon + 1 : p + strlen(p);
  }

  return 0;
}

/* Fixed fd the pipe write end lives on across the self-exec - see header. */
#define RMFORK_PIPE_FD 63

/* Deployed location, used to re-exec when argv[0] has no '/' in it (a bare
   name found via $PATH cannot be execv()'d by name). Supplied by the build
   (src/pase/Rules.mk passes -DRMFORK_DEPLOYED_PATH, read from
   FORK_NATIVE_PATH in include/RMFORK_D.rpgleinc) so it is never out of step
   with the release the binary is deployed for. */
#ifndef RMFORK_DEPLOYED_PATH
#error "Build with -DRMFORK_DEPLOYED_PATH=... - see src/pase/Rules.mk"
#endif

/* The failure record written to the pipe; zero bytes read == success. */
struct rmfork_rec {
  int rc;
  int err;
};

static void
fail_via_pipe(int fd, int rc, int err)
{
  struct rmfork_rec rec;

  rec.rc = rc;
  rec.err = err;
  /* write() result deliberately ignored: we are about to _exit() and there is
     no other channel left to report a failure on; the parent sees EOF/short. */
  write(fd, &rec, sizeof(rec));
  _exit(rc);
}

/* Phase 2: running post-exec inside the forked job. Never returns.
   argv: rmfork --phase2 <jobname> <keep_stdio> <nvars> [<envvar>...] <cmd> */
static void
phase2(int argc, char **argv)
{
  long nvars;
  long keep;
  int ok;
  int cmd_index;
  int i;
  int devnull;
  int setenv_rc;

  if (argc < 6) {
    fail_via_pipe(RMFORK_PIPE_FD, 1, EINVAL);
  }
  keep = parse_decimal(argv[3], &ok);
  if (!ok || keep > 1) {
    fail_via_pipe(RMFORK_PIPE_FD, 1, EINVAL);
  }
  nvars = parse_decimal(argv[4], &ok);
  if (!ok || argc != 6 + nvars) {
    fail_via_pipe(RMFORK_PIPE_FD, 1, EINVAL);
  }
  cmd_index = 5 + (int)nvars;

  /* (1) stdio first - everything after depends on what fds mean. */
  if (!keep) {
    devnull = open("/dev/null", O_RDWR);
    if (devnull < 0) {
      fail_via_pipe(RMFORK_PIPE_FD, 127, errno);
    }
    dup2(devnull, 0);
    dup2(devnull, 1);
    dup2(devnull, 2);
    close(devnull);
  }

  /* (2) publish the environment, here in the forked job. envp needs a real
     NULL-terminated copy, not a slice of argv (argv[cmd_index] is the cmd). */
  {
    char *envp_copy[nvars + 1];
    for (i = 0; i < (int)nvars; i++) {
      envp_copy[i] = argv[5 + i];
    }
    envp_copy[nvars] = (char *)0;

    setenv_rc = Qp2setenv_ile((const char *const *)envp_copy, (const char *)0);
  }
  if (setenv_rc != 0) {
    fail_via_pipe(RMFORK_PIPE_FD, 3, setenv_rc);
  }

  /* (3) see header for why this runs here. */
  if (!cmd_first_word_is_executable(argv[cmd_index])) {
    fail_via_pipe(RMFORK_PIPE_FD, 127, ENOENT);
  }

  /* (4) FD_CLOEXEC now genuinely protects the happy path: the write end
     closes the instant bash's exec succeeds, not when <cmd> finishes. */
  fcntl(RMFORK_PIPE_FD, F_SETFD, FD_CLOEXEC);

  /* (5) */
  execl("/QOpenSys/pkgs/bin/bash", "bash", "-c", argv[cmd_index], (char *)0);

  /* bash itself could not be exec'd - still holding the write end. */
  fail_via_pipe(RMFORK_PIPE_FD, 127, errno);
}

int
main(int argc, char **argv)
{
  pid_t pid;
  long nvars;
  long resource_id;
  long keep_stdio;
  int ok;
  int cmd_index;
  int i;
  int pipefd[2];
  const char *target;

  if (argc >= 2 && strcmp(argv[1], "--phase2") == 0) {
    phase2(argc, argv);
    return 1;  /* not reached */
  }

  /* Minimum shape: prog jobname nvars cmd - argc >= 4. */
  if (argc < 4) {
    return 1;
  }

  nvars = parse_decimal(argv[2], &ok);
  if (!ok || nvars < 0) {
    return 1;
  }

  /* argc must be exactly 4+nvars, 5+nvars (resourceid) or 6+nvars
     (resourceid and keep_stdio). */
  if (argc != 4 + nvars && argc != 5 + nvars && argc != 6 + nvars) {
    return 1;
  }

  cmd_index = 3 + (int)nvars;

  resource_id = 0;
  if (argc >= 5 + nvars) {
    resource_id = parse_decimal(argv[cmd_index + 1], &ok);
    if (!ok || resource_id < 0) {
      return 1;
    }
  }

  keep_stdio = 0;
  if (argc == 6 + nvars) {
    keep_stdio = parse_decimal(argv[cmd_index + 2], &ok);
    if (!ok || keep_stdio > 1) {
      return 1;
    }
  }

  /* A relative argv[0] containing '/' (e.g. "./rmfork") is re-exec'd as-is;
     that works only because the forked child shares our cwd - fine for the
     deployed absolute path, fragile for ad-hoc relative invocations. */
  target = (strchr(argv[0], '/') != NULL) ? argv[0] : RMFORK_DEPLOYED_PATH;

  /* Build the phase-2 argv here, pre-fork, so the child allocates nothing:
     target --phase2 jobname keep nvars envvars... cmd NULL */
  {
    char *p2[nvars + 7];

    p2[0] = (char *)target;
    p2[1] = "--phase2";
    p2[2] = argv[1];
    p2[3] = keep_stdio ? "1" : "0";
    p2[4] = argv[2];
    for (i = 0; i < (int)nvars; i++) {
      p2[5 + i] = argv[3 + i];
    }
    p2[5 + nvars] = argv[cmd_index];
    p2[6 + nvars] = (char *)0;

    /* Self-pipe (see header) - created before f_fork400() so both sides
       share it from the start. */
    if (pipe(pipefd) < 0) {
      fprintf(stdout, "RMFORK: pipe() failed: %s\n", strerror(errno));
      return 2;
    }

    pid = f_fork400(argv[1], (unsigned)resource_id);

    if (pid < 0) {
      /* No child, no job. Reported on this process's own stdout, still
         connected to whatever called this binary (PASE_run_cmd's capture
         pipe, in production). */
      fprintf(stdout, "RMFORK: f_fork400(%s) failed: %s\n",
              argv[1], strerror(errno));
      close(pipefd[0]);
      close(pipefd[1]);
      return 2;
    }

    if (pid == 0) {
      /* PHASE 1 - the "undefined" window: nothing but the pipe move and
         the re-exec. */
      close(pipefd[0]);
      if (pipefd[1] != RMFORK_PIPE_FD) {
        if (dup2(pipefd[1], RMFORK_PIPE_FD) < 0) {
          fail_via_pipe(pipefd[1], 127, errno);
        }
        close(pipefd[1]);
      }
      execv(target, p2);
      fail_via_pipe(RMFORK_PIPE_FD, 127, errno);
    }
  }

  /* parent: close our copy of the write end, then read the read end - EOF
     means success, a record carries the exit code to return. */
  close(pipefd[1]);

  {
    struct rmfork_rec rec;
    char *buf = (char *)&rec;
    size_t got = 0;
    int read_failed = 0;

    /* Accumulate until a full record or EOF; retry on EINTR. */
    while (got < sizeof(rec)) {
      ssize_t n = read(pipefd[0], buf + got, sizeof(rec) - got);

      if (n < 0) {
        if (errno == EINTR) {
          continue;
        }
        read_failed = 1;
        break;
      }
      if (n == 0) {
        break;  /* EOF */
      }
      got += (size_t)n;
    }

    close(pipefd[0]);

    if (got == sizeof(rec)) {
      return rec.rc;
    }
    if (got > 0 || read_failed) {
      /* short record (cannot happen: atomic write) or an unreadable pipe:
         the outcome is unknown, so never report success. */
      return 127;
    }
  }

  return 0;
}
