# Baseline UI-Venus 2B-6bit — screenshot asli (2026-09-21 malam)
Daemon: mlx_vlm server :8001, model path absolut (bug: "model":"ui-venus" gagal load dr HF).
Catatan: daemon tadi sempat ganti model krn request dgn "model" salah — tetapi ground dgn path absolut tetap OK.

## Hasil T0 full-frame (1280x831), Long-RE EN
| # | Target | Expression | Output | Verdict zoom | Lat |
|---|--------|-----------|--------|--------------|-----|
| 1 | WhatsApp Dock | "WhatsApp icon with green speech bubble logo in the Dock at the bottom of the screen" | [190,962] -> (243,799) | HIT (tengah ikon WA) | 2.8s |
| 2 | Traffic close (Terminal) | "red close button in the top-left corner of the Terminal window" | [25,79] -> (32,66) | HIT (tengah lingkaran merah) | 2.8s |
| 3 | Open IDE (ZCode) | "Open IDE button in the top-right corner of the window" | [925,53] -> (1184,44) | HIT (di badge Open IDE) | 2.8s |
| 4 | Trash Dock | "Trash bin icon at the right end of the Dock" | [850,962] -> (1088,799) | HIT (tengah trash) | 2.9s |
| 5 | Create btn (browser Atlassian) | "blue Create button in the top toolbar" | [733,150] -> (938,125) | HIT (tengah Create) | 3.3s |
| 6 | Ask Rovo (browser) | "Ask Rovo button in the top-right toolbar" | [888,152] -> (1137,126) | HIT (tepat di Ask Rovo) | 2.8s |

## Ablasi expression (kasus 1)
| Expression | Output | Hasil |
|-----------|--------|-------|
| Long-RE (di atas) | [190,962] | HIT |
| "WhatsApp icon" (pendek) | [189,962] | HIT (sama, 1px beda) |
| "button untuk teks yang mana" (ID mentah, tanpa planner) | [825,457] | MISS total (tengah layar kosong) |

## ROI T1 (kasus 1): crop 400px origin (43,431) -> [490,925] lokal -> global (239,801): err 6px dr T0. Konsisten, T0/T1 sepakat.
## AX coverage (ukur): Finder 0, Safari 14, Antigravity(Electron) 0, ZCode 0, Terminal 0, VLC 0.
