import os
import pty
import select
import signal
import sys
import time
import unittest


class InstallerPromptsTest(unittest.TestCase):
    @unittest.skipIf(sys.platform == 'darwin', 'sandbox prevents access to the test controlling terminal on macOS')
    def test_prompts_are_visible_with_redirected_output(self):
        pid, fd = pty.fork()
        if pid == 0:
            os.execvp('bash', ['bash', '-c', '''
                exec >/dev/null 2>&1
                . lib/common.sh
                . lib/mode.sh
                . lib/preflight.sh
                ad_select_mode /nonexistent || exit 1
                ad_confirm || exit 1
                echo FINISHED >/dev/tty
            '''])
        output = b''
        try:
            for expected, answer in [(b'Selection [1]:', b'1\n'), (b'Proceed? [y/N]', b'y\n'), (b'FINISHED', None)]:
                deadline = time.monotonic() + 5
                while expected not in output and time.monotonic() < deadline:
                    ready, _, _ = select.select([fd], [], [], 0.2)
                    if ready:
                        try:
                            output += os.read(fd, 4096)
                        except OSError:
                            break
                self.assertIn(expected, output)
                if answer:
                    os.write(fd, answer)
        finally:
            try:
                os.kill(pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            os.waitpid(pid, 0)
            os.close(fd)
