# Robot Framework Mobile Call Test

A minimal Robot Framework test suite that dials a phone number on a USB-connected Android device using ADB.

## Prerequisites

1. **Python 3.8+** installed.
2. **Android Debug Bridge (ADB)** installed and available in your system `PATH`.
3. An **Android device** connected via USB with **USB debugging enabled**.

## Setup

```bash
# 1. Create a virtual environment (recommended)
python -m venv venv

# 2. Activate it
# On Linux/macOS:
source venv/bin/activate
# On Windows:
# venv\Scripts\activate

# 3. Install dependencies
pip install -r requirements.txt
```

## How to run

### Basic run
```bash
robot call_test.robot
```

### Run with a custom phone number
```bash
PHONE_NUMBER="+15551234567" robot call_test.robot
```

### Run a specific test case
```bash
robot -t "Make Mobile Call" call_test.robot
```

### Run with verbose output
```bash
robot -L DEBUG call_test.robot
```

## What it does

1. **Setup And Verify Environment**
   - Checks that `adb` is installed.
   - Confirms at least one Android device is connected.

2. **Make Mobile Call**
   - Uses `adb shell am start -a android.intent.action.CALL -d tel:<number>` to dial the number.
   - Waits 5 seconds.
   - Simulates pressing the end-call key to hang up.

## Output

After running, Robot Framework generates:
- `report.html` — human-readable test report
- `log.html` — detailed execution log
- `output.xml` — machine-readable results

Open `report.html` in your browser to view results.

## Extending the test

- To use **Appium** for richer UI interactions, install `robotframework-appiumlibrary` and replace the ADB keywords with AppiumLibrary keywords.
- To test **iOS**, switch to Appium with an iOS device/simulator instead of ADB.
