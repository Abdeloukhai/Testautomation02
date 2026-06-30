# Mobile Call Test Suite using Robot Framework
# This example uses the Process library to invoke ADB commands
# for dialing a phone number on a connected Android device.

*** Settings ***
Documentation       Simple Robot Framework test to make a phone call via ADB.
...               Connect an Android device via USB and enable USB debugging first.
Library           OperatingSystem
Library           Process
Library           String

*** Variables ***
${PHONE_NUMBER}    %{PHONE_NUMBER=555}
${ADB_TIMEOUT}     30

*** Keywords ***
Verify ADB Is Available
    ${result}=    Run Process    adb    --version    stdout=${OUTPUT_DIR}/adb_version.txt
    Should Be Equal As Integers    ${result.rc}    0
    ${output}=    Get File    ${OUTPUT_DIR}/adb_version.txt
    Should Contain    ${output}    Android Debug Bridge

Verify Device Is Connected
    ${result}=    Run Process    adb    devices    stdout=${OUTPUT_DIR}/devices.txt
    Should Be Equal As Integers    ${result.rc}    0
    ${output}=    Get File    ${OUTPUT_DIR}/devices.txt
    # Check that at least one device (non-empty line after header) is present
    Should Match Regexp    ${output}    (?m)^\\S+\\s+device$
    Log    Device connected successfully    level=INFO

Dial Phone Number
    [Arguments]    ${number}
    Log    Dialing ${number} ...    level=INFO
    # Use am start with tel: URI to trigger the dialer
    ${result}=    Run Process    adb    shell    am    start    -a    android.intent.action.CALL    -d    tel:${number}
    ...    timeout=${ADB_TIMEOUT}s
    Should Be Equal As Integers    ${result.rc}    0
    Log    Dial command executed successfully    level=INFO

Wait And End Call
    # Wait a few seconds to let the call connect before ending it
    Sleep    5s
    # Simulate pressing the end-call button via keyevent (KEYCODE_ENDCALL = 6)
    ${result}=    Run Process    adb    shell    input    keyevent    6
    ...    timeout=${ADB_TIMEOUT}s
    Should Be Equal As Integers    ${result.rc}    0
    Log    Call ended    level=INFO

*** Test Cases ***
Setup And Verify Environment
    [Documentation]    Verify ADB is installed and a device is connected.
    Verify ADB Is Available
    Verify Device Is Connected

Make Mobile Call
    [Documentation]    Dial the configured phone number and then end the call.
    ...    Override PHONE_NUMBER via environment variable, e.g.:
    ...    PHONE_NUMBER=+15551234567 robot call_test.robot
    [Tags]    mobile    call
    Dial Phone Number    ${PHONE_NUMBER}
    Wait And End Call
