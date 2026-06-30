# =============================================================================
# CCS Charging & Subscription Expiry Test Suite
# IDs: TMSII01276126 | TMSII01276150 | TMSII01228917 | TMSII01228922
# =============================================================================

*** Settings ***
Documentation       CCS charging verification tests for AldiTalk / NettoKom subscribers.
...                 Requires: Matrixx RT-CCS, RS Gateway, ADB device, Kafka access.
Library             RequestsLibrary
Library             Process
Library             OperatingSystem
Library             String
Library             Collections
Library             DateTime

*** Variables ***
# ── Connection ───────────────────────────────────────────────────────────────
${BASE_URL}                 https://your-ccs-host
${SUBSCRIPTION_ID}          %{SUBSCRIPTION_ID=CHANGE_ME}

# ── ADB ──────────────────────────────────────────────────────────────────────
${PHONE_NUMBER}             %{PHONE_NUMBER=555}
${ADB_PATH}                 adb
${ADB_TIMEOUT}              30

# ── Pricing constants ─────────────────────────────────────────────────────────
${VOICE_CHARGE_EUR}         0.03
${DATA_CHARGE_PER_MB_EUR}   0.24
${DATA_SESSION_MB}          10

# ── Offer constants (TEF-165) ─────────────────────────────────────────────────
${WHATSALL_OFFER_ID}        vsdU_rlh_4wD0dI28dR_1RC_1D_iT_165
${TESTER}                   %{TESTER=AutomationBot}
${CYCLE_ADVANCE_MINUTES}    18

*** Test Cases ***

# =============================================================================
# TMSII01276126 – Voice call onnet charge < 60 sec from main balance
# =============================================================================
TMSII01276126 Voice Call Onnet Charge From Main Balance Less Than 60 Sec
    [Documentation]    Verify CCS charges 0.03€ for a voice onnet call < 60 sec from main balance.
    [Tags]             TMSII01276126    voice    charging    main-balance    AldiTalk

    # Pre-condition: ADB device must be connected
    Verify ADB Device Connected

    # Step 1 – Query wallet and note initial balance
    ${initial_balance}=    Get Main Balance    ${SUBSCRIPTION_ID}
    Log    Available main balance before call: ${initial_balance} EUR

    # Step 2 – Initiate voice call to onnet AldiTalk number
    Dial Phone Number    ${PHONE_NUMBER}

    # Step 3 – Disconnect after 50 seconds (< 60 sec threshold)
    Sleep    50s
    End Call

    # Step 4 – Verify EDR TefVoiceEvent fields
    Verify Voice EDR Fields    ${SUBSCRIPTION_ID}

    # Step 5 – Query wallet and verify 0.03€ deducted from main balance
    ${final_balance}=    Get Main Balance    ${SUBSCRIPTION_ID}
    ${deduction}=        Evaluate    round(${initial_balance} - ${final_balance}, 2)
    Should Be Equal As Numbers    ${deduction}    ${VOICE_CHARGE_EUR}
    Log    Deduction verified: ${deduction} EUR charged from main balance


# =============================================================================
# TMSII01276150 – Data usage charge from main balance
# =============================================================================
TMSII01276150 Data Usage Charge From Main Balance
    [Documentation]    Verify CCS charges 2.4€ (10 MB × 0.24€/MB) for data usage from main balance.
    [Tags]             TMSII01276150    data    charging    main-balance    AldiTalk

    # Pre-condition: ADB device must be connected
    Verify ADB Device Connected

    # Step 1 – Query wallet and note initial balance
    ${initial_balance}=    Get Main Balance    ${SUBSCRIPTION_ID}
    Log    Available main balance before data session: ${initial_balance} EUR

    # Step 2 – Initiate data session (target ~10 MB usage)
    Start Data Session
    Log    Data session running – consuming approx. ${DATA_SESSION_MB} MB
    Sleep    120s
    Stop Data Session

    # Step 3 – Verify EDR TefDataEvent fields
    Verify Data EDR Fields    ${SUBSCRIPTION_ID}

    # Step 4 – Query wallet and verify 2.4€ charged
    ${final_balance}=    Get Main Balance    ${SUBSCRIPTION_ID}
    ${deduction}=        Evaluate    round(${initial_balance} - ${final_balance}, 2)
    ${expected}=         Evaluate    round(${DATA_SESSION_MB} * ${DATA_CHARGE_PER_MB_EUR}, 2)
    Should Be Equal As Numbers    ${deduction}    ${expected}
    Log    Deduction verified: ${deduction} EUR charged from main balance


