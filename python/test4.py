"""
pc_display_vision.py

No UART required. Detects game state AND mole hits purely from the
captured video:
  - WIN / GAME_OVER: mostly black background + bright YELLOW "WIN" text
    or bright RED "GAME OVER" text (game_renderer_v3.sv's fallback screen)
  - HIT: small regions of the frame (at the 6 known "HIT!" text
    positions) turning bright yellow (12'hFF0, same color as WIN text)

Requires:
  pip install opencv-python pillow numpy
  (winsound is built into Python on Windows - no install needed there)

Usage:
  python pc_display_vision.py --cam 1
  python pc_display_vision.py --cam 1 --debug     (shows detection stats + ROI boxes)
"""

import argparse
import sys
import time
import os
import threading

import cv2
import numpy as np
from PIL import Image

if sys.platform == "win32":
    import winsound

OUTPUT_W, OUTPUT_H = 1280, 960

# how many consecutive frames must agree before we switch WIN/GAMEOVER
# state - avoids flicker from a single noisy/glitched capture frame.
# Entering WIN/GAMEOVER can be fast (a black+colored-text frame is very
# unlikely to appear falsely during normal gameplay), but returning to
# normal gameplay stays more conservative to avoid flicker.
STABLE_FRAMES_ENTER = 1
STABLE_FRAMES_EXIT = 5

# --- tuning knobs for the color/black detection - adjust with --debug ---
BLACK_V_THRESH = 40
BLACK_FRAC_THRESH = 0.55
COLOR_MIN_FRAC = 0.002

# --- HIT detection ROIs ---
# Logical (320x240) coordinates of each area's "HIT!" text bounding box,
# derived from game_renderer_v3.sv:
#   hit_origin_x = cx - 13, width = 4 chars * 6 * scale(2) = 48
#   top row (area<3):    hit_origin_y = cy - 62, height = 7*2 = 14
#   bottom row (area>=3): hit_origin_y = cy + 10, height = 14
# using the calibrated cx/cy values: (72,136) (162,136) (249,136)
#                                     (72,186) (162,187) (249,186)
# Physical (captured 640x480) coords = logical * 2.
# If you recalibrate hole positions later, regenerate these the same way.
HIT_ROIS_PHYSICAL = [
    (118, 148, 214, 176),  # area 0
    (298, 148, 394, 176),  # area 1
    (472, 148, 568, 176),  # area 2
    (118, 392, 214, 420),  # area 3
    (298, 394, 394, 422),  # area 4
    (472, 392, 568, 420),  # area 5
]

HIT_YELLOW_FRAC_THRESH = 0.25  # fraction of ROI that must be bright yellow to count as "HIT visible"
HIT_COOLDOWN_SEC = 0.4          # min time between triggers for the SAME area (avoids re-firing
                                 # multiple times during one flash's duration, which lasts a few frames)


def load_overlay(path, size):
    img = Image.open(path).convert("RGB")
    img = img.resize(size, Image.LANCZOS)
    return cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR)


def detect_end_state(frame):
    """Returns (state, black_frac, yellow_frac, red_frac) for WIN/GAMEOVER detection."""
    h_img = frame.shape[0]
    # 위아래 금색 띠(12'hFF0)를 제외하고 중앙 영역만 본다.
    # 띠가 노란 픽셀을 대량으로 만들어 GAME_OVER를 WIN으로 오판시키기 때문.
    roi = frame[int(h_img * 0.15):int(h_img * 0.85), :]

    hsv = cv2.cvtColor(roi, cv2.COLOR_BGR2HSV)
    # hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
    h, s, v = cv2.split(hsv)
    total = v.size

    black_frac = np.count_nonzero(v < BLACK_V_THRESH) / total
    if black_frac < BLACK_FRAC_THRESH:
        return "NONE", black_frac, 0.0, 0.0

    yellow_mask = (h >= 20) & (h <= 35) & (s > 100) & (v > 100)
    red_mask = ((h <= 10) | (h >= 170)) & (s > 100) & (v > 100)
    yellow_frac = np.count_nonzero(yellow_mask) / total
    red_frac = np.count_nonzero(red_mask) / total

    if yellow_frac >= red_frac and yellow_frac > COLOR_MIN_FRAC:
        return "WIN", black_frac, yellow_frac, red_frac
    elif red_frac > yellow_frac and red_frac > COLOR_MIN_FRAC:
        return "GAMEOVER", black_frac, yellow_frac, red_frac
    else:
        return "NONE", black_frac, yellow_frac, red_frac


