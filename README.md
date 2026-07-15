# 🎯 Whac-A-Mole FPGA Game

카메라 기반 두더지 잡기 (Whac-A-Mole) 게임 프로젝트입니다.  
두 개의 Basys3 FPGA 보드와 Python PC 디스플레이를 활용한 시스템입니다.

## 📁 프로젝트 구조

```
project_Whac-A-Mole/
├── vivado/                          # Vivado FPGA 설계 코드
│   ├── mon1_camera_mole_detector/   # FPGA1: 카메라 기반 두더지 감지
│   │   ├── src/                     # SystemVerilog 소스 파일
│   │   └── constraints/             # Basys3 핀 제약 파일 (.xdc)
│   └── mon2_game_display/           # FPGA2: 게임 화면 출력 및 로직
│       ├── src/                     # SystemVerilog 소스 파일
│       ├── constraints/             # Basys3 핀 제약 파일 (.xdc)
│       └── assets/                  # 스프라이트/배경 .mem 파일
├── uvm/                             # UVM 검증 환경
│   ├── rtl/                         # 검증 대상 RTL (mole_state_manager)
│   ├── tb/                          # UVM 테스트벤치
│   ├── filelist.f                   # VCS 컴파일용 파일 리스트
│   └── makefile                     # VCS 빌드/시뮬레이션 Makefile
├── python/                          # PC 측 디스플레이 애플리케이션
│   ├── test4.py                     # 캡처 카드 기반 게임 디스플레이
│   └── hit.wav                      # 히트 효과음
├── .gitignore
└── README.md
```

## 🔧 시스템 구성

### FPGA1 — 카메라 두더지 감지 (`mon1_camera_mole_detector`)
- OV7670 카메라 모듈로 영상 캡처
- HSV 색상 변환을 통한 두더지(색상 물체) 감지
- 감지된 이벤트를 UART를 통해 FPGA2로 전송
- **Top Module**: `fpga1_top`

### FPGA2 — 게임 화면/로직 (`mon2_game_display`)
- VGA를 통한 게임 화면 출력 (320×240 → 640×480)
- 두더지 생성/상태 관리 (FSM)
- 점수 계산 및 스테이지 타이머
- UART를 통해 FPGA1에서 히트 이벤트 수신
- **Top Module**: `fpga2_top`

### UVM 검증 (`uvm`)
- `mole_state_manager` 모듈에 대한 UVM 기반 검증
- VCS 시뮬레이터 사용

### Python 디스플레이 (`python`)
- 캡처 카드를 통해 FPGA2의 VGA 출력을 PC에서 표시
- OpenCV 기반 게임 상태(WIN/GAME OVER) 감지
- 히트 효과음 재생

## 🚀 사용 방법

### Vivado 프로젝트
1. Vivado에서 새 프로젝트 생성 (Part: `xc7a35tcpg236-1`, Board: Basys3)
2. 해당 `src/` 폴더의 `.sv` 파일들을 Design Sources로 추가
3. `constraints/` 폴더의 `.xdc` 파일을 Constraints로 추가
4. `assets/` 폴더의 `.mem` 파일을 Design Sources로 추가 (mon2만 해당)
5. Synthesis → Implementation → Generate Bitstream → Program Device

### UVM 시뮬레이션
```bash
cd uvm
make compile   # VCS 컴파일
make sim       # 시뮬레이션 실행
make clean     # 빌드 부산물 정리
```

### Python 디스플레이
```bash
pip install opencv-python pillow numpy
cd python
python test4.py --cam 1          # 캡처 카드 인덱스 지정
python test4.py --cam 1 --debug  # 디버그 모드
```

## 🛠️ 개발 환경
- **FPGA**: Xilinx Vivado 2020.2
- **보드**: Digilent Basys3 (xc7a35tcpg236-1)
- **시뮬레이션**: Synopsys VCS (UVM 1.2)
- **Python**: 3.x + OpenCV, Pillow, NumPy
