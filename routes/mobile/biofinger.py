#!/usr/bin/env python3
"""
biofinger_bridge.py
====================
TCP Bridge: Menerima data dari mesin fingerprint BioFinger TM-501
lalu forward ke UMGAP API di Render.

Jalankan: python3 biofinger_bridge.py
Auto-start: sudah dikonfigurasi via systemd
"""

import socket
import threading
import json
import http.client
import urllib.parse
import datetime
import time
import logging
import re

# ── Konfigurasi ──────────────────────────────────────────────────
TCP_HOST    = "0.0.0.0"   # Dengarkan semua interface
TCP_PORT    = 8081         # Port yang sama dengan biofinger.id
UMGAP_HOST  = "umgap-ai.onrender.com"
UMGAP_PATH  = "/api/mobile/biofinger/webhook"
UMGAP_TOKEN = ""  # Kosong - webhook tidak perlu auth

LOG_FILE = "/home/ubuntu/biofinger_bridge.log"

# ── Setup logging ─────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler()
    ]
)
log = logging.getLogger(__name__)


# ── Forward ke UMGAP ─────────────────────────────────────────────
def forward_to_umgap(payload: dict):
    """Kirim data absensi ke UMGAP API via HTTPS."""
    try:
        body = json.dumps(payload).encode("utf-8")
        conn = http.client.HTTPSConnection(UMGAP_HOST, timeout=15)
        headers = {
            "Content-Type":  "application/json",
            "Content-Length": str(len(body)),
            "User-Agent":    "BioFinger-Bridge/1.0",
        }
        conn.request("POST", UMGAP_PATH, body=body, headers=headers)
        resp = conn.getresponse()
        resp_body = resp.read().decode("utf-8", errors="ignore")
        log.info(f"UMGAP response {resp.status}: {resp_body[:200]}")
        conn.close()
        return resp.status
    except Exception as e:
        log.error(f"Forward error: {e}")
        return 0


# ── Parse data dari mesin ─────────────────────────────────────────
def parse_machine_data(raw: str) -> list:
    """
    Mesin BioFinger TM mengirim data dalam format:
    
    Format 1 (ADMS HTTP-like):
    POST /iclock/cdata?SN=XXXX&table=ATTLOG&Stamp=XXX HTTP/1.1
    ...
    PIN\tTime\tStatus\tVerify\tWorkCode\tReserved
    
    Format 2 (JSON):
    {"biohook":"sdatareco","user_id":"123","tran_dt":"..."}
    
    Return list of attendance records
    """
    records = []
    raw = raw.strip()

    # ── Format JSON langsung ──────────────────────────────────────
    if raw.startswith("{"):
        try:
            data = json.loads(raw)
            if data.get("biohook") == "sdatareco" or "user_id" in data:
                records.append(data)
            return records
        except Exception:
            pass

    # ── Format ADMS (HTTP POST dari mesin) ───────────────────────
    # Header: POST /iclock/cdata?SN=XXXXXX&table=ATTLOG
    sn_match = re.search(r"SN=([A-Z0-9]+)", raw)
    sn = sn_match.group(1) if sn_match else "UNKNOWN"

    # Cari baris data setelah header HTTP
    # Format baris: PIN\tDateTime\tStatus\tVerify\tWorkCode
    lines = raw.split("\n")
    for line in lines:
        line = line.strip()
        parts = line.split("\t")
        if len(parts) >= 2:
            # Validasi: parts[0] = PIN (angka), parts[1] = datetime
            if parts[0].isdigit() and len(parts[0]) > 0:
                try:
                    # Validasi format tanggal
                    dt_str = parts[1].strip()
                    # Format: "2026-04-10 09:41:12"
                    datetime.datetime.strptime(dt_str[:19], "%Y-%m-%d %H:%M:%S")

                    record = {
                        "biohook":  "sdatareco",
                        "tran_id":  f"{sn}_{parts[0]}_{dt_str.replace(' ','_').replace(':','')}",
                        "snmesin":  sn,
                        "tran_dt":  dt_str[:19],
                        "user_id":  parts[0],
                        "disp_nm":  "",
                        "stateid":  parts[2].strip() if len(parts) > 2 else "0",
                        "verify":   parts[3].strip() if len(parts) > 3 else "0",
                        "workcod":  parts[4].strip() if len(parts) > 4 else "",
                    }
                    records.append(record)
                    log.info(f"Parsed: PIN={parts[0]} time={dt_str} status={record['stateid']}")
                except Exception as e:
                    log.debug(f"Skip line '{line}': {e}")

    # ── Format heartbeat / info mesin (abaikan) ───────────────────
    if not records and ("iclock" in raw or "Heartbeat" in raw or "GetRequest" in raw):
        log.debug(f"Heartbeat/Info packet from {sn} - ignored")

    return records


