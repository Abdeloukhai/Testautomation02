*** Settings ***
# Import the Browser library for web automation
Library    Browser

# This runs before each test case
Test Setup    Open Browser To Example Page
# This runs after each test case
Test Teardown    Close Browser

*** Test Cases ***
User Can Search On Example Website
    [Documentation]    This test verifies a user can type text and search
    [Tags]    smoke    happy-path
    
    # Wait for the page to be fully loaded
    Wait For Load State    load
    
    # Type text into the search box
    Fill Text    input[name="q"]    Robot Framework is awesome!
    
    # Click the search button (Google's "Google Search" button)
    Click    input[value="Google Search"]
    
    # Wait for results to load
    Wait For Load State    load
    
    # Verify the search was successful by checking the page title
    Get Title    contains    Robot Framework
    
    # Take a screenshot for visual verification
    Take Screenshot    filename=search_results.png

Another Simple Test
    [Documentation]    This test just checks page title
    [Tags]    smoke    simple
    
    Get Title    equal    Google

*** Keywords ***
Open Browser To Example Page
    # Opens Google.com with visible browser (headless=False means you can see it)
    New Browser    browser=chromium    headless=False
    New Page    https://www.google.com