# =============================================================================
# TMSII01228917 – WhatsApp External Payment Purchase (TEF-165_003)
# =============================================================================
TMSII01228917 WhatsApp External Payment Purchase
    [Documentation]    Verify tefActiveEndDateTime is set to 6 months after purchase
    ...                when a WhatsAll pack is bought via External Payment.
    [Tags]             TMSII01228917    whatsapp    purchase    external-payment    TEF-165

    # Step 1 – Query subscription and note current tefActiveEndDateTime
    ${sub_before}=         Get Subscription    ${SUBSCRIPTION_ID}
    ${initial_end_date}=   Get From Dictionary    ${sub_before}    tefActiveEndDateTime
    Log    tefActiveEndDateTime before purchase: ${initial_end_date}
    ${purchase_timestamp}=    Get Current Date    result_format=%Y-%m-%dT%H:%M:%S

    # Step 2 – Purchase WhatsAll pack with External Payment
    Purchase WhatsAll Pack    ${SUBSCRIPTION_ID}    ${TESTER}

    # Step 3 – Query subscription and verify tefActiveEndDateTime = 6 months after purchase
    ${sub_after}=       Get Subscription    ${SUBSCRIPTION_ID}
    ${new_end_date}=    Get From Dictionary    ${sub_after}    tefActiveEndDateTime
    Log    tefActiveEndDateTime after purchase: ${new_end_date}
    Verify Date Is N Months After    ${new_end_date}    ${purchase_timestamp}    6

    ${next_transition}=    Get From Dictionary    ${sub_after}    nextStatusTransitionTimeEstimate
    Should Be Equal    ${new_end_date}    ${next_transition}
    Log    nextStatusTransitionTimeEstimate matches tefActiveEndDateTime: PASS

    # Step 4 – Verify MtxPurchaseEvent
    Verify Event Exists    MtxPurchaseEvent    ${SUBSCRIPTION_ID}

    # Step 5 – Verify MtxRecurringEvent
    Verify Event Exists    MtxRecurringEvent    ${SUBSCRIPTION_ID}

    # Step 6 – Verify MtxSubscriptionModifyEvent and its fields
    ${modify_event}=    Verify Event Exists    MtxSubscriptionModifyEvent    ${SUBSCRIPTION_ID}
    Verify Subscription Modify Event Fields    ${modify_event}    ${new_end_date}


