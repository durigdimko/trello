Description: Trello Task 2a

Scenario: Sign In scenario
Given I am on the main application page
When I click on an element by the xpath '//button[@data-analytics-button="greenSignupHeroButton"]'
When I click on an element by the xpath '//a[contains(@href,"/login")]'
When I enter '${userEmail}' in a field by the xpath '//input[@name="user"]'
When I click on an element by the xpath '//input[@id="login"]'
When I click on an element by the xpath '//input[@id="password"]'
When I enter '${userPassword}' in a field by the xpath '//input[@id="password"]'
When I click on an element by the xpath '//button[@id="login-submit"]'
When I wait until elements with the name 'Dzmitry's workspace' appear
Then the text 'Dzmitry's workspace' exists