def yellow_fraction_in_roi(frame, roi, frame_scale_x, frame_scale_y):
    x0, y0, x1, y1 = roi
    x0, x1 = int(x0 * frame_scale_x), int(x1 * frame_scale_x)
    y0, y1 = int(y0 * frame_scale_y), int(y1 * frame_scale_y)
    x0, y0 = max(0, x0), max(0, y0)
    x1, y1 = min(frame.shape[1], x1), min(frame.shape[0], y1)
    if x1 <= x0 or y1 <= y0:
        return 0.0, (x0, y0, x1, y1)
    crop = frame[y0:y1, x0:x1]
    hsv = cv2.cvtColor(crop, cv2.COLOR_BGR2HSV)
    h, s, v = cv2.split(hsv)
    yellow_mask = (h >= 20) & (h <= 35) & (s > 100) & (v > 100)
    frac = np.count_nonzero(yellow_mask) / yellow_mask.size
    return frac, (x0, y0, x1, y1)


def play_hit_sound(hit_wav_path):
    if sys.platform != "win32":
        return
    if hit_wav_path and os.path.exists(hit_wav_path):
        winsound.PlaySound(hit_wav_path, winsound.SND_ASYNC | winsound.SND_NODEFAULT)
    else:
        winsound.Beep(1000, 80)  # fallback beep if hit.wav is missing