# =============================================================================
# TMSII01228922 – NettoKom External Payment Recurring above 1.99€ (TEF-165_008)
# =============================================================================
TMSII01228922 NettoKom External Payment Recurring Above
    [Documentation]    Verify subscription expiry and cycle are updated correctly after
    ...                External Payment recurring renewal for a NettoKom account (price > 1.99€).
    [Tags]             TMSII01228922    nettokom    recurring    external-payment    TEF-165

    # Step 1 – Set tefActiveEndDateTime a few days in the future
    ${future_date}=    Add Time To Date
    ...    $(    Get Current Date    result_format=%Y-%m-%dT%H:%M:00.000000+0200    )
    ...    3 days
    ...    result_format=%Y-%m-%dT%H:%M:00.000000+0200
    ${near_expiry}=    Get Future Datetime String    days=3
    Set Subscription End Date    ${SUBSCRIPTION_ID}    ${near_expiry}    ${TESTER}

    # Step 2 – Query subscription and verify tefActiveEndDateTime and nextStatusTransitionTimeEstimate
    ${sub_step2}=       Get Subscription    ${SUBSCRIPTION_ID}
    ${active_end}=      Get From Dictionary    ${sub_step2}    tefActiveEndDateTime
    ${next_trans}=      Get From Dictionary    ${sub_step2}    nextStatusTransitionTimeEstimate
    Log    tefActiveEndDateTime: ${active_end}
    Should Be Equal    ${active_end}    ${next_trans}

    # Step 3 – Advance cycleEndTime 18 min in future to trigger MtxExternalPaymentRequestEvent
    ${bundle_resource_id}=    Get Bundle Resource Id    ${SUBSCRIPTION_ID}
    ${cycle_time_1}=          Get Future Datetime String    minutes=${CYCLE_ADVANCE_MINUTES}
    Set Offer Cycle End Time    ${SUBSCRIPTION_ID}    ${bundle_resource_id}    ${cycle_time_1}    ${TESTER}
    Log    Waiting for MtxExternalPaymentRequestEvent (up to 20 min)…
    Wait For Event    MtxExternalPaymentRequestEvent    ${SUBSCRIPTION_ID}    timeout=20 minutes

    # Step 4 – Get external payment record; note amount and resourceId
    ${payment_info}=       Get External Payment Info    ${SUBSCRIPTION_ID}
    ${amount}=             Get From Dictionary    ${payment_info}    amount
    ${payment_res_id}=     Get From Dictionary    ${payment_info}    resourceId
    ${payment_status}=     Get From Dictionary    ${payment_info}    paymentStatus
    Should Be Equal As Strings    ${payment_status}    due
    Log    External payment record — amount: ${amount}, resourceId: ${payment_res_id}, status: ${payment_status}

    # Step 5 – Submit external payment
    Update External Payment    ${SUBSCRIPTION_ID}    ${payment_res_id}    ${amount}    ${TESTER}

    # Step 6 – Verify paymentStatus changed to pending
    ${payment_info_2}=     Get External Payment Info    ${SUBSCRIPTION_ID}
    ${status_2}=           Get From Dictionary    ${payment_info_2}    paymentStatus
    Should Be Equal As Strings    ${status_2}    pending

    # Step 7 – Advance cycleEndTime again to trigger the next cycle
    ${cycle_time_2}=    Get Future Datetime String    minutes=${CYCLE_ADVANCE_MINUTES}
    Set Offer Cycle End Time    ${SUBSCRIPTION_ID}    ${bundle_resource_id}    ${cycle_time_2}    ${TESTER}
    Log    Waiting for next renewal cycle…
    Wait For Event    MtxRecurringEvent    ${SUBSCRIPTION_ID}    timeout=20 minutes

    # Step 8 – Query subscription; verify cycleEndTime = 4 weeks out, tefActiveEndDateTime = 12 months out
    ${sub_after}=      Get Subscription    ${SUBSCRIPTION_ID}
    ${new_end}=        Get From Dictionary    ${sub_after}    tefActiveEndDateTime
    ${next_trans_2}=   Get From Dictionary    ${sub_after}    nextStatusTransitionTimeEstimate
    Verify Cycle End Is Approximately N Weeks In Future    ${sub_after}    4
    Verify Active End Is Approximately N Months In Future    ${sub_after}    12
    Should Be Equal    ${new_end}    ${next_trans_2}
    Log    tefActiveEndDateTime: ${new_end} — nextStatusTransitionTimeEstimate matches: PASS

    # Step 9 – Verify paymentStatus = paid
    ${payment_info_3}=    Get External Payment Info    ${SUBSCRIPTION_ID}
    Should Be Equal As Strings    ${payment_info_3}[paymentStatus]    paid

    # Step 10 – Verify MtxExternalPaymentEvent
    Verify Event Exists    MtxExternalPaymentEvent    ${SUBSCRIPTION_ID}

    # Step 11 – Verify MtxRecurringEvent
    Verify Event Exists    MtxRecurringEvent    ${SUBSCRIPTION_ID}

    # Step 12 – Verify MtxRecurringChargeNotification
    Verify Event Exists    MtxRecurringChargeNotification    ${SUBSCRIPTION_ID}

    # Step 13 – Verify MtxSubscriptionModifyEvent fields
    ${modify_event}=    Verify Event Exists    MtxSubscriptionModifyEvent    ${SUBSCRIPTION_ID}
    Verify Subscription Modify Event Fields    ${modify_event}    ${new_end}


