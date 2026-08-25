#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

"""Performs a Minecraft Server List Ping and prints the server's status JSON.

This is the same handshake a Minecraft client performs to render a server in its
server list, so a reply is proof that the Minecraft server process itself is up
and serving the protocol - not merely that a port is open or that a systemd unit
is `active`. The reply also carries the server's own MOTD, its player slots and
the Minecraft version it is running, all of which come from the configuration
the role rendered.

Usage: server-list-ping.py <host> <port> [deadline-seconds]

Exits non-zero, with the last error on stderr, if no status could be obtained
before the deadline. Only the Python standard library is used, because the
Molecule test hosts have nothing else installed.
"""

import json
import socket
import struct
import sys
import time

# Any protocol version is accepted for a status request; servers answer
# regardless and report their own version in the reply.
PROTOCOL_VERSION = 767

CONNECT_TIMEOUT_SECONDS = 5


def encode_varint(value):
    encoded = b""
    while True:
        byte = value & 0x7F
        value >>= 7
        if value:
            encoded += struct.pack("B", byte | 0x80)
        else:
            return encoded + struct.pack("B", byte)


def read_varint(sock):
    result = 0
    for offset in range(5):
        (byte,) = struct.unpack("B", read_exactly(sock, 1))
        result |= (byte & 0x7F) << (7 * offset)
        if not byte & 0x80:
            return result
    raise ValueError("VarInt is longer than 5 bytes")


def read_exactly(sock, count):
    buffer = b""
    while len(buffer) < count:
        chunk = sock.recv(count - len(buffer))
        if not chunk:
            raise EOFError(
                "connection closed after %d of %d bytes" % (len(buffer), count)
            )
        buffer += chunk
    return buffer


def encode_packet(packet_id, payload):
    body = encode_varint(packet_id) + payload
    return encode_varint(len(body)) + body


def ping(host, port):
    sock = socket.create_connection((host, port), timeout=CONNECT_TIMEOUT_SECONDS)
    try:
        sock.settimeout(CONNECT_TIMEOUT_SECONDS)

        address = host.encode("utf-8")
        handshake = (
            encode_varint(PROTOCOL_VERSION)
            + encode_varint(len(address))
            + address
            + struct.pack(">H", port)
            + encode_varint(1)  # next state: status
        )
        sock.sendall(encode_packet(0x00, handshake))
        sock.sendall(encode_packet(0x00, b""))  # status request

        read_varint(sock)  # length of the packet that follows
        packet_id = read_varint(sock)
        if packet_id != 0x00:
            raise ValueError("expected a status response, got packet id %d" % packet_id)

        length = read_varint(sock)
        return json.loads(read_exactly(sock, length).decode("utf-8"))
    finally:
        sock.close()


def main():
    if len(sys.argv) < 3:
        sys.stderr.write(__doc__)
        return 2

    host = sys.argv[1]
    port = int(sys.argv[2])
    deadline = time.monotonic() + (float(sys.argv[3]) if len(sys.argv) > 3 else 0.0)

    last_error = None
    while True:
        try:
            print(json.dumps(ping(host, port)))
            return 0
        except Exception as error:  # noqa: BLE001 - anything here means "not ready"
            last_error = error

        if time.monotonic() >= deadline:
            sys.stderr.write(
                "No Server List Ping reply from %s:%d - last error: %r\n"
                % (host, port, last_error)
            )
            return 1

        time.sleep(2)


if __name__ == "__main__":
    sys.exit(main())
