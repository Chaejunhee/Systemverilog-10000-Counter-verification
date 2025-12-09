 
# 🧪 SystemVerilog Verification for UART-Controlled Counter

## 📋 프로젝트 개요 (Project Overview)
이 프로젝트는 **SystemVerilog의 OOP(Object-Oriented Programming)** 기능을 활용하여 **UART 제어 기반 14비트 카운터 시스템**에 대한 계층적 검증 환경(Layered Testbench)을 구축한 결과물입니다.

단순한 파형(Waveform) 관찰을 넘어, **Random Stimulus** 생성, **Self-Checking Scoreboard**, **Coverage** 분석을 통해 설계의 신뢰성을 체계적으로 확보하는 데 중점을 두었습니다.

### 👨‍💻 Team 13
* **Members:** 박주원, 채준희
* **Tools:** Xilinx Vivado Design Suite
* **Language:** SystemVerilog (Verification), Verilog (Design)

---

## 🏗️ 검증 환경 아키텍처 (Verification Environment)

본 프로젝트는 재사용성과 확장성을 고려하여 **Class 기반의 계층적 구조**로 설계되었습니다.

### 1. Testbench Components
| 컴포넌트 (Component) | 역할 (Role) | 주요 특징 (Key Features) |
| :--- | :--- | :--- |
| **Generator** | Stimulus 생성 | `rand`와 `constraint`를 사용하여 다양한 시나리오의 트랜잭션을 무작위 생성 |
| **Driver** | 신호 구동 | Transaction을 받아 Interface를 통해 DUT(Device Under Test)에 물리적 신호 인가 |
| **Monitor** | 신호 관측 | DUT의 입출력 신호를 샘플링하여 Transaction 형태로 재조립 후 Scoreboard로 전달 |
| **Scoreboard** | 결과 판정 | Reference Model(Queue)과 실제 DUT 출력을 비교하여 Pass/Fail 자동 판정 |
| **Environment** | 환경 구성 | 위 컴포넌트들을 생성(new)하고 Mailbox와 Event로 연결(Connect) |

### 2. 통신 메커니즘 (Communication)
* **Interface:** Testbench(Class 영역)와 DUT(Static 영역) 간의 신호 연결을 추상화.
* **Mailbox:** Generator $\rightarrow$ Driver, Monitor $\rightarrow$ Scoreboard 간의 트랜잭션 객체 전달.
* **Event:** 컴포넌트 간의 동작 동기화 (예: `gen_next_event`, `mon_next_event`).

---

## 🛠️ 검증 전략 (Verification Strategy)

### 1. UART Sub-module Verification
UART 통신의 무결성을 보장하기 위해 송신부(TX)와 수신부(RX)를 독립적으로 검증한 후 통합했습니다.
* **FIFO 무결성 검사:** Random Data를 Write/Read 했을 때 데이터 손실이나 순서 섞임이 없는지 확인.
* **Protocol Timing 검사:** Start bit(Low), Data bits(8bit), Stop bit(High)의 타이밍이 Baudrate(9600bps)에 맞춰 정확히 생성되는지 Monitor에서 체크.

### 2. Counter Logic Verification (Queue-based Modeling)
카운터의 동작(Up/Down, Enable/Disable, Clear)을 검증하기 위해 **Scoreboard 내부에 Reference Model**을 구현했습니다.

* **Golden Model:** SystemVerilog의 `Queue` 자료구조를 활용하여 기대값(Expected Value)을 저장.
* **Prediction Logic:**
    ```systemverilog
    // Scoreboard 로직 예시
    if (i_enable) begin
        if (i_mode == UP) expected_val++;
        else expected_val--;
    end
    if (i_clear) expected_val = 0;
    
    queue.push_back(expected_val); // 예측값을 큐에 저장
    ```
* **Comparison:** Monitor로부터 수신된 실제 카운터 값과 Queue의 앞부분(`pop_front`)을 비교하여 검증.

* # 🔍 Datapath & Control Logic Verification Details

## 🎯 검증 목표 (Verification Goal)
카운터 시스템의 핵심인 **Datapath(14-bit Counter)**가 제어 신호(Enable, Mode, Clear)에 따라 정확하게 동작하는지 검증합니다. 특히 **Corner Case**(0 $\leftrightarrow$ 9999 오버플로우/언더플로우)와 **제어 신호 우선순위**를 중점적으로 확인합니다.

## 🛠️ 검증 전략 (Verification Strategy)

### 1. Constrained Random Stimulus (제약된 무작위 입력)
모든 가능한 입력 조합을 테스트하기 위해 `Constraint`를 사용하여 의미 있는 시나리오를 생성했습니다. `Clear` 신호의 빈도를 낮추어 카운팅 동작이 충분히 일어나도록 조정했습니다.

```systemverilog
// tb_cu_dp_systemverilog.sv
constraint input_dist {
    i_enable dist { 0 :/ 20, 1 :/ 80 }; // 80% 확률로 Enable
    i_mode   dist { 0 :/ 30, 1 :/ 70 }; // 70% 확률로 Up Mode
    i_clear  dist { 0 :/ 99, 1 :/ 1  }; // 1% 확률로 Clear (Rare Event)
}

---

## 📊 시뮬레이션 결과 (Simulation Results)

### 1. UART Loopback Test
* **Test:** PC(TB) $\rightarrow$ RX $\rightarrow$ FIFO $\rightarrow$ TX $\rightarrow$ PC(TB) 경로 테스트
* **Result:** 500회의 Random Character 전송 테스트 **ALL PASS**
    > **[SCB]** Data matched! rx_data : c6 == send_data : c6

### 2. Counter Control Test
* **Test:** UART 명령('r', 'c', 'm')과 버튼 입력을 무작위로 인가하여 카운터 동작 확인
* **Result:** Enable, Mode Toggle, Clear 동작에 대한 500회 시나리오 **ALL PASS**

### 📝 Console Output Log
```text
========================================================
===================== Test Report ======================
========================================================
==                  Total Test   : 500                ==
==                  Pass Test    : 500                ==
==                  Fail Test    :   0                ==
==                  enable count : 381                ==
==                  mode   count : 349                ==
==                  clear  count :   4                ==
========================================================
================= Test bench is finish =================
