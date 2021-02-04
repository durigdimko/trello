Description: Trello Task 1b

Scenario: Create several users using Examples tables
Given I am on the main application page
When I click on an element by the xpath '//button[@data-analytics-button="greenSignupHeroButton"]'
When I click on an element by the xpath '//input[@name="email"]'
When I enter '<userEmail>' in a field by the xpath '//input[@name="email"]'
When I click on an element by the xpath '//input[@id="signup-submit"]'
When I wait until elements with the name 'displayName' appear
When I enter '<userName>' in a field by the xpath '//input[@id="displayName"]'
When I enter '<userPass>' in a field by the xpath '//input[@id="password"]'
When I click on an element by the xpath '//button[@id="signup-submit"]'
Examples:
|userEmail               |userName|userPass|
|durigdimko@gmail.com    |Durig   |#{generate(regexify '[a-z]{6}[A-Z]{2}')}|
|messiaonly@gmail.com|Dzmitry |#{generate(regexify '[a-z]{6}[A-Z]{2}')}|