*** Keywords ***

# ── ADB ──────────────────────────────────────────────────────────────────────

Verify ADB Device Connected
    ${result}=    Run Process    ${ADB_PATH}    devices
    ...    timeout=${ADB_TIMEOUT}s    stdout=PIPE    stderr=STDOUT
    Should Be Equal As Integers    ${result.rc}    0
    Should Match Regexp    ${result.stdout}    (?m)^\\S+\\s+device$
    Log    ADB device verified as connected

Dial Phone Number
    [Arguments]    ${number}
    Log    Dialling ${number} via ADB…
    ${result}=    Run Process    ${ADB_PATH}    shell    am    start
    ...    -a    android.intent.action.CALL    -d    tel:${number}
    ...    timeout=${ADB_TIMEOUT}s    stdout=PIPE    stderr=STDOUT
    Should Be Equal As Integers    ${result.rc}    0
    Log    Dial command sent successfully

End Call
    ${result}=    Run Process    ${ADB_PATH}    shell    input    keyevent    6
    ...    timeout=${ADB_TIMEOUT}s    stdout=PIPE    stderr=STDOUT
    Should Be Equal As Integers    ${result.rc}    0
    Log    End-call keyevent sent (KEYCODE_ENDCALL)

Start Data Session
    # Enable mobile data via ADB (API 21+)
    ${result}=    Run Process    ${ADB_PATH}    shell    svc    data    enable
    ...    timeout=${ADB_TIMEOUT}s    stdout=PIPE    stderr=STDOUT
    Should Be Equal As Integers    ${result.rc}    0
    Log    Mobile data enabled on device

Stop Data Session
    ${result}=    Run Process    ${ADB_PATH}    shell    svc    data    disable
    ...    timeout=${ADB_TIMEOUT}s    stdout=PIPE    stderr=STDOUT
    Should Be Equal As Integers    ${result.rc}    0
    Log    Mobile data disabled on device

# ── REST – Wallet & Subscription ─────────────────────────────────────────────

Get Subscription
    [Arguments]    ${subscription_id}
    ${response}=    GET    ${BASE_URL}/rsgateway/data/openapi/subscription/${subscription_id}
    ...    expected_status=200
    RETURN    ${response.json()}

Get Main Balance
    [Arguments]    ${subscription_id}
    ${response}=    GET
    ...    ${BASE_URL}/rsgateway/data/openapi/subscription/${subscription_id}/wallet
    ...    expected_status=200
    ${balance}=    Get From Dictionary    ${response.json()}    availableAmount
    RETURN    ${balance}

Set Subscription End Date
    [Arguments]    ${subscription_id}    ${end_date}    ${tester}
    ${api_event}=    Create Dictionary
    ...    mtx_container_name=TefApiEventDataExtension
    ...    clientName=TestClient_${tester}
    ${attr}=    Create Dictionary
    ...    mtx_container_name=TefSubscriptionExtension
    ...    tefActiveEndDateTime=${end_date}
    ${body}=    Create Dictionary
    ...    mtx_container_name=MtxRequestSubscriptionModify
    ...    executeMode=normal
    ...    apiEventData=${api_event}
    ...    attr=${attr}
    PUT    ${BASE_URL}/rsgateway/data/openapi/subscription/${subscription_id}
    ...    json=${body}    expected_status=200
    Log    Subscription expiry set to: ${end_date}

Get Bundle Resource Id
    [Arguments]    ${subscription_id}
    ${sub}=    Get Subscription    ${subscription_id}
    ${resource_id}=    Get From Dictionary    ${sub}    resourceId
    RETURN    ${resource_id}

# ── REST – Offers ─────────────────────────────────────────────────────────────