def open_capture(cam_index, result_holder):
    """Runs in a background thread. Tries multiple backends, polling for
    a readable frame instead of a blind sleep, and stores the working
    VideoCapture (or None) into result_holder[0] once done."""
    backends = [("DSHOW", cv2.CAP_DSHOW), ("MSMF", cv2.CAP_MSMF), ("ANY", cv2.CAP_ANY)]
    for bname, backend in backends:
        print(f"[Camera] Trying cam {cam_index} with {bname} backend...")
        test_cap = cv2.VideoCapture(cam_index, backend)
        if not test_cap.isOpened():
            print(f"[Camera] {bname} could not open.")
            continue

        test_cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*'MJPG'))
        test_cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
        test_cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

        # poll for a readable frame instead of a flat 1-second sleep -
        # usually ready in well under 1s, occasionally needs a bit more
        deadline = time.time() + 2.0
        ok, frame = False, None
        while time.time() < deadline:
            ok, frame = test_cap.read()
            if ok:
                break
            time.sleep(0.05)

        if ok:
            h, w = frame.shape[:2]
            print(f"[Camera] SUCCESS with {bname}! Resolution: {w}x{h}")
            result_holder[0] = test_cap
            return
        print(f"[Camera] {bname} opened but cannot read frames.")
        test_cap.release()
    result_holder[0] = False  # signal "gave up"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cam", type=int, default=0, help="capture card index")
    parser.add_argument("--victory-img", type=str, default="victory_hd.png")
    parser.add_argument("--gameover-img", type=str, default="gameover_hd.png")
    parser.add_argument("--hit-wav", type=str, default="hit.wav")
    parser.add_argument("--list-cams", action="store_true")
    parser.add_argument("--debug", action="store_true", help="print/overlay detection stats + ROI boxes")
    args = parser.parse_args()

    if args.list_cams:
        for i in range(6):
            cap = cv2.VideoCapture(i, cv2.CAP_DSHOW if sys.platform == "win32" else 0)
            print(f"index {i}: {'available' if cap.isOpened() else 'not found'}")
            cap.release()
        return

    window_name = "Whack-a-Mole Display"
    cv2.namedWindow(window_name, cv2.WINDOW_NORMAL)

    # show a loading placeholder IMMEDIATELY, before the camera is even
    # opened, so the window appears instantly instead of hanging on a
    # blank/frozen screen while backends are being tried
    loading = np.zeros((OUTPUT_H, OUTPUT_W, 3), dtype=np.uint8)
    cv2.putText(loading, "Connecting to capture card...", (50, OUTPUT_H // 2),
                cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 200, 255), 2)
    cv2.imshow(window_name, loading)
    cv2.waitKey(1)

    cap_result = [None]  # [0]: VideoCapture once ready, or False if all backends failed
    cam_thread = threading.Thread(target=open_capture, args=(args.cam, cap_result), daemon=True)
    cam_thread.start()

    while cap_result[0] is None:
        cv2.imshow(window_name, loading)
        if (cv2.waitKey(30) & 0xFF) in (ord('q'), 27):
            return
        time.sleep(0.03)

    if cap_result[0] is False:
        print(f"[error] could not open capture device index {args.cam} with any backend. Try --list-cams.")
        return
    cap = cap_result[0]

    script_dir = os.path.dirname(os.path.abspath(__file__))
    hit_wav_path = os.path.join(script_dir, args.hit_wav)
    if not os.path.exists(hit_wav_path):
        print(f"[Warning] '{args.hit_wav}' not found at {hit_wav_path} - will use a fallback beep instead.")

    victory_img = load_overlay(args.victory_img, (OUTPUT_W, OUTPUT_H))
    gameover_img = load_overlay(args.gameover_img, (OUTPUT_W, OUTPUT_H))

    current_display = "NONE"
    candidate = "NONE"
    candidate_count = 0

    # per-area HIT cooldown: timestamp of last trigger, so the same area
    # can't re-fire faster than HIT_COOLDOWN_SEC even if the ROI stays
    # yellow across several frames (one flash = one sound)
    last_hit_time = [0.0] * 6

    try:
        while True:
            ok, frame = cap.read()
            if not ok:
                out = np.zeros((OUTPUT_H, OUTPUT_W, 3), dtype=np.uint8)
                cv2.putText(out, "Waiting for camera signal...", (50, OUTPUT_H // 2),
                            cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)
                cv2.imshow(window_name, out)
                if (cv2.waitKey(1) & 0xFF) in (ord('q'), 27):
                    break
                continue

            fh, fw = frame.shape[:2]
            scale_x, scale_y = fw / 640.0, fh / 480.0

            # --- WIN / GAME_OVER detection (only meaningful on the
            # already-mostly-black fallback screen, so it won't fight
            # with HIT detection during normal gameplay) ---
            detected, black_frac, yellow_frac, red_frac = detect_end_state(frame)
            if detected == candidate:
                candidate_count += 1
            else:
                candidate = detected
                candidate_count = 1

            required = STABLE_FRAMES_ENTER if candidate in ("WIN", "GAMEOVER") else STABLE_FRAMES_EXIT
            if candidate_count >= required and candidate != current_display:
                current_display = candidate

            # --- HIT detection (only makes sense during normal gameplay,
            # i.e. when we're not already showing an end screen) ---
            if current_display == "NONE":
                now = time.time()
                for i, roi in enumerate(HIT_ROIS_PHYSICAL):
                    frac, roi_px = yellow_fraction_in_roi(frame, roi, scale_x, scale_y)
                    is_yellow = frac > HIT_YELLOW_FRAC_THRESH

                    if is_yellow and (now - last_hit_time[i] >= HIT_COOLDOWN_SEC):
                        last_hit_time[i] = now
                        play_hit_sound(hit_wav_path)

                    if args.debug:
                        x0, y0, x1, y1 = roi_px
                        color = (0, 255, 255) if is_yellow else (0, 128, 0)
                        cv2.rectangle(frame, (x0, y0), (x1, y1), color, 2)

            if current_display == "WIN":
                out = victory_img.copy()
            elif current_display == "GAMEOVER":
                out = gameover_img.copy()
            else:
                out = cv2.resize(frame, (OUTPUT_W, OUTPUT_H), interpolation=cv2.INTER_CUBIC)

            if args.debug:
                txt = (f"black={black_frac:.2f} yellow={yellow_frac:.3f} red={red_frac:.3f} "
                       f"detected={detected} shown={current_display}")
                cv2.putText(out, txt, (10, OUTPUT_H - 15), cv2.FONT_HERSHEY_SIMPLEX,
                            0.5, (0, 255, 0), 1, cv2.LINE_AA)

            cv2.imshow(window_name, out)
            key = cv2.waitKey(1) & 0xFF
            if key == ord('q') or key == 27:
                break
            if key == ord('f'):
                prop = cv2.getWindowProperty(window_name, cv2.WND_PROP_FULLSCREEN)
                new_val = cv2.WINDOW_NORMAL if prop == cv2.WINDOW_FULLSCREEN else cv2.WINDOW_FULLSCREEN
                cv2.setWindowProperty(window_name, cv2.WND_PROP_FULLSCREEN, new_val)
            if key == ord('n'):
                current_display = "NONE"
                candidate = "NONE"
                candidate_count = 0
    finally:
        cap.release()
        cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
