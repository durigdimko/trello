Scenario: Visual Establish scenario

Given I am on the main application page
When I ESTABLISH baseline with `main`
When I click on an element by the xpath '//button[@data-analytics-button="greenSignupHeroButton"]'
When I ESTABLISH baseline with `signup`
When I click on an element by the xpath '//a[contains(@href,"/login")]'
When I ESTABLISH baseline with `login`
When I click on an element by the xpath '//a[contains(@href,"http://developers.trello.com")]'
When I ESTABLISH baseline with `developers`
When I click on an element by the xpath '//a[contains(@href,"/platform/marketplace/atlassian-developer-terms/")]'
When I ESTABLISH baseline with `terms`

Scenario: Visual check scenario
Given I am on the main application page
When I COMPARE_AGAINST baseline with `main`
When I click on an element by the xpath '//button[@data-analytics-button="greenSignupHeroButton"]'
When I COMPARE_AGAINST baseline with `signup`
When I click on an element by the xpath '//a[contains(@href,"/login")]'
When I COMPARE_AGAINST baseline with `login` 
When I click on an element by the xpath '//a[contains(@href,"http://developers.trello.com")]'
When I COMPARE_AGAINST baseline with `developers`
When I click on an element by the xpath '//a[contains(@href,"/platform/marketplace/atlassian-developer-terms/")]'
When I COMPARE_AGAINST baseline with `terms`