Purchase WhatsAll Pack
    [Arguments]    ${subscription_id}    ${tester}
    ${api_event}=    Create Dictionary
    ...    mtx_container_name=TefApiEventDataExtension
    ...    ClientName=PostmanTestClient_${tester}
    ${offer_attr}=    Create Dictionary
    ...    mtx_container_name=TefPurchasedItemExtension
    ...    UnitGrantAmount=${4000}
    ...    c1ChargeId=RC00001
    ...    epcProductId=ABCD123456
    ...    epcProductName=WhatsAll UnitsPack
    ...    glCode=100000
    ...    paymentMethod=External Payment
    ...    productTaxCategory=Services_Telco
    ...    productTaxCode=A2
    ...    purchaseSequence=00001
    ...    quoteTaxCategory=NA
    ...    serviceInstanceId=0123456789
    ...    throttledProfile=1007
    ${param_value}=    Create Dictionary
    ...    mtx_container_name=MtxParameterDecimalValue    value=${10}
    ${param}=    Create Dictionary
    ...    mtx_container_name=MtxParameterData
    ...    parameterName=c1UnitPrice    value=${param_value}
    ${offer}=    Create Dictionary
    ...    mtx_container_name=MtxPurchasedOfferData
    ...    externalId=${WHATSALL_OFFER_ID}
    ...    attr=${offer_attr}
    ...    parameterArray=${[${param}]}
    ${body}=    Create Dictionary
    ...    mtx_container_name=MtxRequestSubscriberPurchaseOffer
    ...    executeMode=normal
    ...    apiEventData=${api_event}
    ...    offerRequestArray=${[${offer}]}
    POST    ${BASE_URL}/rsgateway/data/openapi/subscription/${subscription_id}/offers
    ...    json=${body}    expected_status=200
    Log    WhatsAll pack purchased via External Payment

Set Offer Cycle End Time
    [Arguments]    ${subscription_id}    ${resource_id}    ${cycle_time}    ${tester}
    ${api_event}=    Create Dictionary
    ...    mtx_container_name=TefApiEventDataExtension
    ...    clientName=TestClient_${tester}
    ${attr}=    Create Dictionary    mtx_container_name=TefPurchasedItemExtension
    ${cycle_data}=    Create Dictionary
    ...    mtx_container_name=MtxPurchasedItemCycleData
    ...    cycleEndTime=${cycle_time}
    ...    immediateChange=${TRUE}
    ${body}=    Create Dictionary
    ...    mtx_container_name=MtxRequestSubscriberModifyOffer
    ...    apiEventData=${api_event}
    ...    attr=${attr}
    ...    cycleData=${cycle_data}
    PUT
    ...    ${BASE_URL}/rsgateway/data/openapi/subscription/${subscription_id}/offers/${resource_id}
    ...    json=${body}    expected_status=200
    Log    Offer cycleEndTime advanced to: ${cycle_time}

# ── REST – External Payment ───────────────────────────────────────────────────

Get External Payment Info
    [Arguments]    ${subscription_id}
    ${response}=    GET
    ...    ${BASE_URL}/rsgateway/data/openapi/subscription/${subscription_id}/external_payment
    ...    expected_status=200
    ${info_list}=    Get From Dictionary    ${response.json()}    externalPaymentRequestInfoList
    RETURN    ${info_list}[0]

Update External Payment
    [Arguments]    ${subscription_id}    ${resource_id}    ${amount}    ${tester}
    ${api_event}=    Create Dictionary
    ...    mtx_container_name=TefApiEventDataExtension
    ...    clientName=${tester}
    ${body}=    Create Dictionary
    ...    mtx_container_name=MtxRequestSubscriberModifyExternalPayment
    ...    amount=${amount}
    ...    opType=payment
    ...    reason=TEF-165 External Payment Recurring
    ...    info=TEF-165 External Payment Recurring Test
    ...    apiEventData=${api_event}
    PUT
    ...    ${BASE_URL}/rsgateway/data/openapi/subscription/${subscription_id}/external_payment/${resource_id}
    ...    json=${body}    expected_status=200
    Log    External payment submitted — amount: ${amount}, resourceId: ${resource_id}

