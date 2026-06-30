# Multi-Destination Call Test Suite
# Dials 10 different numbers in sequence via ADB.
# Override each destination via environment variables:
#   DEST_01=+49151234567 DEST_02=+49159876543 ... robot multi_call_test.robot

*** Settings ***
Documentation       Dials 10 different phone numbers in sequence, waits, then ends each call.
...                 Requires a connected Android device with USB debugging enabled.
...                 Set DEST_01 through DEST_10 as environment variables to configure numbers.
Library             OperatingSystem
Library             Process
Library             String
Library             Collections

*** Variables ***
${CALL_DURATION}      5s
${INTER_CALL_DELAY}   3s
${ADB_TIMEOUT}        30

# Individual destinations — override any via environment variable
${DEST_01}    %{DEST_01=+49151000001}
${DEST_02}    %{DEST_02=+49151000002}
${DEST_03}    %{DEST_03=+49151000003}
${DEST_04}    %{DEST_04=+49151000004}
${DEST_05}    %{DEST_05=+49151000005}
${DEST_06}    %{DEST_06=+49151000006}
${DEST_07}    %{DEST_07=+49151000007}
${DEST_08}    %{DEST_08=+49151000008}
${DEST_09}    %{DEST_09=+49151000009}
${DEST_10}    %{DEST_10=+49151000010}

@{DESTINATION_NUMBERS}
...    ${DEST_01}    ${DEST_02}    ${DEST_03}    ${DEST_04}    ${DEST_05}
...    ${DEST_06}    ${DEST_07}    ${DEST_08}    ${DEST_09}    ${DEST_10}

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
    Should Match Regexp    ${output}    (?m)^\\S+\\s+device$
    Log    Device connected successfully    level=INFO

Dial Phone Number
    [Arguments]    ${number}
    Log    Dialing ${number} ...    level=INFO
    ${result}=    Run Process    adb    shell    am    start    -a    android.intent.action.CALL    -d    tel:${number}
    ...    timeout=${ADB_TIMEOUT}s
    Should Be Equal As Integers    ${result.rc}    0
    Log    Dial command executed successfully    level=INFO

Wait And End Call
    Sleep    ${CALL_DURATION}
    ${result}=    Run Process    adb    shell    input    keyevent    6
    ...    timeout=${ADB_TIMEOUT}s
    Should Be Equal As Integers    ${result.rc}    0
    Log    Call ended    level=INFO

Make Single Call
    [Arguments]    ${number}    ${index}    ${total}
    Log    \n── Call ${index} of ${total}: ${number} ──    level=INFO    console=yes
    Dial Phone Number    ${number}
    Wait And End Call

*** Test Cases ***
Setup And Verify Environment
    [Documentation]    Verify ADB is installed and a device is connected.
    Verify ADB Is Available
    Verify Device Is Connected

Make 10 Mobile Calls
    [Documentation]    Dial each number in DESTINATION_NUMBERS in sequence.
    ...                Waits ${CALL_DURATION} per call, ${INTER_CALL_DELAY} between calls.
    [Tags]    mobile    call    multi
    ${total}=    Get Length    ${DESTINATION_NUMBERS}
    Log    Starting ${total}-call sequence    level=INFO    console=yes
    ${index}=    Set Variable    ${1}
    FOR    ${number}    IN    @{DESTINATION_NUMBERS}
        Make Single Call    ${number}    ${index}    ${total}
        ${index}=    Evaluate    ${index} + 1
        IF    ${index} <= ${total}
            Log    Waiting ${INTER_CALL_DELAY} before next call ...    level=INFO
            Sleep    ${INTER_CALL_DELAY}
        END
    END
    Log    All ${total} calls completed    level=INFO    console=yes
