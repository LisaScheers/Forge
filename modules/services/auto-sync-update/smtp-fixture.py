"""Minimal SMTP sink for the updater VM test; appends each message body to /run/mail.txt."""
import socket

server = socket.socket()
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind(("127.0.0.1", 2525))
server.listen()


def serve(connection):
    stream = connection.makefile("rwb")

    def reply(text):
        stream.write(text.encode() + b"\r\n")
        stream.flush()

    reply("220 fixture")
    in_data, body = False, []
    for raw in stream:
        line = raw.decode(errors="replace").rstrip("\r\n")
        if in_data:
            if line == ".":
                with open("/run/mail.txt", "a") as mail:
                    mail.write("\n".join(body) + "\n")
                in_data, body = False, []
                reply("250 stored")
            else:
                body.append(line)
            continue
        command = line.split(" ")[0].upper()
        if command == "DATA":
            in_data = True
            reply("354 send")
        elif command == "QUIT":
            reply("221 bye")
            return
        else:
            reply("250 ok")


while True:
    connection, _ = server.accept()
    # Port probes connect and drop; keep serving.
    try:
        serve(connection)
    except OSError:
        pass
    finally:
        connection.close()