# ── Event Verification ────────────────────────────────────────────────────────

Verify Event Exists
    [Documentation]    Check that the named event exists for the subscription in NMC-Tools / Kafka.
    ...                Replace this keyword body with your event-query integration.
    [Arguments]    ${event_type}    ${subscription_id}
    Log    [VERIFY] ${event_type} for subscription ${subscription_id}
    Log    >> Use NMC-Tools or Kafka consumer to confirm this event exists and is consistent.
    # TODO: integrate with your event query API and add assertions here
    RETURN    ${event_type}

Wait For Event
    [Documentation]    Poll until the named event appears or timeout expires.
    [Arguments]    ${event_type}    ${subscription_id}    ${timeout}=20 minutes
    Log    Waiting up to ${timeout} for event: ${event_type}
    # TODO: replace with a polling loop that queries your event source

Verify Voice EDR Fields
    [Arguments]    ${subscription_id}
    Log    [EDR CHECK] TefVoiceEvent for subscription ${subscription_id}
    Log    Expected EDR fields:
    ...    catalogItemExternalId | productOfferExternalId | usageQuantity | amount
    ...    balanceResourceId | grossAmountBefore | grossAmountAfter
    ...    sessionId | calledStationId | callingStationId
    ...    originationCCName=DEU | originationCCRegion=OD | destinationTypeId=NC
    ...    roamingFlagId=false | callTypeId=MO | iddCCName=DEU | iddCCRegion=DD
    # TODO: query Kafka / Empirix / Anritsu trace and assert each field

Verify Data EDR Fields
    [Arguments]    ${subscription_id}
    Log    [EDR CHECK] TefDataEvent for subscription ${subscription_id}
    Log    Expected EDR fields:
    ...    catalogItemExternalId | productOfferExternalId | usageQuantity | amount
    ...    balanceResourceId | grossAmountBefore | grossAmountAfter
    ...    imsi | sessionId | originationCCName=DEU | originationCCRegion=OD
    ...    roamingFlagId=false
    # TODO: query Kafka / Empirix / Anritsu trace and assert each field

Verify Subscription Modify Event Fields
    [Arguments]    ${event}    ${expected_end_date}
    Log    [VERIFY] MtxSubscriptionModifyEvent
    Log    - associatedEventId must reference the MtxPurchaseEvent
    Log    - subscriptionInfoModified must list tefActiveEndDateTime=${expected_end_date}
    # TODO: parse event payload and add Should Contain / Should Be Equal assertions

# ── Date helpers ──────────────────────────────────────────────────────────────

Get Future Datetime String
    [Arguments]    ${days}=0    ${minutes}=0
    ${now}=       Get Current Date
    ${delta}=     Evaluate    (${days} * 86400 + ${minutes} * 60)
    ${future}=    Add Time To Date    ${now}    ${delta} seconds
    ...    result_format=%Y-%m-%dT%H:%M:00.000000+0200
    RETURN    ${future}

Verify Date Is N Months After
    [Arguments]    ${actual_date}    ${reference_date}    ${months}
    Log    [DATE CHECK] Verify ${actual_date} is ${months} month(s) after ${reference_date}
    # TODO: parse both dates and assert the month difference equals ${months}

Verify Cycle End Is Approximately N Weeks In Future
    [Arguments]    ${subscription}    ${weeks}
    ${cycle_end}=    Get From Dictionary    ${subscription}    cycleEndTime
    Log    [DATE CHECK] Verify cycleEndTime (${cycle_end}) is ${weeks} weeks in the future
    # TODO: parse cycleEndTime and compare against (now + weeks)

Verify Active End Is Approximately N Months In Future
    [Arguments]    ${subscription}    ${months}
    ${active_end}=    Get From Dictionary    ${subscription}    tefActiveEndDateTime
    Log    [DATE CHECK] Verify tefActiveEndDateTime (${active_end}) is ${months} months in the future
    # TODO: parse tefActiveEndDateTime and compare against (now + months)
