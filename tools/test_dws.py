import json
import os
import shutil
import socket
import stat
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import dws  # noqa: E402


class ClientNameTests(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root, True)

    def test_the_default_name(self):
        self.assertEqual(dws.client_name({}, self.root), "Dorico Examples Test Runner")

    def test_a_name_file_reuses_a_name_dorico_has_allowed(self):
        (self.root / ".dorico-client-name").write_text("Some Allowed Name\n", encoding="utf-8")
        self.assertEqual(dws.client_name({}, self.root), "Some Allowed Name")

    def test_the_environment_comes_first(self):
        (self.root / ".dorico-client-name").write_text("From The File\n", encoding="utf-8")
        self.assertEqual(dws.client_name({"DORICO_CLIENT_NAME": "From The Environment"}, self.root),
                         "From The Environment")

    def test_a_blank_name_file_is_ignored(self):
        (self.root / ".dorico-client-name").write_text("\n", encoding="utf-8")
        self.assertEqual(dws.client_name({}, self.root), "Dorico Examples Test Runner")


def server_frame(obj):
    """An unmasked text frame, as Dorico sends them."""
    data = json.dumps(obj).encode()
    assert len(data) < 126
    return bytes([0x81, len(data)]) + data


def raw_frame(first, payload):
    """An unmasked frame with the length in whichever form its size needs."""
    n = len(payload)
    if n < 126:
        return bytes([first, n]) + payload
    if n < 65536:
        return bytes([first, 126]) + n.to_bytes(2, "big") + payload
    return bytes([first, 127]) + n.to_bytes(8, "big") + payload


class FakeSocket:
    def __init__(self, incoming=b""):
        self.incoming = incoming
        self.sent = b""

    def sendall(self, data):
        self.sent += data

    def recv(self, n):
        chunk, self.incoming = self.incoming[:n], self.incoming[n:]
        return chunk


class EncodeFrameTests(unittest.TestCase):
    def test_encode_frame_small(self):
        mask = b"\x01\x02\x03\x04"
        self.assertEqual(
            dws.encode_frame(b"hi", mask),
            b"\x81\x82\x01\x02\x03\x04" + bytes([0x68 ^ 1, 0x69 ^ 2]),
        )

    def test_encode_frame_126(self):
        frame = dws.encode_frame(b"x" * 200, b"\x00\x00\x00\x00")
        self.assertEqual(frame[0], 0x81)
        self.assertEqual(frame[1], 0x80 | 126)
        self.assertEqual(frame[2:4], (200).to_bytes(2, "big"))
        self.assertEqual(len(frame), 4 + 4 + 200)


class ReceiveTests(unittest.TestCase):
    def receive(self, data):
        return dws.DoricoClient(sock=FakeSocket(data)).recv()

    def test_16_bit_length(self):
        text = "x" * 300
        self.assertEqual(self.receive(raw_frame(0x81, json.dumps({"t": text}).encode()))["t"], text)

    def test_64_bit_length(self):
        text = "x" * 70000
        self.assertEqual(self.receive(raw_frame(0x81, json.dumps({"t": text}).encode()))["t"], text)

    def test_fragments_are_joined(self):
        data = json.dumps({"message": "response", "code": "kOK"}).encode()
        frames = raw_frame(0x01, data[:10]) + raw_frame(0x00, data[10:20]) + raw_frame(0x80, data[20:])
        self.assertEqual(self.receive(frames)["code"], "kOK")

    def test_pings_are_skipped(self):
        frames = raw_frame(0x89, b"hi") + server_frame({"message": "response"})
        self.assertEqual(self.receive(frames)["message"], "response")

    def test_close_ends_the_connection(self):
        with self.assertRaises(EOFError):
            self.receive(raw_frame(0x88, b""))


def connected(test, frames):
    """A client on a real socket pair (settle and status wait on the socket itself), with frames sent from Dorico's
    end."""
    dorico, ours = socket.socketpair()
    test.addCleanup(dorico.close)
    test.addCleanup(ours.close)
    dorico.sendall(frames)
    return dws.DoricoClient(sock=ours)


class SettleTests(unittest.TestCase):
    def test_settle_reads_the_burst_and_returns_once_quiet(self):
        client = connected(self, server_frame({"message": "status", "activeOpenScoreID": 5}) + server_frame(
            {"message": "status", "canUndo": True}
        ))
        self.assertTrue(client.settle(quiet=0.2, limit=5))
        self.assertEqual(client.state, {"message": "status", "activeOpenScoreID": 5, "canUndo": True})

    def test_a_closed_socket_is_an_error_not_quiet(self):
        # quiet would let a run carry on as though Dorico had finished
        client = connected(self, b"")
        client.sock.close()
        with self.assertRaises((OSError, ValueError)):
            client.settle(quiet=0.1, limit=1)


class RequestTests(unittest.TestCase):
    def frames(self):
        return server_frame({"message": "status"}) + server_frame(
            {"message": "commandlist", "commands": []}
        )

    def test_request_skips_status(self):
        client = dws.DoricoClient(sock=FakeSocket(self.frames()))
        reply = client.request({"message": "getcommands"})
        self.assertEqual(reply, {"message": "commandlist", "commands": []})

    def test_status_merges_deltas(self):
        client = connected(self, server_frame({"message": "status", "activeOpenScoreID": 1, "hasScore": True})
                           + server_frame({"message": "status", "hasScore": True}))
        client.request({"message": "getstatus"}, expect="status")
        self.assertEqual(client.status()["activeOpenScoreID"], 1)

    def test_status_reads_every_status_already_waiting(self):
        # Dorico pushes status deltas unasked: one queued before the reply must not stand in for it
        client = connected(self, server_frame({"message": "status", "activeOpenScoreID": 1}) + server_frame(
            {"message": "status", "activeOpenScoreID": 2, "hasScore": True}
        ))
        self.assertEqual(client.status()["activeOpenScoreID"], 2)

    def test_a_command_skips_the_messages_dorico_sends_unasked(self):
        # Dorico sends selectionchanged after a script selects notes; taken as the next command's reply, it ended a
        # run early
        client = dws.DoricoClient(sock=FakeSocket(server_frame({"message": "selectionchanged", "openScoreID": 0})
                                                  + server_frame({"message": "response", "code": "kOK"})))
        self.assertEqual(client.command("Edit.Undo"), {"message": "response", "code": "kOK"})

    def test_request_expect_status(self):
        client = dws.DoricoClient(sock=FakeSocket(self.frames()))
        reply = client.request({"message": "getstatus"}, expect="status")
        self.assertEqual(reply, {"message": "status"})


class TokenTests(unittest.TestCase):
    def test_the_token_is_created_for_its_owner_only(self):
        # Whoever can read it connects without Dorico asking, and can run any Lua through Script.RunScript.
        folder = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, folder, True)
        token = folder / ".dorico-token"
        frames = server_frame({"message": "response", "sessionToken": "abc"}) + server_frame(
            {"message": "response", "code": "kConnected"})
        client = dws.DoricoClient(sock=FakeSocket(frames), token_path=token)
        with mock.patch.object(dws.os, "open", wraps=os.open) as opened:
            client.connect()
        self.assertEqual(token.read_text(), "abc")
        modes = [c.args[2] for c in opened.call_args_list if Path(c.args[0]) == token and len(c.args) > 2]
        self.assertEqual(modes, [0o600])
        if os.name == "posix":
            self.assertEqual(stat.S_IMODE(token.stat().st_mode), 0o600)


if __name__ == "__main__":
    unittest.main()
