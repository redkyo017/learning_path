# syntax=docker/dockerfile:1.7
# ws -- the primary shell. Ubuntu plus the operator toolbox.
# The only container where strace works (compose grants it SYS_PTRACE).
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    TERM=xterm-256color

# The toolbox, in two layers on purpose.
#
# Layer one is the contract: every one of these must install, and if any of
# them cannot, this build should fail loudly rather than hand the learner a
# half-equipped shell on day one.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      procps psmisc lsof strace file findutils coreutils util-linux \
      iproute2 iputils-ping netcat-openbsd curl ca-certificates openssl \
      tcpdump nftables less vim neovim git jq acl attr sysstat tree \
 && rm -rf /var/lib/apt/lists/*

# Layer two is best effort, and it is separate so that one missing package
# cannot cost the learner the whole shell:
#   bsdmainutils, dnsutils  transitional packages in noble (bsdextrautils,
#                           bind9-dnsutils) that may vanish or be renamed
#   ltrace                  has no build on every architecture
# A failure here prints a warning and moves on. `hexdump`, `column`, `dig` and
# `ltrace` are conveniences; nothing in the seven days depends on them, and
# strace -- which everything does depend on -- is in layer one.
RUN apt-get update \
 && for pkg in bsdmainutils dnsutils ltrace ; do \
      apt-get install -y --no-install-recommends "$pkg" \
        || echo "WARNING: $pkg unavailable here; continuing without it" ; \
    done \
 && rm -rf /var/lib/apt/lists/*

# The shipped, plugin-free neovim config. Day 1 and Day 7 both live in it.
RUN mkdir -p /root/.config/nvim \
 && cat > /root/.config/nvim/init.lua <<'LUA'
-- Linux Operator Mastery: plugin-free operator config.
-- No plugin manager, no LSP, no completion. Motions and ex commands only.
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.softtabstop = 2
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true
vim.opt.undofile = true
-- clipboard: deliberately left at the default. A container has no host
-- clipboard, so learning the plus-register here would teach you a lie.

-- Arrow keys are off. h j k l is the whole point.
for _, key in ipairs({ "<Up>", "<Down>", "<Left>", "<Right>" }) do
  for _, mode in ipairs({ "n", "i", "v" }) do
    vim.keymap.set(mode, key, function()
      vim.notify("Use h j k l.", vim.log.levels.WARN)
    end)
  end
end
LUA

CMD ["sleep", "infinity"]
