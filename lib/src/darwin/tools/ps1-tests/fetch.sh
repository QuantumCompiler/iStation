#!/bin/sh
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 iStation contributors
#
# Downloads ps1-tests' compiled programs (MIT, Jakub Czekański): release build-158's tests.zip,
# 6,613,816 bytes, into the git-ignored .build/, beside the suite's licence and the CPU tests'
# psx.log files. The programs are open test code, not Sony's; they still need a BIOS to run, which
# is the user's.
set -eu
cd "$(dirname "$0")"
mkdir -p .build
curl -fL https://github.com/JaCzekanski/ps1-tests/releases/download/build-158/tests.zip -o .build/tests.zip
curl -fsSL https://raw.githubusercontent.com/JaCzekanski/ps1-tests/f727802fead11f1daa7549285548392ef87749cb/LICENSE -o .build/LICENSE
rm -rf .build/tests && mkdir -p .build/tests && unzip -q .build/tests.zip -d .build/tests
# The CPU tests' psx.log files, recorded on a real PS1, from the suite's repository at the same pin.
# All four or none: they land in .build/logs only once every one has arrived.
rm -rf .build/logs .build/logs.partial && mkdir -p .build/logs.partial
for TEST in access-time code-in-io cop io-access-bitwidth; do
    curl -fsSL "https://raw.githubusercontent.com/JaCzekanski/ps1-tests/f727802fead11f1daa7549285548392ef87749cb/cpu/$TEST/psx.log" -o ".build/logs.partial/$TEST.log"
done
mv .build/logs.partial .build/logs
find .build/tests -path '*cpu*' -name '*.exe' | sort