# ── Buat response untuk mesin ─────────────────────────────────────
def make_response(status: int = 200) -> bytes:
    """
    Mesin mengharapkan response HTTP standar.
    Harus reply agar mesin tahu data diterima.
    """
    now = datetime.datetime.utcnow().strftime("%a, %d %b %Y %H:%M:%S GMT")
    if status == 200:
        body = "OK"
    else:
        body = "ERROR"

    response = (
        f"HTTP/1.1 {status} {'OK' if status==200 else 'Error'}\r\n"
        f"Date: {now}\r\n"
        f"Content-Type: text/plain\r\n"
        f"Content-Length: {len(body)}\r\n"
        f"Connection: close\r\n"
        f"\r\n"
        f"{body}"
    )
    return response.encode("utf-8")


# ── Handle koneksi dari mesin ─────────────────────────────────────
def handle_client(conn, addr):
    """Handle satu koneksi TCP dari mesin fingerprint."""
    log.info(f"Koneksi dari {addr[0]}:{addr[1]}")
    try:
        # Terima data
        data_chunks = []
        conn.settimeout(10)
        while True:
            try:
                chunk = conn.recv(4096)
                if not chunk:
                    break
                data_chunks.append(chunk)
                # Berhenti jika sudah ada data lengkap
                if len(chunk) < 4096:
                    break
            except socket.timeout:
                break

        if not data_chunks:
            return

        raw = b"".join(data_chunks).decode("utf-8", errors="ignore")
        log.debug(f"Raw data:\n{raw[:500]}")

        # Parse records
        records = parse_machine_data(raw)

        if records:
            log.info(f"Ditemukan {len(records)} record absensi")
            for rec in records:
                status = forward_to_umgap(rec)
                if status == 200:
                    log.info(f"✓ Forwarded PIN={rec.get('user_id')} ke UMGAP")
                else:
                    log.warning(f"✗ Gagal forward PIN={rec.get('user_id')} (status={status})")
        else:
            log.debug(f"Tidak ada record dari {addr[0]} (heartbeat/info)")

        # Kirim response OK ke mesin
        conn.send(make_response(200))

    except Exception as e:
        log.error(f"Error handle_client {addr}: {e}")
        try:
            conn.send(make_response(500))
        except Exception:
            pass
    finally:
        conn.close()


# ── Main TCP Server ───────────────────────────────────────────────
def start_server():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

    try:
        server.bind((TCP_HOST, TCP_PORT))
        server.listen(10)
        log.info(f"🟢 BioFinger Bridge listening on {TCP_HOST}:{TCP_PORT}")
        log.info(f"🔗 Forwarding to https://{UMGAP_HOST}{UMGAP_PATH}")
        log.info(f"📋 Log: {LOG_FILE}")
        log.info("Menunggu koneksi dari mesin fingerprint...")

        while True:
            try:
                conn, addr = server.accept()
                t = threading.Thread(
                    target=handle_client,
                    args=(conn, addr),
                    daemon=True
                )
                t.start()
            except KeyboardInterrupt:
                log.info("Server dihentikan.")
                break
            except Exception as e:
                log.error(f"Accept error: {e}")
                time.sleep(1)

    finally:
        server.close()


if __name__ == "__main__":
    start_server()
